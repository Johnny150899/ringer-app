import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/app_theme.dart';

part '../widgets/user_management_widgets.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key, this.canManageRoles = false});

  final bool canManageRoles;

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  static const _roles = [
    'all',
    'fan',
    'member',
    'trainer',
    'organization',
    'admin',
  ];

  late Future<List<Map<String, dynamic>>> _profiles;
  final _searchController = TextEditingController();
  String _roleFilter = 'all';
  String? _processingUserId;

  @override
  void initState() {
    super.initState();
    _profiles = _loadProfiles();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _loadProfiles() async {
    final rows = await Supabase.instance.client
        .from('profiles')
        .select(
          'id, first_name, last_name, role, membership_status, created_at, '
          'can_respond_training, training_group, '
          'profile_training_groups(group_name)',
        )
        .order('last_name')
        .order('first_name');
    return List<Map<String, dynamic>>.from(rows);
  }

  void _reload() {
    final profiles = _loadProfiles();
    setState(() {
      _profiles = profiles;
    });
  }

  Future<void> _changeRole(Map<String, dynamic> profile, String newRole) async {
    final oldRole = profile['role'] as String? ?? 'fan';
    if (oldRole == newRole) return;
    final userId = profile['id'] as String;
    final name = _displayName(profile);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.manage_accounts_rounded, color: AppColors.red),
        title: const Text('Rolle ändern?'),
        content: Text(
          '$name wird von „${_roleLabel(oldRole)}“ zu '
          '„${_roleLabel(newRole)}“ geändert.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Ändern'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _processingUserId = userId);
    try {
      await Supabase.instance.client.rpc<void>(
        'set_user_role',
        params: {'target_user_id': userId, 'new_role': newRole},
      );
      if (!mounted) return;
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name ist jetzt ${_roleLabel(newRole)}.')),
      );
    } on PostgrestException catch (error) {
      if (!mounted) return;
      final message = error.message.contains('cannot_change_own_role')
          ? 'Deine eigene Admin-Rolle kann hier nicht geändert werden.'
          : 'Rolle konnte nicht geändert werden: ${error.message}';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _processingUserId = null);
    }
  }

  Future<void> _configureTraining(Map<String, dynamic> profile) async {
    final existing = List<Map<String, dynamic>>.from(
      profile['profile_training_groups'] as List? ?? const [],
    );
    final groups = existing.map((row) => row['group_name'] as String).toSet();
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          icon: const Icon(Icons.sports_kabaddi_rounded, color: AppColors.red),
          title: const Text('Trainingsgruppen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: ['Männer', 'Jugend', 'Bambinis']
                .map(
                  (group) => CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(group),
                    subtitle: const Text('Darf für diese Gruppe zu-/absagen'),
                    value: groups.contains(group),
                    onChanged: (selected) => setDialogState(() {
                      if (selected == true) {
                        groups.add(group);
                      } else {
                        groups.remove(group);
                      }
                    }),
                  ),
                )
                .toList(growable: false),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
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
    if (save != true || !mounted) return;
    final userId = profile['id'] as String;
    setState(() => _processingUserId = userId);
    try {
      await Supabase.instance.client.rpc<void>(
        'set_training_groups',
        params: {
          'target_user_id': userId,
          'assigned_groups': groups.toList(growable: false),
        },
      );
      if (mounted) _reload();
    } on PostgrestException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Zuordnung nicht möglich: ${error.message}')),
      );
    } finally {
      if (mounted) setState(() => _processingUserId = null);
    }
  }

  List<Map<String, dynamic>> _filtered(List<Map<String, dynamic>> profiles) {
    final query = _searchController.text.trim().toLowerCase();
    return profiles.where((profile) {
      final matchesRole =
          _roleFilter == 'all' || profile['role'] == _roleFilter;
      final matchesQuery =
          query.isEmpty || _displayName(profile).toLowerCase().contains(query);
      return matchesRole && matchesQuery;
    }).toList();
  }

  String _displayName(Map<String, dynamic> profile) {
    final firstName = profile['first_name'] as String? ?? '';
    final lastName = profile['last_name'] as String? ?? '';
    final name = '$firstName $lastName'.trim();
    return name.isEmpty ? 'Unbekanntes Profil' : name;
  }

  static String _roleLabel(String role) => switch (role) {
    'fan' => 'Fan',
    'member' => 'Mitglied',
    'trainer' => 'Trainer',
    'organization' => 'Organisation',
    'admin' => 'Admin',
    _ => 'Alle',
  };

  static Color _roleColor(String role) => switch (role) {
    'admin' => AppColors.red,
    'trainer' => const Color(0xFF7154B8),
    'organization' => const Color(0xFFB45309),
    'member' => const Color(0xFF168A5B),
    _ => const Color(0xFF64748B),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        title: const Text('Benutzerverwaltung'),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _profiles,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            }
            if (snapshot.hasError) {
              return _ErrorView(onRetry: _reload);
            }
            final allProfiles = snapshot.data ?? const [];
            final profiles = _filtered(allProfiles);
            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  color: const Color(0x19000000),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Name suchen',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _searchController.text.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.close_rounded),
                                ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 36,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _roles.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 7),
                          itemBuilder: (context, index) {
                            final role = _roles[index];
                            return ChoiceChip(
                              label: Text(_roleLabel(role)),
                              selected: _roleFilter == role,
                              showCheckmark: false,
                              onSelected: (_) =>
                                  setState(() => _roleFilter = role),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: profiles.isEmpty
                      ? const Center(
                          child: Text(
                            'Keine passenden Benutzer gefunden.',
                            style: TextStyle(color: Colors.white),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () async {
                            final refreshed = await _loadProfiles();
                            if (mounted) {
                              setState(
                                () => _profiles = Future.value(refreshed),
                              );
                            }
                          },
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
                            itemCount: profiles.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 9),
                            itemBuilder: (context, index) => _ProfileCard(
                              profile: profiles[index],
                              processing:
                                  _processingUserId == profiles[index]['id'],
                              onRoleChanged: (role) =>
                                  _changeRole(profiles[index], role),
                              onConfigureTraining: () =>
                                  _configureTraining(profiles[index]),
                              canManageRoles: widget.canManageRoles,
                            ),
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
