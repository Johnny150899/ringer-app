import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/app_theme.dart';

part '../widgets/account_screen.dart';
part '../widgets/membership_requests_screen.dart';

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
