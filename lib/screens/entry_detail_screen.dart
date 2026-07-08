import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:faithful_journal/models/journal_entry.dart';
import 'package:faithful_journal/services/entry_service.dart';
import 'package:faithful_journal/widgets/resurfacing_section.dart';
import 'package:faithful_journal/widgets/related_entries_list.dart';
import 'package:faithful_journal/widgets/auth_required_sheet.dart';
import 'package:faithful_journal/widgets/share_entry_sheet.dart';
import 'package:faithful_journal/theme.dart';
import 'package:share_plus/share_plus.dart';
import 'package:faithful_journal/widgets/app_logo.dart';

class EntryDetailScreen extends StatelessWidget {
  final String entryId;
  final bool isSavedView;

  const EntryDetailScreen({super.key, required this.entryId, this.isSavedView = false});

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
          title: AppLogoTitle(isSavedView ? 'Saved Entry' : 'Entry'),
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
              tooltip: 'Share',
              icon: const Icon(Icons.ios_share),
              onPressed: () async {
                final entry = context.read<EntryService>().getEntryById(entryId);
                if (entry == null) return;

                if (entry.isQuestion) {
                  final parts = <String>[];
                  final ref = entry.scriptureReference.trim();
                  if (ref.isNotEmpty) parts.add(ref);
                  final q = (entry.question ?? '').trim();
                  if (q.isNotEmpty) parts.add(q);
                  final understand = (entry.beginningToUnderstand ?? '').trim();
                  if (understand.isNotEmpty) parts.add("What I’m Beginning to Understand\n$understand");
                  final text = parts.where((p) => p.trim().isNotEmpty).join('\n\n');
                  if (text.trim().isEmpty) return;
                  await Share.share(text);
                  return;
                }

                if (!context.mounted) return;
                await showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  builder: (_) => ShareEntrySheet(entry: entry),
                );
              },
            ),
            if (!isSavedView) ...[
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
            final relatedForSaved = entryService.getRelatedForSavedEntry(entryId, limit: 5);
            final dateFormat = DateFormat('EEEE, MMMM d, yyyy');

            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isSavedView) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, size: 18, color: scheme.onPrimaryContainer),
                          const SizedBox(width: 8),
                          Text('Saved', style: context.textStyles.labelLarge?.copyWith(color: scheme.onPrimaryContainer)),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
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
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: Text(
                        entry.reflectionText.trim().isEmpty ? '—' : entry.reflectionText.trim(),
                        style: context.textStyles.bodyLarge?.copyWith(height: 1.65),
                      ),
                    ),
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
                  if (isSavedView) ...[
                    RelatedEntriesList(title: 'Related Reflections', entries: relatedForSaved),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                  if (!isSavedView)
                    ResurfacingSection(
                      title: 'Related Reflections',
                      subtitle: null,
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
      final entryService = context.read<EntryService>();
      await entryService.ensureAuthenticated();
      if (entryService.isUsingSupabase && entryService.needsAuth) {
        final ok = await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => AuthRequiredSheet(
            onAuthenticated: () {
              context.read<EntryService>().refresh();
            },
          ),
        );
        if (!context.mounted) return;
        if (ok != true && entryService.needsAuth) return;
      }
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
