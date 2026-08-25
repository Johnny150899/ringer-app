import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/app_theme.dart';

class AppGlassSurface extends StatelessWidget {
  const AppGlassSurface({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 18,
    this.blur = 16,
    this.opacity = 1,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final double blur;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.navy.withValues(alpha: .56 * opacity),
                AppColors.navigationBlue.withValues(alpha: .38 * opacity),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: radius,
            border: Border.all(
              color: Colors.white.withValues(alpha: .18 * opacity),
            ),
          ),
          child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
        ),
      ),
    );
  }
}

class AppGlassIconButton extends StatelessWidget {
  const AppGlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 40,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AppGlassSurface(
      borderRadius: size / 2,
      child: SizedBox.square(
        dimension: size,
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          color: Colors.white,
          iconSize: 20,
          padding: EdgeInsets.zero,
          icon: Icon(icon),
        ),
      ),
    );
  }
}
