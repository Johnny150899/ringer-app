part of '../screens/account_gate_screen.dart';

class MembershipBenefitsScreen extends StatelessWidget {
  const MembershipBenefitsScreen({
    super.key,
    required this.profile,
    required this.email,
    required this.onRequestMembership,
    this.embedded = false,
    this.actionLabel = 'Mitgliedschaft beantragen',
  });

  final Map<String, dynamic>? profile;
  final String email;
  final Future<void> Function() onRequestMembership;
  final bool embedded;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    final role = profile?['role'] as String? ?? 'fan';
    final approved = profile?['membership_status'] == 'approved';
    final pending = profile?['membership_status'] == 'pending';
    final isMember = approved && role != 'fan';
    final name =
        '${profile?['first_name'] ?? ''} ${profile?['last_name'] ?? ''}'.trim();
    final referralCode = profile?['referral_code'] as String?;

    final content = ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 112),
      children: [
        if (embedded) ...[
          Text(
            isMember ? 'Meine Vorteile' : 'Mitglied werden',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            isMember
                ? 'Dein Mitgliederbereich auf einen Blick.'
                : 'Werde Teil des KSC Olympia.',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 18),
        ],
        if (isMember)
          _DigitalMemberCard(name: name, email: email, code: referralCode)
        else
          const _MembershipIntroCard(),
        if (pending || profile?['membership_status'] == 'rejected')
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const MembershipApplicationScreen(),
              ),
            ),
            child: const Text(
              'Antragsstatus ansehen',
              style: TextStyle(color: Colors.white),
            ),
          ),
        const SizedBox(height: 16),
        const Text(
          'Deine Möglichkeiten',
          style: TextStyle(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        const _BenefitTile(
          icon: Icons.fitness_center_rounded,
          title: 'Gemeinsam trainieren',
          body:
              'Nimm am Vereinsbetrieb teil und werde Teil unserer Trainingsgruppen.',
        ),
        const _BenefitTile(
          icon: Icons.event_available_rounded,
          title: 'Training planen',
          body: 'Als aktiver Ringer kannst du zu Einheiten zu- oder absagen.',
        ),
        const _BenefitTile(
          icon: Icons.groups_rounded,
          title: 'Vereinsgemeinschaft',
          body:
              'Erhalte interne Informationen und bleibe bei Veranstaltungen dabei.',
        ),
        if (isMember) ...[
          const SizedBox(height: 8),
          _PartnerOffersSection(),
          if (referralCode != null && referralCode.isNotEmpty) ...[
            const SizedBox(height: 16),
            _ReferralCard(code: referralCode),
          ],
        ] else ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => TrialTrainingScreen(
                  client: Supabase.instance.client,
                  initialName: name,
                ),
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white54),
            ),
            icon: const Icon(Icons.sports_kabaddi_rounded),
            label: const Text('Probetraining anfragen'),
          ),
          const SizedBox(height: 8),
          if (pending)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(Icons.hourglass_top_rounded, color: AppColors.red),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Dein Mitgliedsantrag wird gerade vom Verein geprüft.',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            )
          else
            FilledButton.icon(
              onPressed: () async {
                await onRequestMembership();
                if (!embedded && context.mounted) Navigator.pop(context);
              },
              style: FilledButton.styleFrom(backgroundColor: AppColors.navy),
              icon: const Icon(Icons.badge_outlined),
              label: Text(actionLabel),
            ),
          if (!pending) ...[
            const SizedBox(height: 8),
            const Text(
              'Dein Antrag wird anschließend vom Verein geprüft.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ],
      ],
    );

    if (embedded) return content;
    return Scaffold(
      backgroundColor: AppColors.navy,
      appBar: AppBar(
        title: Text(isMember ? 'Meine Vorteile' : 'Mitglied werden'),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: content,
      ),
    );
  }
}

class MembershipTabScreen extends StatefulWidget {
  const MembershipTabScreen({
    super.key,
    required this.isAuthenticated,
    required this.hasClubAccess,
    required this.role,
    required this.onLogin,
  });

  final bool isAuthenticated;
  final bool hasClubAccess;
  final String role;
  final Future<void> Function() onLogin;

  @override
  State<MembershipTabScreen> createState() => _MembershipTabScreenState();
}

class _MembershipTabScreenState extends State<MembershipTabScreen> {
  Future<Map<String, dynamic>?>? _profile;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant MembershipTabScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isAuthenticated != widget.isAuthenticated ||
        oldWidget.hasClubAccess != widget.hasClubAccess ||
        oldWidget.role != widget.role) {
      _reload();
    }
  }

  void _reload() {
    _profile = widget.isAuthenticated ? _loadProfile() : null;
  }

  Future<Map<String, dynamic>?> _loadProfile() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    try {
      return await client
          .from('profiles')
          .select(
            'first_name, last_name, role, membership_status, referral_code',
          )
          .eq('id', userId)
          .maybeSingle();
    } on PostgrestException {
      return client
          .from('profiles')
          .select('first_name, last_name, role, membership_status')
          .eq('id', userId)
          .maybeSingle();
    }
  }

  Future<void> _requestMembership() async {
    try {
      if (!await submitMembershipApplication(context)) return;
      if (!mounted) return;
      setState(_reload);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mitgliedsantrag wurde gesendet.')),
      );
    } on PostgrestException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Antrag nicht möglich: ${error.message}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isAuthenticated) {
      return MembershipBenefitsScreen(
        profile: null,
        email: '',
        embedded: true,
        actionLabel: 'Anmelden, um Mitglied zu werden',
        onRequestMembership: widget.onLogin,
      );
    }
    return FutureBuilder<Map<String, dynamic>?>(
      future: _profile,
      builder: (context, snapshot) {
        if (!snapshot.hasData &&
            snapshot.connectionState != ConnectionState.done &&
            !widget.hasClubAccess) {
          return Stack(
            children: [
              IgnorePointer(
                child: Opacity(
                  opacity: .72,
                  child: MembershipBenefitsScreen(
                    profile: const {
                      'role': 'fan',
                      'membership_status': 'not_requested',
                    },
                    email:
                        Supabase.instance.client.auth.currentUser?.email ?? '',
                    embedded: true,
                    onRequestMembership: _requestMembership,
                  ),
                ),
              ),
              const Align(
                alignment: Alignment.topCenter,
                child: LinearProgressIndicator(minHeight: 2),
              ),
            ],
          );
        }
        final profile = <String, dynamic>{
          if (snapshot.data != null) ...snapshot.data!,
          if (widget.hasClubAccess) ...{
            'role': widget.role,
            'membership_status': 'approved',
          },
        };
        if (widget.hasClubAccess) {
          return ClubScreen(
            supabaseClient: Supabase.instance.client,
            role: widget.role,
            onOpenMemberArea: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => MembershipBenefitsScreen(
                  profile: profile,
                  email: Supabase.instance.client.auth.currentUser?.email ?? '',
                  onRequestMembership: _requestMembership,
                ),
              ),
            ),
          );
        }
        return MembershipBenefitsScreen(
          profile: profile,
          email: Supabase.instance.client.auth.currentUser?.email ?? '',
          embedded: true,
          onRequestMembership: _requestMembership,
        );
      },
    );
  }
}

class _MembershipIntroCard extends StatelessWidget {
  const _MembershipIntroCard();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
    ),
    child: const Column(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: Color(0xFFFFE3EA),
          child: Icon(Icons.favorite_rounded, color: AppColors.red, size: 30),
        ),
        SizedBox(height: 14),
        Text(
          'Mehr als nur zuschauen',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
        ),
        SizedBox(height: 6),
        Text(
          'Werde Teil des KSC Olympia und gestalte das Vereinsleben aktiv mit.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted),
        ),
      ],
    ),
  );
}

class _BenefitTile extends StatelessWidget {
  const _BenefitTile({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: const Color(0xFFFFE3EA),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.red),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(
                body,
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _DigitalMemberCard extends StatelessWidget {
  const _DigitalMemberCard({
    required this.name,
    required this.email,
    required this.code,
  });
  final String name;
  final String email;
  final String? code;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.navy,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.white24),
      boxShadow: const [
        BoxShadow(
          color: Color(0x33000000),
          blurRadius: 18,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.badge_rounded, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'DIGITALER MITGLIEDSAUSWEIS',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: .5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          name.isEmpty ? 'Vereinsmitglied' : name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(email, style: const TextStyle(color: Colors.white70)),
        if (code != null) ...[
          const SizedBox(height: 18),
          Text(
            'ID · $code',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ],
    ),
  );
}

class _PartnerOffersSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<Map<String, dynamic>>>(
        future: Supabase.instance.client
            .from('member_benefits')
            .select('title, description, partner_name')
            .eq('active', true)
            .order('sort_order'),
        builder: (context, snapshot) {
          final rows = snapshot.data ?? const <Map<String, dynamic>>[];
          if (rows.isEmpty) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Partner-Vorteile',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              ...rows.map(
                (row) => _BenefitTile(
                  icon: Icons.local_offer_rounded,
                  title: row['title'] as String? ?? 'Vorteil',
                  body: [row['partner_name'], row['description']]
                      .whereType<String>()
                      .where((value) => value.isNotEmpty)
                      .join(' · '),
                ),
              ),
            ],
          );
        },
      );
}

class _ReferralCard extends StatelessWidget {
  const _ReferralCard({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        const Icon(Icons.group_add_rounded, color: AppColors.red),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Freunde einladen',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(
                code,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Code kopieren',
          onPressed: () {
            Clipboard.setData(ClipboardData(text: code));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Einladungscode kopiert.')),
            );
          },
          icon: const Icon(Icons.copy_rounded),
        ),
      ],
    ),
  );
}
