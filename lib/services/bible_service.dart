import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Minimal Bible passage fetcher using the free bible-api.com endpoint.
///
/// Notes:
/// - No API key required.
/// - Translation support is limited; default is WEB (World English Bible).
/// - Intended for quick journaling lookup, not full-featured Bible study.
class BibleService {
  static const _base = 'https://bible-api.com';

  Future<BiblePassage?> fetchPassage({required String reference, String translation = 'web'}) async {
    final trimmed = reference.trim();
    if (trimmed.isEmpty) return null;

    final uri = Uri.parse('$_base/${Uri.encodeComponent(trimmed)}?translation=${Uri.encodeQueryComponent(translation)}');
    try {
      final res = await http.get(uri, headers: {'accept': 'application/json'});
      if (res.statusCode < 200 || res.statusCode >= 300) {
        debugPrint('BibleService fetch failed (${res.statusCode}): ${res.body}');
        return null;
      }

      final decoded = json.decode(utf8.decode(res.bodyBytes));
      if (decoded is! Map<String, dynamic>) return null;

      final error = decoded['error'];
      if (error is String && error.trim().isNotEmpty) {
        debugPrint('BibleService API error: $error');
        return null;
      }

      final referenceOut = (decoded['reference'] as String?)?.trim();
      final text = (decoded['text'] as String?)?.trim();
      final translationOut = (decoded['translation_name'] as String?)?.trim();

      if (referenceOut == null || referenceOut.isEmpty || text == null || text.isEmpty) return null;
      return BiblePassage(reference: referenceOut, text: _cleanPassageText(text), translationName: translationOut);
    } catch (e) {
      debugPrint('BibleService fetchPassage exception: $e');
      return null;
    }
  }

  String _cleanPassageText(String text) {
    // bible-api often includes extra newlines; normalize without losing paragraphing.
    final lines = text
        .split('\n')
        .map((l) => l.trimRight())
        .toList();
    return lines.join('\n').trim();
  }
}

class BiblePassage {
  final String reference;
  final String text;
  final String? translationName;

  const BiblePassage({required this.reference, required this.text, this.translationName});
}
