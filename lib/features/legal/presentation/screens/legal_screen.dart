import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/app_theme.dart';

enum LegalPage { privacy, imprint }

class LegalHubScreen extends StatelessWidget {
  const LegalHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    void open(LegalPage page) => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => LegalScreen(page: page)));

    return Scaffold(
      appBar: AppBar(title: const Text('Info & Rechtliches')),
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              _LegalNavigationCard(
                icon: Icons.privacy_tip_outlined,
                title: 'Datenschutz',
                onTap: () => open(LegalPage.privacy),
              ),
              _LegalNavigationCard(
                icon: Icons.description_outlined,
                title: 'Impressum',
                onTap: () => open(LegalPage.imprint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegalNavigationCard extends StatelessWidget {
  const _LegalNavigationCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppDesign.cardGap),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppDesign.radiusCard),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: Icon(icon, color: AppColors.red),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    ),
  );
}

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.page});

  final LegalPage page;

  static const _privacyUrl =
      'https://ksc-olympia-graben-neudorf.de/datenschutz';
  static const _imprintUrl = 'https://ksc-olympia-graben-neudorf.de/impressum';

  Future<void> _openUrl(BuildContext context, String value) async {
    final opened = await launchUrl(
      Uri.parse(value),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Die Webseite konnte nicht geöffnet werden.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPrivacy = page == LegalPage.privacy;
    return Scaffold(
      appBar: AppBar(title: Text(isPrivacy ? 'Datenschutz' : 'Impressum')),
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 36),
            children: [
              if (isPrivacy) ...[
                const _LegalCard(
                  title: 'Verantwortlicher',
                  text:
                      'KSC „Olympia“ Graben-Neudorf 1972 e. V.\n'
                      'Moltkestraße 53, 76676 Graben-Neudorf\n'
                      'Wilhelm.Wenz@gmail.com',
                ),
                const _LegalCard(
                  title: 'Welche Daten die App verarbeitet',
                  text:
                      'Je nach Nutzung werden Konto- und Profildaten '
                      '(Name, E-Mail und Rolle), Mitgliedschaftsanträge, '
                      'Probetrainingsanfragen und Teilnahmen, Trainings- und '
                      'Veranstaltungszusagen sowie Beiträge, Umfragen und '
                      'Stimmen verarbeitet. Diese Angaben dienen den jeweiligen '
                      'Vereinsfunktionen und der Kommunikation im Verein.',
                ),
                const _LegalCard(
                  title: 'Technische Dienste',
                  text:
                      'Für Anmeldung und Speicherung verwendet die App '
                      'Supabase. Kampf- und Ligadaten lädt sie von LigaDB. '
                      'Instagram-Inhalte werden über eine Vereinsfunktion '
                      'abgerufen; beim Öffnen von Medien oder externen Links '
                      'können weitere Anbieter Daten erhalten. Lokale '
                      'Einstellungen und Zwischenspeicher liegen auf dem Gerät.',
                ),
                const _LegalCard(
                  title: 'Deine Rechte',
                  text:
                      'Du kannst beim Verein Auskunft, Berichtigung, Löschung '
                      'oder Einschränkung der Verarbeitung anfragen und dich '
                      'bei einer Datenschutzaufsichtsbehörde beschweren. '
                      'Für Anfragen nutze bitte die oben genannte E-Mail-Adresse.',
                ),
                const _LegalCard(
                  title: 'Wichtiger Hinweis zur App',
                  text:
                      'Die verlinkte Datenschutzerklärung der Vereinswebsite '
                      'beschreibt noch nicht alle App-Funktionen. Vor einer '
                      'öffentlichen Veröffentlichung müssen insbesondere '
                      'Rechtsgrundlagen, Speicherfristen, Empfänger, mögliche '
                      'Drittlandübermittlungen und Löschwege vom Verein '
                      'geprüft und ergänzt werden.',
                ),
                _LegalLink(
                  label: 'Datenschutzerklärung der Vereinswebsite öffnen',
                  onPressed: () => _openUrl(context, _privacyUrl),
                ),
              ] else ...[
                const _LegalCard(
                  title: 'Diensteanbieter',
                  text:
                      'KSC „Olympia“ Graben-Neudorf 1972 e. V.\n'
                      'Moltkestraße 53\n76676 Graben-Neudorf',
                ),
                const _LegalCard(
                  title: 'Kontakt',
                  text:
                      'Telefon: 0 72 55-59 60\n'
                      'E-Mail: Wilhelm.Wenz@gmail.com',
                ),
                const _LegalCard(
                  title: 'Vertretung',
                  text:
                      '1. Vorstand: Reinhold Kessel\n'
                      'Spöckerstraße 15, 76676 Graben-Neudorf',
                ),
                const _LegalCard(
                  title: 'Vereinsregister',
                  text: 'Amtsgericht Mannheim\nRegisternummer: 23313',
                ),
                _LegalLink(
                  label: 'Impressum der Vereinswebsite öffnen',
                  onPressed: () => _openUrl(context, _imprintUrl),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class LegalLinks extends StatelessWidget {
  const LegalLinks({super.key, this.onWhiteBackground = false});

  final bool onWhiteBackground;

  @override
  Widget build(BuildContext context) {
    void open(LegalPage page) => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => LegalScreen(page: page)));

    final color = onWhiteBackground ? AppColors.navy : Colors.white;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 4,
      children: [
        TextButton(
          onPressed: () => open(LegalPage.privacy),
          style: TextButton.styleFrom(foregroundColor: color),
          child: const Text('Datenschutz'),
        ),
        TextButton(
          onPressed: () => open(LegalPage.imprint),
          style: TextButton.styleFrom(foregroundColor: color),
          child: const Text('Impressum'),
        ),
      ],
    );
  }
}

class _LegalCard extends StatelessWidget {
  const _LegalCard({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppDesign.cardGap),
    child: Container(
      width: double.infinity,
      padding: AppDesign.cardPadding,
      decoration: AppDesign.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(text, style: const TextStyle(height: 1.5)),
        ],
      ),
    ),
  );
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      foregroundColor: Colors.white,
      side: const BorderSide(color: Colors.white70),
    ),
    icon: const Icon(Icons.open_in_new_rounded),
    label: Text(label),
  );
}
