import 'package:flutter/material.dart';

import 'package:faithful_journal/theme.dart';

/// A lightweight, reusable searchable combo box built on Flutter's Autocomplete.
///
/// Design goals:
/// - native-feeling text input (no custom cursor/selection behavior)
/// - type-to-filter
/// - optional custom values (e.g., create new topics)
///
/// Notes:
/// - This does not enforce selection from the list when [allowCustom] is true.
/// - Callers can treat [controller.text] as the source of truth.
class SearchableComboBox extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String labelText;
  final String? hintText;
  final List<String> options;
  final bool allowCustom;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onSelected;
  final VoidCallback? onCleared;

  const SearchableComboBox({
    super.key,
    required this.controller,
    required this.labelText,
    required this.options,
    this.focusNode,
    this.hintText,
    this.allowCustom = false,
    this.validator,
    this.onSelected,
    this.onCleared,
  });

  @override
  State<SearchableComboBox> createState() => _SearchableComboBoxState();
}

class _SearchableComboBoxState extends State<SearchableComboBox> {
  bool _syncing = false;
  TextEditingController? _lastInternal;

  void _internalListener() {
    final internal = _lastInternal;
    if (internal == null) return;
    _pushToExternal(internal);
    if (mounted) setState(() {});
  }

  static String _norm(String s) => s.trim().toLowerCase();

  Iterable<String> _buildMatches(String query) {
    final q = _norm(query);
    if (q.isEmpty) return const Iterable<String>.empty();

    // Prefer prefix matches, then contains matches, preserving original order.
    final prefix = <String>[];
    final contains = <String>[];
    for (final o in widget.options) {
      final n = _norm(o);
      if (n.startsWith(q)) {
        prefix.add(o);
      } else if (n.contains(q)) {
        contains.add(o);
      }
    }
    return [...prefix, ...contains].take(30);
  }

  void _pushToExternal(TextEditingController internal) {
    if (_syncing) return;
    if (widget.controller.value == internal.value) return;
    _syncing = true;
    widget.controller.value = internal.value;
    _syncing = false;
  }

  void _pullFromExternal(TextEditingController internal) {
    if (_syncing) return;
    if (internal.value == widget.controller.value) return;
    _syncing = true;
    internal.value = widget.controller.value;
    _syncing = false;
  }

  @override
  void dispose() {
    _lastInternal?.removeListener(_internalListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Autocomplete<String>(
      optionsBuilder: (value) {
        return _buildMatches(value.text);
      },
      displayStringForOption: (o) => o,
      onSelected: (selection) {
        widget.controller.value = TextEditingValue(
          text: selection,
          selection: TextSelection.collapsed(offset: selection.length),
        );
        widget.onSelected?.call(selection);
        setState(() {});
      },
      fieldViewBuilder: (context, textController, fieldFocusNode, onFieldSubmitted) {
        // Autocomplete's overlay is driven by [textController]. We keep it synced with
        // the external [widget.controller] so the rest of the app can keep using that.
        _pullFromExternal(textController);

        if (!identical(_lastInternal, textController)) {
          _lastInternal?.removeListener(_internalListener);
          _lastInternal = textController;
          _lastInternal!.addListener(_internalListener);
        }

        return TextFormField(
          controller: textController,
          focusNode: widget.focusNode ?? fieldFocusNode,
          decoration: InputDecoration(
            labelText: widget.labelText,
            hintText: widget.hintText,
            suffixIcon: textController.text.trim().isEmpty
                ? const Icon(Icons.expand_more)
                : IconButton(
                    tooltip: 'Clear',
                    icon: Icon(Icons.clear, color: cs.onSurfaceVariant),
                    onPressed: () {
                      textController.clear();
                      _pushToExternal(textController);
                      widget.onCleared?.call();
                    },
                  ),
          ),
          validator: widget.validator,
          onFieldSubmitted: (_) {
            if (!widget.allowCustom) {
              final t = textController.text.trim();
              final match = widget.options.where((o) => _norm(o) == _norm(t)).toList();
              if (match.isNotEmpty) {
                final canonical = match.first;
                textController.value = TextEditingValue(
                  text: canonical,
                  selection: TextSelection.collapsed(offset: canonical.length),
                );
                _pushToExternal(textController);
                widget.onSelected?.call(canonical);
              }
            }
            onFieldSubmitted();
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 0,
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 280),
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: cs.outline.withValues(alpha: 0.18)),
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return InkWell(
                    onTap: () => onSelected(option),
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
                      child: Text(option, style: Theme.of(context).textTheme.bodyMedium),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
