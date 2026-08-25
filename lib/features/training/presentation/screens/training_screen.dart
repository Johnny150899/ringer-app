import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/widgets/app_glass_surface.dart';
import '../../data/sources/training_schedule.dart';
import '../../data/services/training_contact_service.dart';
import '../../domain/models/training_contact_info.dart';
import '../../domain/models/training_session.dart';

part '../widgets/training_navigation_widgets.dart';
part '../widgets/member_training_card.dart';
part '../widgets/attendance_widgets.dart';
part '../widgets/training_group_card.dart';
part '../widgets/training_contact_card.dart';

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
  TrainingContactInfo _contactInfo = TrainingContactInfo.defaults;

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
    _loadContactInfo();
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

  Future<void> _loadContactInfo() async {
    final client = widget.supabaseClient;
    if (client == null) return;
    try {
      final info = await TrainingContactService(client).load();
      if (mounted) setState(() => _contactInfo = info);
    } on PostgrestException {
      // Bis zur Migration bleiben die sicheren Standardwerte sichtbar.
    }
  }

  Future<void> _editContactInfo() async {
    final client = widget.supabaseClient;
    if (client == null || !widget.isAdmin) return;
    final clubName = TextEditingController(text: _contactInfo.clubName);
    final address = TextEditingController(text: _contactInfo.address);
    final contactName = TextEditingController(text: _contactInfo.contactName);
    final phone = TextEditingController(text: _contactInfo.phone);
    final email = TextEditingController(text: _contactInfo.email);
    final formKey = GlobalKey<FormState>();

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.contact_page_rounded, color: AppColors.red),
        title: const Text('Halle & Kontakt bearbeiten'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ContactTextField(controller: clubName, label: 'Verein'),
                _ContactTextField(
                  controller: address,
                  label: 'Adresse der Trainingshalle',
                  maxLines: 2,
                ),
                _ContactTextField(
                  controller: contactName,
                  label: 'Ansprechpartner',
                ),
                _ContactTextField(
                  controller: phone,
                  label: 'Telefon',
                  keyboardType: TextInputType.phone,
                ),
                _ContactTextField(
                  controller: email,
                  label: 'E-Mail',
                  keyboardType: TextInputType.emailAddress,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );

    if (save == true && mounted) {
      final updated = TrainingContactInfo(
        clubName: clubName.text.trim(),
        address: address.text.trim(),
        contactName: contactName.text.trim(),
        phone: phone.text.trim(),
        email: email.text.trim(),
      );
      try {
        await TrainingContactService(client).update(updated);
        if (!mounted) return;
        setState(() => _contactInfo = updated);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kontaktdaten wurden aktualisiert.')),
        );
      } on PostgrestException catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Änderung nicht möglich: ${error.message}')),
        );
      }
    }

    clubName.dispose();
    address.dispose();
    contactName.dispose();
    phone.dispose();
    email.dispose();
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
    final canSwitchView =
        widget.isAdmin ||
        widget.memberAccess ||
        (kDebugMode && !widget.memberAccess);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Training',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (canSwitchView)
              AppGlassSurface(
                borderRadius: 18,
                child: TextButton.icon(
                  onPressed: () =>
                      setState(() => _showMemberPreview = !_showMemberPreview),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  icon: Icon(
                    _showMemberPreview
                        ? Icons.public_rounded
                        : Icons.badge_outlined,
                    size: 16,
                  ),
                  label: Text(
                    _showMemberPreview ? 'Gästeansicht' : 'Mitgliederansicht',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (!_showMemberPreview) ...[
          const SizedBox(height: 3),
          const Text(
            'Unsere wöchentlichen Trainingszeiten.',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
        const SizedBox(height: 18),
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
        ] else ...[
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
          const SizedBox(height: 4),
          _TrainingContactCard(
            info: _contactInfo,
            canEdit: widget.isAdmin && widget.supabaseClient != null,
            onEdit: _editContactInfo,
          ),
        ],
      ],
    );
  }
}
