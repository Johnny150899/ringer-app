import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';

const membershipStatusLabels = {
  'received': 'Eingegangen',
  'processing': 'In Bearbeitung',
  'approved': 'Genehmigt',
  'rejected': 'Abgelehnt',
};

Future<bool> submitMembershipApplication(BuildContext context) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) return false;
  final profile = await client
      .from('profiles')
      .select('first_name,last_name')
      .eq('id', user.id)
      .single();
  if (!context.mounted) return false;
  final first = '${profile['first_name'] ?? ''}'.trim();
  final last = '${profile['last_name'] ?? ''}'.trim();
  if (first.isEmpty || last.isEmpty || (user.email ?? '').isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Bitte ergänze zuerst Vor- und Nachname sowie deine E-Mail im Profil.',
        ),
      ),
    );
    return false;
  }
  final approved = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Mitgliedschaft beantragen'),
      content: SingleChildScrollView(
        child: Text(
          'Jahresbeitrag: 70 €\nDeine Mitgliedschaft beginnt erst nach Genehmigung.\n\n'
          'Diese Daten werden an die zuständigen Vereinsverantwortlichen in der App übermittelt:\n\n'
          '$first $last\n${user.email}\n\n'
          'Der Verein kontaktiert dich per E-Mail, um den Beitritt und die Zahlungsmodalitäten zu klären. '
          'Weitere Vertragsbedingungen werden dabei mit dir vereinbart. Mit diesem Antrag wird keine Zahlung ausgelöst.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Antrag senden'),
        ),
      ],
    ),
  );
  if (approved != true) return false;
  await client.rpc<void>('request_membership');
  return true;
}

class MembershipApplicationScreen extends StatefulWidget {
  const MembershipApplicationScreen({
    super.key,
    this.staff = false,
    this.client,
    this.embedded = false,
  });
  final bool embedded;
  final SupabaseClient? client;
  final bool staff;
  @override
  State<MembershipApplicationScreen> createState() => _ApplicationState();
}

class _ApplicationState extends State<MembershipApplicationScreen> {
  late final client = widget.client ?? Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> data;
  bool busy = false;
  bool archive = false;
  @override
  void initState() {
    super.initState();
    data = load();
  }

  Future<List<Map<String, dynamic>>> load() async {
    var query = client.from('membership_applications').select();
    if (!widget.staff) query = query.eq('user_id', client.auth.currentUser!.id);
    return await query.order('submitted_at', ascending: false);
  }

  Future<void> refresh() async {
    setState(() => data = load());
    await data;
  }

  Future<void> act(Map<String, dynamic> row, String action) async {
    if (busy) return;
    if (action != 'claim') {
      final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            action == 'approve'
                ? 'Mitgliedschaft genehmigen?'
                : 'Antrag ablehnen?',
          ),
          content: Text(
            action == 'approve'
                ? 'Der persönliche Beitrittsprozess ist abgeschlossen? Mit der Genehmigung beginnt die Mitgliedschaft heute.'
                : 'Soll dieser Mitgliedschaftsantrag abgelehnt werden?',
          ),
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
      if (yes != true) return;
    }
    setState(() => busy = true);
    try {
      await client.rpc<void>(
        action == 'claim'
            ? 'claim_membership_application'
            : 'review_membership_request',
        params: {
          'target_user_id': row['user_id'],
          if (action != 'claim') 'approve': action == 'approve',
        },
      );
      if (mounted) setState(() => data = load());
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Aktion nicht möglich. Bitte aktualisieren und Berechtigung prüfen.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: widget.embedded
        ? null
        : AppBar(
            title: Text(
              widget.staff ? 'Mitgliedschaftsanträge' : 'Mein Mitgliedsantrag',
            ),
            actions: [
              IconButton(
                onPressed: refresh,
                tooltip: 'Aktualisieren',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: data,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: refresh,
              child: const Text('Anträge nicht verfügbar · Erneut versuchen'),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final rows = snapshot.data!
            .where(
              (r) =>
                  !widget.staff ||
                  (archive == ['approved', 'rejected'].contains(r['status'])),
            )
            .toList();
        return RefreshIndicator(
          onRefresh: refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              if (widget.staff)
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Offen')),
                    ButtonSegment(value: true, label: Text('Archiv')),
                  ],
                  selected: {archive},
                  onSelectionChanged: (v) => setState(() => archive = v.single),
                ),
              if (rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Keine Anträge vorhanden.'),
                ),
              for (final row in rows)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${row['first_name']} ${row['last_name']}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          membershipStatusLabels[row['status']] ??
                              '${row['status']}',
                        ),
                        const Text('Jahresbeitrag: 70 €'),
                        if (row['status'] == 'approved' &&
                            row['decided_at'] != null)
                          Text(
                            'Genehmigt am ${DateTime.parse(row['decided_at']).toLocal().day}.${DateTime.parse(row['decided_at']).toLocal().month}.${DateTime.parse(row['decided_at']).toLocal().year}',
                          ),
                        if (!widget.staff &&
                            ['received', 'processing'].contains(row['status']))
                          const Text(
                            'Der Verein wird dich per E-Mail kontaktieren. Deine Mitgliedschaft beginnt erst nach Genehmigung.',
                          ),
                        if (widget.staff) ...[
                          SelectableText('${row['email']}'),
                          TextButton.icon(
                            onPressed: () async {
                              await Clipboard.setData(
                                ClipboardData(text: '${row['email']}'),
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('E-Mail-Adresse kopiert.'),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.copy),
                            label: const Text('E-Mail kopieren'),
                          ),
                          if (row['status'] == 'processing')
                            Text(
                              row['assigned_to'] == client.auth.currentUser?.id
                                  ? 'Von dir übernommen'
                                  : 'Bereits von einer anderen Person übernommen',
                            ),
                          if (!archive)
                            Wrap(
                              spacing: 8,
                              children: [
                                if (row['assigned_to'] !=
                                        client.auth.currentUser?.id ||
                                    row['status'] == 'received')
                                  OutlinedButton(
                                    onPressed: busy
                                        ? null
                                        : () => act(row, 'claim'),
                                    child: const Text('Übernehmen'),
                                  ),
                                if (row['status'] == 'processing' &&
                                    row['assigned_to'] ==
                                        client.auth.currentUser?.id) ...[
                                  FilledButton(
                                    onPressed: busy
                                        ? null
                                        : () => act(row, 'approve'),
                                    child: const Text('Genehmigen'),
                                  ),
                                  TextButton(
                                    onPressed: busy
                                        ? null
                                        : () => act(row, 'reject'),
                                    child: const Text('Ablehnen'),
                                  ),
                                ],
                              ],
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}

class MembershipReviewersScreen extends StatefulWidget {
  const MembershipReviewersScreen({super.key});
  @override
  State<MembershipReviewersScreen> createState() => _ReviewersState();
}

class _ReviewersState extends State<MembershipReviewersScreen> {
  final client = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> data;
  final selected = <String>{};
  bool busy = false;
  Future<List<Map<String, dynamic>>> load() async {
    final rights = await client.from('membership_reviewers').select('user_id');
    selected
      ..clear()
      ..addAll(rights.map((r) => r['user_id'] as String));
    return await client
        .from('profiles')
        .select('id,first_name,last_name')
        .eq('is_organization', true)
        .eq('membership_status', 'approved');
  }

  @override
  void initState() {
    super.initState();
    data = load();
  }

  Future<void> change(String id, bool value) async {
    setState(() => busy = true);
    try {
      if (value) {
        await client.from('membership_reviewers').insert({'user_id': id});
      } else {
        await client.from('membership_reviewers').delete().eq('user_id', id);
      }
      if (mounted) setState(() => data = load());
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Berechtigung nicht gespeichert.')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Zuständige Orga-Personen')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: data,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: () => setState(() => data = load()),
              child: const Text('Nicht verfügbar · Erneut versuchen'),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Admins haben immer Zugriff. Freigeschaltete Orga-Personen dürfen Kontaktdaten lesen und Mitgliedschaftsanträge bearbeiten.',
              ),
            ),
            if (snapshot.data!.isEmpty)
              const ListTile(
                title: Text('Keine genehmigten Orga-Konten vorhanden.'),
              ),
            for (final row in snapshot.data!)
              SwitchListTile(
                title: Text('${row['first_name']} ${row['last_name']}'),
                value: selected.contains(row['id']),
                onChanged: busy ? null : (v) => change(row['id'], v),
              ),
          ],
        );
      },
    ),
  );
}
