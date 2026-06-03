import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:faithful_journal/models/journal_entry.dart';
import 'package:faithful_journal/services/entry_service.dart';
import 'package:faithful_journal/widgets/resurfacing_section.dart';
import 'package:faithful_journal/theme.dart';

class EntryDetailScreen extends StatelessWidget {
  final String entryId;

  const EntryDetailScreen({super.key, required this.entryId});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Navigation stability:
    // The detail screen is a root-level route (over the tab shell). Using
    // `context.pop()` can return to a now-disposed form route (/new-entry) or
    // otherwise interact poorly with async refreshes. We always route back to
    // Archive explicitly.
    void goBackToArchive() => context.go('/');

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        goBackToArchive();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leadingWidth: 96,
          leading: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: goBackToArchive,
                icon: Icon(Icons.arrow_back, size: 18, color: scheme.onSurface),
                label: Text('Back', style: context.textStyles.labelLarge?.copyWith(color: scheme.onSurface)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  foregroundColor: scheme.onSurface,
                ),
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                final entry = context.read<EntryService>().getEntryById(entryId);
                if (entry?.isQuestion == true) {
                  context.push('/questions/edit/$entryId');
                } else {
                  context.push('/edit-entry/$entryId');
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _confirmDelete(context),
            ),
          ],
        ),
        body: SafeArea(
          child: Consumer<EntryService>(
            builder: (context, entryService, _) {
            final entry = entryService.getEntryById(entryId);

            if (entry == null) {
                return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64),
                    const SizedBox(height: AppSpacing.lg),
                    const Text('Entry not found'),
                    const SizedBox(height: AppSpacing.lg),
                    ElevatedButton(
                        onPressed: goBackToArchive,
                      child: const Text('Go Home'),
                    ),
                  ],
                ),
              );
            }

            final resurfacing = entryService.getResurfacingForEntry(entryId, maxItems: 5);
            final dateFormat = DateFormat('EEEE, MMMM d, yyyy');

            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (entry.isQuestion) ...[
                    Row(
                      children: [
                        Icon(Icons.help_outline, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'Question',
                          style: context.textStyles.headlineSmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    if (entry.scriptureReference.trim().isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        entry.scriptureReference.trim(),
                        style: context.textStyles.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ] else ...[
                    Text(
                      entry.scriptureReference,
                      style: context.textStyles.headlineMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                  if (entry.scriptureText != null && entry.scriptureText!.trim().isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: Text(
                        entry.scriptureText!.trim(),
                        style: context.textStyles.bodyMedium?.copyWith(
                          height: 1.5,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      if (!entry.isQuestion && entry.topic.trim().isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            entry.topic,
                            style: context.textStyles.labelMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                      ],
                      Text(
                        dateFormat.format(entry.createdAt),
                        style: context.textStyles.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  if (entry.isQuestion) ...[
                    SectionHeader(title: 'Question', icon: Icons.help_outline),
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: Text(
                        (entry.question ?? '').trim(),
                        style: context.textStyles.bodyLarge?.copyWith(height: 1.65),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    SectionHeader(title: 'What I’m Beginning to Understand', icon: Icons.auto_awesome),
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: Text(
                        (entry.beginningToUnderstand ?? '').trim().isEmpty
                            ? '—'
                            : (entry.beginningToUnderstand ?? '').trim(),
                        style: context.textStyles.bodyLarge?.copyWith(
                          height: 1.65,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ] else ...[
                    SectionHeader(title: 'Observation', icon: Icons.visibility),
                    const SizedBox(height: AppSpacing.md),
                    ObservationBody(entry: entry),
                    const SizedBox(height: AppSpacing.xl),
                    SectionHeader(title: 'Application', icon: Icons.lightbulb),
                    const SizedBox(height: AppSpacing.md),
                    Text(entry.application, style: context.textStyles.bodyLarge),
                    const SizedBox(height: AppSpacing.xl),
                    SectionHeader(title: 'Prayer', icon: Icons.favorite),
                    const SizedBox(height: AppSpacing.md),
                    Text(entry.prayer, style: context.textStyles.bodyLarge),
                  ],
                  const SizedBox(height: AppSpacing.xxl),
                  ResurfacingSection(
                    title: 'Remembering',
                    subtitle: entry.chapterKey.trim().isEmpty
                        ? 'A few quiet memories to revisit.'
                        : 'From ${entry.chapterKey.trim()}',
                    items: resurfacing,
                  ),
                ],
              ),
            );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Delete Entry?',
              style: context.textStyles.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'This action cannot be undone.',
              style: context.textStyles.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.pop(false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => context.pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Theme.of(context).colorScheme.onError,
                    ),
                    child: const Text('Delete'),
                  ),
                ),
              ],
            ),
            SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
          ],
        ),
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await context.read<EntryService>().deleteEntry(entryId);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not delete entry. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Entry deleted'),
        behavior: SnackBarBehavior.floating,
      ),
    );

    // Navigation safety:
    // When a root-level route (EntryDetail) is popped/replaced while overlays
    // are still animating, Flutter web can hit framework assertions.
    // Scheduling the navigation to the next frame prevents that.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      GoRouter.of(context).go('/');
    });
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const SectionHeader({
    super.key,
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          title,
          style: context.textStyles.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }
}

class ObservationBody extends StatelessWidget {
  final JournalEntry entry;

  const ObservationBody({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final s = entry.observationStructured;

    final paragraphs = <String>[];
    if (s != null) {
      // Order requested: Before -> After -> Stands out -> Repeated theme.
      if (s.leadingContext.trim().isNotEmpty) paragraphs.add(_sentence(s.leadingContext, prefix: 'Leading into this passage,'));
      if (s.followingContext.trim().isNotEmpty) paragraphs.add(_sentence(s.followingContext, prefix: 'Following this section,'));
      if (s.standOut.trim().isNotEmpty) paragraphs.add(_sentence(s.standOut, prefix: 'What stands out most is'));
      if (s.repeatedIdeas.trim().isNotEmpty) paragraphs.add(_sentence(s.repeatedIdeas, prefix: 'Repeated ideas include'));
    }

    // Fallback: if the structured blob exists but is empty (common in imports),
    // still show the plain observation field.
    if (paragraphs.isEmpty && entry.observation.trim().isNotEmpty) {
      paragraphs.add(entry.observation.trim());
    }

    final metaParts = <String>[];
    if (entry.book.trim().isNotEmpty) metaParts.add(entry.book.trim());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Text(
            paragraphs.join('\n\n'),
            style: context.textStyles.bodyLarge?.copyWith(height: 1.65),
          ),
        ),
        if (metaParts.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            metaParts.join(' • '),
            style: context.textStyles.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }

  String _sentence(String text, {required String prefix}) {
    final t = text.trim();
    if (t.isEmpty) return '';
    final lower = t.toLowerCase();
    final prefixLower = prefix.toLowerCase();
    final composed = lower.startsWith(prefixLower) ? t : '$prefix $t';
    return _ensureTerminalPunctuation(composed);
  }

  String _ensureTerminalPunctuation(String s) {
    final t = s.trimRight();
    if (t.isEmpty) return '';
    final last = t[t.length - 1];
    if (last == '.' || last == '!' || last == '?' || last == '…') return t;
    return '$t.';
  }
}
