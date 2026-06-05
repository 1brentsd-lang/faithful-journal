import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:faithful_journal/models/journal_entry.dart';
import 'package:faithful_journal/services/bible_service.dart';
import 'package:faithful_journal/services/entry_service.dart';
import 'package:faithful_journal/services/unsaved_changes_service.dart';
import 'package:faithful_journal/nav.dart';
import 'package:faithful_journal/theme.dart';
import 'package:faithful_journal/widgets/app_journal_text_field.dart';
import 'package:faithful_journal/widgets/auth_required_sheet.dart';
import 'package:faithful_journal/widgets/discard_changes_dialog.dart';

class NewEntryScreen extends StatefulWidget {
  final String? entryId;

  const NewEntryScreen({super.key, this.entryId});

  @override
  State<NewEntryScreen> createState() => _NewEntryScreenState();
}

class _NewEntryScreenState extends State<NewEntryScreen> {
  static const _unsavedKey = 'new_entry';

  final _formKey = GlobalKey<FormState>();
  final _scriptureController = TextEditingController();
  final _scriptureTextController = TextEditingController();
  final _observationController = TextEditingController();
  final _contextAroundController = TextEditingController();
  final _contextStandOutController = TextEditingController();
  final _applicationController = TextEditingController();
  final _prayerController = TextEditingController();
  final _topicController = TextEditingController();

  bool _isDirty = false;
  bool _suspendDirty = false;

  bool _highlighted = false;

  final _bibleService = BibleService();
  bool _isImporting = false;
  String _translation = 'web';

  bool _isEditing = false;
  JournalEntry? _existingEntry;

  bool _contextExpanded = false;

  UnsavedChangesService? _unsavedChanges;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _unsavedChanges ??= context.read<UnsavedChangesService>();
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      (_unsavedChanges ?? context.read<UnsavedChangesService>()).claim(_unsavedKey);
    });

    _scriptureTextController.addListener(_markDirty);
    _scriptureController.addListener(_markDirty);
    _observationController.addListener(_markDirty);
    _contextAroundController.addListener(_markDirty);
    _contextStandOutController.addListener(_markDirty);
    _applicationController.addListener(_markDirty);
    _prayerController.addListener(_markDirty);
    _topicController.addListener(_markDirty);

    if (widget.entryId != null) {
      _loadEntry();
    }
  }

  void _markDirty() {
    if (_suspendDirty) return;
    if (_isDirty) return;
    _isDirty = true;
    if (!mounted) return;
    (_unsavedChanges ?? context.read<UnsavedChangesService>()).markDirty(_unsavedKey);
  }

  void _loadEntry() {
    final entryService = context.read<EntryService>();
    _existingEntry = entryService.getEntryById(widget.entryId!);
    
    if (_existingEntry != null) {
      _suspendDirty = true;
      _isEditing = true;
      _highlighted = _existingEntry!.highlighted;
      final t = (_existingEntry!.translation ?? '').trim().toLowerCase();
      if (t == 'kjv' || t == 'asv' || t == 'web') {
        _translation = t;
      }
      _scriptureController.text = _existingEntry!.scriptureReference;
      _scriptureTextController.text = _existingEntry!.scriptureText ?? '';
      _observationController.text = _existingEntry!.observation;
      final structured = _existingEntry!.observationStructured;
      if (structured != null) _hydrateContextFromStored(structured);
      _applicationController.text = _existingEntry!.application;
      _prayerController.text = _existingEntry!.prayer;
      _topicController.text = _existingEntry!.topic;
      _suspendDirty = false;
    }
  }

  void _hydrateContextFromStored(ObservationStructured structured) {
    // Backwards compatible:
    // - Older data: before_passage/after_passage stored as plain text.
    // - New UI: we store a small labeled block inside leadingContext.
    final raw = structured.leadingContext.trim();
    final lines = raw.split('\n').map((l) => l.trimRight()).toList();
    final map = <String, String>{};
    for (final line in lines) {
      final idx = line.indexOf(':');
      if (idx <= 0) continue;
      final key = line.substring(0, idx).trim().toLowerCase();
      final value = line.substring(idx + 1).trim();
      if (value.isEmpty) continue;
      map[key] = value;
    }

    // Previous UI stored a small labeled block in leadingContext.
    final around = map["what's happening"] ?? '';
    if (around.trim().isNotEmpty) {
      _contextAroundController.text = around;
    } else {
      // Old format fallback.
      _contextAroundController.text = raw;
    }

    // Older data may have placed the "after" field in followingContext.
    // We gently migrate that into the new "stands out" prompt if needed.
    final legacyStandOut = structured.standOut.trim().isNotEmpty
        ? structured.standOut.trim()
        : structured.followingContext.trim();
    _contextStandOutController.text = legacyStandOut;
  }

  @override
  void dispose() {
    // If we leave the screen normally (save, discard, or route change), ensure
    // any pending state is cleared.
    // Avoid BuildContext lookups during dispose; the element is deactivated.
    _unsavedChanges?.clear(_unsavedKey);
    _scriptureController.dispose();
    _scriptureTextController.dispose();
    _observationController.dispose();
    _contextAroundController.dispose();
    _contextStandOutController.dispose();
    _applicationController.dispose();
    _prayerController.dispose();
    _topicController.dispose();
    super.dispose();
  }

  Future<void> _attemptLeave() async {
    if (!_isDirty) {
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.home);
      }
      return;
    }

    final discard = await showDiscardChangesDialog(context);
    if (!discard) return;
    if (!mounted) return;
    (_unsavedChanges ?? context.read<UnsavedChangesService>()).clear(_unsavedKey);
    _isDirty = false;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  ObservationStructured _buildObservationStructured() {
    String clean(String s) => s.trim();
    final around = clean(_contextAroundController.text);
    final standOut = clean(_contextStandOutController.text);
    return ObservationStructured(
      leadingContext: around,
      followingContext: '',
      standOut: standOut,
      repeatedIdeas: '',
    );
  }

  Future<bool> _ensureSignedInOrPrompt() async {
    final entryService = context.read<EntryService>();
    await entryService.ensureAuthenticated();
    if (!(entryService.isUsingSupabase && entryService.needsAuth)) return true;
    if (!mounted) return false;

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
    if (!mounted) return false;
    if (ok == true) return true;
    // If the user dismissed the sheet, re-check session.
    return !(entryService.isUsingSupabase && entryService.needsAuth);
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
      _markDirty();
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

    // Stability: formState can be null if a save is triggered during a rebuild
    // or a route transition. Avoid null-assertions to prevent red screens.
    final formState = _formKey.currentState;
    if (formState == null) return;
    if (!formState.validate()) return;

    final entryService = context.read<EntryService>();
    try {
      final ok = await _ensureSignedInOrPrompt();
      if (!ok) return;

      debugPrint('NewEntryScreen: ensureAuthenticated complete. supabaseUserId=${entryService.supabaseUserId}');
      final now = DateTime.now();

      final parsed = BibleService.parseReferenceMetadata(_scriptureController.text.trim());
      final metaTranslation = (parsed.translation ?? _translation.toUpperCase()).trim();

      late final String savedId;
      if (_isEditing && _existingEntry != null) {
        savedId = _existingEntry!.id;
        final updatedEntry = _existingEntry!.copyWith(
          entryType: JournalEntryType.soap,
          scriptureReference: _scriptureController.text.trim(),
          scriptureText: _scriptureTextController.text.trim().isEmpty ? null : _scriptureTextController.text.trim(),
          bookName: parsed.book,
          chapter: parsed.chapter,
          verseStart: parsed.verseStart,
          verseEnd: parsed.verseEnd,
          translation: metaTranslation.isEmpty ? null : metaTranslation,
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
        savedId = entryService.generateId();
        final newEntry = JournalEntry(
          id: savedId,
          userId: entryService.currentUserId,
          scriptureReference: _scriptureController.text.trim(),
          scriptureText: _scriptureTextController.text.trim().isEmpty ? null : _scriptureTextController.text.trim(),
          bookName: parsed.book,
          chapter: parsed.chapter,
          verseStart: parsed.verseStart,
          verseEnd: parsed.verseEnd,
          translation: metaTranslation.isEmpty ? null : metaTranslation,
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
        (_unsavedChanges ?? context.read<UnsavedChangesService>()).clear(_unsavedKey);
        _isDirty = false;

        // Use next-frame navigation to avoid overlay/route animation assertions.
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          context.go('/saved-entry/$savedId');
        });
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
    final entryService = context.watch<EntryService>();
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        await _attemptLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Edit Entry' : 'New Entry'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _attemptLeave,
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
                Text('Passage', style: context.textStyles.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                Autocomplete<String>(
                  optionsBuilder: (value) {
                    final q = value.text.trim().toLowerCase();
                    if (q.isEmpty) return const Iterable<String>.empty();

                    final hasDigits = RegExp(r'\d').hasMatch(q);
                    final chapterKeys = entryService.getAllChapterKeys();
                    final fromHistory = chapterKeys.where((k) => k.toLowerCase().contains(q)).take(8);

                    // Provide gentle starter suggestions from canonical books.
                    final fromBooks = <String>[];
                    for (final book in BibleService.canonicalBooks) {
                      final lower = book.toLowerCase();
                      if (!lower.startsWith(q)) continue;
                      if (hasDigits) {
                        // If the user already typed digits, don't fight their input.
                        fromBooks.add(value.text.trim());
                      } else if (lower == 'psalm' || lower == 'psalms') {
                        fromBooks.addAll(['Psalm 23', 'Psalm 1', 'Psalm 91', 'Psalm 121']);
                      } else {
                        fromBooks.addAll(List.generate(5, (i) => '$book ${i + 1}'));
                      }
                      break;
                    }

                    final merged = <String>[];
                    for (final s in fromHistory) {
                      if (!merged.any((m) => m.toLowerCase() == s.toLowerCase())) merged.add(s);
                    }
                    for (final s in fromBooks) {
                      if (s.trim().isEmpty) continue;
                      if (!merged.any((m) => m.toLowerCase() == s.toLowerCase())) merged.add(s);
                    }
                    return merged.take(10);
                  },
                  onSelected: (selection) {
                    final text = selection.trim();
                    _scriptureController.value = TextEditingValue(
                      text: text,
                      selection: TextSelection.collapsed(offset: text.length),
                    );
                    _markDirty();
                  },
                  fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
                    // Force Autocomplete to use our controller so the rest of
                    // the screen (import/save/parse) reads one source of truth.
                    return TextFormField(
                      controller: _scriptureController,
                      focusNode: focusNode,
                      decoration: const InputDecoration(hintText: 'Start typing… Psalm 23, John 3, Romans 8'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Please enter a passage';
                        return null;
                      },
                      onFieldSubmitted: (_) => onFieldSubmitted(),
                    );
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
                          DropdownMenuItem(value: 'web', child: Text('WEB')),
                          DropdownMenuItem(value: 'kjv', child: Text('KJV')),
                          DropdownMenuItem(value: 'asv', child: Text('ASV')),
                        ],
                        onChanged: _isImporting
                            ? null
                            : (v) {
                                setState(() => _translation = v ?? 'web');
                                _markDirty();
                              },
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
                AppJournalTextField(
                  controller: _scriptureTextController,
                  decoration: const InputDecoration(
                    labelText: 'Passage',
                    hintText: 'Imported text will appear here…',
                  ),
                  minLines: 4,
                  maxLines: 6,
                ),
                const SizedBox(height: AppSpacing.lg),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.30),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.10)),
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      initiallyExpanded: _contextExpanded,
                      onExpansionChanged: (v) => setState(() => _contextExpanded = v),
                      tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
                      childrenPadding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                      title: Text(
                        'Context (Optional)',
                        style: context.textStyles.labelLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                      children: [
                        AppJournalTextField(
                          controller: _contextAroundController,
                          decoration: const InputDecoration(
                            labelText: "What's happening around this passage?",
                            hintText: 'A sentence or two is enough…',
                          ),
                          minLines: 2,
                          maxLines: 4,
                          style: context.textStyles.bodyMedium,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppJournalTextField(
                          controller: _contextStandOutController,
                          decoration: const InputDecoration(
                            labelText: 'What stands out in the surrounding context?',
                          ),
                          minLines: 2,
                          maxLines: 4,
                          style: context.textStyles.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                EntrySectionCard(
                  title: 'Observation',
                  tint: sectionTint,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppJournalTextField(
                        controller: _observationController,
                        decoration: const InputDecoration(hintText: 'What do you notice?'),
                        minLines: 6,
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
                      AppJournalTextField(
                        controller: _applicationController,
                        decoration: const InputDecoration(hintText: 'How might you respond?'),
                        minLines: 6,
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
                      AppJournalTextField(
                        controller: _prayerController,
                        decoration: const InputDecoration(hintText: 'Write your prayer...'),
                        minLines: 5,
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
                      Autocomplete<String>(
                        optionsBuilder: (value) {
                          final q = value.text.trim().toLowerCase();
                          if (q.isEmpty) return const Iterable<String>.empty();
                          return entryService
                              .getAllTopics()
                              .where((t) => t.toLowerCase().contains(q))
                              .take(12);
                        },
                        onSelected: (selection) {
                          final canonical = entryService.canonicalizeTopic(selection);
                          _topicController.value = TextEditingValue(
                            text: canonical,
                            selection: TextSelection.collapsed(offset: canonical.length),
                          );
                          _markDirty();
                        },
                        fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) => TextFormField(
                          controller: _topicController,
                          focusNode: focusNode,
                          textCapitalization: TextCapitalization.words,
                          autocorrect: true,
                          enableSuggestions: true,
                          decoration: const InputDecoration(hintText: 'Start typing… Faith, Trust, Prayer, Hope'),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) return 'Please add a topic';
                            return null;
                          },
                          onFieldSubmitted: (_) => onFieldSubmitted(),
                        ),
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
                  onChanged: (v) {
                    setState(() => _highlighted = v);
                    _markDirty();
                  },
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
