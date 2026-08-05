part of '../screens/account_gate_screen.dart';

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
