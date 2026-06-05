import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:faithful_journal/models/journal_entry.dart';
import 'package:faithful_journal/services/bible_service.dart';
import 'package:faithful_journal/services/entry_service.dart';
import 'package:faithful_journal/services/unsaved_changes_service.dart';
import 'package:faithful_journal/theme.dart';
import 'package:faithful_journal/widgets/app_journal_text_field.dart';
import 'package:faithful_journal/widgets/auth_required_sheet.dart';
import 'package:faithful_journal/widgets/discard_changes_dialog.dart';

class QuestionEditorScreen extends StatefulWidget {
  final String? entryId;

  const QuestionEditorScreen({super.key, this.entryId});

  @override
  State<QuestionEditorScreen> createState() => _QuestionEditorScreenState();
}

class _QuestionEditorScreenState extends State<QuestionEditorScreen> {
  static const _unsavedKey = 'question_editor';

  final _formKey = GlobalKey<FormState>();
  final _scriptureController = TextEditingController();
  final _scriptureTextController = TextEditingController();
  final _questionController = TextEditingController();
  final _beginningToUnderstandController = TextEditingController();

  bool _isDirty = false;
  bool _suspendDirty = false;

  final _bibleService = BibleService();
  bool _isImporting = false;
  String _translation = 'web';

  bool _isEditing = false;
  JournalEntry? _existing;

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

    _scriptureController.addListener(_markDirty);
    _scriptureTextController.addListener(_markDirty);
    _questionController.addListener(_markDirty);
    _beginningToUnderstandController.addListener(_markDirty);

    if (widget.entryId != null) {
      _loadExisting();
    }
  }

  void _markDirty() {
    if (_suspendDirty) return;
    if (_isDirty) return;
    _isDirty = true;
    if (!mounted) return;
    (_unsavedChanges ?? context.read<UnsavedChangesService>()).markDirty(_unsavedKey);
  }

  void _loadExisting() {
    final entryService = context.read<EntryService>();
    _existing = entryService.getEntryById(widget.entryId!);
    if (_existing == null) return;
    _suspendDirty = true;
    _isEditing = true;
    _scriptureController.text = _existing!.scriptureReference;
    _scriptureTextController.text = _existing!.scriptureText ?? '';
    _questionController.text = _existing!.question ?? '';
    _beginningToUnderstandController.text = _existing!.beginningToUnderstand ?? '';
    _suspendDirty = false;
  }

  @override
  void dispose() {
    // Avoid using BuildContext lookups during dispose; the element is deactivated.
    _unsavedChanges?.clear(_unsavedKey);
    _scriptureController.dispose();
    _scriptureTextController.dispose();
    _questionController.dispose();
    _beginningToUnderstandController.dispose();
    super.dispose();
  }

  Future<void> _attemptLeave() async {
    if (!_isDirty) {
      if (!mounted) return;
      context.pop();
      return;
    }

    final discard = await showDiscardChangesDialog(context);
    if (!discard) return;
    if (!mounted) return;
    (_unsavedChanges ?? context.read<UnsavedChangesService>()).clear(_unsavedKey);
    _isDirty = false;
    context.pop();
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
      debugPrint('QuestionEditorScreen: import failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Import failed. Please try again.'), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _save() async {
    debugPrint('QuestionEditorScreen: Save pressed');

    // Stability: avoid null-assertions on form state.
    final formState = _formKey.currentState;
    if (formState == null) return;
    if (!formState.validate()) return;
    final entryService = context.read<EntryService>();

    try {
      await entryService.ensureAuthenticated();

      if (entryService.isUsingSupabase && entryService.needsAuth) {
        if (!mounted) return;
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (context) => AuthRequiredSheet(
            onAuthenticated: () {
              context.read<EntryService>().refresh();
            },
          ),
        );
        if (!mounted) return;
        if (entryService.needsAuth) return;
      }

      final now = DateTime.now();

      if (_isEditing && _existing != null) {
        final updated = _existing!.copyWith(
          entryType: JournalEntryType.question,
          scriptureReference: _scriptureController.text.trim(),
          scriptureText: _scriptureTextController.text.trim().isEmpty ? null : _scriptureTextController.text.trim(),
          question: _questionController.text.trim(),
          beginningToUnderstand: _beginningToUnderstandController.text.trim().isEmpty
              ? null
              : _beginningToUnderstandController.text.trim(),
            // Quiet mode: questions no longer support a "highlighted" state.
            highlighted: false,
          updatedAt: now,
        );
        await entryService.updateEntry(updated);
      } else {
        final newQuestion = JournalEntry(
          id: entryService.generateId(),
          userId: entryService.currentUserId,
          entryType: JournalEntryType.question,
          scriptureReference: _scriptureController.text.trim(),
          scriptureText: _scriptureTextController.text.trim().isEmpty ? null : _scriptureTextController.text.trim(),
          question: _questionController.text.trim(),
          beginningToUnderstand: null,
            // Quiet mode: questions no longer support a "highlighted" state.
            highlighted: false,
          // Unused in questions (kept for schema compatibility)
          observation: '',
          application: '',
          prayer: '',
          topic: '',
          createdAt: now,
          updatedAt: now,
        );
        await entryService.createEntry(newQuestion);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Question updated' : 'Question saved'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      // Clear before navigating; keep it off of context during dispose.
      (_unsavedChanges ?? context.read<UnsavedChangesService>()).clear(_unsavedKey);
      _isDirty = false;
      context.go('/questions');
    } catch (e) {
      debugPrint('QuestionEditorScreen: save failed: $e');
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
    final showUnderstanding = _isEditing;
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        await _attemptLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Edit Question' : 'New Question'),
          leading: IconButton(icon: const Icon(Icons.close), onPressed: _attemptLeave),
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Text('Scripture (optional)', style: context.textStyles.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _scriptureController,
                  decoration: const InputDecoration(hintText: 'Search a reference (optional) — e.g. John 1:1'),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _translation,
                        decoration: const InputDecoration(labelText: 'Translation'),
                        items: const [DropdownMenuItem(value: 'web', child: Text('WEB'))],
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
                    labelText: 'Passage (optional)',
                    hintText: 'Imported text will appear here…',
                  ),
                  minLines: 4,
                  maxLines: 6,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Question', style: context.textStyles.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                AppJournalTextField(
                  controller: _questionController,
                  decoration: const InputDecoration(hintText: 'What question are you wrestling with?'),
                  minLines: 6,
                  maxLines: 8,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Please write your question';
                    return null;
                  },
                ),
                if (showUnderstanding) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text('What I’m Beginning to Understand', style: context.textStyles.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  AppJournalTextField(
                    controller: _beginningToUnderstandController,
                    decoration: const InputDecoration(hintText: 'Write gently — this can stay unfinished.'),
                    minLines: 6,
                    maxLines: 8,
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _save,
                    child: Text(_isEditing ? 'Update Question' : 'Save Question'),
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
