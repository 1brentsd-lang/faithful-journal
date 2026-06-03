import 'package:flutter/material.dart';

import 'package:faithful_journal/theme.dart';

/// A consistent FilterChip style used across Archive/Questions.
class AppFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final ValueChanged<bool> onSelected;
  final EdgeInsetsGeometry? padding;

  const AppFilterChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onSelected,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FilterChip(
      label: Text(label, overflow: TextOverflow.ellipsis),
      selected: isSelected,
      onSelected: onSelected,
      backgroundColor: scheme.surface,
      selectedColor: scheme.primaryContainer,
      showCheckmark: true,
      checkmarkColor: scheme.onPrimaryContainer,
      labelStyle: (context.textStyles.labelLarge ?? const TextStyle()).copyWith(
        color: isSelected ? scheme.onPrimaryContainer : scheme.onSurface,
      ),
      side: BorderSide(
        color: isSelected ? scheme.primary : scheme.outline.withValues(alpha: 0.3),
      ),
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    );
  }
}
