import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:faithful_journal/models/journal_entry.dart';
import 'package:faithful_journal/services/entry_service.dart';
import 'package:faithful_journal/widgets/entry_card.dart';
import 'package:faithful_journal/widgets/app_filter_chip.dart';
import 'package:faithful_journal/widgets/filter_panel.dart';
import 'package:faithful_journal/theme.dart';
import 'package:faithful_journal/widgets/auth_required_sheet.dart';
import 'package:faithful_journal/widgets/account_sheet.dart';

class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

enum _ArchiveKind { all, reflections, questions }

class _ArchiveScreenState extends State<ArchiveScreen> {
  String? _selectedTopic;
  String? _selectedFromChapter;
  _ArchiveKind _kind = _ArchiveKind.all;
  QuestionFilter _questionFilter = QuestionFilter.all;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Archive'),
        actions: [
          IconButton(
            tooltip: 'Account',
            icon: const Icon(Icons.account_circle),
            onPressed: () async {
              await showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => const AccountSheet(),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Consumer<EntryService>(
          builder: (context, entryService, _) {
            if (entryService.isUsingSupabase && entryService.needsAuth) {
              return Center(
                child: Padding(
                  padding: AppSpacing.paddingXl,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 64,
                        color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Sign in to view your private journal',
                        style: context.textStyles.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Your Archive is protected by Supabase Row Level Security.',
                        style: context.textStyles.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      FilledButton.icon(
                        onPressed: () async {
                          await showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            showDragHandle: true,
                            builder: (_) => AuthRequiredSheet(
                              onAuthenticated: () {
                                context.read<EntryService>().refresh();
                              },
                            ),
                          );
                        },
                        icon: Icon(Icons.email, color: Theme.of(context).colorScheme.onPrimary),
                        label: const Text('Sign in with email link'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final allTopics = entryService.getAllTopics();
            final allChapters = entryService.getAllChapterKeys();
            
            // NOTE: `entryService.entries` may be backed by an unmodifiable list
            // (e.g. from a DB/stream layer). We will sort later, so start with a
            // growable copy to avoid: `Unsupported operation: sort`.
            List<JournalEntry> filteredEntries = List<JournalEntry>.from(entryService.entries);

            if (_kind == _ArchiveKind.reflections) {
              filteredEntries = filteredEntries.where((e) => e.entryType == JournalEntryType.soap).toList();
            } else if (_kind == _ArchiveKind.questions) {
              filteredEntries = filteredEntries.where((e) => e.entryType == JournalEntryType.question).toList();
              if (_questionFilter == QuestionFilter.stillWrestling) {
                filteredEntries = filteredEntries.where((e) => !e.hasBeginningToUnderstand).toList();
              } else if (_questionFilter == QuestionFilter.developingUnderstanding) {
                filteredEntries = filteredEntries.where((e) => e.hasBeginningToUnderstand).toList();
              }
            }
            
            if (_selectedTopic != null) {
              final selectedLower = _selectedTopic!.trim().toLowerCase();
              filteredEntries = filteredEntries
                  .where((e) => entryService.normalizeTopic(e.topic).toLowerCase() == selectedLower)
                  .toList();
            }

            if (_selectedFromChapter != null) {
              filteredEntries = filteredEntries.where((e) => e.chapterKey == _selectedFromChapter).toList();
            }

            // Archive ordering:
            // 1) Highlighted entries at the top
            // 2) Oldest -> newest (so growth over time is visible)
            // (Safe because `filteredEntries` is always a growable list.)
            filteredEntries.sort((a, b) {
              if (a.highlighted != b.highlighted) return a.highlighted ? -1 : 1;
              return a.createdAt.compareTo(b.createdAt);
            });

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
                  child: FilterPanel(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              AppFilterChip(
                                label: 'All',
                                isSelected: _kind == _ArchiveKind.all,
                                onSelected: (_) => setState(() => _kind = _ArchiveKind.all),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              AppFilterChip(
                                label: 'Reflections',
                                isSelected: _kind == _ArchiveKind.reflections,
                                onSelected: (_) => setState(() => _kind = _ArchiveKind.reflections),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              AppFilterChip(
                                label: 'Questions',
                                isSelected: _kind == _ArchiveKind.questions,
                                onSelected: (_) => setState(() => _kind = _ArchiveKind.questions),
                              ),
                            ],
                          ),
                        ),
                        if (_kind == _ArchiveKind.questions) ...[
                          const SizedBox(height: AppSpacing.md),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                AppFilterChip(
                                  label: 'All Questions',
                                  isSelected: _questionFilter == QuestionFilter.all,
                                  onSelected: (_) => setState(() => _questionFilter = QuestionFilter.all),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                AppFilterChip(
                                  label: 'Still Wrestling',
                                  isSelected: _questionFilter == QuestionFilter.stillWrestling,
                                  onSelected: (_) => setState(() => _questionFilter = QuestionFilter.stillWrestling),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                AppFilterChip(
                                  label: 'Developing Understanding',
                                  isSelected: _questionFilter == QuestionFilter.developingUnderstanding,
                                  onSelected: (_) => setState(() => _questionFilter = QuestionFilter.developingUnderstanding),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (allTopics.isNotEmpty || allChapters.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.md),
                          if (allTopics.isNotEmpty) ...[
                            Text(
                              'Filter by Topic',
                              style: context.textStyles.labelMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  AppFilterChip(
                                    label: 'All Topics',
                                    isSelected: _selectedTopic == null,
                                    onSelected: (_) => setState(() => _selectedTopic = null),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  ...allTopics.map(
                                    (topic) => Padding(
                                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                                      child: AppFilterChip(
                                        label: topic,
                                        isSelected: _selectedTopic == topic,
                                        onSelected: (_) => setState(() => _selectedTopic = topic),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (allChapters.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'From Book & Chapter',
                              style: context.textStyles.labelMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  AppFilterChip(
                                    label: 'All',
                                    isSelected: _selectedFromChapter == null,
                                    onSelected: (_) => setState(() => _selectedFromChapter = null),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  ...allChapters.map(
                                    (chapterKey) => Padding(
                                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                                      child: AppFilterChip(
                                        label: chapterKey,
                                        isSelected: _selectedFromChapter == chapterKey,
                                        onSelected: (_) => setState(() => _selectedFromChapter = chapterKey),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: filteredEntries.isEmpty
                      ? Center(
                          child: Padding(
                            padding: AppSpacing.paddingXl,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.filter_alt_off,
                                  size: 64,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                Text(
                                  'No entries found',
                                  style: context.textStyles.titleLarge?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  'Try adjusting your filters',
                                  style: context.textStyles.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          itemCount: filteredEntries.length,
                          itemBuilder: (context, index) => EntryCard(
                            entry: filteredEntries[index],
                            onTap: () => context.push('/entry/${filteredEntries[index].id}'),
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

