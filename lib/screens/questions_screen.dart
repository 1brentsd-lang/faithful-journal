import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:faithful_journal/services/entry_service.dart';
import 'package:faithful_journal/widgets/entry_card.dart';
import 'package:faithful_journal/widgets/app_filter_chip.dart';
import 'package:faithful_journal/widgets/filter_panel.dart';
import 'package:faithful_journal/theme.dart';

class QuestionsScreen extends StatefulWidget {
  const QuestionsScreen({super.key});

  @override
  State<QuestionsScreen> createState() => _QuestionsScreenState();
}

class _QuestionsScreenState extends State<QuestionsScreen> {
  QuestionFilter _filter = QuestionFilter.all;

  void _goBack() {
    // In tab mode, "back" should feel predictable: return to Home.
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: _goBack,
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
        ),
        title: const Text('Questions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/questions/new'),
            tooltip: 'New Question',
          ),
        ],
      ),
      body: SafeArea(
        child: Consumer<EntryService>(
          builder: (context, entryService, _) {
            final questions = entryService.getQuestions(filter: _filter);
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
                  child: FilterPanel(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          AppFilterChip(
                            label: 'All Questions',
                            isSelected: _filter == QuestionFilter.all,
                            onSelected: (_) => setState(() => _filter = QuestionFilter.all),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          AppFilterChip(
                            label: 'Still Wrestling',
                            isSelected: _filter == QuestionFilter.stillWrestling,
                            onSelected: (_) => setState(() => _filter = QuestionFilter.stillWrestling),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          AppFilterChip(
                            label: 'Developing Understanding',
                            isSelected: _filter == QuestionFilter.developingUnderstanding,
                            onSelected: (_) => setState(() => _filter = QuestionFilter.developingUnderstanding),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: questions.isEmpty
                      ? Center(
                          child: Padding(
                            padding: AppSpacing.paddingXl,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.help_outline,
                                  size: 64,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                Text(
                                  _filter == QuestionFilter.all
                                      ? 'No questions yet'
                                      : (_filter == QuestionFilter.stillWrestling
                                          ? 'Nothing you’re actively wrestling with'
                                          : 'No questions marked as developing understanding'),
                                  style: context.textStyles.titleLarge?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  'This is a place for ongoing reflection — it doesn’t need to be resolved quickly.',
                                  style: context.textStyles.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                FilledButton.icon(
                                  onPressed: () => context.push('/questions/new'),
                                  icon: Icon(Icons.add, color: Theme.of(context).colorScheme.onPrimary),
                                  label: const Text('New Question'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
                          itemCount: questions.length,
                          itemBuilder: (context, index) => EntryCard(
                            entry: questions[index],
                            onTap: () => context.push('/entry/${questions[index].id}'),
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/questions/new'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: Icon(Icons.add, color: Theme.of(context).colorScheme.onPrimary),
      ),
    );
  }
}

