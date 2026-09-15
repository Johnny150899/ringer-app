import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/data/offline_cache.dart';

/// Interaktiver Vereinsbereich für bestätigte Vereinsmitglieder.
///
/// Der aufrufende Screen entscheidet über [role], welche redaktionellen
/// Funktionen verfügbar sind. Trainer, Organisation und Admins gelten als
/// Mitarbeitende und dürfen Veranstaltungen und Umfragen erstellen.
class ClubScreen extends StatefulWidget {
  const ClubScreen({
    super.key,
    required this.supabaseClient,
    required this.role,
    required this.onOpenMemberArea,
  });

  final SupabaseClient supabaseClient;
  final String role;
  final VoidCallback onOpenMemberArea;

  @override
  State<ClubScreen> createState() => _ClubScreenState();
}

class _ClubScreenState extends State<ClubScreen> {
  final _eventCache = OfflineCache();
  bool _showingSavedEvents = false;
  _ClubPageData? _data;
  bool _isInitialLoading = true;
  bool _isRefreshing = false;
  int _requestGeneration = 0;
  final Set<String> _busyActions = <String>{};
  final Map<String, Set<String>> _pollSelections = <String, Set<String>>{};
  RealtimeChannel? _clubChannel;
  Timer? _reloadDebounce;
  late DateTime _visibleEventMonth;
  DateTime? _selectedEventDate;
  bool _eventsLoading = false;
  int _eventRequestGeneration = 0;
  bool _calendarExpanded = false;
  bool _boardExpanded = false;

  bool get _isAdmin => widget.role.trim().toLowerCase() == 'admin';

  bool _canDelete(String authorId) {
    final userId = widget.supabaseClient.auth.currentUser?.id;
    return userId != null && (_isAdmin || authorId == userId);
  }

  bool get _canManageClub {
    final role = widget.role.trim().toLowerCase();
    return role == 'trainer' || role == 'organization' || role == 'admin';
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleEventMonth = DateTime(now.year, now.month);
    _subscribeToChanges();
    unawaited(_load(initial: true));
  }

  @override
  void didUpdateWidget(covariant ClubScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.supabaseClient != widget.supabaseClient) {
      final previous = _clubChannel;
      _clubChannel = null;
      if (previous != null) {
        unawaited(oldWidget.supabaseClient.removeChannel(previous));
      }
      _subscribeToChanges();
      unawaited(_load());
    } else if (oldWidget.role != widget.role) {
      unawaited(_load());
    }
  }

  void _subscribeToChanges() {
    final userId = widget.supabaseClient.auth.currentUser?.id;
    if (userId == null) return;
    var channel = widget.supabaseClient.channel('club-hub-$userId');
    for (final table in const [
      'club_events',
      'club_event_registrations',
      'club_polls',
      'club_poll_options',
      'club_poll_votes',
      'club_board_posts',
    ]) {
      channel = channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: (_) => _scheduleRealtimeReload(),
      );
    }
    _clubChannel = channel.subscribe();
  }

  void _scheduleRealtimeReload() {
    _reloadDebounce?.cancel();
    _reloadDebounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) unawaited(_load());
    });
  }

  @override
  void dispose() {
    _requestGeneration++;
    _reloadDebounce?.cancel();
    final channel = _clubChannel;
    if (channel != null) {
      unawaited(widget.supabaseClient.removeChannel(channel));
    }
    super.dispose();
  }

  Future<void> _load({bool initial = false}) async {
    final generation = ++_requestGeneration;
    final requestedEventMonth = _visibleEventMonth;
    if (mounted) {
      setState(() {
        if (initial && _data == null) {
          _isInitialLoading = true;
        } else {
          _isRefreshing = true;
        }
      });
    }

    final pending = _fetchPageData(requestedEventMonth);
    if (initial) {
      final cachedMonth = await _readEventCache(requestedEventMonth);
      final cachedNext = await _readEventCache();
      if (mounted &&
          generation == _requestGeneration &&
          (cachedMonth != null || cachedNext != null)) {
        setState(() {
          _data = (_data ?? _ClubPageData.empty()).copyWith(
            events: cachedMonth == null ? null : _Section(data: cachedMonth),
            upcoming: cachedNext == null ? null : _Section(data: cachedNext),
          );
          _showingSavedEvents = true;
          _isInitialLoading = false;
          _isRefreshing = true;
        });
      }
    }
    final loaded = await pending;
    if (!mounted || generation != _requestGeneration) return;
    setState(() {
      final sameVisibleMonth = _isSameMonth(
        requestedEventMonth,
        _visibleEventMonth,
      );
      _data = sameVisibleMonth
          ? loaded
          : loaded.copyWith(events: _data?.events);
      _isInitialLoading = false;
      _isRefreshing = false;
      _showingSavedEvents =
          loaded.events.error != null || loaded.upcoming.error != null;
      if (sameVisibleMonth) {
        _alignSelectedEventDate(loaded.events.data);
      }
    });
  }

  Future<_ClubPageData> _fetchPageData(DateTime eventMonth) async {
    // Alle Future-Aufrufe werden vor dem ersten await gestartet und laden damit
    // parallel. Ein Fehler in einer Sektion blockiert die anderen nicht.
    final events = _loadEventSection(eventMonth);
    final upcoming = _loadEventSection();
    final poll = _safeSection<_ClubPoll?>(_loadPoll, null, 'Umfrage');
    final board = _safeSection(
      _loadBoard,
      const _BoardData(posts: <_BoardPost>[], authorNames: <String, String>{}),
      'Schwarzes Brett',
    );
    final notifications = _safeSection(
      _loadNotificationPreferences,
      const _NotificationPreferences(),
      'Benachrichtigungen',
    );

    return _ClubPageData(
      events: await events,
      upcoming: await upcoming,
      poll: await poll,
      board: await board,
      notifications: await notifications,
    );
  }

  Future<_Section<T>> _safeSection<T>(
    Future<T> Function() loader,
    T fallback,
    String sectionName,
  ) async {
    try {
      return _Section<T>(data: await loader());
    } catch (error) {
      return _Section<T>(
        data: fallback,
        error: _friendlyError(error, sectionName),
      );
    }
  }

  String? _eventCacheKey(DateTime? month) {
    final userId = widget.supabaseClient.auth.currentUser?.id;
    if (userId == null) return null;
    return 'club.events.v1.$userId.${month == null ? 'next' : '${month.year}-${month.month}'}';
  }

  Future<List<_ClubEvent>?> _readEventCache([DateTime? month]) async {
    final key = _eventCacheKey(month);
    if (key == null) return null;
    try {
      final rows = await _eventCache.read(key);
      return rows?.map(_ClubEvent.fromCache).toList();
    } catch (_) {
      return null;
    }
  }

  Future<_Section<List<_ClubEvent>>> _loadEventSection([
    DateTime? month,
  ]) async {
    final section = await _safeSection(
      () => _loadEvents(month),
      const <_ClubEvent>[],
      'Vereinstermine',
    );
    if (section.error == null) return section;
    final cached = await _readEventCache(month);
    return _Section(data: cached ?? [], error: section.error);
  }

  // Without a month, fetch the next published event across all future months.
  Future<List<_ClubEvent>> _loadEvents([DateTime? eventMonth]) async {
    final cacheKey = _eventCacheKey(eventMonth);
    final rangeStart = eventMonth == null
        ? DateTime.now()
        : DateTime(eventMonth.year, eventMonth.month);
    var query = widget.supabaseClient
        .from('club_events')
        .select(
          'id,title,description,event_type,location,starts_at,ends_at,'
          'registration_deadline,participant_limit,helper_slots',
        )
        .eq('is_published', true)
        .gte('starts_at', rangeStart.toUtc().toIso8601String());
    if (eventMonth != null) {
      final monthEnd = DateTime(eventMonth.year, eventMonth.month + 1);
      query = query.lt('starts_at', monthEnd.toUtc().toIso8601String());
    }
    final response = await query
        .order('starts_at', ascending: true)
        .order('id', ascending: true)
        .limit(eventMonth == null ? 1 : 200);
    final rows = List<Map<String, dynamic>>.from(response);
    if (rows.isEmpty) {
      if (cacheKey != null) await _eventCache.write(cacheKey, []);
      return const <_ClubEvent>[];
    }

    final eventIds = rows.map((row) => row['id'].toString()).toList();
    final registrationResponse = await widget.supabaseClient
        .from('club_event_registrations')
        .select('event_id,user_id,attendance_status,is_helper')
        .inFilter('event_id', eventIds);
    final registrations = List<Map<String, dynamic>>.from(registrationResponse);
    final userId = widget.supabaseClient.auth.currentUser?.id;

    final result = rows
        .map((row) {
          final id = row['id'].toString();
          final forEvent = registrations.where(
            (registration) => registration['event_id'].toString() == id,
          );
          Map<String, dynamic>? own;
          if (userId != null) {
            for (final registration in forEvent) {
              if (registration['user_id']?.toString() == userId) {
                own = registration;
                break;
              }
            }
          }
          return _ClubEvent(
            id: id,
            title: _string(row['title'], fallback: 'Vereinstermin'),
            description: _string(row['description']),
            type: _eventTypeLabel(_string(row['event_type'], fallback: 'club')),
            location: _string(row['location']),
            startsAt: _date(row['starts_at']) ?? rangeStart,
            endsAt: _date(row['ends_at']),
            registrationDeadline: _date(row['registration_deadline']),
            participantLimit: _integer(row['participant_limit']),
            helperSlots: _integer(row['helper_slots']) ?? 0,
            attendingCount: forEvent
                .where(
                  (registration) =>
                      registration['attendance_status'] == 'attending',
                )
                .length,
            helperCount: forEvent
                .where((registration) => registration['is_helper'] == true)
                .length,
            ownStatus: own?['attendance_status'] as String?,
            isHelper: own?['is_helper'] == true,
          );
        })
        .toList(growable: false);
    if (cacheKey != null) {
      await _eventCache.write(
        cacheKey,
        result.map((event) => event.toCache()).toList(),
      );
    }
    return result;
  }

  void _alignSelectedEventDate(List<_ClubEvent> events) {
    final selected = _selectedEventDate;
    if (selected != null && _isSameMonth(selected, _visibleEventMonth)) return;
    if (events.isNotEmpty) {
      final first = events.first.startsAt;
      _selectedEventDate = DateTime(first.year, first.month, first.day);
      return;
    }
    final now = DateTime.now();
    _selectedEventDate = _isSameMonth(now, _visibleEventMonth)
        ? DateTime(now.year, now.month, now.day)
        : DateTime(_visibleEventMonth.year, _visibleEventMonth.month);
  }

  List<_ClubEvent> _eventsForSelectedDate(List<_ClubEvent> events) {
    final selected = _selectedEventDate;
    if (selected == null) return const [];
    return events
        .where((event) => _isSameDay(event.startsAt, selected))
        .toList(growable: false);
  }

  void _changeEventMonth(int offset) {
    if (_eventsLoading || _isInitialLoading) return;
    setState(() {
      _visibleEventMonth = DateTime(
        _visibleEventMonth.year,
        _visibleEventMonth.month + offset,
      );
      _selectedEventDate = null;
    });
    unawaited(_loadMonthEvents());
  }

  Future<void> _loadMonthEvents() async {
    final generation = ++_eventRequestGeneration;
    final requestedMonth = _visibleEventMonth;
    setState(() => _eventsLoading = true);
    final cached = await _readEventCache(requestedMonth);
    if (mounted && generation == _eventRequestGeneration && cached != null) {
      setState(
        () => _data = (_data ?? _ClubPageData.empty()).copyWith(
          events: _Section(data: cached),
        ),
      );
    }
    final events = await _loadEventSection(requestedMonth);
    if (!mounted || generation != _eventRequestGeneration) return;
    setState(() {
      if (_isSameMonth(requestedMonth, _visibleEventMonth)) {
        _data = (_data ?? _ClubPageData.empty()).copyWith(events: events);
        _alignSelectedEventDate(events.data);
      }
      _eventsLoading = false;
    });
  }

  Future<void> _openEventDetails(_ClubEvent event) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => _EventDetailsSheet(
          event: event,
          onAttend: () {
            Navigator.pop(sheetContext);
            unawaited(_setEventResponse(event, 'attending'));
          },
          onDecline: () {
            Navigator.pop(sheetContext);
            unawaited(_setEventResponse(event, 'not_attending'));
          },
          onToggleHelper: () {
            Navigator.pop(sheetContext);
            unawaited(
              _setEventResponse(event, 'attending', isHelper: !event.isHelper),
            );
          },
        ),
      );

  Future<_ClubPoll?> _loadPoll() async {
    final response = await widget.supabaseClient
        .from('club_polls')
        .select(
          'id,question,description,allow_multiple,closes_at,created_at,created_by',
        )
        .eq('is_published', true)
        .order('created_at', ascending: false)
        .limit(10);
    final now = DateTime.now();
    final rows = List<Map<String, dynamic>>.from(response);
    Map<String, dynamic>? current;
    for (final row in rows) {
      final closesAt = _date(row['closes_at']);
      if (closesAt == null || closesAt.isAfter(now)) {
        current = row;
        break;
      }
    }
    if (current == null) return null;

    final pollId = current['id'].toString();
    final optionsResponse = await widget.supabaseClient
        .from('club_poll_options')
        .select('id,label,sort_order')
        .eq('poll_id', pollId)
        .order('sort_order');
    final optionRows = List<Map<String, dynamic>>.from(optionsResponse);
    final optionIds = optionRows.map((row) => row['id'].toString()).toList();

    var votes = const <Map<String, dynamic>>[];
    if (optionIds.isNotEmpty) {
      final voteResponse = await widget.supabaseClient
          .from('club_poll_votes')
          .select('option_id,user_id')
          .eq('poll_id', pollId);
      votes = List<Map<String, dynamic>>.from(voteResponse);
    }
    final userId = widget.supabaseClient.auth.currentUser?.id;

    return _ClubPoll(
      id: pollId,
      authorId: _string(current['created_by']),
      question: _string(current['question'], fallback: 'Aktuelle Umfrage'),
      description: _string(current['description']),
      allowMultiple: current['allow_multiple'] == true,
      closesAt: _date(current['closes_at']),
      options: optionRows
          .map((row) {
            final optionId = row['id'].toString();
            return _PollOption(
              id: optionId,
              label: _string(row['label'], fallback: 'Option'),
              votes: votes
                  .where((vote) => vote['option_id'].toString() == optionId)
                  .length,
            );
          })
          .toList(growable: false),
      votedOptionIds: votes
          .where((vote) => vote['user_id']?.toString() == userId)
          .map((vote) => vote['option_id'].toString())
          .toSet(),
    );
  }

  Future<_BoardData> _loadBoard() async {
    final response = await widget.supabaseClient
        .from('club_board_posts')
        .select(
          'id,title,body,category,is_pinned,expires_at,created_by,created_at',
        )
        .order('is_pinned', ascending: false)
        .order('created_at', ascending: false)
        .limit(30);
    final now = DateTime.now();
    final posts = List<Map<String, dynamic>>.from(response)
        .where((row) {
          final expiresAt = _date(row['expires_at']);
          return expiresAt == null || expiresAt.isAfter(now);
        })
        .map(
          (row) => _BoardPost(
            id: row['id'].toString(),
            title: _string(row['title'], fallback: 'Mitteilung'),
            body: _string(row['body']),
            category: _boardCategoryLabel(
              _string(row['category'], fallback: 'general'),
            ),
            isPinned: row['is_pinned'] == true,
            authorId: _string(row['created_by']),
            createdAt: _date(row['created_at']) ?? now,
          ),
        )
        .toList(growable: false);

    final authorIds = posts
        .map((post) => post.authorId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final names = <String, String>{};
    if (authorIds.isNotEmpty) {
      try {
        final profileResponse = await widget.supabaseClient
            .from('profiles')
            .select('id,first_name,last_name')
            .inFilter('id', authorIds);
        for (final profile in List<Map<String, dynamic>>.from(
          profileResponse,
        )) {
          final name = [
            _string(profile['first_name']),
            _string(profile['last_name']),
          ].where((part) => part.isNotEmpty).join(' ');
          if (name.isNotEmpty) names[profile['id'].toString()] = name;
        }
      } catch (_) {
        // Die Beiträge bleiben auch sichtbar, wenn Profilnamen gesperrt sind.
      }
    }
    return _BoardData(posts: posts, authorNames: names);
  }

  Future<_NotificationPreferences> _loadNotificationPreferences() async {
    final userId = widget.supabaseClient.auth.currentUser?.id;
    if (userId == null) return const _NotificationPreferences();
    final response = await widget.supabaseClient
        .from('club_notification_preferences')
        .select(
          'events_enabled,event_reminders_enabled,helper_requests_enabled,'
          'polls_enabled,board_enabled,news_enabled,training_enabled,'
          'league_enabled',
        )
        .eq('user_id', userId)
        .maybeSingle();
    if (response == null) return const _NotificationPreferences();
    return _NotificationPreferences.fromMap(response);
  }

  Future<void> _setEventResponse(
    _ClubEvent event,
    String status, {
    bool? isHelper,
  }) async {
    final userId = _requireUserId();
    await _runAction(
      'event:${event.id}',
      () async {
        await widget.supabaseClient.from('club_event_registrations').upsert({
          'event_id': int.parse(event.id),
          'user_id': userId,
          'attendance_status': status,
          'is_helper': status == 'attending'
              ? (isHelper ?? event.isHelper)
              : false,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'event_id,user_id');
      },
      status == 'attending'
          ? 'Du bist angemeldet.'
          : 'Deine Absage ist gespeichert.',
    );
  }

  Future<void> _savePollVote(_ClubPoll poll) async {
    final choices = _pollSelections[poll.id] ?? poll.votedOptionIds;
    if (choices.isEmpty) return;
    final userId = _requireUserId();
    await _runAction('poll:${poll.id}', () async {
      await widget.supabaseClient
          .from('club_poll_votes')
          .delete()
          .eq('poll_id', poll.id)
          .eq('user_id', userId);
      await widget.supabaseClient
          .from('club_poll_votes')
          .insert(
            choices
                .map(
                  (optionId) => {
                    'poll_id': int.parse(poll.id),
                    'option_id': int.parse(optionId),
                    'user_id': userId,
                  },
                )
                .toList(),
          );
      _pollSelections.remove(poll.id);
    }, 'Deine Stimme wurde gespeichert.');
  }

  Future<void> _createEvent() async {
    final draft = await showDialog<_NewEvent>(
      context: context,
      builder: (_) =>
          _CreateEventDialog(initialDate: _selectedEventDate ?? DateTime.now()),
    );
    if (draft == null) return;
    setState(() {
      _visibleEventMonth = DateTime(draft.startsAt.year, draft.startsAt.month);
      _selectedEventDate = DateTime(
        draft.startsAt.year,
        draft.startsAt.month,
        draft.startsAt.day,
      );
    });
    final userId = _requireUserId();
    await _runAction('create-event', () async {
      await widget.supabaseClient.from('club_events').insert({
        'title': draft.title,
        'description': _nullIfEmpty(draft.description),
        'event_type': 'club',
        'location': _nullIfEmpty(draft.location),
        'starts_at': draft.startsAt.toUtc().toIso8601String(),
        'ends_at': draft.startsAt
            .add(const Duration(hours: 2))
            .toUtc()
            .toIso8601String(),
        'helper_slots': draft.helperSlots,
        'is_published': true,
        'created_by': userId,
      });
    }, 'Veranstaltung wurde veröffentlicht.');
  }

  Future<void> _createPoll() async {
    final draft = await showDialog<_NewPoll>(
      context: context,
      builder: (_) => const _CreatePollDialog(),
    );
    if (draft == null) return;
    final userId = _requireUserId();
    await _runAction('create-poll', () async {
      final poll = await widget.supabaseClient
          .from('club_polls')
          .insert({
            'question': draft.question,
            'description': _nullIfEmpty(draft.description),
            'allow_multiple': draft.allowMultiple,
            'closes_at': draft.closesAt.toUtc().toIso8601String(),
            'is_published': true,
            'created_by': userId,
          })
          .select('id')
          .single();
      final pollId = poll['id'];
      await widget.supabaseClient.from('club_poll_options').insert([
        for (var index = 0; index < draft.options.length; index++)
          {
            'poll_id': pollId,
            'label': draft.options[index],
            'sort_order': index,
          },
      ]);
    }, 'Umfrage wurde veröffentlicht.');
  }

  Future<void> _createBoardPost() async {
    final draft = await showDialog<_NewBoardPost>(
      context: context,
      builder: (_) => const _CreateBoardPostDialog(),
    );
    if (draft == null) return;
    final userId = _requireUserId();
    await _runAction('create-board-post', () async {
      await widget.supabaseClient.from('club_board_posts').insert({
        'title': draft.title,
        'body': draft.body,
        'category': draft.category,
        'is_pinned': false,
        'created_by': userId,
      });
    }, 'Dein Eintrag wurde veröffentlicht.');
  }

  Future<void> _deleteClubItem({
    required String table,
    required String id,
    required String authorId,
    required String label,
  }) async {
    if (!_canDelete(authorId)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('$label löschen?'),
        content: Text(
          'Der $label und zugehörige Daten werden dauerhaft entfernt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _runAction('delete:$table:$id', () async {
      final deleted = await widget.supabaseClient
          .from(table)
          .delete()
          .eq('id', id)
          .select('id');
      if ((deleted as List).isEmpty) {
        throw StateError(
          'Keine Berechtigung zum Löschen oder Eintrag nicht gefunden.',
        );
      }
    }, '$label wurde gelöscht.');
  }

  Future<void> _runAction(
    String key,
    Future<void> Function() action,
    String successMessage,
  ) async {
    if (_busyActions.contains(key)) return;
    setState(() => _busyActions.add(key));
    try {
      await action();
      await _load();
      if (mounted) _showMessage(successMessage);
    } catch (error) {
      if (mounted) _showMessage(_friendlyError(error, 'Speichern'));
    } finally {
      if (mounted) setState(() => _busyActions.remove(key));
    }
  }

  String _requireUserId() {
    final userId = widget.supabaseClient.auth.currentUser?.id;
    if (userId == null) throw StateError('Keine aktive Anmeldung');
    return userId;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final data = _data ?? _ClubPageData.empty();
    final selectedEvents = _eventsForSelectedDate(data.events.data);
    final upcomingEvents = data.upcoming.data;
    final boardPosts = data.board.data.posts;
    final visibleBoardPosts = _boardExpanded
        ? boardPosts
        : boardPosts.take(3).toList(growable: false);

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.red,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (_showingSavedEvents)
            SliverToBoxAdapter(
              child: TextButton(
                onPressed: _isRefreshing ? null : _load,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white70,
                ),
                child: Text(
                  _isRefreshing
                      ? 'Gespeicherte Termine · wird aktualisiert …'
                      : 'Termine nicht aktualisiert · Erneut versuchen',
                ),
              ),
            ),
          if (_isRefreshing || _isInitialLoading)
            const SliverToBoxAdapter(
              child: LinearProgressIndicator(
                minHeight: 2,
                color: AppColors.red,
                backgroundColor: Colors.transparent,
              ),
            ),
          SliverToBoxAdapter(
            child: _SectionTitle(
              'Als Nächstes',
              action: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton.icon(
                    onPressed: () =>
                        setState(() => _calendarExpanded = !_calendarExpanded),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    icon: Icon(
                      _calendarExpanded
                          ? Icons.expand_less_rounded
                          : Icons.calendar_month_rounded,
                      size: 18,
                    ),
                    label: Text(_calendarExpanded ? 'Schließen' : 'Kalender'),
                  ),
                  if (_canManageClub)
                    _SectionAddButton(
                      tooltip: 'Veranstaltung erstellen',
                      busy: _busyActions.contains('create-event'),
                      onPressed: _createEvent,
                    ),
                ],
              ),
            ),
          ),
          if (data.upcoming.error != null)
            SliverToBoxAdapter(child: _InlineError(data.upcoming.error!)),
          if (upcomingEvents.isEmpty && data.upcoming.error == null)
            const SliverToBoxAdapter(
              child: _EmptyCard(
                icon: Icons.event_available_outlined,
                text: 'Aktuell ist kein weiterer Vereinstermin geplant.',
              ),
            )
          else if (upcomingEvents.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              sliver: SliverToBoxAdapter(
                child: _EventListTile(
                  event: upcomingEvents.first,
                  onTap: () => _openEventDetails(upcomingEvents.first),
                ),
              ),
            ),
          if (_calendarExpanded) ...[
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            if (data.events.error != null)
              SliverToBoxAdapter(child: _InlineError(data.events.error!)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              sliver: SliverToBoxAdapter(
                child: _EventCalendar(
                  month: _visibleEventMonth,
                  selectedDate: _selectedEventDate,
                  events: data.events.data,
                  loading: _eventsLoading || _isInitialLoading,
                  onPreviousMonth: () => _changeEventMonth(-1),
                  onNextMonth: () => _changeEventMonth(1),
                  onDateSelected: (date) =>
                      setState(() => _selectedEventDate = date),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            if (data.events.error == null && selectedEvents.isEmpty)
              SliverToBoxAdapter(
                child: _EmptyCard(
                  icon: Icons.event_available_outlined,
                  text: data.events.data.isEmpty
                      ? 'In diesem Monat gibt es keine Veranstaltungen.'
                      : 'An diesem Tag gibt es keine Veranstaltung.',
                ),
              )
            else if (selectedEvents.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                sliver: SliverList.separated(
                  itemCount: selectedEvents.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final event = selectedEvents[index];
                    return _EventListTile(
                      event: event,
                      onTap: () => _openEventDetails(event),
                    );
                  },
                ),
              ),
          ],
          SliverToBoxAdapter(
            child: _SectionTitle(
              'Aktuelle Umfrage',
              action: _canManageClub
                  ? _SectionAddButton(
                      tooltip: 'Umfrage erstellen',
                      busy: _busyActions.contains('create-poll'),
                      onPressed: _createPoll,
                    )
                  : null,
            ),
          ),
          if (data.poll.error != null)
            SliverToBoxAdapter(child: _InlineError(data.poll.error!))
          else if (data.poll.data == null)
            const SliverToBoxAdapter(
              child: _EmptyCard(
                icon: Icons.poll_outlined,
                text: 'Aktuell gibt es keine offene Umfrage.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              sliver: SliverToBoxAdapter(
                child: _PollCard(
                  poll: data.poll.data!,
                  onDelete: _canDelete(data.poll.data!.authorId)
                      ? () => _deleteClubItem(
                          table: 'club_polls',
                          id: data.poll.data!.id,
                          authorId: data.poll.data!.authorId,
                          label: 'Umfrage',
                        )
                      : null,
                  selection:
                      _pollSelections[data.poll.data!.id] ??
                      data.poll.data!.votedOptionIds,
                  busy: _busyActions.contains('poll:${data.poll.data!.id}'),
                  onOptionTap: (optionId) {
                    final poll = data.poll.data!;
                    final selected = Set<String>.from(
                      _pollSelections[poll.id] ?? poll.votedOptionIds,
                    );
                    if (poll.allowMultiple) {
                      if (!selected.remove(optionId)) selected.add(optionId);
                    } else {
                      selected
                        ..clear()
                        ..add(optionId);
                    }
                    setState(() => _pollSelections[poll.id] = selected);
                  },
                  onSubmit: () => _savePollVote(data.poll.data!),
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: _SectionTitle(
              'Schwarzes Brett',
              action: _SectionAddButton(
                tooltip: 'Eintrag erstellen',
                busy: _busyActions.contains('create-board-post'),
                onPressed: _createBoardPost,
              ),
            ),
          ),
          if (data.board.error != null)
            SliverToBoxAdapter(child: _InlineError(data.board.error!))
          else if (data.board.data.posts.isEmpty)
            const SliverToBoxAdapter(
              child: _EmptyCard(
                icon: Icons.dashboard_outlined,
                text: 'Noch keine Einträge vorhanden.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              sliver: SliverList.separated(
                itemCount: visibleBoardPosts.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, index) {
                  final post = visibleBoardPosts[index];
                  return _BoardPostCard(
                    post: post,
                    authorName: data.board.data.authorNames[post.authorId],
                    onDelete: _canDelete(post.authorId)
                        ? () => _deleteClubItem(
                            table: 'club_board_posts',
                            id: post.id,
                            authorId: post.authorId,
                            label: 'Eintrag',
                          )
                        : null,
                  );
                },
              ),
            ),
          if (boardPosts.length > 3)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: TextButton(
                  onPressed: () =>
                      setState(() => _boardExpanded = !_boardExpanded),
                  child: Text(
                    _boardExpanded
                        ? 'Weniger anzeigen'
                        : 'Alle Einträge anzeigen',
                  ),
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 112)),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 24, 18, 10),
    child: Row(
      children: [
        Container(
          width: 4,
          height: 22,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        ?action,
      ],
    ),
  );
}

class _SectionAddButton extends StatelessWidget {
  const _SectionAddButton({
    required this.tooltip,
    required this.busy,
    required this.onPressed,
  });

  final String tooltip;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: busy ? null : onPressed,
    style: IconButton.styleFrom(
      foregroundColor: Colors.white,
      disabledForegroundColor: Colors.white54,
      backgroundColor: Colors.white.withValues(alpha: .12),
      side: const BorderSide(color: Colors.white24),
    ),
    icon: busy
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : const Icon(Icons.add_rounded),
  );
}

class _EventCalendar extends StatelessWidget {
  const _EventCalendar({
    required this.month,
    required this.selectedDate,
    required this.events,
    required this.loading,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onDateSelected,
  });

  final DateTime month;
  final DateTime? selectedDate;
  final List<_ClubEvent> events;
  final bool loading;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month);
    final leadingDays = firstDay.weekday - DateTime.monday;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final calendarCellCount = ((leadingDays + daysInMonth + 6) ~/ 7) * 7;
    final eventCounts = <int, int>{};
    for (final event in events) {
      if (_isSameMonth(event.startsAt, month)) {
        eventCounts.update(
          event.startsAt.day,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDesign.radiusLarge),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Vorheriger Monat',
                onPressed: loading ? null : onPreviousMonth,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  '${_monthName(month.month)} ${month.year}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Nächster Monat',
                onPressed: loading ? null : onNextMonth,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          if (loading)
            const LinearProgressIndicator(
              minHeight: 2,
              color: AppColors.red,
              backgroundColor: AppColors.outline,
            )
          else
            const SizedBox(height: 2),
          const SizedBox(height: 9),
          Row(
            children: [
              for (final label in const [
                'Mo',
                'Di',
                'Mi',
                'Do',
                'Fr',
                'Sa',
                'So',
              ])
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          GridView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            primary: false,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: calendarCellCount,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: .94,
            ),
            itemBuilder: (context, index) {
              final day = index - leadingDays + 1;
              if (day < 1 || day > daysInMonth) {
                return const SizedBox.shrink();
              }
              final date = DateTime(month.year, month.month, day);
              final selected =
                  selectedDate != null && _isSameDay(selectedDate!, date);
              final isToday = _isSameDay(DateTime.now(), date);
              final count = eventCounts[day] ?? 0;
              return Semantics(
                button: true,
                selected: selected,
                label: count == 0
                    ? '$day. ${_monthName(month.month)}'
                    : '$day. ${_monthName(month.month)}, $count Veranstaltung${count == 1 ? '' : 'en'}',
                child: InkWell(
                  onTap: loading ? null : () => onDateSelected(date),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.red : Colors.transparent,
                      borderRadius: BorderRadius.circular(11),
                      border: isToday && !selected
                          ? Border.all(color: AppColors.red)
                          : null,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text(
                          '$day',
                          style: TextStyle(
                            color: selected ? Colors.white : AppColors.text,
                            fontWeight: selected || count > 0
                                ? FontWeight.w900
                                : FontWeight.w500,
                          ),
                        ),
                        if (count > 0)
                          Positioned(
                            bottom: 4,
                            child: Container(
                              width: count > 1 ? 14 : 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: selected ? Colors.white : AppColors.red,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              alignment: Alignment.center,
                              child: count > 1
                                  ? Text(
                                      '$count',
                                      style: TextStyle(
                                        color: selected
                                            ? AppColors.red
                                            : Colors.white,
                                        fontSize: 7,
                                        height: .7,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          if (selectedDate != null) ...[
            const Divider(height: 18),
            Row(
              children: [
                const Icon(Icons.today_rounded, size: 18, color: AppColors.red),
                const SizedBox(width: 8),
                Text(
                  _formatDate(selectedDate!),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EventListTile extends StatelessWidget {
  const _EventListTile({required this.event, required this.onTap});

  final _ClubEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(AppDesign.radiusMedium),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDesign.radiusMedium),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 52,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE3EA),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Column(
                children: [
                  Text(
                    _formatTime(event.startsAt),
                    style: const TextStyle(
                      color: AppColors.red,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Text(
                    'UHR',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    event.location.isEmpty ? event.type : event.location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  if (event.ownStatus != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      event.ownStatus == 'attending'
                          ? event.isHelper
                                ? 'Angemeldet · als Helfer'
                                : 'Angemeldet'
                          : 'Abgesagt',
                      style: TextStyle(
                        color: event.ownStatus == 'attending'
                            ? AppColors.success
                            : AppColors.red,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    ),
  );
}

class _EventDetailsSheet extends StatelessWidget {
  const _EventDetailsSheet({
    required this.event,
    required this.onAttend,
    required this.onDecline,
    required this.onToggleHelper,
  });

  final _ClubEvent event;
  final VoidCallback onAttend;
  final VoidCallback onDecline;
  final VoidCallback onToggleHelper;

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    heightFactor: .86,
    child: DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outline,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 8, 2),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Veranstaltung',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Schließen',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: _EventCard(
                  event: event,
                  busy: false,
                  onAttend: onAttend,
                  onDecline: onDecline,
                  onToggleHelper: onToggleHelper,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.busy,
    required this.onAttend,
    required this.onDecline,
    required this.onToggleHelper,
  });

  final _ClubEvent event;
  final bool busy;
  final VoidCallback onAttend;
  final VoidCallback onDecline;
  final VoidCallback onToggleHelper;

  @override
  Widget build(BuildContext context) {
    final registrationClosed =
        event.registrationDeadline?.isBefore(DateTime.now()) ?? false;
    final isFull =
        event.participantLimit != null &&
        event.attendingCount >= event.participantLimit! &&
        event.ownStatus != 'attending';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDesign.radiusLarge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE3EA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.event_rounded, color: AppColors.red),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _formatEventSchedule(event),
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _SmallBadge(event.type),
            ],
          ),
          if (event.location.isNotEmpty) ...[
            const SizedBox(height: 12),
            _MetaLine(icon: Icons.place_outlined, text: event.location),
          ],
          if (event.registrationDeadline != null) ...[
            const SizedBox(height: 9),
            _MetaLine(
              icon: Icons.event_busy_outlined,
              text:
                  'Anmeldeschluss: ${_formatDate(event.registrationDeadline!)} · ${_formatTime(event.registrationDeadline!)} Uhr',
            ),
          ],
          if (event.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              event.description,
              style: const TextStyle(color: AppColors.muted),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _CountLabel(
                icon: Icons.group_rounded,
                text:
                    '${event.attendingCount}${event.participantLimit == null ? '' : '/${event.participantLimit}'} angemeldet',
              ),
              if (event.helperSlots > 0)
                _CountLabel(
                  icon: Icons.volunteer_activism_rounded,
                  text: '${event.helperCount}/${event.helperSlots} Helfer',
                ),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: busy || registrationClosed || isFull
                      ? null
                      : onAttend,
                  style: FilledButton.styleFrom(
                    backgroundColor: event.ownStatus == 'attending'
                        ? AppColors.success
                        : AppColors.navy,
                  ),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Dabei'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy || registrationClosed ? null : onDecline,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.red,
                    side: BorderSide(
                      color: event.ownStatus == 'not_attending'
                          ? AppColors.red
                          : AppColors.outline,
                    ),
                  ),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Absagen'),
                ),
              ),
            ],
          ),
          if (event.helperSlots > 0 && event.ownStatus == 'attending') ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed:
                    busy ||
                        (!event.isHelper &&
                            event.helperCount >= event.helperSlots)
                    ? null
                    : onToggleHelper,
                icon: Icon(
                  event.isHelper
                      ? Icons.volunteer_activism_rounded
                      : Icons.volunteer_activism_outlined,
                ),
                label: Text(
                  event.isHelper
                      ? 'Als Helfer eingetragen'
                      : 'Als Helfer melden',
                ),
              ),
            ),
          ],
          if (registrationClosed)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Die Anmeldung ist geschlossen.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ),
          if (isFull)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Die Veranstaltung ist bereits voll.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class _PollCard extends StatelessWidget {
  const _PollCard({
    required this.poll,
    this.onDelete,
    required this.selection,
    required this.busy,
    required this.onOptionTap,
    required this.onSubmit,
  });

  final _ClubPoll poll;
  final VoidCallback? onDelete;
  final Set<String> selection;
  final bool busy;
  final ValueChanged<String> onOptionTap;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppDesign.radiusLarge),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const CircleAvatar(
              backgroundColor: Color(0xFFFFE3EA),
              child: Icon(Icons.poll_rounded, color: AppColors.red),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                poll.question,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (onDelete != null)
              IconButton(
                tooltip: 'Umfrage löschen',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
          ],
        ),
        if (poll.description.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            poll.description,
            style: const TextStyle(color: AppColors.muted),
          ),
        ],
        if (poll.allowMultiple)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Mehrfachauswahl möglich',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
        const SizedBox(height: 12),
        for (final option in poll.options)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: busy ? null : () => onOptionTap(option.id),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: selection.contains(option.id)
                      ? const Color(0xFFFFEDF2)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selection.contains(option.id)
                        ? AppColors.red
                        : AppColors.outline,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      selection.contains(option.id)
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: selection.contains(option.id)
                          ? AppColors.red
                          : AppColors.muted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(option.label)),
                    Text(
                      '${option.votes}',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: busy || selection.isEmpty ? null : onSubmit,
            icon: const Icon(Icons.how_to_vote_rounded),
            label: Text(busy ? 'Wird gespeichert…' : 'Stimme speichern'),
          ),
        ),
        if (poll.closesAt != null)
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text(
              'Offen bis ${_formatDate(poll.closesAt!)}',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
      ],
    ),
  );
}

class _BoardPostCard extends StatelessWidget {
  const _BoardPostCard({
    required this.post,
    required this.authorName,
    this.onDelete,
  });

  final _BoardPost post;
  final String? authorName;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppDesign.radiusMedium),
      border: post.isPinned
          ? Border.all(color: AppColors.red.withValues(alpha: .35))
          : null,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (post.isPinned) ...[
              const Icon(
                Icons.push_pin_rounded,
                size: 18,
                color: AppColors.red,
              ),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                post.title,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            _SmallBadge(post.category),
            if (onDelete != null)
              IconButton(
                tooltip: 'Eintrag löschen',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
          ],
        ),
        if (post.body.isNotEmpty) ...[
          const SizedBox(height: 7),
          Text(post.body, style: const TextStyle(color: AppColors.muted)),
        ],
        const SizedBox(height: 9),
        Text(
          '${authorName ?? 'Vereinsmitglied'} · ${_formatDate(post.createdAt)}',
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    ),
  );
}

class _NotificationSettingsSheet extends StatefulWidget {
  const _NotificationSettingsSheet({
    required this.initialPreferences,
    required this.enabled,
    required this.error,
    required this.onSave,
  });

  final _NotificationPreferences initialPreferences;
  final bool enabled;
  final String? error;
  final Future<bool> Function(_NotificationPreferences) onSave;

  @override
  State<_NotificationSettingsSheet> createState() =>
      _NotificationSettingsSheetState();
}

class _NotificationSettingsSheetState
    extends State<_NotificationSettingsSheet> {
  late _NotificationPreferences _preferences;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _preferences = widget.initialPreferences;
  }

  Future<void> _update(_NotificationPreferences next) async {
    if (_saving || !widget.enabled) return;
    final previous = _preferences;
    setState(() {
      _preferences = next;
      _saving = true;
    });
    final saved = await widget.onSave(next);
    if (!mounted) return;
    setState(() {
      if (!saved) _preferences = previous;
      _saving = false;
    });
  }

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    heightFactor: .78,
    child: DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outline,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 8, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Benachrichtigungen',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'Lege fest, was für dich wichtig ist.',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Schließen',
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            if (_saving) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  if (widget.error != null) ...[
                    _InlineError(widget.error!),
                    const SizedBox(height: 10),
                  ],
                  _NotificationCard(
                    preferences: _preferences,
                    enabled: widget.enabled && !_saving,
                    onChanged: (next) => unawaited(_update(next)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.preferences,
    required this.enabled,
    required this.onChanged,
  });

  final _NotificationPreferences preferences;
  final bool enabled;
  final ValueChanged<_NotificationPreferences> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppDesign.radiusLarge),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        SwitchListTile(
          value: preferences.events,
          onChanged: enabled
              ? (value) => onChanged(preferences.copyWith(events: value))
              : null,
          secondary: const Icon(Icons.event_rounded, color: AppColors.red),
          title: const Text('Veranstaltungen'),
          subtitle: const Text('Neue Termine und Änderungen'),
        ),
        const Divider(),
        SwitchListTile(
          value: preferences.eventReminders,
          onChanged: enabled
              ? (value) =>
                    onChanged(preferences.copyWith(eventReminders: value))
              : null,
          secondary: const Icon(Icons.alarm_rounded, color: AppColors.red),
          title: const Text('Terminerinnerungen'),
        ),
        const Divider(),
        SwitchListTile(
          value: preferences.helperRequests,
          onChanged: enabled
              ? (value) =>
                    onChanged(preferences.copyWith(helperRequests: value))
              : null,
          secondary: const Icon(
            Icons.volunteer_activism_rounded,
            color: AppColors.red,
          ),
          title: const Text('Helferaufrufe'),
        ),
        const Divider(),
        SwitchListTile(
          value: preferences.polls,
          onChanged: enabled
              ? (value) => onChanged(preferences.copyWith(polls: value))
              : null,
          secondary: const Icon(Icons.poll_rounded, color: AppColors.red),
          title: const Text('Umfragen'),
        ),
        const Divider(),
        SwitchListTile(
          value: preferences.board,
          onChanged: enabled
              ? (value) => onChanged(preferences.copyWith(board: value))
              : null,
          secondary: const Icon(Icons.dashboard_rounded, color: AppColors.red),
          title: const Text('Schwarzes Brett'),
        ),
      ],
    ),
  );
}

class _InlineError extends StatelessWidget {
  const _InlineError(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .94),
        borderRadius: BorderRadius.circular(AppDesign.radiusMedium),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.muted),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18),
    child: _EmptyCardBody(icon: icon, text: text),
  );
}

class _EmptyCardBody extends StatelessWidget {
  const _EmptyCardBody({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppDesign.radiusMedium),
    ),
    child: Row(
      children: [
        Icon(icon, color: AppColors.muted),
        const SizedBox(width: 11),
        Expanded(
          child: Text(text, style: const TextStyle(color: AppColors.muted)),
        ),
      ],
    ),
  );
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 19, color: AppColors.red),
      const SizedBox(width: 8),
      Expanded(child: Text(text)),
    ],
  );
}

class _CountLabel extends StatelessWidget {
  const _CountLabel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 17, color: AppColors.muted),
      const SizedBox(width: 5),
      Text(text, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
    ],
  );
}

class _SmallBadge extends StatelessWidget {
  const _SmallBadge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: AppColors.muted,
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _CreateEventDialog extends StatefulWidget {
  const _CreateEventDialog({required this.initialDate});

  final DateTime initialDate;

  @override
  State<_CreateEventDialog> createState() => _CreateEventDialogState();
}

class _CreateEventDialogState extends State<_CreateEventDialog> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();
  final _helpers = TextEditingController(text: '0');
  late DateTime _date;
  TimeOfDay _time = const TimeOfDay(hour: 18, minute: 0);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final requested = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
    );
    _date = requested.isBefore(today) ? today : requested;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    _helpers.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Veranstaltung erstellen'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Titel *'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _description,
            decoration: const InputDecoration(labelText: 'Beschreibung'),
            maxLines: 3,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _location,
            decoration: const InputDecoration(labelText: 'Ort'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _helpers,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Benötigte Helfer'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final value = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                    );
                    if (value != null && mounted) setState(() => _date = value);
                  },
                  icon: const Icon(Icons.calendar_today_rounded),
                  label: Text(_formatDate(_date)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final value = await showTimePicker(
                      context: context,
                      initialTime: _time,
                    );
                    if (value != null && mounted) setState(() => _time = value);
                  },
                  icon: const Icon(Icons.schedule_rounded),
                  label: Text(_time.format(context)),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Abbrechen'),
      ),
      FilledButton(
        onPressed: () {
          final title = _title.text.trim();
          if (title.isEmpty) return;
          Navigator.pop(
            context,
            _NewEvent(
              title: title,
              description: _description.text.trim(),
              location: _location.text.trim(),
              startsAt: DateTime(
                _date.year,
                _date.month,
                _date.day,
                _time.hour,
                _time.minute,
              ),
              helperSlots: int.tryParse(_helpers.text.trim()) ?? 0,
            ),
          );
        },
        child: const Text('Veröffentlichen'),
      ),
    ],
  );
}

class _CreatePollDialog extends StatefulWidget {
  const _CreatePollDialog();

  @override
  State<_CreatePollDialog> createState() => _CreatePollDialogState();
}

class _CreatePollDialogState extends State<_CreatePollDialog> {
  final _question = TextEditingController();
  final _description = TextEditingController();
  final _options = TextEditingController(text: 'Ja\nNein');
  bool _multiple = false;
  late DateTime _closesAt;

  @override
  void initState() {
    super.initState();
    _closesAt = DateTime.now().add(const Duration(days: 7));
  }

  @override
  void dispose() {
    _question.dispose();
    _description.dispose();
    _options.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Umfrage erstellen'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _question,
            decoration: const InputDecoration(labelText: 'Frage *'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _description,
            decoration: const InputDecoration(labelText: 'Beschreibung'),
            maxLines: 2,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _options,
            decoration: const InputDecoration(
              labelText: 'Antworten *',
              helperText: 'Eine Antwort pro Zeile',
            ),
            minLines: 3,
            maxLines: 6,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _multiple,
            onChanged: (value) => setState(() => _multiple = value),
            title: const Text('Mehrfachauswahl'),
          ),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final value = await showDatePicker(
                  context: context,
                  initialDate: _closesAt,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (value != null && mounted) {
                  setState(
                    () => _closesAt = DateTime(
                      value.year,
                      value.month,
                      value.day,
                      23,
                      59,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.event_busy_rounded),
              label: Text('Endet am ${_formatDate(_closesAt)}'),
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Abbrechen'),
      ),
      FilledButton(
        onPressed: () {
          final question = _question.text.trim();
          final options = _options.text
              .split('\n')
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toSet()
              .toList();
          if (question.isEmpty || options.length < 2) return;
          Navigator.pop(
            context,
            _NewPoll(
              question: question,
              description: _description.text.trim(),
              options: options,
              allowMultiple: _multiple,
              closesAt: _closesAt,
            ),
          );
        },
        child: const Text('Veröffentlichen'),
      ),
    ],
  );
}

class _CreateBoardPostDialog extends StatefulWidget {
  const _CreateBoardPostDialog();

  @override
  State<_CreateBoardPostDialog> createState() => _CreateBoardPostDialogState();
}

class _CreateBoardPostDialogState extends State<_CreateBoardPostDialog> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  String _category = 'general';

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Eintrag erstellen'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Titel *'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _body,
            decoration: const InputDecoration(labelText: 'Text *'),
            minLines: 3,
            maxLines: 6,
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Kategorie'),
            items: const [
              DropdownMenuItem(value: 'general', child: Text('Allgemein')),
              DropdownMenuItem(value: 'rides', child: Text('Fahrgemeinschaft')),
              DropdownMenuItem(value: 'lost_found', child: Text('Fundsache')),
              DropdownMenuItem(value: 'wanted', child: Text('Hilfe gesucht')),
              DropdownMenuItem(value: 'offer', child: Text('Angebot')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _category = value);
            },
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Abbrechen'),
      ),
      FilledButton(
        onPressed: () {
          final title = _title.text.trim();
          final body = _body.text.trim();
          if (title.isEmpty || body.isEmpty) return;
          Navigator.pop(
            context,
            _NewBoardPost(title: title, body: body, category: _category),
          );
        },
        child: const Text('Veröffentlichen'),
      ),
    ],
  );
}

class _ClubPageData {
  const _ClubPageData({
    required this.events,
    required this.upcoming,
    required this.poll,
    required this.board,
    required this.notifications,
  });

  factory _ClubPageData.empty() => const _ClubPageData(
    events: _Section<List<_ClubEvent>>(data: <_ClubEvent>[]),
    upcoming: _Section<List<_ClubEvent>>(data: <_ClubEvent>[]),
    poll: _Section<_ClubPoll?>(data: null),
    board: _Section<_BoardData>(
      data: _BoardData(posts: <_BoardPost>[], authorNames: <String, String>{}),
    ),
    notifications: _Section<_NotificationPreferences>(
      data: _NotificationPreferences(),
    ),
  );

  final _Section<List<_ClubEvent>> events;
  final _Section<List<_ClubEvent>> upcoming;
  final _Section<_ClubPoll?> poll;
  final _Section<_BoardData> board;
  final _Section<_NotificationPreferences> notifications;

  _ClubPageData copyWith({
    _Section<List<_ClubEvent>>? events,
    _Section<List<_ClubEvent>>? upcoming,
    _Section<_ClubPoll?>? poll,
    _Section<_BoardData>? board,
    _Section<_NotificationPreferences>? notifications,
  }) => _ClubPageData(
    events: events ?? this.events,
    upcoming: upcoming ?? this.upcoming,
    poll: poll ?? this.poll,
    board: board ?? this.board,
    notifications: notifications ?? this.notifications,
  );
}

class _Section<T> {
  const _Section({required this.data, this.error});

  final T data;
  final String? error;
}

class _ClubEvent {
  factory _ClubEvent.fromCache(Map<String, dynamic> row) => _ClubEvent(
    id: row['id'] as String,
    title: row['title'] as String,
    description: row['description'] as String,
    type: row['type'] as String,
    location: row['location'] as String,
    startsAt: DateTime.parse(row['startsAt'] as String),
    endsAt: row['endsAt'] == null
        ? null
        : DateTime.parse(row['endsAt'] as String),
    registrationDeadline: row['deadline'] == null
        ? null
        : DateTime.parse(row['deadline'] as String),
    participantLimit: row['limit'] as int?,
    helperSlots: row['helperSlots'] as int,
    attendingCount: row['attendingCount'] as int,
    helperCount: row['helperCount'] as int,
    ownStatus: row['ownStatus'] as String?,
    isHelper: row['isHelper'] as bool,
  );

  Map<String, dynamic> toCache() => {
    'id': id,
    'title': title,
    'description': description,
    'type': type,
    'location': location,
    'startsAt': startsAt.toIso8601String(),
    'endsAt': endsAt?.toIso8601String(),
    'deadline': registrationDeadline?.toIso8601String(),
    'limit': participantLimit,
    'helperSlots': helperSlots,
    'attendingCount': attendingCount,
    'helperCount': helperCount,
    'ownStatus': ownStatus,
    'isHelper': isHelper,
  };

  const _ClubEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.location,
    required this.startsAt,
    required this.endsAt,
    required this.registrationDeadline,
    required this.participantLimit,
    required this.helperSlots,
    required this.attendingCount,
    required this.helperCount,
    required this.ownStatus,
    required this.isHelper,
  });

  final String id;
  final String title;
  final String description;
  final String type;
  final String location;
  final DateTime startsAt;
  final DateTime? endsAt;
  final DateTime? registrationDeadline;
  final int? participantLimit;
  final int helperSlots;
  final int attendingCount;
  final int helperCount;
  final String? ownStatus;
  final bool isHelper;
}

class _ClubPoll {
  const _ClubPoll({
    required this.id,
    required this.authorId,
    required this.question,
    required this.description,
    required this.allowMultiple,
    required this.closesAt,
    required this.options,
    required this.votedOptionIds,
  });

  final String id;
  final String authorId;
  final String question;
  final String description;
  final bool allowMultiple;
  final DateTime? closesAt;
  final List<_PollOption> options;
  final Set<String> votedOptionIds;
}

class _PollOption {
  const _PollOption({
    required this.id,
    required this.label,
    required this.votes,
  });

  final String id;
  final String label;
  final int votes;
}

class _BoardData {
  const _BoardData({required this.posts, required this.authorNames});

  final List<_BoardPost> posts;
  final Map<String, String> authorNames;
}

class _BoardPost {
  const _BoardPost({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.isPinned,
    required this.authorId,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final String category;
  final bool isPinned;
  final String authorId;
  final DateTime createdAt;
}

class _NotificationPreferences {
  const _NotificationPreferences({
    this.events = true,
    this.eventReminders = true,
    this.helperRequests = true,
    this.polls = true,
    this.board = true,
    this.news = true,
    this.training = true,
    this.league = true,
  });

  factory _NotificationPreferences.fromMap(Map<String, dynamic> map) =>
      _NotificationPreferences(
        events: map['events_enabled'] != false,
        eventReminders: map['event_reminders_enabled'] != false,
        helperRequests: map['helper_requests_enabled'] != false,
        polls: map['polls_enabled'] != false,
        board: map['board_enabled'] != false,
        news: map['news_enabled'] != false,
        training: map['training_enabled'] != false,
        league: map['league_enabled'] != false,
      );

  final bool events;
  final bool eventReminders;
  final bool helperRequests;
  final bool polls;
  final bool board;
  final bool news;
  final bool training;
  final bool league;

  _NotificationPreferences copyWith({
    bool? events,
    bool? eventReminders,
    bool? helperRequests,
    bool? polls,
    bool? board,
  }) => _NotificationPreferences(
    events: events ?? this.events,
    eventReminders: eventReminders ?? this.eventReminders,
    helperRequests: helperRequests ?? this.helperRequests,
    polls: polls ?? this.polls,
    board: board ?? this.board,
    news: news,
    training: training,
    league: league,
  );

  Map<String, dynamic> toMap(String userId) => {
    'user_id': userId,
    'events_enabled': events,
    'event_reminders_enabled': eventReminders,
    'helper_requests_enabled': helperRequests,
    'polls_enabled': polls,
    'board_enabled': board,
    'news_enabled': news,
    'training_enabled': training,
    'league_enabled': league,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };
}

class _NewEvent {
  const _NewEvent({
    required this.title,
    required this.description,
    required this.location,
    required this.startsAt,
    required this.helperSlots,
  });

  final String title;
  final String description;
  final String location;
  final DateTime startsAt;
  final int helperSlots;
}

class _NewPoll {
  const _NewPoll({
    required this.question,
    required this.description,
    required this.options,
    required this.allowMultiple,
    required this.closesAt,
  });

  final String question;
  final String description;
  final List<String> options;
  final bool allowMultiple;
  final DateTime closesAt;
}

class _NewBoardPost {
  const _NewBoardPost({
    required this.title,
    required this.body,
    required this.category,
  });

  final String title;
  final String body;
  final String category;
}

String _string(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String? _nullIfEmpty(String value) =>
    value.trim().isEmpty ? null : value.trim();

DateTime? _date(Object? value) {
  if (value is DateTime) return value.toLocal();
  return DateTime.tryParse(value?.toString() ?? '')?.toLocal();
}

int? _integer(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

String _formatDate(DateTime value) {
  const weekdays = <String>['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
  final local = value.toLocal();
  return '${weekdays[local.weekday - 1]}, '
      '${local.day.toString().padLeft(2, '0')}.'
      '${local.month.toString().padLeft(2, '0')}.'
      '${local.year}';
}

String _formatTime(DateTime value) {
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

bool _isSameDay(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

bool _isSameMonth(DateTime first, DateTime second) =>
    first.year == second.year && first.month == second.month;

String _monthName(int month) => const [
  'Januar',
  'Februar',
  'März',
  'April',
  'Mai',
  'Juni',
  'Juli',
  'August',
  'September',
  'Oktober',
  'November',
  'Dezember',
][month - 1];

String _formatEventSchedule(_ClubEvent event) {
  final start = event.startsAt;
  final end = event.endsAt;
  if (end == null) {
    return '${_formatDate(start)} · ${_formatTime(start)} Uhr';
  }
  if (_isSameDay(start, end)) {
    return '${_formatDate(start)} · ${_formatTime(start)}–${_formatTime(end)} Uhr';
  }
  return '${_formatDate(start)}, ${_formatTime(start)} Uhr – '
      '${_formatDate(end)}, ${_formatTime(end)} Uhr';
}

String _friendlyError(Object error, String sectionName) {
  if (error is PostgrestException) {
    if (error.code == '42P01' || error.code == 'PGRST205') {
      return '$sectionName wird gerade eingerichtet.';
    }
    if (error.code == '42501') {
      return 'Du hast für $sectionName keine Berechtigung.';
    }
    return '$sectionName konnte nicht geladen werden.';
  }
  if (error is StateError) return 'Bitte melde dich erneut an.';
  return '$sectionName ist momentan nicht verfügbar.';
}

String _eventTypeLabel(String value) => switch (value) {
  'social' => 'Gemeinschaft',
  'competition' => 'Wettkampf',
  'work_assignment' => 'Arbeitseinsatz',
  _ => 'Verein',
};

String _boardCategoryLabel(String value) => switch (value) {
  'rides' => 'Fahrgemeinschaft',
  'offer' => 'Angebot',
  'wanted' => 'Hilfe gesucht',
  'lost_found' => 'Fundsache',
  _ => 'Allgemein',
};
