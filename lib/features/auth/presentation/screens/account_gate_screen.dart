import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/app_theme.dart';

class AccountGateScreen extends StatelessWidget {
  const AccountGateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Supabase.instance.client.auth;
    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? auth.currentSession;
        return session == null
            ? const _AuthScreen()
            : _AccountScreen(user: session.user);
      },
    );
  }
}

class _AuthScreen extends StatefulWidget {
  const _AuthScreen();

  @override
  State<_AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<_AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordRepeatController = TextEditingController();
  bool _registering = false;
  bool _loading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordRepeatController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final navigator = Navigator.of(context);
    setState(() => _loading = true);
    try {
      final auth = Supabase.instance.client.auth;
      if (_registering) {
        final firstName = _firstNameController.text.trim();
        final lastName = _lastNameController.text.trim();
        final response = await auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          data: {
            'first_name': firstName,
            'last_name': lastName,
            'full_name': '$firstName $lastName',
          },
        );
        if (response.session == null) {
          if (!mounted) return;
          setState(() => _registering = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Registrierung erfolgreich. Bitte bestätige deine E-Mail.',
              ),
            ),
          );
        } else if (navigator.canPop()) {
          navigator.pop(true);
        }
      } else {
        await auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        if (navigator.canPop()) navigator.pop(true);
      }
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_authMessage(error.message))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _authMessage(String message) {
    final normalized = message.toLowerCase();
    if (normalized.contains('invalid login credentials')) {
      return 'E-Mail oder Passwort ist nicht korrekt.';
    }
    if (normalized.contains('already registered')) {
      return 'Für diese E-Mail besteht bereits ein Konto.';
    }
    if (normalized.contains('email not confirmed')) {
      return 'Bitte bestätige zuerst deine E-Mail-Adresse.';
    }
    return 'Anmeldung nicht möglich: $message';
  }

  void _toggleMode() {
    setState(() {
      _registering = !_registering;
      _formKey.currentState?.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        title: Text(_registering ? 'Konto erstellen' : 'Anmelden'),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 28, 18, 32),
            children: [
              const Icon(
                Icons.account_circle_rounded,
                size: 62,
                color: Colors.white,
              ),
              const SizedBox(height: 12),
              Text(
                _registering ? 'Fan-Konto erstellen' : 'Willkommen zurück',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _registering
                    ? 'Mit deinem kostenlosen Konto kannst du unsere Livestreams sehen.'
                    : 'Melde dich für den Mitgliederbereich an.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      if (_registering) ...[
                        TextFormField(
                          controller: _firstNameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Vorname',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              value == null || value.trim().length < 2
                              ? 'Bitte gib deinen Vornamen an.'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _lastNameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Nachname',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              value == null || value.trim().length < 2
                              ? 'Bitte gib deinen Nachnamen an.'
                              : null,
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'E-Mail',
                          prefixIcon: Icon(Icons.mail_outline_rounded),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final email = value?.trim() ?? '';
                          return email.contains('@') && email.contains('.')
                              ? null
                              : 'Bitte gib eine gültige E-Mail an.';
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        autofillHints: const [AutofillHints.password],
                        decoration: InputDecoration(
                          labelText: 'Passwort',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (value) => (value?.length ?? 0) < 8
                            ? 'Das Passwort muss mindestens 8 Zeichen haben.'
                            : null,
                      ),
                      if (_registering) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passwordRepeatController,
                          obscureText: _obscurePassword,
                          decoration: const InputDecoration(
                            labelText: 'Passwort wiederholen',
                            prefixIcon: Icon(Icons.lock_reset_rounded),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              value != _passwordController.text
                              ? 'Die Passwörter stimmen nicht überein.'
                              : null,
                        ),
                      ],
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _loading ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.red,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: _loading
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  _registering ? 'Registrieren' : 'Anmelden',
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _loading ? null : _toggleMode,
                        child: Text(
                          _registering
                              ? 'Ich habe bereits ein Konto'
                              : 'Noch kein Konto? Registrieren',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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

class MembershipRequestsScreen extends StatefulWidget {
  const MembershipRequestsScreen({super.key});

  @override
  State<MembershipRequestsScreen> createState() =>
      _MembershipRequestsScreenState();
}

class _MembershipRequestsScreenState extends State<MembershipRequestsScreen> {
  late Future<List<Map<String, dynamic>>> _requests;
  String? _processingUserId;

  @override
  void initState() {
    super.initState();
    _requests = _loadRequests();
  }

  Future<List<Map<String, dynamic>>> _loadRequests() async {
    final rows = await Supabase.instance.client
        .from('profiles')
        .select('id, first_name, last_name, created_at')
        .eq('role', 'member')
        .eq('membership_status', 'pending')
        .order('created_at');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> _review(String userId, bool approve) async {
    setState(() => _processingUserId = userId);
    try {
      await Supabase.instance.client.rpc<void>(
        'review_membership_request',
        params: {'target_user_id': userId, 'approve': approve},
      );
      if (!mounted) return;
      setState(() {
        _requests = _loadRequests();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve ? 'Mitgliedschaft bestätigt.' : 'Antrag abgelehnt.',
          ),
        ),
      );
    } on PostgrestException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Aktion nicht möglich: ${error.message}')),
      );
    } finally {
      if (mounted) setState(() => _processingUserId = null);
    }
  }

  Future<void> _confirmReview(String userId, String name, bool approve) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          approve ? Icons.how_to_reg_rounded : Icons.person_remove_outlined,
          color: approve ? const Color(0xFF168A5B) : AppColors.red,
        ),
        title: Text(approve ? 'Mitglied bestätigen?' : 'Antrag ablehnen?'),
        content: Text(
          approve
              ? 'Möchtest du $name wirklich als Vereinsmitglied freischalten?'
              : 'Möchtest du den Mitgliedsantrag von $name wirklich ablehnen?',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: approve
                  ? const Color(0xFF168A5B)
                  : AppColors.red,
            ),
            child: Text(approve ? 'Bestätigen' : 'Ablehnen'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _review(userId, approve);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        title: const Text('Mitgliedsanträge'),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _requests,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            }
            if (snapshot.hasError) {
              return const Center(
                child: Text(
                  'Anträge konnten nicht geladen werden.',
                  style: TextStyle(color: Colors.white),
                ),
              );
            }
            final requests = snapshot.data ?? const [];
            if (requests.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.task_alt_rounded, size: 54, color: Colors.white),
                    SizedBox(height: 12),
                    Text(
                      'Keine offenen Anträge',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
              itemCount: requests.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final request = requests[index];
                final userId = request['id'] as String;
                final firstName = request['first_name'] as String? ?? '';
                final lastName = request['last_name'] as String? ?? '';
                final name = '$firstName $lastName'.trim();
                final displayName = name.isEmpty ? 'Unbekanntes Profil' : name;
                final processing = _processingUserId == userId;
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: AppColors.navy,
                            child: Icon(Icons.person, color: Colors.white),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              displayName,
                              style: const TextStyle(
                                color: AppColors.text,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: processing
                                  ? null
                                  : () => _confirmReview(
                                      userId,
                                      displayName,
                                      false,
                                    ),
                              icon: const Icon(Icons.close_rounded),
                              label: const Text('Ablehnen'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: processing
                                  ? null
                                  : () => _confirmReview(
                                      userId,
                                      displayName,
                                      true,
                                    ),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF168A5B),
                              ),
                              icon: processing
                                  ? const SizedBox.square(
                                      dimension: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.check_rounded),
                              label: const Text('Bestätigen'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
