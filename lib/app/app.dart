import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/data/services/user_access_service.dart';
import '../features/matches/domain/models/team_match.dart';
import 'app_shell.dart';
import 'app_theme.dart';

class RingerApp extends StatelessWidget {
  const RingerApp({
    super.key,
    this.supabaseClient,
    this.userAccessService,
    this.firstTeamMatchesFuture,
  });

  final SupabaseClient? supabaseClient;
  final UserAccessService? userAccessService;
  final Future<List<TeamMatch>>? firstTeamMatchesFuture;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'KSC Olympia',
      locale: const Locale('de', 'DE'),
      supportedLocales: const [Locale('de', 'DE')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: AppTheme.light,
      home: AppShell(
        supabaseClient: supabaseClient,
        userAccessService: userAccessService,
        firstTeamMatchesFuture: firstTeamMatchesFuture,
      ),
    );
  }
}
