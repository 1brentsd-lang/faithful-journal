import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:faithful_journal/models/journal_entry.dart';
import 'package:faithful_journal/services/entry_service.dart';
import 'package:faithful_journal/widgets/entry_card.dart';
import 'package:faithful_journal/theme.dart';

class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  String? _selectedTopic;
  String? _selectedBook;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Archive'),
      ),
      body: SafeArea(
        child: Consumer<EntryService>(
          builder: (context, entryService, _) {
            final allTopics = entryService.getAllTopics();
            final allBooks = entryService.getAllBooks();
            
            List<JournalEntry> filteredEntries = entryService.entries;
            
            if (_selectedTopic != null) {
              filteredEntries = filteredEntries
                  .where((e) => e.topic == _selectedTopic)
                  .toList();
            }
            
            if (_selectedBook != null) {
              filteredEntries = filteredEntries
                  .where((e) => e.book == _selectedBook)
                  .toList();
            }

            return Column(
              children: [
                if (allTopics.isNotEmpty || allBooks.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                                FilterChipWidget(
                                  label: 'All Topics',
                                  isSelected: _selectedTopic == null,
                                  onSelected: (_) {
                                    setState(() => _selectedTopic = null);
                                  },
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                ...allTopics.map((topic) => Padding(
                                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                                  child: FilterChipWidget(
                                    label: topic,
                                    isSelected: _selectedTopic == topic,
                                    onSelected: (_) {
                                      setState(() {
                                        _selectedTopic = topic;
                                      });
                                    },
                                  ),
                                )),
                              ],
                            ),
                          ),
                        ],
                        if (allBooks.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Filter by Book',
                            style: context.textStyles.labelMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                FilterChipWidget(
                                  label: 'All Books',
                                  isSelected: _selectedBook == null,
                                  onSelected: (_) {
                                    setState(() => _selectedBook = null);
                                  },
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                ...allBooks.map((book) => Padding(
                                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                                  child: FilterChipWidget(
                                    label: book,
                                    isSelected: _selectedBook == book,
                                    onSelected: (_) {
                                      setState(() {
                                        _selectedBook = book;
                                      });
                                    },
                                  ),
                                )),
                              ],
                            ),
                          ),
                        ],
                      ],
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

class FilterChipWidget extends StatelessWidget {
  final String label;
  final bool isSelected;
  final ValueChanged<bool> onSelected;

  const FilterChipWidget({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: onSelected,
      backgroundColor: Theme.of(context).colorScheme.surface,
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
      labelStyle: TextStyle(
        color: isSelected
            ? Theme.of(context).colorScheme.onPrimaryContainer
            : Theme.of(context).colorScheme.onSurface,
      ),
      side: BorderSide(
        color: isSelected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }
}
