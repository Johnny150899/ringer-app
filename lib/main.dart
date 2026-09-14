import 'package:flutter/material.dart';
import 'app/startup_screen.dart';

export 'app/app.dart' show RingerApp;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StartupScreen());
}
