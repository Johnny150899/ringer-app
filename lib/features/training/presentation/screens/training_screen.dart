import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/app_theme.dart';
import '../../data/sources/training_schedule.dart';
import '../../domain/models/training_session.dart';

class TrainingScreen extends StatefulWidget {
  const TrainingScreen({
    super.key,
    this.nowOverride,
    this.memberAccess = false,
    this.isAdmin = false,
    this.supabaseClient,
    this.canRespond = false,
    this.trainingGroups = const [],
    this.canManageSessions = false,
  });

  // Bleibt für bestehende Tests und die spätere Mitgliederansicht kompatibel.
  final DateTime? nowOverride;
  final bool memberAccess;
  final bool isAdmin;
  final SupabaseClient? supabaseClient;
  final bool canRespond;
  final List<String> trainingGroups;
  final bool canManageSessions;

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  bool _showMemberPreview = false;
  String _selectedMemberGroup = 'Männer';
  late DateTime _visibleMonth;
  final Map<String, bool> _responses = {};
  final Map<String, String> _declineReasons = {};
  final Map<String, Future<_AttendanceData>> _attendanceFutures = {};
  final Map<String, Map<String, dynamic>> _occurrenceOverrides = {};
  List<TrainingSession> _sessions = TrainingSchedule.sessions;

  static const _groupOrder = ['Männer', 'Jugend', 'Bambinis'];
  static const _weekdays = {
    DateTime.monday: 'Montag',
    DateTime.tuesday: 'Dienstag',
    DateTime.wednesday: 'Mittwoch',
    DateTime.thursday: 'Donnerstag',
    DateTime.friday: 'Freitag',
    DateTime.saturday: 'Samstag',
    DateTime.sunday: 'Sonntag',
  };
  static const _months = [
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
  ];

  @override
  void initState() {
    super.initState();
    _showMemberPreview = widget.memberAccess;
    final now = widget.nowOverride ?? DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
    _loadSchedule();
  }

  @override
  void didUpdateWidget(covariant TrainingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.memberAccess != widget.memberAccess) {
      _showMemberPreview = widget.memberAccess;
    }
  }

  List<_DatedTrainingSession> _sessionsForVisibleMonth() {
    final lastDay = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + 1,
      0,
    ).day;
    final sessions = <_DatedTrainingSession>[];

    for (var day = 1; day <= lastDay; day++) {
      final date = DateTime(_visibleMonth.year, _visibleMonth.month, day);
      for (final session in _sessions) {
        if (session.weekday == date.weekday &&
            session.group == _selectedMemberGroup) {
          sessions.add(_DatedTrainingSession(session, date));
        }
      }
    }
    return sessions;
  }

  void _changeMonth(int offset) {
    setState(() {
      _visibleMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month + offset,
      );
      _attendanceFutures.clear();
    });
    _loadOwnResponses();
    _loadOccurrenceOverrides();
  }

  Future<void> _loadSchedule() async {
    final client = widget.supabaseClient;
    if (client == null) return;
    try {
      final rows = await client
          .from('weekly_training_schedule')
          .select(
            'id, group_name, weekday, start_hour, start_minute, '
            'end_hour, end_minute, location_name, location_query',
          )
          .order('weekday')
          .order('start_hour');
      final sessions = List<Map<String, dynamic>>.from(rows)
          .map(
            (row) => TrainingSession(
              id: row['id'] as int,
              weekday: row['weekday'] as int,
              startHour: row['start_hour'] as int,
              startMinute: row['start_minute'] as int,
              endHour: row['end_hour'] as int,
              endMinute: row['end_minute'] as int,
              group: row['group_name'] as String,
              locationName: row['location_name'] as String,
              locationQuery: row['location_query'] as String,
            ),
          )
          .toList(growable: false);
      if (mounted && sessions.isNotEmpty) setState(() => _sessions = sessions);
      await _loadOwnResponses();
      await _loadOccurrenceOverrides();
    } on PostgrestException {
      // Bis zur Migration bleibt der lokale Standardplan sichtbar.
    }
  }

  Future<void> _loadOwnResponses() async {
    final client = widget.supabaseClient;
    final user = client?.auth.currentUser;
    if (client == null || user == null) return;
    final firstDay =
        '${_visibleMonth.year.toString().padLeft(4, '0')}-'
        '${_visibleMonth.month.toString().padLeft(2, '0')}-01';
    final last = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0);
    final lastDay =
        '${last.year.toString().padLeft(4, '0')}-'
        '${last.month.toString().padLeft(2, '0')}-'
        '${last.day.toString().padLeft(2, '0')}';
    try {
      final rows = await client
          .from('weekly_training_responses')
          .select('schedule_id, training_date, status, decline_reason')
          .eq('user_id', user.id)
          .gte('training_date', firstDay)
          .lte('training_date', lastDay);
      if (!mounted) return;
      setState(() {
        for (final row in List<Map<String, dynamic>>.from(rows)) {
          final session = _sessions.cast<TrainingSession?>().firstWhere(
            (item) => item?.id == row['schedule_id'],
            orElse: () => null,
          );
          final date = DateTime.tryParse(row['training_date'] as String? ?? '');
          if (session == null || date == null) continue;
          final key = '${session.group}-${date.year}-${date.month}-${date.day}';
          _responses[key] = row['status'] == 'accepted';
          final reason = row['decline_reason'] as String?;
          if (reason != null) _declineReasons[key] = reason;
        }
      });
    } on PostgrestException {
      // Lokale Testantworten bleiben nutzbar.
    }
  }

  String _occurrenceKey(TrainingSession session, DateTime date) =>
      '${session.id}-${date.year}-${date.month}-${date.day}';

  Future<void> _loadOccurrenceOverrides() async {
    final client = widget.supabaseClient;
    if (client == null) return;
    try {
      final rows = await client
          .from('training_occurrence_overrides')
          .select('schedule_id, training_date, is_cancelled, note');
      if (!mounted) return;
      setState(() {
        _occurrenceOverrides.clear();
        for (final row in List<Map<String, dynamic>>.from(rows)) {
          final date = DateTime.tryParse(row['training_date'] as String? ?? '');
          if (date != null) {
            _occurrenceOverrides['${row['schedule_id']}-${date.year}-${date.month}-${date.day}'] =
                row;
          }
        }
      });
    } on PostgrestException {
      // Nach Migration 009 verfügbar.
    }
  }

  Future<void> _manageOccurrence(TrainingSession session, DateTime date) async {
    final key = _occurrenceKey(session, date);
    final existing = _occurrenceOverrides[key];
    var cancelled = existing?['is_cancelled'] == true;
    final note = TextEditingController(
      text: existing?['note'] as String? ?? '',
    );
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Einzeltermin bearbeiten'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Training fällt aus'),
                value: cancelled,
                onChanged: (value) => setDialogState(() => cancelled = value),
              ),
              TextField(
                controller: note,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Hinweis (optional)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
    if (save == true && mounted && session.id != null) {
      final dateValue =
          '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
      try {
        await widget.supabaseClient!.rpc<void>(
          'set_training_occurrence',
          params: {
            'target_schedule_id': session.id,
            'target_date': dateValue,
            'cancelled': cancelled,
            'new_note': note.text.trim(),
          },
        );
        if (mounted) {
          setState(
            () => _occurrenceOverrides[key] = {
              'is_cancelled': cancelled,
              'note': note.text.trim(),
            },
          );
        }
      } on PostgrestException catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Termin nicht geändert: ${error.message}')),
          );
        }
      }
    }
    note.dispose();
  }

  Future<void> _editSession(TrainingSession session) async {
    var start = TimeOfDay(hour: session.startHour, minute: session.startMinute);
    var end = TimeOfDay(hour: session.endHour, minute: session.endMinute);
    final changed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          icon: const Icon(Icons.edit_calendar_rounded, color: AppColors.red),
          title: Text('${session.group} bearbeiten'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _weekdays[session.weekday] ?? '',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.play_circle_outline_rounded),
                title: const Text('Beginn'),
                trailing: Text(start.format(context)),
                onTap: () async {
                  final value = await showTimePicker(
                    context: context,
                    initialTime: start,
                  );
                  if (value != null) setDialogState(() => start = value);
                },
              ),
              ListTile(
                leading: const Icon(Icons.stop_circle_outlined),
                title: const Text('Ende'),
                trailing: Text(end.format(context)),
                onTap: () async {
                  final value = await showTimePicker(
                    context: context,
                    initialTime: end,
                  );
                  if (value != null) setDialogState(() => end = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () {
                if (end.hour * 60 + end.minute <=
                    start.hour * 60 + start.minute) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Das Ende muss nach dem Beginn liegen.'),
                    ),
                  );
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
    if (changed != true || !mounted || session.id == null) return;
    try {
      await widget.supabaseClient!
          .from('weekly_training_schedule')
          .update({
            'start_hour': start.hour,
            'start_minute': start.minute,
            'end_hour': end.hour,
            'end_minute': end.minute,
          })
          .eq('id', session.id!);
      if (!mounted) return;
      setState(() {
        final index = _sessions.indexWhere((item) => item.id == session.id);
        if (index != -1) {
          _sessions[index] = session.copyWith(
            startHour: start.hour,
            startMinute: start.minute,
            endHour: end.hour,
            endMinute: end.minute,
          );
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trainingszeit wurde aktualisiert.')),
      );
    } on PostgrestException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Änderung nicht möglich: ${error.message}')),
      );
    }
  }

  Future<_AttendanceData> _loadAttendance(
    TrainingSession session,
    DateTime date,
  ) async {
    final client = widget.supabaseClient;
    if (client == null || session.id == null) {
      final key = '${session.group}-${date.year}-${date.month}-${date.day}';
      final response = _responses[key];
      return _AttendanceData(
        accepted: [
          'Max Mustermann',
          'Lukas Becker',
          'Tim Wagner',
          if (response == true) 'Du',
        ],
        declined: ['Jonas Klein', if (response == false) 'Du'],
        declineReasons: response == false && _declineReasons[key] != null
            ? {'Du': _declineReasons[key]!}
            : const {},
        openCount: 5,
      );
    }
    final dateValue =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final rows = await client
        .from('weekly_training_responses')
        .select(
          'user_id, status, decline_reason, profiles(first_name, last_name)',
        )
        .eq('schedule_id', session.id!)
        .eq('training_date', dateValue);
    final participantCount = await client
        .from('profile_training_groups')
        .count()
        .eq('group_name', session.group);
    final accepted = <String>[];
    final declined = <String>[];
    final reasons = <String, String>{};
    for (final raw in List<Map<String, dynamic>>.from(rows)) {
      final profile = raw['profiles'] as Map<String, dynamic>?;
      final name =
          '${profile?['first_name'] ?? ''} ${profile?['last_name'] ?? ''}'
              .trim();
      final displayName = name.isEmpty ? 'Unbekanntes Mitglied' : name;
      if (raw['status'] == 'accepted') {
        accepted.add(displayName);
      } else {
        declined.add(displayName);
        final reason = raw['decline_reason'] as String?;
        if (reason != null && reason.isNotEmpty) reasons[displayName] = reason;
      }
    }
    return _AttendanceData(
      accepted: accepted,
      declined: declined,
      declineReasons: reasons,
      openCount: (participantCount - accepted.length - declined.length).clamp(
        0,
        participantCount,
      ),
    );
  }

  Future<_AttendanceData> _attendanceFor(
    TrainingSession session,
    DateTime date,
  ) {
    final key = '${session.id}-${date.year}-${date.month}-${date.day}';
    return _attendanceFutures.putIfAbsent(
      key,
      () => _loadAttendance(session, date),
    );
  }

  void _invalidateAttendance(TrainingSession session, DateTime date) {
    _attendanceFutures.remove(
      '${session.id}-${date.year}-${date.month}-${date.day}',
    );
  }

  Future<void> _showAttendance(
    TrainingSession session,
    DateTime date,
    bool? response,
    String? declineReason,
  ) async {
    final attendance = await _attendanceFor(session, date);
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AttendanceSheet(
        session: session,
        date: date,
        response: response,
        declineReason: declineReason,
        attendance: attendance,
        showDeclineReasons: widget.canManageSessions,
      ),
    );
  }

  Future<void> _saveResponse(
    TrainingSession session,
    DateTime date,
    bool accepted, [
    String? reason,
  ]) async {
    final key = '${session.group}-${date.year}-${date.month}-${date.day}';
    final client = widget.supabaseClient;
    if (client != null && session.id != null) {
      try {
        final dateValue =
            '${date.year.toString().padLeft(4, '0')}-'
            '${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}';
        await client.rpc<void>(
          'respond_to_training',
          params: {
            'target_schedule_id': session.id,
            'target_date': dateValue,
            'new_status': accepted ? 'accepted' : 'declined',
            'reason': reason,
          },
        );
      } on PostgrestException catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Antwort nicht gespeichert: ${error.message}'),
          ),
        );
        return;
      }
    }
    if (!mounted) return;
    setState(() {
      _responses[key] = accepted;
      if (accepted) {
        _declineReasons.remove(key);
      } else if (reason != null) {
        _declineReasons[key] = reason;
      }
      _invalidateAttendance(session, date);
    });
  }

  @override
  Widget build(BuildContext context) {
    final monthlySessions = _sessionsForVisibleMonth();

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        widget.isAdmin && _showMemberPreview ? 6 : 14,
        16,
        96,
      ),
      children: [
        if (!_showMemberPreview) ...[
          const Text(
            'Training',
            style: TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'Unsere wöchentlichen Trainingszeiten.',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
        if (widget.isAdmin || (kDebugMode && !widget.memberAccess)) ...[
          SizedBox(height: widget.isAdmin && _showMemberPreview ? 2 : 9),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () =>
                  setState(() => _showMemberPreview = !_showMemberPreview),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white38),
                visualDensity: VisualDensity.compact,
              ),
              icon: Icon(
                _showMemberPreview
                    ? Icons.public_rounded
                    : Icons.badge_outlined,
                size: 16,
              ),
              label: Text(
                _showMemberPreview
                    ? 'Gästeansicht'
                    : widget.isAdmin
                    ? 'Mitgliederansicht'
                    : 'Mitgliederansicht testen',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
        SizedBox(height: widget.isAdmin && _showMemberPreview ? 8 : 18),
        if (_showMemberPreview) ...[
          _MonthSelector(
            label: '${_months[_visibleMonth.month - 1]} ${_visibleMonth.year}',
            onPrevious: () => _changeMonth(-1),
            onNext: () => _changeMonth(1),
          ),
          const SizedBox(height: 10),
          _MemberGroupFilter(
            selected: _selectedMemberGroup,
            onSelected: (group) => setState(() => _selectedMemberGroup = group),
          ),
          const SizedBox(height: 12),
          ...monthlySessions.map((entry) {
            final session = entry.session;
            final date = entry.date;
            final key =
                '${session.group}-${date.year}-${date.month}-${date.day}';
            return _MemberTrainingCard(
              session: session,
              date: date,
              response: _responses[key],
              attendance: _attendanceFor(session, date),
              occurrence: _occurrenceOverrides[_occurrenceKey(session, date)],
              canManage: widget.canManageSessions,
              onManage: () => _manageOccurrence(session, date),
              canRespond:
                  widget.supabaseClient == null ||
                  (widget.canRespond &&
                      widget.trainingGroups.contains(session.group)),
              onAccept: () => _saveResponse(session, date, true),
              onDecline: (reason) =>
                  _saveResponse(session, date, false, reason),
              onOpenDetails: () => _showAttendance(
                session,
                date,
                _responses[key],
                _declineReasons[key],
              ),
            );
          }),
        ] else
          ..._groupOrder.map(
            (group) => _TrainingGroupCard(
              group: group,
              sessions: _sessions
                  .where((session) => session.group == group)
                  .toList(growable: false),
              weekdayLabel: (weekday) => _weekdays[weekday] ?? '',
              canEdit: widget.isAdmin,
              onEdit: _editSession,
            ),
          ),
      ],
    );
  }
}

class _DatedTrainingSession {
  const _DatedTrainingSession(this.session, this.date);

  final TrainingSession session;
  final DateTime date;
}

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({
    required this.label,
    required this.onPrevious,
    required this.onNext,
  });

  final String label;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _MonthButton(icon: Icons.chevron_left_rounded, onTap: onPrevious),
        Expanded(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        _MonthButton(icon: Icons.chevron_right_rounded, onTap: onNext),
      ],
    );
  }
}

class _MonthButton extends StatelessWidget {
  const _MonthButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon),
      color: Colors.white,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: .12),
      ),
    );
  }
}

class _MemberGroupFilter extends StatelessWidget {
  const _MemberGroupFilter({required this.selected, required this.onSelected});

  static const _groups = ['Männer', 'Jugend', 'Bambinis'];
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _groups.indexed
          .map((entry) {
            final index = entry.$1;
            final group = entry.$2;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: index < _groups.length - 1 ? 7 : 0,
                ),
                child: Semantics(
                  selected: selected == group,
                  button: true,
                  child: InkWell(
                    key: ValueKey('member-group-$group'),
                    onTap: () => onSelected(group),
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: 40,
                      decoration: BoxDecoration(
                        color: selected == group
                            ? Colors.white
                            : AppColors.navy.withValues(alpha: .55),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white38),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            group,
                            style: TextStyle(
                              color: selected == group
                                  ? AppColors.navy
                                  : Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          })
          .toList(growable: false),
    );
  }
}

class _MemberTrainingCard extends StatelessWidget {
  const _MemberTrainingCard({
    required this.session,
    required this.date,
    required this.response,
    required this.onAccept,
    required this.onDecline,
    required this.onOpenDetails,
    required this.canRespond,
    required this.attendance,
    required this.occurrence,
    required this.canManage,
    required this.onManage,
  });

  final TrainingSession session;
  final DateTime date;
  final bool? response;
  final VoidCallback onAccept;
  final ValueChanged<String> onDecline;
  final VoidCallback onOpenDetails;
  final bool canRespond;
  final Future<_AttendanceData> attendance;
  final Map<String, dynamic>? occurrence;
  final bool canManage;
  final VoidCallback onManage;

  Future<void> _requestDeclineReason(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    var enteredReason = '';
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Absage begründen'),
        content: Form(
          key: formKey,
          child: TextFormField(
            autofocus: true,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (value) => enteredReason = value,
            decoration: const InputDecoration(
              labelText: 'Grund',
              hintText: 'z. B. krank oder verhindert',
              border: OutlineInputBorder(),
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Bitte gib einen Grund an.'
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(dialogContext, enteredReason.trim());
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            child: const Text('Absage speichern'),
          ),
        ],
      ),
    );
    if (reason != null) onDecline(reason);
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.${date.year}';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white.withValues(alpha: .96),
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey(
            'training-${session.group}-${date.year}-${date.month}-${date.day}',
          ),
          onTap: onOpenDetails,
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.sports_kabaddi_rounded,
                      size: 21,
                      color: AppColors.red,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        session.group,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      dateLabel,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (canManage)
                      IconButton(
                        tooltip: 'Einzeltermin bearbeiten',
                        visualDensity: VisualDensity.compact,
                        onPressed: onManage,
                        icon: const Icon(Icons.more_vert_rounded, size: 18),
                      ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  '${_TrainingScreenState._weekdays[session.weekday]} · ${session.timeLabel} Uhr',
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (occurrence?['is_cancelled'] == true) ...[
                  const SizedBox(height: 5),
                  const Text(
                    'TRAINING FÄLLT AUS',
                    style: TextStyle(
                      color: AppColors.red,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ] else if ((occurrence?['note'] as String? ?? '')
                    .isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    occurrence!['note'] as String,
                    style: const TextStyle(color: AppColors.red, fontSize: 11),
                  ),
                ],
                const SizedBox(height: 9),
                Row(
                  children: [
                    Expanded(
                      child: FutureBuilder<_AttendanceData>(
                        future: attendance,
                        builder: (context, snapshot) {
                          final data = snapshot.data;
                          return Text(
                            data == null
                                ? 'Teilnahmen laden …'
                                : '${data.accepted.length} Zusagen · '
                                      '${data.declined.length} Absagen · '
                                      '${data.openCount} offen',
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        },
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: AppColors.muted,
                    ),
                  ],
                ),
                if (canRespond) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _ResponseButton(
                          label: 'Zusagen',
                          icon: Icons.check_rounded,
                          selected: response == true,
                          color: const Color(0xFF168A5B),
                          onTap: onAccept,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ResponseButton(
                          label: 'Absagen',
                          icon: Icons.close_rounded,
                          selected: response == false,
                          color: AppColors.red,
                          onTap: () => _requestDeclineReason(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AttendanceSheet extends StatelessWidget {
  const _AttendanceSheet({
    required this.session,
    required this.date,
    required this.response,
    required this.declineReason,
    required this.attendance,
    required this.showDeclineReasons,
  });

  final TrainingSession session;
  final DateTime date;
  final bool? response;
  final String? declineReason;
  final _AttendanceData attendance;
  final bool showDeclineReasons;

  @override
  Widget build(BuildContext context) {
    final accepted = attendance.accepted;
    final declined = attendance.declined;
    final dateLabel =
        '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.${date.year}';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .78,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFF7F8FA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
        shrinkWrap: true,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.muted.withValues(alpha: .35),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Teilnahmen',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${session.group} · $dateLabel · ${session.timeLabel} Uhr',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _AttendanceSection(
            title: 'Zusagen',
            names: accepted,
            color: const Color(0xFF168A5B),
            icon: Icons.check_circle_rounded,
          ),
          const SizedBox(height: 12),
          _AttendanceSection(
            title: 'Absagen',
            names: declined,
            color: AppColors.red,
            icon: Icons.cancel_rounded,
            notes: showDeclineReasons ? attendance.declineReasons : const {},
            selfNote: response == false ? declineReason : null,
          ),
          if (response == null) ...[
            const SizedBox(height: 14),
            const Text(
              'Du hast noch nicht geantwortet.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _AttendanceSection extends StatelessWidget {
  const _AttendanceSection({
    required this.title,
    required this.names,
    required this.color,
    required this.icon,
    this.selfNote,
    this.notes = const {},
  });

  final String title;
  final List<String> names;
  final Color color;
  final IconData icon;
  final String? selfNote;
  final Map<String, String> notes;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: .16)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                '$title (${names.length})',
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...names.map(
            (name) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: color.withValues(alpha: .11),
                    child: Text(
                      name.characters.first,
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (name == 'Du' && selfNote != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            selfNote!,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                        if (notes[name] case final note?) ...[
                          const SizedBox(height: 2),
                          Text(
                            note,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceData {
  const _AttendanceData({
    required this.accepted,
    required this.declined,
    required this.declineReasons,
    required this.openCount,
  });

  final List<String> accepted;
  final List<String> declined;
  final Map<String, String> declineReasons;
  final int openCount;
}

class _ResponseButton extends StatelessWidget {
  const _ResponseButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: selected ? Colors.white : color,
        backgroundColor: selected ? color : Colors.transparent,
        side: BorderSide(color: color.withValues(alpha: selected ? 1 : .45)),
        visualDensity: VisualDensity.compact,
      ),
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _TrainingGroupCard extends StatelessWidget {
  const _TrainingGroupCard({
    required this.group,
    required this.sessions,
    required this.weekdayLabel,
    required this.canEdit,
    required this.onEdit,
  });

  final String group;
  final List<TrainingSession> sessions;
  final String Function(int weekday) weekdayLabel;
  final bool canEdit;
  final ValueChanged<TrainingSession> onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .96),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.red.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.sports_kabaddi_rounded,
                  size: 21,
                  color: AppColors.red,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  group,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: Color(0xFFE4E7EC)),
          ),
          ...sessions.map(
            (session) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 105,
                    child: Text(
                      weekdayLabel(session.weekday),
                      style: TextStyle(
                        color: AppColors.red,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.schedule_rounded,
                    size: 16,
                    color: AppColors.muted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${session.timeLabel} Uhr',
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (canEdit) ...[
                    const Spacer(),
                    IconButton(
                      tooltip: 'Trainingszeit bearbeiten',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => onEdit(session),
                      icon: const Icon(
                        Icons.edit_rounded,
                        size: 18,
                        color: AppColors.red,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
