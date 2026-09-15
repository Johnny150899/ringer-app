import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/app_theme.dart';

class TrialRequestsPanel extends StatefulWidget {
  const TrialRequestsPanel({
    super.key,
    required this.client,
    this.staff = false,
    this.emptyBuilder,
  });
  final SupabaseClient client;
  final bool staff;
  final WidgetBuilder? emptyBuilder;

  @override
  State<TrialRequestsPanel> createState() => _TrialRequestsPanelState();
}

class _TrialRequestsPanelState extends State<TrialRequestsPanel> {
  late Future<List<Map<String, dynamic>>> _data;
  bool _busy = false;
  bool _showArchive = false;
  String _archiveSearch = '';

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final user = widget.client.auth.currentUser;
    if (!widget.staff && user == null) return [];
    var query = widget.client.from('trial_training_requests').select('*');
    if (!widget.staff) query = query.eq('user_id', user!.id);
    final rows = await query.order('created_at', ascending: false);
    if (rows.isEmpty) return [];
    final visits = await widget.client
        .from('trial_training_visits')
        .select('*')
        .inFilter('request_id', rows.map((row) => row['id']).toList());
    return [
      for (final row in rows)
        {
          ...row,
          'trial_training_visits': visits
              .where((visit) => visit['request_id'] == row['id'])
              .toList(),
        },
    ];
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() {
      _data = next;
    });
    await next;
  }

  Future<void> _act(
    Map<String, dynamic> row,
    String action, {
    int? visitId,
  }) async {
    DateTime? date;
    if (action == 'attend') {
      final now = DateTime.now();
      date = await showDatePicker(
        context: context,
        initialDate: now,
        firstDate: DateTime(2000),
        lastDate: now,
        helpText: 'Absolviertes Probetraining erfassen',
        cancelText: 'Abbrechen',
        confirmText: 'Weiter',
        fieldLabelText: 'Trainingsdatum',
      );
      if (date == null || !mounted) return;
    }
    final message = switch (action) {
      'approve' => 'Probetraining für ${row['full_name']} freigeben?',
      'reject' =>
        'Probetraining für ${row['full_name']} ablehnen bzw. beenden?',
      'undo' =>
        'Diese Teilnahme als Fehleintrag markieren? Der Platz wird wieder frei.',
      _ =>
        'Teilnahme von ${row['full_name']} am ${_date(date!.toIso8601String())} bestätigen? Nur tatsächlich absolvierte Trainings zählen.',
    };
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bitte bestätigen'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Bestätigen'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.client.rpc(
        'manage_trial_training',
        params: {
          'target_request_id': row['id'],
          'action': action,
          'visit_date': date?.toIso8601String().split('T').first,
          'target_visit_id': visitId,
        },
      );
      // The mutation is already complete here. A refresh failure must not
      // make a successfully recorded attendance look like an error.
      if (mounted) {
        try {
          await _refresh();
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Gespeichert. Die Übersicht konnte noch nicht aktualisiert werden.',
                ),
              ),
            );
          }
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is PostgrestException
                  ? error.message
                  : 'Die Anfrage konnte nicht verarbeitet werden.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _date(String value) {
    final date = DateTime.parse(value);
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
    child: FutureBuilder<List<Map<String, dynamic>>>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Probetrainings konnten nicht geladen werden.',
                  style: TextStyle(color: Colors.white),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _data = _load();
                    });
                  },
                  child: const Text('Erneut versuchen'),
                ),
              ],
            ),
          );
        }
        final rows = snapshot.data ?? [];
        bool archived(Map<String, dynamic> row) => row['status'] == 'completed';
        final archivedCount = rows.where(archived).length;
        final visibleRows = widget.staff
            ? rows
                  .where(
                    (row) =>
                        archived(row) == _showArchive &&
                        (!_showArchive ||
                            _archiveSearch
                                .trim()
                                .toLowerCase()
                                .split(RegExp(r'\s+'))
                                .every(
                                  (part) => (row['full_name'] as String? ?? '')
                                      .toLowerCase()
                                      .contains(part),
                                )),
                  )
                  .toList()
            : rows;
        if (rows.isEmpty && widget.emptyBuilder != null) {
          return widget.emptyBuilder!(context);
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              if (widget.staff) ...[
                SegmentedButton<bool>(
                  style: SegmentedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.navy,
                    selectedBackgroundColor: AppColors.navy,
                    selectedForegroundColor: Colors.white,
                  ),
                  segments: [
                    ButtonSegment(
                      value: false,
                      label: Text('Aktuell (${rows.length - archivedCount})'),
                    ),
                    ButtonSegment(
                      value: true,
                      icon: const Icon(Icons.inventory_2_outlined),
                      label: Text('Archiv ($archivedCount)'),
                    ),
                  ],
                  selected: {_showArchive},
                  onSelectionChanged: (value) => setState(() {
                    _showArchive = value.first;
                  }),
                ),
                const SizedBox(height: 16),
              ],
              if (widget.staff && _showArchive) ...[
                TextField(
                  onChanged: (value) => setState(() {
                    _archiveSearch = value;
                  }),
                  decoration: const InputDecoration(
                    hintText: 'Vor- oder Nachname suchen',
                    prefixIcon: Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 14),
              ],
              if (visibleRows.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _showArchive
                        ? (_archiveSearch.trim().isEmpty
                              ? 'Keine abgeschlossenen Probetrainings'
                              : 'Keine passenden Namen gefunden')
                        : 'Keine aktuellen Probetraining-Anfragen',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ...visibleRows.map(_card),
            ],
          ),
        );
      },
    ),
  );

  Widget _card(Map<String, dynamic> row) {
    if (widget.staff && _showArchive) {
      return Card(
        color: Colors.white,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        margin: const EdgeInsets.only(bottom: AppDesign.cardGap),
        child: ExpansionTile(
          key: PageStorageKey('trial-archive-compact-${row['id']}'),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          title: Text(
            row['full_name'] as String? ?? '',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          children: [_archiveDetails(row)],
        ),
      );
    }
    final visits =
        List<Map<String, dynamic>>.from(
          row['trial_training_visits'] as List? ?? [],
        )..sort(
          (a, b) => (a['attended_on'] as String).compareTo(
            b['attended_on'] as String,
          ),
        );
    final count = visits.where((v) => v['voided_at'] == null).length;
    final status = row['status'];
    final legacy = row['user_id'] == null;
    final statusLabel = switch (status) {
      'contacted' => 'Freigegeben',
      'completed' => 'Probetraining abgeschlossen',
      'cancelled' => 'Abgelehnt / beendet',
      _ => 'Wartet auf Bestätigung',
    };
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.red.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.sports_kabaddi_rounded,
                    color: AppColors.red,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    row['full_name'] as String,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (widget.staff && (status == 'open' || status == 'contacted'))
                  PopupMenuButton<String>(
                    tooltip: 'Weitere Aktionen',
                    enabled: !_busy,
                    onSelected: (value) => _act(row, value),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'reject',
                        child: Text(
                          status == 'open'
                              ? 'Anfrage ablehnen'
                              : 'Probetraining beenden',
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${row['training_group']} · Anfrage vom ${_date(row['created_at'] as String)}',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color:
                    (status == 'contacted' ? AppColors.success : AppColors.navy)
                        .withValues(alpha: .07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    status == 'contacted'
                        ? Icons.verified_outlined
                        : Icons.info_outline,
                    size: 17,
                    color: status == 'contacted'
                        ? AppColors.success
                        : AppColors.navy,
                  ),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: status == 'contacted'
                            ? AppColors.success
                            : AppColors.navy,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (legacy)
              const Text(
                'Altanfrage ohne Konto. Bitte angemeldet erneut anfragen. Keine automatische Kontozuordnung.',
              ),
            const SizedBox(height: 12),
            Text(
              '$count / 4 Probetrainings absolviert',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (var i = 0; i < 4; i++)
                  Expanded(
                    child: Container(
                      margin: EdgeInsets.only(right: i == 3 ? 0 : 8),
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        color: i < count
                            ? AppColors.success.withValues(alpha: .1)
                            : const Color(0xFFF1F4F8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            i < count
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked,
                            size: 19,
                            color: i < count
                                ? AppColors.success
                                : const Color(0xFFB5C0CD),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            if (row['phone'] != null) Text('Telefon: ${row['phone']}'),
            if (row['note'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text('Nachricht: ${row['note']}'),
              ),
            if (visits.isNotEmpty)
              ExpansionTile(
                dense: true,
                tilePadding: EdgeInsets.zero,
                title: const Text('Teilnahmeverlauf'),
                children: [
                  for (final visit in visits)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        visit['voided_at'] == null
                            ? Icons.check_circle_outline
                            : Icons.undo,
                      ),
                      title: Text(_date(visit['attended_on'] as String)),
                      subtitle: visit['voided_at'] != null
                          ? const Text('Als Fehleintrag korrigiert')
                          : null,
                      trailing: widget.staff && visit['voided_at'] == null
                          ? IconButton(
                              tooltip: 'Fehleintrag korrigieren',
                              onPressed: _busy
                                  ? null
                                  : () => _act(
                                      row,
                                      'undo',
                                      visitId: visit['id'] as int,
                                    ),
                              icon: const Icon(Icons.undo),
                            )
                          : null,
                    ),
                ],
              ),
            if (widget.staff)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 18),
                  if (!legacy &&
                      (status == 'open' || status == 'cancelled') &&
                      count < 4)
                    FilledButton(
                      onPressed: _busy ? null : () => _act(row, 'approve'),
                      child: const Text('Freigeben'),
                    ),
                  if (!legacy && status == 'contacted' && count < 4)
                    FilledButton.icon(
                      onPressed: _busy ? null : () => _act(row, 'attend'),
                      icon: const Icon(Icons.add),
                      label: const Text('Teilnahme erfassen'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _archiveDetails(Map<String, dynamic> row) {
    final visits =
        List<Map<String, dynamic>>.from(
          row['trial_training_visits'] as List? ?? [],
        )..sort(
          (a, b) => (a['attended_on'] as String).compareTo(
            b['attended_on'] as String,
          ),
        );
    final completedCount = visits
        .where((visit) => visit['voided_at'] == null)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1),
        const SizedBox(height: 12),
        Text(
          '${row['training_group']} · Anfrage vom ${_date(row['created_at'] as String)}',
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Text(
          '$completedCount / 4 Probetrainings absolviert',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        if (row['note'] != null) ...[
          const SizedBox(height: 8),
          Text('Nachricht: ${row['note']}'),
        ],
        if (visits.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text(
            'Teilnahmen',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          for (final visit in visits)
            SizedBox(
              height: 40,
              child: Row(
                children: [
                  Icon(
                    visit['voided_at'] == null
                        ? Icons.check_circle_outline_rounded
                        : Icons.undo_rounded,
                    size: 19,
                    color: visit['voided_at'] == null
                        ? AppColors.success
                        : AppColors.muted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _date(visit['attended_on'] as String),
                      style: TextStyle(
                        color: visit['voided_at'] == null
                            ? AppColors.text
                            : AppColors.muted,
                      ),
                    ),
                  ),
                  if (visit['voided_at'] == null)
                    IconButton(
                      tooltip: 'Fehleintrag korrigieren',
                      onPressed: _busy
                          ? null
                          : () =>
                                _act(row, 'undo', visitId: visit['id'] as int),
                      icon: const Icon(Icons.undo_rounded, size: 19),
                    ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
