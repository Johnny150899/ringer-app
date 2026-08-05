part of '../screens/account_gate_screen.dart';

class _AccountScreen extends StatefulWidget {
  const _AccountScreen({required this.user});

  final User user;

  @override
  State<_AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<_AccountScreen> {
  late Future<Map<String, dynamic>?> _profile;
  bool _savingProfile = false;

  @override
  void initState() {
    super.initState();
    _profile = _loadProfile();
  }

  Future<Map<String, dynamic>?> _loadProfile() => Supabase.instance.client
      .from('profiles')
      .select('first_name, last_name, role, membership_status')
      .eq('id', widget.user.id)
      .maybeSingle();

  Future<void> _requestMembership() async {
    try {
      await Supabase.instance.client.rpc<void>('request_membership');
      if (!mounted) return;
      setState(() {
        _profile = _loadProfile();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mitgliedschaft wurde beantragt.')),
      );
    } on PostgrestException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Antrag nicht möglich: ${error.message}')),
      );
    }
  }

  Future<void> _editProfile(Map<String, dynamic>? profile) async {
    var firstName = profile?['first_name'] as String? ?? '';
    var lastName = profile?['last_name'] as String? ?? '';
    final formKey = GlobalKey<FormState>();
    final names = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Profildaten bearbeiten'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: firstName,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Vorname',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => firstName = value,
                validator: (value) => value == null || value.trim().length < 2
                    ? 'Bitte gib deinen Vornamen an.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: lastName,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nachname',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => lastName = value,
                validator: (value) => value == null || value.trim().length < 2
                    ? 'Bitte gib deinen Nachnamen an.'
                    : null,
              ),
            ],
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
                Navigator.pop(dialogContext, {
                  'first_name': firstName.trim(),
                  'last_name': lastName.trim(),
                });
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.navy),
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
    if (names == null || !mounted) return;

    setState(() => _savingProfile = true);
    try {
      await Supabase.instance.client
          .from('profiles')
          .update(names)
          .eq('id', widget.user.id);
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          data: {
            ...names,
            'full_name': '${names['first_name']} ${names['last_name']}',
          },
        ),
      );
      if (!mounted) return;
      setState(() {
        _profile = _loadProfile();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profildaten wurden gespeichert.')),
      );
    } on PostgrestException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Speichern nicht möglich: ${error.message}')),
      );
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        title: const Text('Mein Konto'),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: FutureBuilder<Map<String, dynamic>?>(
          future: _profile,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            }
            final profile = snapshot.data;
            final firstName = profile?['first_name'] as String? ?? '';
            final lastName = profile?['last_name'] as String? ?? '';
            final displayName = '$firstName $lastName'.trim();
            final role = profile?['role'] as String? ?? 'fan';
            final status =
                profile?['membership_status'] as String? ?? 'not_requested';
            final approved = status == 'approved';
            final isFan = role == 'fan';
            final isTrainer = role == 'trainer';
            final isOrganization = role == 'organization';
            final isAdmin = role == 'admin';
            final statusColor = isFan || approved
                ? const Color(0xFF168A5B)
                : Colors.orange.shade800;
            final statusText = isAdmin
                ? 'Administratorkonto'
                : isOrganization
                ? 'Organisationskonto'
                : isTrainer
                ? 'Trainerkonto'
                : isFan
                ? 'Fan-Konto aktiv'
                : approved
                ? 'Mitgliedschaft bestätigt'
                : 'Mitgliedschaft wird geprüft';
            return ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    children: [
                      const CircleAvatar(
                        radius: 31,
                        backgroundColor: AppColors.navy,
                        child: Icon(
                          Icons.person_rounded,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        displayName.isNotEmpty ? displayName : 'Fan',
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.user.email ?? '',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: .11),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isFan || approved
                                  ? Icons.verified_rounded
                                  : Icons.hourglass_top_rounded,
                              color: statusColor,
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                statusText,
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          key: const ValueKey('edit-profile-button'),
                          onPressed: _savingProfile
                              ? null
                              : () => _editProfile(profile),
                          icon: _savingProfile
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.edit_outlined),
                          label: const Text('Profildaten bearbeiten'),
                        ),
                      ),
                      if (isFan) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _requestMembership,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.navy,
                            ),
                            icon: const Icon(Icons.badge_outlined),
                            label: const Text('Mitgliedschaft beantragen'),
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              Supabase.instance.client.auth.signOut(),
                          icon: const Icon(Icons.logout_rounded),
                          label: const Text('Abmelden'),
                        ),
                      ),
                    ],
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
