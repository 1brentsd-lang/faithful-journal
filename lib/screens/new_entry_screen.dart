import 'package:flutter/foundation.dart';
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
  final _obsStandOutController = TextEditingController();
  final _obsBeforeController = TextEditingController();
  final _obsAfterController = TextEditingController();
  final _obsRepeatedController = TextEditingController();
  final _obsAuthorController = TextEditingController();
  final _obsAudienceController = TextEditingController();
  final _applicationController = TextEditingController();
  final _prayerController = TextEditingController();
  final _topicController = TextEditingController();

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
      _scriptureController.text = _existingEntry!.scriptureReference;
      _scriptureTextController.text = _existingEntry!.scriptureText ?? '';
      _observationController.text = _existingEntry!.observation;
      final structured = _existingEntry!.observationStructured;
      if (structured != null) {
        _obsStandOutController.text = structured.standOut;
        _obsBeforeController.text = structured.leadingContext;
        _obsAfterController.text = structured.followingContext;
        _obsRepeatedController.text = structured.repeatedIdeas;
        _obsAuthorController.text = structured.author;
        _obsAudienceController.text = structured.audience;
      } else {
        // Back-compat: treat legacy observation as the "stands out" answer.
        _obsStandOutController.text = _existingEntry!.observation;
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
    _obsStandOutController.dispose();
    _obsBeforeController.dispose();
    _obsAfterController.dispose();
    _obsRepeatedController.dispose();
    _obsAuthorController.dispose();
    _obsAudienceController.dispose();
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
      standOut: clean(_obsStandOutController.text),
      repeatedIdeas: clean(_obsRepeatedController.text),
      author: clean(_obsAuthorController.text),
      audience: clean(_obsAudienceController.text),
    );
  }

  String _renderObservationBody(ObservationStructured s) {
    String sentence(String text, {required String prefix}) {
      final t = text.trim();
      if (t.isEmpty) return '';

      // If the user already started with a similar phrase, don't double-prefix.
      final lower = t.toLowerCase();
      final prefixLower = prefix.toLowerCase();
      if (lower.startsWith(prefixLower)) return _ensurePeriod(t);
      return _ensurePeriod('$prefix $t');
    }

    final parts = <String>[];
    final leading = sentence(s.leadingContext, prefix: 'Leading into this passage,');
    final following = sentence(s.followingContext, prefix: 'Following this section,');
    final standOut = sentence(s.standOut, prefix: 'What stands out most is');
    final repeated = sentence(s.repeatedIdeas, prefix: 'Repeated ideas include');

    // Order requested: Before -> After -> Stands out -> Repeated theme.
    if (leading.isNotEmpty) parts.add(leading);
    if (following.isNotEmpty) parts.add(following);
    if (standOut.isNotEmpty) parts.add(standOut);
    if (repeated.isNotEmpty) parts.add(repeated);

    return parts.join('\n\n').trim();
  }

  String _ensurePeriod(String s) {
    final t = s.trimRight();
    if (t.isEmpty) return '';
    final last = t[t.length - 1];
    if (last == '.' || last == '!' || last == '?' || last == '…') return t;
    return '$t.';
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
    _observationController.text = _renderObservationBody(structured);
    if (!_formKey.currentState!.validate()) return;

    final entryService = context.read<EntryService>();
    try {
      await entryService.ensureAuthenticated();
      debugPrint('NewEntryScreen: ensureAuthenticated complete. supabaseUserId=${entryService.supabaseUserId}');
      final now = DateTime.now();

      if (_isEditing && _existingEntry != null) {
        final updatedEntry = _existingEntry!.copyWith(
          scriptureReference: _scriptureController.text.trim(),
          scriptureText: _scriptureTextController.text.trim().isEmpty ? null : _scriptureTextController.text.trim(),
          observation: _observationController.text.trim(),
          observationStructured: structured,
          application: _applicationController.text.trim(),
          prayer: _prayerController.text.trim(),
          topic: _topicController.text.trim(),
          updatedAt: now,
        );
        await entryService.updateEntry(updatedEntry);
      } else {
        final newEntry = JournalEntry(
          id: entryService.generateId(),
          userId: entryService.currentUserId,
          scriptureReference: _scriptureController.text.trim(),
          scriptureText: _scriptureTextController.text.trim().isEmpty ? null : _scriptureTextController.text.trim(),
          observation: _observationController.text.trim(),
          observationStructured: structured,
          application: _applicationController.text.trim(),
          prayer: _prayerController.text.trim(),
          topic: _topicController.text.trim(),
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
                    labelText: 'Passage (optional)',
                    hintText: 'Imported text will appear here…',
                  ),
                  maxLines: 6,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Observation',
                  style: context.textStyles.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Answer a few prompts — we’ll format this into one Observation.',
                  style: context.textStyles.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _obsBeforeController,
                  decoration: const InputDecoration(
                    labelText: 'What is happening before this passage?',
                    hintText: 'Short summary…',
                  ),
                  maxLines: 2,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please add a short “before” summary';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _obsAfterController,
                  decoration: const InputDecoration(
                    labelText: 'What is happening after this passage?',
                    hintText: 'Short summary…',
                  ),
                  maxLines: 2,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please add a short “after” summary';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _obsStandOutController,
                  decoration: const InputDecoration(
                    labelText: 'What stands out in this passage?',
                    hintText: 'Free text…',
                  ),
                  maxLines: 4,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please answer: What stands out?';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _obsRepeatedController,
                  decoration: const InputDecoration(
                    labelText: 'Is there a repeated word, idea, or theme? (optional)',
                    hintText: 'Optional…',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Optional metadata (subtle)',
                  style: context.textStyles.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _obsAuthorController,
                        decoration: const InputDecoration(labelText: 'Author (optional)'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: TextFormField(
                        controller: _obsAudienceController,
                        decoration: const InputDecoration(labelText: 'Audience (optional)'),
                      ),
                    ),
                  ],
                ),
                // Hidden field: holds the composed Observation for form validation + saving.
                Offstage(
                  offstage: true,
                  child: TextFormField(
                    controller: _observationController,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please add your observations';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Application',
                  style: context.textStyles.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'How will you apply this to your life?',
                  style: context.textStyles.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _applicationController,
                  decoration: const InputDecoration(
                    hintText: 'Write how you will apply this...',
                  ),
                  maxLines: 4,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please add an application';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Prayer',
                  style: context.textStyles.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Respond to God in prayer',
                  style: context.textStyles.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _prayerController,
                  decoration: const InputDecoration(
                    hintText: 'Write your prayer...',
                  ),
                  maxLines: 4,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please add a prayer';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Topic',
                  style: context.textStyles.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'One word theme for this reflection',
                  style: context.textStyles.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _topicController,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Faith, Grace, Trust',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please add a topic';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.xl),
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
