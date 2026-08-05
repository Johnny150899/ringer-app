import 'package:flutter/material.dart';

import 'app_shell.dart';
import 'app_theme.dart';

class RingerApp extends StatelessWidget {
  const RingerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ringer App',
      theme: AppTheme.light,
      home: const AppShell(),
    );
  }
}
