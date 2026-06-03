import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:faithful_journal/models/journal_entry.dart';
import 'package:faithful_journal/theme.dart';

class ResurfacingSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<JournalEntry> items;

  const ResurfacingSection({
    super.key,
    required this.title,
    required this.items,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.textStyles.titleMedium?.copyWith(color: scheme.onSurface)),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle!,
              style: context.textStyles.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.5),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: items.map((e) => _MemoryGlanceCard(entry: e)).toList(),
          ),
        ],
      ),
    );
  }
}

class _MemoryGlanceCard extends StatelessWidget {
  final JournalEntry entry;

  const _MemoryGlanceCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dateFormat = DateFormat('MMM d, yyyy');
    final title = entry.scriptureReference.trim().isNotEmpty
        ? entry.scriptureReference.trim()
        : (entry.isQuestion ? 'Question' : 'Reflection');

    final excerpt = _excerptFor(entry);

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 320),
      child: GestureDetector(
        onTap: () => context.push('/entry/${entry.id}'),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: scheme.outline.withValues(alpha: 0.10)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: context.textStyles.labelLarge?.copyWith(color: scheme.onSurface, height: 1.25),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (entry.highlighted) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Icon(Icons.star, size: 16, color: scheme.primary.withValues(alpha: 0.85)),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                dateFormat.format(entry.createdAt),
                style: context.textStyles.labelSmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.2),
              ),
              if (excerpt.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                _FadedTwoLineExcerpt(text: excerpt),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _excerptFor(JournalEntry entry) {
    String clean(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ');

    final application = clean(entry.application);
    if (application.isNotEmpty) return application;

    final observation = clean(entry.observation);
    if (observation.isNotEmpty) return observation;

    final prayer = clean(entry.prayer);
    if (prayer.isNotEmpty) return prayer;

    return '';
  }
}

class _FadedTwoLineExcerpt extends StatelessWidget {
  final String text;

  const _FadedTwoLineExcerpt({required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Text(
          text,
          style: context.textStyles.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.45),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    scheme.surface.withValues(alpha: 0.0),
                    scheme.surface.withValues(alpha: 0.0),
                    scheme.surface.withValues(alpha: 0.75),
                  ],
                  stops: const [0.0, 0.75, 1.0],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
