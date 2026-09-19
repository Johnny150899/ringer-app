part of '../screens/account_gate_screen.dart';

class MembershipRequestsScreen extends StatelessWidget {
  const MembershipRequestsScreen({
    super.key,
    this.memberships = false,
    this.trials = true,
  });
  final bool memberships;
  final bool trials;
  @override
  Widget build(BuildContext context) {
    if (!trials) return const MembershipApplicationScreen(staff: true);
    if (!memberships) {
      return Scaffold(
        appBar: AppBar(title: const Text('Probetrainings')),
        body: TrialRequestsPanel(client: Supabase.instance.client, staff: true),
      );
    }
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Anträge'),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'Mitgliedschaft'),
              Tab(text: 'Probetraining'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            const MembershipApplicationScreen(staff: true, embedded: true),
            TrialRequestsPanel(client: Supabase.instance.client, staff: true),
          ],
        ),
      ),
    );
  }
}
