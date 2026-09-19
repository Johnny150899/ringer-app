import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../app/app_theme.dart';
import '../../domain/club_tasks.dart';

class UserDetailScreen extends StatefulWidget {
  const UserDetailScreen({
    super.key,
    required this.userId,
    required this.canManageRoles,
    this.client,
  });
  final String userId;
  final bool canManageRoles;
  final SupabaseClient? client;
  @override
  State<UserDetailScreen> createState() => _UserDetailState();
}

class _UserDetailState extends State<UserDetailScreen> {
  late final client = widget.client ?? Supabase.instance.client;
  Map<String, dynamic>? profile;
  String? error;
  bool loading = true, saving = false;
  bool trainer = false,
      organization = false,
      administrator = false,
      reviewer = false,
      revoke = false;
  final groups = <String>{};
  String original = '';
  String get draft =>
      '$trainer|$organization|$administrator|$reviewer|$revoke|${(groups.toList()..sort()).join(',')}';
  bool get dirty => profile != null && draft != original;
  bool get approved =>
      profile?['membership_status'] == 'approved' && profile?['role'] != 'fan';
  bool get ownAdmin =>
      widget.userId == client.auth.currentUser?.id &&
      profile?['role'] == 'admin';
  bool get editRoles => widget.canManageRoles && approved && !saving && !revoke;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final row = await client
          .from('profiles')
          .select(
            'id,first_name,last_name,role,is_trainer,is_organization,membership_status,membership_approved_at,updated_at,profile_training_groups(group_name)',
          )
          .eq('id', widget.userId)
          .single();
      var assigned = false;
      if (widget.canManageRoles) {
        assigned =
            (await client
                    .from('membership_reviewers')
                    .select('user_id')
                    .eq('user_id', widget.userId))
                .isNotEmpty;
      }
      if (!mounted) return;
      setState(() {
        profile = row;
        trainer = hasTrainerTask(row);
        organization = hasOrganizationTask(row);
        administrator = row['role'] == 'admin';
        reviewer = assigned;
        revoke = false;
        groups
          ..clear()
          ..addAll(
            (row['profile_training_groups'] as List? ?? []).map(
              (g) => g['group_name'] as String,
            ),
          );
        original = draft;
        loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error = 'Person konnte nicht geladen werden.';
        });
      }
    }
  }

  Future<bool> confirm(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
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
      ) ??
      false;
  Future<bool> mayLeave() async {
    if (saving) return false;
    return !dirty ||
        await confirm(
          'Änderungen verwerfen?',
          'Deine Änderungen sind noch nicht gespeichert. Möchtest du die Seite trotzdem verlassen?',
        );
  }

  Future<void> save() async {
    if (saving || !dirty || !approved) return;
    if (revoke &&
        !await confirm(
          'Vereinszugang entziehen?',
          'Rollen, Trainingsgruppen und Antragsberechtigung werden entfernt. Das Konto bleibt als Fan bestehen. Dies ersetzt keine vertragliche Kündigung.',
        )) {
      return;
    }
    if (!revoke &&
        administrator != (profile!['role'] == 'admin') &&
        !await confirm(
          'Adminrechte ändern?',
          administrator
              ? 'Diese Person erhält vollständige Verwaltungsrechte. Fortfahren?'
              : 'Die Adminrechte werden entfernt. Fortfahren?',
        )) {
      return;
    }
    if (!mounted) return;
    setState(() => saving = true);
    try {
      await client.rpc<void>(
        'save_person_settings',
        params: {
          'target_user_id': widget.userId,
          'expected_updated_at': profile!['updated_at'],
          'assigned_groups': groups.toList()..sort(),
          if (widget.canManageRoles) ...{
            'trainer': trainer,
            'organization': organization,
            'administrator': administrator,
            'review_applications': reviewer && organization,
            'revoke_access': revoke,
          },
        },
      );
      if (!mounted) return;
      setState(() {
        original = draft;
        saving = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Änderungen gespeichert.')));
      Navigator.of(context).pop(true);
    } catch (failure) {
      if (!mounted) return;
      final conflict =
          failure is PostgrestException &&
          failure.message.contains('settings_changed');
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            conflict
                ? 'Die Person wurde inzwischen geändert. Bitte neu laden und Änderungen erneut prüfen.'
                : 'Nicht gespeichert. Bitte Verbindung, Berechtigung und Datenbankmigration prüfen.',
          ),
        ),
      );
    }
  }

  Widget section(String title, List<Widget> children) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: ListTileTheme(
        data: const ListTileThemeData(
          dense: true,
          minTileHeight: 48,
          minVerticalPadding: 2,
          visualDensity: VisualDensity.compact,
          titleTextStyle: TextStyle(fontSize: 14, color: AppColors.text),
          subtitleTextStyle: TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            ...children,
          ],
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final name = profile == null
        ? 'Person verwalten'
        : '${profile!['first_name']} ${profile!['last_name']}'.trim();
    final status = switch (profile?['membership_status']) {
      'approved' => 'Genehmigt',
      'pending' => 'Antrag in Prüfung',
      'rejected' => 'Antrag abgelehnt',
      _ => 'Keine genehmigte Mitgliedschaft',
    };
    final date = DateTime.tryParse(
      '${profile?['membership_approved_at']}',
    )?.toLocal();
    // An async leave decision also protects navbar tab switches via maybePop.
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: mayLeave,
      child: Scaffold(
        appBar: AppBar(
          title: Text(name),
          actions: [
            TextButton(
              onPressed:
                  dirty && !saving && approved && !loading && error == null
                  ? save
                  : null,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white38,
              ),
              child: saving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                        semanticsLabel: 'Wird gespeichert',
                      ),
                    )
                  : const Text('Speichern'),
            ),

            IconButton(
              tooltip: 'Neu laden',
              onPressed: saving
                  ? null
                  : () async {
                      if (await mayLeave()) await load();
                    },
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: AppColors.backgroundGradient,
          ),
          child: loading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : error != null
              ? Center(
                  child: TextButton(
                    onPressed: load,
                    child: Text(
                      '$error Erneut versuchen',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                  children: [
                    section('Mitgliedschaft', [
                      Text(status, style: const TextStyle(fontSize: 13)),
                      if (date != null)
                        Text(
                          'Genehmigt am ${date.day}.${date.month}.${date.year}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      if (!approved)
                        const Text(
                          'Rollen und Trainingsgruppen können erst nach Genehmigung vergeben werden.',
                        ),
                    ]),
                    section('Rollen', [
                      if (!widget.canManageRoles)
                        const Text(
                          'Nur Admins können Rollen und weitere Berechtigungen ändern.',
                        ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Trainer'),
                        value: trainer,
                        onChanged: editRoles
                            ? (v) => setState(() => trainer = v)
                            : null,
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Organisation'),
                        value: organization,
                        onChanged: editRoles
                            ? (v) => setState(() {
                                organization = v;
                                if (!v) reviewer = false;
                              })
                            : null,
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Admin'),
                        value: administrator,
                        subtitle: ownAdmin
                            ? const Text(
                                'Eigene Adminrechte können hier nicht entfernt werden.',
                              )
                            : null,
                        onChanged: editRoles && !ownAdmin
                            ? (v) => setState(() => administrator = v)
                            : null,
                      ),
                    ]),
                    section('Berechtigungen', [
                      if (widget.canManageRoles)
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Mitgliedschaftsanträge bearbeiten',
                          ),
                          subtitle: Text(
                            administrator
                                ? 'Admins haben automatisch Zugriff.'
                                : organization
                                ? 'Zugriff auf Kontaktdaten und Entscheidungen über Anträge.'
                                : 'Erfordert die Rolle Organisation.',
                          ),
                          value: administrator || reviewer,
                          onChanged: editRoles && organization && !administrator
                              ? (v) => setState(() => reviewer = v)
                              : null,
                        )
                      else
                        const Text(
                          'Antragsberechtigungen werden ausschließlich von Admins verwaltet.',
                        ),
                    ]),
                    section('Trainingsgruppen', [
                      const Text(
                        'Die Person darf in den ausgewählten Gruppen zu- und absagen.',
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                      for (final group in ['Männer', 'Jugend', 'Bambinis'])
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(group),
                          value: groups.contains(group),
                          onChanged: approved && !saving && !revoke
                              ? (v) => setState(() {
                                  if (v == true) {
                                    groups.add(group);
                                  } else {
                                    groups.remove(group);
                                  }
                                })
                              : null,
                        ),
                    ]),
                    if (widget.canManageRoles && approved && !ownAdmin)
                      section('Vereinszugang', [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Vereinszugang entziehen'),
                          subtitle: const Text(
                            'Wird erst beim Speichern nach Bestätigung wirksam.',
                          ),
                          value: revoke,
                          onChanged: saving
                              ? null
                              : (v) => setState(() => revoke = v),
                        ),
                      ]),
                    const SizedBox(height: 16),
                  ],
                ),
        ),
      ),
    );
  }
}
