import 'package:flutter/material.dart';

abstract final class AppColors {
  static const navy = Color(0xFF061E39);
  static const navigationBlue = Color(0xFF002A52);
  static const red = Color(0xFFE4003A);
  static const guestBlue = Color(0xFF1565C0);
  static const text = Color(0xFF101828);
  static const muted = Color(0xFF667085);

  static const backgroundGradient = LinearGradient(
    colors: [Color(0xFFD9003D), Color(0xFF741044), Color(0xFF063662)],
    stops: [0, .46, 1],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

abstract final class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.navy,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.red,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? Colors.white
              : Colors.white70,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.selected)
              ? Colors.white
              : Colors.white70,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
        ),
      ),
    ),
  );
}
