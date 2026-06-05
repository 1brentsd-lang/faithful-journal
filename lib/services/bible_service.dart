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

  /// Canonical book names used for lightweight in-app suggestions.
  ///
  /// This is intentionally static/offline (no API dependency) for stability.
  static const List<String> canonicalBooks = [
    'Genesis',
    'Exodus',
    'Leviticus',
    'Numbers',
    'Deuteronomy',
    'Joshua',
    'Judges',
    'Ruth',
    '1 Samuel',
    '2 Samuel',
    '1 Kings',
    '2 Kings',
    '1 Chronicles',
    '2 Chronicles',
    'Ezra',
    'Nehemiah',
    'Esther',
    'Job',
    'Psalm',
    'Proverbs',
    'Ecclesiastes',
    'Song of Solomon',
    'Isaiah',
    'Jeremiah',
    'Lamentations',
    'Ezekiel',
    'Daniel',
    'Hosea',
    'Joel',
    'Amos',
    'Obadiah',
    'Jonah',
    'Micah',
    'Nahum',
    'Habakkuk',
    'Zephaniah',
    'Haggai',
    'Zechariah',
    'Malachi',
    'Matthew',
    'Mark',
    'Luke',
    'John',
    'Acts',
    'Romans',
    '1 Corinthians',
    '2 Corinthians',
    'Galatians',
    'Ephesians',
    'Philippians',
    'Colossians',
    '1 Thessalonians',
    '2 Thessalonians',
    '1 Timothy',
    '2 Timothy',
    'Titus',
    'Philemon',
    'Hebrews',
    'James',
    '1 Peter',
    '2 Peter',
    '1 John',
    '2 John',
    '3 John',
    'Jude',
    'Revelation',
  ];

  static const Set<String> _knownTranslations = {
    'WEB',
    'ESV',
    'NIV',
    'NLT',
    'CSB',
    'KJV',
  };

  /// Parses a free-form Scripture reference into lightweight metadata.
  ///
  /// Supports inputs like:
  /// - "Romans 8:28-30 ESV"
  /// - "1 John 4:7"
  /// - "Psalm 23"
  ///
  /// Notes:
  /// - The original string should remain unchanged in storage/display.
  /// - Translation is optional and typically appears as a trailing token.
  static ScriptureReferenceMetadata parseReferenceMetadata(String reference) {
    final ref = reference.trim();
    if (ref.isEmpty) return const ScriptureReferenceMetadata();

    final tokens = ref.split(RegExp(r'\s+')).where((t) => t.trim().isNotEmpty).toList();
    if (tokens.isEmpty) return const ScriptureReferenceMetadata();

    String? translation;
    final last = tokens.last.trim();
    final lastUpper = last.toUpperCase();
    if (_knownTranslations.contains(lastUpper)) {
      translation = lastUpper;
      tokens.removeLast();
    }

    final withoutTranslation = tokens.join(' ').trim();
    if (withoutTranslation.isEmpty) {
      return ScriptureReferenceMetadata(translation: translation);
    }

    // Matches:
    // - "1 Corinthians 13:2-6"
    // - "Psalm 23"
    // - "Luke 4:1, 13-14, 18"
    // We keep book as originally typed (case preserved) and ONLY parse metadata.
    final re = RegExp(r'^\s*(.+?)\s+(\d+)(?:\s*:\s*([0-9,\-\s]+))?\s*$');
    final m = re.firstMatch(withoutTranslation);
    if (m == null) {
      return ScriptureReferenceMetadata(translation: translation);
    }

    final bookRaw = (m.group(1) ?? '').trim();
    final chapter = int.tryParse(m.group(2) ?? '');
    final versesRaw = (m.group(3) ?? '').trim();

    if (bookRaw.isEmpty || chapter == null) {
      return ScriptureReferenceMetadata(translation: translation);
    }

    int? verseStart;
    int? verseEnd;

    if (versesRaw.isNotEmpty) {
      // verse_start: first verse number encountered in the string.
      final firstNumber = RegExp(r'\d+').firstMatch(versesRaw);
      if (firstNumber != null) verseStart = int.tryParse(firstNumber.group(0) ?? '');

      // IMPORTANT: verse_end should only be populated when the user provided a range
      // (e.g. "Romans 8:28-30"). For lists without a dash, keep null.
      final dashMatches = RegExp(r'-\s*(\d+)').allMatches(versesRaw).toList();
      if (dashMatches.isNotEmpty) {
        verseEnd = int.tryParse(dashMatches.last.group(1) ?? '');
      }
    }

    return ScriptureReferenceMetadata(
      book: bookRaw,
      chapter: chapter,
      verseStart: verseStart,
      verseEnd: verseEnd,
      translation: translation,
    );
  }

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

class ScriptureReferenceMetadata {
  final String? book;
  final int? chapter;
  final int? verseStart;
  final int? verseEnd;
  final String? translation;

  const ScriptureReferenceMetadata({this.book, this.chapter, this.verseStart, this.verseEnd, this.translation});
}

class BiblePassage {
  final String reference;
  final String text;
  final String? translationName;

  const BiblePassage({required this.reference, required this.text, this.translationName});
}
