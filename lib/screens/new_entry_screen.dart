import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:faithful_journal/models/journal_entry.dart';
import 'package:faithful_journal/services/bible_service.dart';
import 'package:faithful_journal/services/entry_service.dart';
import 'package:faithful_journal/nav.dart';
import 'package:faithful_journal/theme.dart';

class NewEntryScreen extends StatefulWidget {
  final String? entryId;

  const NewEntryScreen({super.key, this.entryId});

  @override
  State<NewEntryScreen> createState() => _NewEntryScreenState();
}

class _NewEntryScreenState extends State<NewEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scriptureController = TextEditingController();
  final _scriptureTextController = TextEditingController();
  final _observationController = TextEditingController();
  final _obsBeforeController = TextEditingController();
  final _obsAfterController = TextEditingController();
  final _applicationController = TextEditingController();
  final _prayerController = TextEditingController();
  final _topicController = TextEditingController();

  bool _highlighted = false;

  final _bibleService = BibleService();
  bool _isImporting = false;
  String _translation = 'web';

  bool _isEditing = false;
  JournalEntry? _existingEntry;

  @override
  void initState() {
    super.initState();
    if (widget.entryId != null) {
      _loadEntry();
    }
  }

  void _loadEntry() {
    final entryService = context.read<EntryService>();
    _existingEntry = entryService.getEntryById(widget.entryId!);
    
    if (_existingEntry != null) {
      _isEditing = true;
      _highlighted = _existingEntry!.highlighted;
      _scriptureController.text = _existingEntry!.scriptureReference;
      _scriptureTextController.text = _existingEntry!.scriptureText ?? '';
      _observationController.text = _existingEntry!.observation;
      final structured = _existingEntry!.observationStructured;
      if (structured != null) {
        _obsBeforeController.text = structured.leadingContext;
        _obsAfterController.text = structured.followingContext;
      }
      _applicationController.text = _existingEntry!.application;
      _prayerController.text = _existingEntry!.prayer;
      _topicController.text = _existingEntry!.topic;
    }
  }

  @override
  void dispose() {
    _scriptureController.dispose();
    _scriptureTextController.dispose();
    _observationController.dispose();
    _obsBeforeController.dispose();
    _obsAfterController.dispose();
    _applicationController.dispose();
    _prayerController.dispose();
    _topicController.dispose();
    super.dispose();
  }

  ObservationStructured _buildObservationStructured() {
    String clean(String s) => s.trim();
    return ObservationStructured(
      leadingContext: clean(_obsBeforeController.text),
      followingContext: clean(_obsAfterController.text),
      standOut: '',
      repeatedIdeas: '',
    );
  }

  Future<void> _importScripture() async {
    final reference = _scriptureController.text.trim();
    if (reference.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a Scripture reference first.'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    setState(() => _isImporting = true);
    try {
      final passage = await _bibleService.fetchPassage(reference: reference, translation: _translation);
      if (!mounted) return;
      if (passage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not find that passage.'), behavior: SnackBarBehavior.floating),
        );
        return;
      }

      _scriptureController.text = passage.reference;
      _scriptureTextController.text = passage.text;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Imported from ${passage.translationName ?? _translation.toUpperCase()}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Import failed. Please try again.'), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _saveEntry() async {
    debugPrint('NewEntryScreen: Save button pressed');
    final structured = _buildObservationStructured();
    if (!_formKey.currentState!.validate()) return;

    final entryService = context.read<EntryService>();
    try {
      await entryService.ensureAuthenticated();
      debugPrint('NewEntryScreen: ensureAuthenticated complete. supabaseUserId=${entryService.supabaseUserId}');
      final now = DateTime.now();

      if (_isEditing && _existingEntry != null) {
        final updatedEntry = _existingEntry!.copyWith(
          entryType: JournalEntryType.soap,
          scriptureReference: _scriptureController.text.trim(),
          scriptureText: _scriptureTextController.text.trim().isEmpty ? null : _scriptureTextController.text.trim(),
          observation: _observationController.text.trim(),
          observationStructured: structured,
          application: _applicationController.text.trim(),
          prayer: _prayerController.text.trim(),
          topic: _topicController.text.trim(),
          highlighted: _highlighted,
          updatedAt: now,
        );
        await entryService.updateEntry(updatedEntry);
      } else {
        final newEntry = JournalEntry(
          id: entryService.generateId(),
          userId: entryService.currentUserId,
          scriptureReference: _scriptureController.text.trim(),
          scriptureText: _scriptureTextController.text.trim().isEmpty ? null : _scriptureTextController.text.trim(),
          entryType: JournalEntryType.soap,
          observation: _observationController.text.trim(),
          observationStructured: structured,
          application: _applicationController.text.trim(),
          prayer: _prayerController.text.trim(),
          topic: _topicController.text.trim(),
          highlighted: _highlighted,
          createdAt: now,
          updatedAt: now,
        );
        await entryService.createEntry(newEntry);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Entry updated' : 'Entry saved'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.go(AppRoutes.home);
      }
    } catch (e) {
      debugPrint('NewEntryScreen: Save failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Save failed. Check Debug Console for details.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sectionTint = Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Entry' : 'New Entry'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Scripture Reference',
                  style: context.textStyles.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _scriptureController,
                  decoration: const InputDecoration(hintText: 'e.g. John 3:16 or Psalm 23:1-3'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a Scripture reference';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _translation,
                        decoration: const InputDecoration(labelText: 'Translation'),
                        items: const [
                          DropdownMenuItem(value: 'web', child: Text('WEB (free)')),
                        ],
                        onChanged: _isImporting ? null : (v) => setState(() => _translation = v ?? 'web'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    FilledButton.icon(
                      onPressed: _isImporting ? null : _importScripture,
                      icon: _isImporting
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            )
                          : Icon(Icons.download, color: Theme.of(context).colorScheme.onPrimary),
                      label: Text(_isImporting ? 'Importing' : 'Import'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _scriptureTextController,
                  decoration: const InputDecoration(
                    labelText: 'Passage',
                    hintText: 'Imported text will appear here…',
                  ),
                  maxLines: 6,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Context',
                  style: context.textStyles.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _obsBeforeController,
                        decoration: const InputDecoration(
                          labelText: 'Before Passage',
                          hintText: 'What leads into this?',
                        ),
                        style: context.textStyles.bodyMedium,
                        maxLines: 2,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _obsAfterController,
                        decoration: const InputDecoration(
                          labelText: 'After Passage',
                          hintText: 'What follows?',
                        ),
                        style: context.textStyles.bodyMedium,
                        maxLines: 2,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      // Author/Audience removed to keep the observation flow quieter.
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                EntrySectionCard(
                  title: 'Observation',
                  tint: sectionTint,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _observationController,
                        decoration: const InputDecoration(hintText: 'What do you notice?'),
                        maxLines: 8,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'Please add an observation';
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const _QuietPrompts(
                        prompts: [
                          'What is being emphasized?',
                          'What might be misunderstood?',
                          'What detail is easy to miss?',
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                EntrySectionCard(
                  title: 'Application',
                  tint: sectionTint,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _applicationController,
                        decoration: const InputDecoration(hintText: 'How might you respond?'),
                        maxLines: 8,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'Please add an application';
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const _QuietPrompts(
                        prompts: [
                          'What is this calling me toward?',
                          'Where do I feel challenged?',
                          'What is one small act of obedience?',
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                EntrySectionCard(
                  title: 'Prayer',
                  tint: sectionTint,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _prayerController,
                        decoration: const InputDecoration(hintText: 'Write your prayer...'),
                        maxLines: 6,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'Please add a prayer';
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const _QuietPrompts(
                        prompts: [
                          'What do I want to thank God for?',
                          'What do I need help surrendering?',
                          'What truth do I need help believing?',
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                EntrySectionCard(
                  title: 'Topic',
                  tint: sectionTint,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _topicController,
                        decoration: const InputDecoration(hintText: 'e.g. Faith, Grace, Trust'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'Please add a topic';
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const _QuietPrompts(
                        prompts: [
                          'What theme keeps surfacing here?',
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _EntryToneToggle(
                  highlighted: _highlighted,
                  onChanged: (v) => setState(() => _highlighted = v),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveEntry,
                    child: Text(_isEditing ? 'Update Entry' : 'Save Entry'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EntrySectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final Color tint;

  const EntrySectionCard({
    super.key,
    required this.title,
    required this.child,
    required this.tint,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.textStyles.titleMedium),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle!,
              style: context.textStyles.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _QuietPrompts extends StatelessWidget {
  final List<String> prompts;

  const _QuietPrompts({required this.prompts});

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: (Theme.of(context).textTheme.bodySmall ?? const TextStyle()).copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
        height: 1.5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final p in prompts)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text(p),
            ),
        ],
      ),
    );
  }
}

class _EntryToneToggle extends StatelessWidget {
  final bool highlighted;
  final ValueChanged<bool> onChanged;

  const _EntryToneToggle({required this.highlighted, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SegmentedButton<bool>(
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected) ? scheme.primaryContainer : scheme.surface,
                ),
                foregroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected) ? scheme.onPrimaryContainer : scheme.onSurface,
                ),
                side: WidgetStateProperty.all(BorderSide(color: scheme.outline.withValues(alpha: 0.25))),
                shape: WidgetStateProperty.all(
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                ),
                textStyle: WidgetStatePropertyAll(context.textStyles.labelLarge),
                padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
              ),
              segments: const [
                ButtonSegment(value: false, label: Text('Normal'), icon: Icon(Icons.notes_outlined)),
                ButtonSegment(value: true, label: Text('Highlight'), icon: Icon(Icons.bookmark_border)),
              ],
              selected: {highlighted},
              onSelectionChanged: (s) => onChanged(s.first),
            ),
          ),
        ],
      ),
    );
  }
}
