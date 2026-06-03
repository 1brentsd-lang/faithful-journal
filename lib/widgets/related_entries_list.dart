import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:faithful_journal/models/journal_entry.dart';
import 'package:faithful_journal/widgets/entry_card.dart';
import 'package:faithful_journal/theme.dart';

class RelatedEntriesList extends StatelessWidget {
  final String title;
  final List<JournalEntry> entries;

  const RelatedEntriesList({
    super.key,
    required this.title,
    required this.entries,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Text(
            title,
            style: context.textStyles.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        ...entries.map((entry) => EntryCard(
          entry: entry,
          onTap: () => context.push('/entry/${entry.id}'),
        )),
      ],
    );
  }
}
