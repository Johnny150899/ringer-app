import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/app_theme.dart';
import '../../../auth/presentation/screens/account_gate_screen.dart';
import 'trial_requests_panel.dart';

class TrialTrainingScreen extends StatefulWidget {
  const TrialTrainingScreen({
    super.key,
    required this.client,
    this.initialName = '',
  });
  final SupabaseClient client;
  final String initialName;

  @override
  State<TrialTrainingScreen> createState() => _TrialTrainingScreenState();
}

class _TrialTrainingScreenState extends State<TrialTrainingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _note = TextEditingController();
  String _group = 'Männer';
  bool _saving = false;
  int _revision = 0;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (widget.client.auth.currentUser == null) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final userId = widget.client.auth.currentUser!.id;
      final profile = await widget.client
          .from('profiles')
          .select('first_name, last_name')
          .eq('id', userId)
          .single();
      final name =
          '${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}'.trim();
      if (name.length < 3) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Bitte vervollständige zuerst deinen Namen unter „Mein Konto“.',
              ),
            ),
          );
        }
        return;
      }
      await widget.client.rpc(
        'request_trial_training',
        params: {
          'applicant_name': name,
          'applicant_phone': null,
          'requested_group': _group,
          'applicant_note': _note.text.trim(),
        },
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(
            Icons.check_circle_rounded,
            color: AppColors.success,
          ),
          title: const Text('Anfrage gesendet'),
          content: const Text(
            'Deine Anfrage liegt jetzt bei den Trainern. Hier siehst du die Freigabe und deine bis zu vier Probetrainings.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fertig'),
            ),
          ],
        ),
      );
      if (mounted) {
        setState(() => _revision++);
      }
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Anfrage nicht möglich: ${error.message}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
    stream: widget.client.auth.onAuthStateChange,
    builder: (context, snapshot) {
      final user = widget.client.auth.currentUser;
      if (user == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Probetraining')),
          body: Container(
            decoration: const BoxDecoration(
              gradient: AppColors.backgroundGradient,
            ),
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, color: Colors.white, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'Bitte melde dich an, um ein Probetraining anzufragen und deine vier Teilnahmen zu verfolgen.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const AccountGateScreen(),
                        ),
                      );
                      if (!mounted) return;
                      setState(() {});
                    },
                    child: const Text('Anmelden / Registrieren'),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      return Scaffold(
        appBar: AppBar(title: const Text('Mein Probetraining')),
        body: TrialRequestsPanel(
          key: ValueKey('${user.id}:$_revision'),
          client: widget.client,
          emptyBuilder: _buildForm,
        ),
      );
    },
  );

  Widget _buildForm(BuildContext context) => Scaffold(
    body: DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ringen ausprobieren',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Die Trainer prüfen deine Anfrage. Du kannst bis zu viermal am Probetraining teilnehmen.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 18),
                  DropdownButtonFormField<String>(
                    initialValue: _group,
                    decoration: const InputDecoration(
                      labelText: 'Trainingsgruppe',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Männer', child: Text('Männer')),
                      DropdownMenuItem(value: 'Jugend', child: Text('Jugend')),
                      DropdownMenuItem(
                        value: 'Bambinis',
                        child: Text('Bambinis'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _group = value ?? _group),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _note,
                    maxLength: 1000,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Nachricht (optional)',
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _submit,
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                      label: const Text('Probetraining anfragen'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
