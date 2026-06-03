import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:faithful_journal/models/journal_entry.dart';
import 'package:faithful_journal/services/entry_service.dart';
import 'package:faithful_journal/widgets/related_entries_list.dart';
import 'package:faithful_journal/theme.dart';

class EntryDetailScreen extends StatelessWidget {
  final String entryId;

  const EntryDetailScreen({super.key, required this.entryId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => context.push('/edit-entry/$entryId'),
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
                      onPressed: () => context.go('/'),
                      child: const Text('Go Home'),
                    ),
                  ],
                ),
              );
            }

            final relatedByTopic = entryService.getRelatedByTopic(entryId, entry.topic);
            final relatedByBook = entryService.getRelatedByBook(entryId, entry.book);
            final dateFormat = DateFormat('EEEE, MMMM d, yyyy');

            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.scriptureReference,
                    style: context.textStyles.headlineMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
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
                      Text(
                        dateFormat.format(entry.createdAt),
                        style: context.textStyles.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  SectionHeader(title: 'Observation', icon: Icons.visibility),
                  const SizedBox(height: AppSpacing.md),
                  ObservationBody(entry: entry),
                  const SizedBox(height: AppSpacing.xl),
                  SectionHeader(title: 'Application', icon: Icons.lightbulb),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    entry.application,
                    style: context.textStyles.bodyLarge,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  SectionHeader(title: 'Prayer', icon: Icons.favorite),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    entry.prayer,
                    style: context.textStyles.bodyLarge,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  if (relatedByTopic.isNotEmpty) ...[
                    RelatedEntriesList(
                      title: 'More on ${entry.topic}',
                      entries: relatedByTopic,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                  if (relatedByBook.isNotEmpty) ...[
                    RelatedEntriesList(
                      title: 'More from ${entry.book}',
                      entries: relatedByBook,
                    ),
                  ],
                ],
              ),
            );
          },
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

    if (confirmed == true && context.mounted) {
      await context.read<EntryService>().deleteEntry(entryId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Entry deleted'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.go('/');
      }
    }
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
    } else if (entry.observation.trim().isNotEmpty) {
      paragraphs.add(entry.observation.trim());
    }

    final metaParts = <String>[];
    if (entry.book.trim().isNotEmpty) metaParts.add(entry.book.trim());
    if (s != null && s.author.trim().isNotEmpty) metaParts.add(s.author.trim());
    if (s != null && s.audience.trim().isNotEmpty) metaParts.add(s.audience.trim());

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
