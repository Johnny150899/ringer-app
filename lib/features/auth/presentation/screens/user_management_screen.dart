import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/app_theme.dart';
import 'user_detail_screen.dart';
import '../../domain/club_tasks.dart';

part '../widgets/user_management_widgets.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({
    super.key,
    this.canManageRoles = false,
    this.client,
  });
  final SupabaseClient? client;

  final bool canManageRoles;

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  late final client = widget.client ?? Supabase.instance.client;
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
    final rows = await client
        .from('profiles')
        .select(
          'id, first_name, last_name, role, is_trainer, is_organization, membership_status, created_at, '
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

  Future<void> _openPerson(Map<String, dynamic> profile) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => UserDetailScreen(
          userId: profile['id'] as String,
          canManageRoles: widget.canManageRoles,
          client: client,
        ),
      ),
    );
    if (mounted) _reload();
  }

  List<Map<String, dynamic>> _filtered(List<Map<String, dynamic>> profiles) {
    final query = _searchController.text.trim().toLowerCase();
    return profiles.where((profile) {
      final matchesRole =
          _roleFilter == 'all' ||
          (_roleFilter == 'trainer'
              ? hasTrainerTask(profile)
              : _roleFilter == 'organization'
              ? hasOrganizationTask(profile)
              : _roleFilter == 'member'
              ? profile['membership_status'] == 'approved'
              : profile['role'] == _roleFilter);
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
                              setState(() {
                                _profiles = Future.value(refreshed);
                              });
                            }
                          },
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
                            itemCount: profiles.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 9),
                            itemBuilder: (context, index) => _ProfileCard(
                              profile: profiles[index],
                              onTap: () => _openPerson(profiles[index]),
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
