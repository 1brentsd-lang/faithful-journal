import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:faithful_journal/services/entry_service.dart';
import 'package:faithful_journal/widgets/entry_card.dart';
import 'package:faithful_journal/theme.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<EntryService>(
          builder: (context, entryService, _) {
            if (entryService.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            final recentEntries = entryService.getRecentEntries();

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Faithful Journal',
                          style: context.textStyles.headlineLarge?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Your space for Scripture reflection',
                          style: context.textStyles.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => context.push('/new-entry'),
                            icon: Icon(Icons.add, color: Theme.of(context).colorScheme.onPrimary),
                            label: const Text('New Entry'),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () => context.push('/questions'),
                                icon: Icon(Icons.help_outline, color: Theme.of(context).colorScheme.onPrimary),
                                label: const Text('Questions'),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => context.push('/archive'),
                                icon: Icon(Icons.library_books, color: Theme.of(context).colorScheme.primary),
                                label: const Text('Archive'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.md,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent Reflections',
                          style: context.textStyles.titleLarge,
                        ),
                        TextButton(
                          onPressed: () => context.push('/weekly-review'),
                          child: const Text('Weekly Review'),
                        ),
                      ],
                    ),
                  ),
                ),
                if (recentEntries.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Padding(
                        padding: AppSpacing.paddingXl,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.auto_stories,
                              size: 64,
                              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            Text(
                              'Begin your journey',
                              style: context.textStyles.titleLarge?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'Reflect on Scripture and preserve your spiritual insights',
                              style: context.textStyles.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => EntryCard(
                          entry: recentEntries[index],
                          onTap: () => context.push('/entry/${recentEntries[index].id}'),
                        ),
                        childCount: recentEntries.length,
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
              ],
            );
          },
        ),
      ),
    );
  }
}
