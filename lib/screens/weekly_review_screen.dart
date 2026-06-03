import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:faithful_journal/services/entry_service.dart';
import 'package:faithful_journal/widgets/entry_card.dart';
import 'package:faithful_journal/theme.dart';

class WeeklyReviewScreen extends StatelessWidget {
  const WeeklyReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly Review'),
      ),
      body: SafeArea(
        child: Consumer<EntryService>(
          builder: (context, entryService, _) {
            final weeklyEntries = entryService.getWeeklyEntries();

            return weeklyEntries.isEmpty
                ? Center(
                    child: Padding(
                      padding: AppSpacing.paddingXl,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.event_note,
                            size: 64,
                            color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            'No entries this week',
                            style: context.textStyles.titleLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Reflect on Scripture to begin your weekly journey',
                            style: context.textStyles.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          ElevatedButton.icon(
                            onPressed: () => context.go('/new-entry'),
                            icon: Icon(Icons.add, color: Theme.of(context).colorScheme.onPrimary),
                            label: const Text('New Entry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'The past 7 days',
                          style: context.textStyles.headlineSmall,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Revisit your recent reflections and see how God has been speaking to you',
                          style: context.textStyles.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        ...weeklyEntries.map(
                          (entry) => EntryCard(
                            entry: entry,
                            onTap: () => context.push('/entry/${entry.id}'),
                          ),
                        ),
                      ],
                    ),
                  );
          },
        ),
      ),
    );
  }
}
