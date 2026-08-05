import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_shell.dart';
import 'app_theme.dart';

class RingerApp extends StatelessWidget {
  const RingerApp({super.key, this.supabaseClient});

  final SupabaseClient? supabaseClient;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ringer App',
      theme: AppTheme.light,
      home: AppShell(supabaseClient: supabaseClient),
    );
  }
}
