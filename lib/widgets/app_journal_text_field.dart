import 'package:flutter/material.dart';

/// A TextFormField tuned for calm, natural long-form journaling.
///
/// - Sentence capitalization
/// - Autocorrect + suggestions
/// - Smart punctuation (dashes/quotes)
/// - Multiline flow
class AppJournalTextField extends StatelessWidget {
  final TextEditingController controller;
  final InputDecoration decoration;
  final int? minLines;
  final int? maxLines;
  final TextStyle? style;
  final String? Function(String?)? validator;
  final bool enabled;
  final bool readOnly;

  const AppJournalTextField({
    super.key,
    required this.controller,
    required this.decoration,
    this.minLines,
    this.maxLines,
    this.style,
    this.validator,
    this.enabled = true,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: decoration,
      validator: validator,
      enabled: enabled,
      readOnly: readOnly,
      style: style,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      textCapitalization: TextCapitalization.sentences,
      // IMPORTANT: Keep this as close to the platform default as possible.
      // The goal is for typing to feel identical to native Notes-style editors:
      // - correct cursor placement/selection
      // - normal copy/paste
      // - native autocorrect/suggestions/spellcheck
      // So we intentionally avoid web-specific overrides.
      minLines: minLines,
      maxLines: maxLines,
      textAlignVertical: TextAlignVertical.top,
    );
  }
}
