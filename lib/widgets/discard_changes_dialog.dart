import 'package:flutter/material.dart';

/// Returns `true` if the user confirms discarding unsaved progress.
Future<bool> showDiscardChangesDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (context) {
      final cs = Theme.of(context).colorScheme;
      return AlertDialog(
        title: const Text('Discard entry?'),
        content: const Text('Unsaved progress will be lost.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              foregroundColor: cs.onSurface,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      );
    },
  );
  return result ?? false;
}
