import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/club_logos.dart';
import 'initialize_app.dart';
import 'app.dart';
import 'app_theme.dart';

class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() => _failed = false);
    try {
      await initializeApp();
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) {
      return RingerApp(supabaseClient: Supabase.instance.client);
    }
    return MaterialApp(
      locale: const Locale('de', 'DE'),
      supportedLocales: const [Locale('de', 'DE')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Scaffold(
        backgroundColor: AppColors.navy,
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: AppColors.backgroundGradient,
          ),
          child: SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox.square(
                    dimension: 164,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (!_failed)
                          const SizedBox.expand(
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: Colors.white,
                              backgroundColor: Colors.white12,
                            ),
                          ),
                        Image.asset(
                          ClubLogos.kscOlympiaGrabenNeudorf,
                          width: 120,
                          height: 120,
                          fit: BoxFit.contain,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'KSC Olympia',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Text(
                    'Graben-Neudorf',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 24),
                  if (_failed) ...[
                    const Text(
                      'Der Start ist fehlgeschlagen.',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _initialize,
                      child: const Text('Erneut versuchen'),
                    ),
                  ] else
                    const Text(
                      'Wird geladen …',
                      style: TextStyle(color: Colors.white70),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
