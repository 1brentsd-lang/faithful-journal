import 'package:flutter/material.dart';

import 'package:faithful_journal/models/journal_entry.dart';
import 'package:faithful_journal/theme.dart';
import 'package:share_plus/share_plus.dart';

/// Bottom sheet that lets the user choose which parts of a journal entry to share.
class ShareEntrySheet extends StatefulWidget {
  final JournalEntry entry;

  const ShareEntrySheet({super.key, required this.entry});

  @override
  State<ShareEntrySheet> createState() => _ShareEntrySheetState();
}

class _ShareEntrySheetState extends State<ShareEntrySheet> {
  bool _scripture = true;
  bool _reflection = true;
  bool _application = true;
  bool _prayer = true;

  String _buildText() {
    final e = widget.entry;
    final parts = <String>[];

    void addBlock(String title, String text) {
      final t = text.trim();
      if (t.isEmpty) return;
      parts.add('$title\n$t');
    }

    if (_scripture) {
      final ref = e.scriptureReference.trim();
      if (ref.isNotEmpty) parts.add(ref);
      final passage = (e.scriptureText ?? '').trim();
      if (passage.isNotEmpty) parts.add(passage);
    }

    if (_reflection) addBlock('Reflection', e.reflectionText);
    if (_application) addBlock('Application', e.application);
    if (_prayer) addBlock('Prayer', e.prayer);

    return parts.where((p) => p.trim().isNotEmpty).join('\n\n');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final preview = _buildText();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Share', style: context.textStyles.titleLarge),
            const SizedBox(height: 6),
            Text(
              'Choose what to include.',
              style: context.textStyles.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.lg),
            _ShareToggle(
              title: 'Scripture',
              value: _scripture,
              onChanged: (v) => setState(() => _scripture = v),
            ),
            _ShareToggle(
              title: 'Reflection',
              value: _reflection,
              onChanged: (v) => setState(() => _reflection = v),
            ),
            _ShareToggle(
              title: 'Application',
              value: _application,
              onChanged: (v) => setState(() => _application = v),
            ),
            _ShareToggle(
              title: 'Prayer',
              value: _prayer,
              onChanged: (v) => setState(() => _prayer = v),
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Text(
                preview.trim().isEmpty ? 'Nothing selected.' : preview,
                style: context.textStyles.bodySmall?.copyWith(color: cs.onSurfaceVariant, height: 1.45),
                maxLines: 8,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: preview.trim().isEmpty
                    ? null
                    : () async {
                        await Share.share(preview);
                      },
                icon: Icon(Icons.ios_share, color: cs.onPrimary),
                label: const Text('Share'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareToggle extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ShareToggle({required this.title, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SwitchListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      value: value,
      onChanged: onChanged,
      title: Text(title, style: context.textStyles.bodyMedium?.copyWith(color: cs.onSurface)),
    );
  }
}
