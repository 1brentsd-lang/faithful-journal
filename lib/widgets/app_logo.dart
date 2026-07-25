import 'package:flutter/material.dart';
import 'package:faithful_journal/theme.dart';

/// App logo sourced from `assets/images/FJ_Logo.png`.
///
/// This widget centralizes the asset path so any future logo change is 1-line.
class AppLogo extends StatelessWidget {
  final double size;
  final BorderRadius borderRadius;

  /// Default size is slightly larger to better match the new logo proportions.
  const AppLogo({super.key, this.size = 28, this.borderRadius = const BorderRadius.all(Radius.circular(6))});

  static const String assetPath = 'assets/images/FJ_Logo.png';

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => SizedBox(
          width: size,
          height: size,
          child: Icon(Icons.auto_awesome, size: size * 0.85, color: Theme.of(context).colorScheme.primary),
        ),
      ),
    );
  }
}

/// A consistent AppBar title that includes the logo.
class AppLogoTitle extends StatelessWidget {
  final String title;

  const AppLogoTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AppLogo(size: 26),
        const SizedBox(width: AppSpacing.sm),
        Flexible(child: Text(title, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}
