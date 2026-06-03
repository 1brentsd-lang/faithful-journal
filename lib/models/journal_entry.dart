enum JournalEntryType { soap, question }

JournalEntryType _parseEntryType(dynamic value) {
  final v = (value as String?)?.trim().toLowerCase();
  if (v == 'question') return JournalEntryType.question;
  return JournalEntryType.soap;
}

String _entryTypeToDb(JournalEntryType type) => type == JournalEntryType.question ? 'question' : 'soap';

class JournalEntry {
  final String id;
  /// Supabase: may be null in temporary testing mode when no auth provider is configured.
  /// Local mode: typically a stable string like `user_1`.
  final String? userId;
  /// For Questions, this may be empty or null.
  final String scriptureReference;
  final String? scriptureText;

  // Scripture metadata (parsed, optional)
  final String? bookName;
  final int? chapter;
  final int? verseStart;
  final int? verseEnd;
  final String? translation;
  final JournalEntryType entryType;
  final bool highlighted;

  // SOAP
  final String observation;
  final ObservationStructured? observationStructured;
  final String application;
  final String prayer;

  // Questions
  final String? question;
  final String? beginningToUnderstand;

  /// For SOAP entries this is typically a theme; for Questions it's optional.
  final String topic;
  final DateTime createdAt;
  final DateTime updatedAt;

  JournalEntry({
    required this.id,
    required this.userId,
    required this.scriptureReference,
    this.scriptureText,
    this.bookName,
    this.chapter,
    this.verseStart,
    this.verseEnd,
    this.translation,
    this.entryType = JournalEntryType.soap,
    this.highlighted = false,
    required this.observation,
    this.observationStructured,
    required this.application,
    required this.prayer,
    this.question,
    this.beginningToUnderstand,
    required this.topic,
    required this.createdAt,
    required this.updatedAt,
  });

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    final type = _parseEntryType(json['entry_type']);

    String firstNonEmpty(List<String> keys) {
      for (final k in keys) {
        final v = (json[k] as String?) ?? '';
        if (v.trim().isNotEmpty) return v;
      }
      return '';
    }

    return JournalEntry(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      scriptureReference: (json['scripture_reference'] as String?) ?? '',
      scriptureText: json['scripture_text'] as String?,
      bookName: (json['book'] as String?)?.trim().isEmpty == true ? null : (json['book'] as String?),
      chapter: json['chapter'] is int ? (json['chapter'] as int) : int.tryParse('${json['chapter'] ?? ''}'),
      verseStart: json['verse_start'] is int ? (json['verse_start'] as int) : int.tryParse('${json['verse_start'] ?? ''}'),
      verseEnd: json['verse_end'] is int ? (json['verse_end'] as int) : int.tryParse('${json['verse_end'] ?? ''}'),
      translation: (json['translation'] as String?)?.trim().isEmpty == true ? null : (json['translation'] as String?),
      entryType: type,
      highlighted: (json['highlighted'] as bool?) ?? false,
      // Observation mapping: some imported datasets used different column names.
      observation: firstNonEmpty(['observation', 'observations', 'observation_text', 'o']),
      observationStructured: _parseObservationStructured(json),
      application: (json['application'] as String?) ?? '',
      prayer: (json['prayer'] as String?) ?? '',
      question: json['question'] as String?,
      // DB column is `resolution` (older code used `beginning_to_understand`).
      beginningToUnderstand: (json['resolution'] as String?) ?? (json['beginning_to_understand'] as String?),
      topic: (json['topic'] as String?) ?? '',
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at'] ?? json['created_at']),
    );
  }

  static ObservationStructured? _parseObservationStructured(Map<String, dynamic> json) {
    // Preferred: JSON blob stored under observation_structured
    final fromStructured = ObservationStructured.fromUnknown(json['observation_structured']);
    if (fromStructured != null && !fromStructured.isEffectivelyEmpty) return fromStructured;

    // Backing columns (Supabase schema): before_passage / after_passage / repeated_theme
    // (Author/Audience were removed from the journaling UI.)
    final hasAnyColumn = json.containsKey('before_passage') ||
        json.containsKey('after_passage') ||
        json.containsKey('repeated_theme');
    if (!hasAnyColumn) return null;

    String read(String key) => (json[key] as String?)?.trim() ?? '';
    final parsed = ObservationStructured(
      leadingContext: read('before_passage'),
      followingContext: read('after_passage'),
      standOut: '',
      repeatedIdeas: read('repeated_theme'),
    );
    if (parsed.isEffectivelyEmpty) return null;
    return parsed;
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    throw FormatException('Invalid datetime: $value');
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'scripture_reference': scriptureReference,
    'scripture_text': scriptureText,
    'book': bookName,
    'chapter': chapter,
    'verse_start': verseStart,
    'verse_end': verseEnd,
    'translation': translation,
    'entry_type': _entryTypeToDb(entryType),
    'highlighted': highlighted,
    'observation': observation,
    'observation_structured': observationStructured?.toJson(),
    'application': application,
    'prayer': prayer,
    'question': question,
    'beginning_to_understand': beginningToUnderstand,
    'topic': topic,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  JournalEntry copyWith({
    String? id,
    String? userId,
    String? scriptureReference,
    String? scriptureText,
    String? bookName,
    int? chapter,
    int? verseStart,
    int? verseEnd,
    String? translation,
    JournalEntryType? entryType,
    bool? highlighted,
    String? observation,
    ObservationStructured? observationStructured,
    String? application,
    String? prayer,
    String? question,
    String? beginningToUnderstand,
    String? topic,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => JournalEntry(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    scriptureReference: scriptureReference ?? this.scriptureReference,
    scriptureText: scriptureText ?? this.scriptureText,
    bookName: bookName ?? this.bookName,
    chapter: chapter ?? this.chapter,
    verseStart: verseStart ?? this.verseStart,
    verseEnd: verseEnd ?? this.verseEnd,
    translation: translation ?? this.translation,
    entryType: entryType ?? this.entryType,
    highlighted: highlighted ?? this.highlighted,
    observation: observation ?? this.observation,
    observationStructured: observationStructured ?? this.observationStructured,
    application: application ?? this.application,
    prayer: prayer ?? this.prayer,
    question: question ?? this.question,
    beginningToUnderstand: beginningToUnderstand ?? this.beginningToUnderstand,
    topic: topic ?? this.topic,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  bool get isQuestion => entryType == JournalEntryType.question;

  bool get hasBeginningToUnderstand => (beginningToUnderstand ?? '').trim().isNotEmpty;

  String get book {
    final stored = bookName?.trim() ?? '';
    if (stored.isNotEmpty) return stored;
    return _computeBookFromScriptureReference(scriptureReference);
  }

  static String _computeBookFromScriptureReference(String scriptureReference) {
    final parts = scriptureReference.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '';

    final numberMatch = RegExp(r'^\d+$').firstMatch(parts[0]);
    if (numberMatch != null && parts.length > 1) return '${parts[0]} ${parts[1]}';
    return parts[0];
  }

  /// A lightweight key that approximates "Scripture chapter".
  ///
  /// Examples:
  /// - "Psalm 23:1-3" -> "Psalm 23"
  /// - "1 John 4:7" -> "1 John 4"
  /// - "John 3" -> "John 3"
  ///
  /// If the chapter cannot be parsed, returns an empty string.
  String get chapterKey {
    final b = book.trim();
    if (b.isEmpty) return '';

    final ch = chapter;
    if (ch != null) return '$b $ch';

    final ref = scriptureReference.trim();
    if (ref.isEmpty) return '';

    // Prefer classic chapter:verse formats.
    final m = RegExp(r'(\d+)(?=\s*:)').firstMatch(ref);
    if (m != null) return '$b ${m.group(1)}';

    // Fall back: look for a chapter number token right after the book name.
    final afterBook = ref.replaceFirst(b, '').trimLeft();
    final m2 = RegExp(r'^(\d+)\b').firstMatch(afterBook);
    if (m2 != null) return '$b ${m2.group(1)}';

    return '';
  }

  String get preview {
    final text = isQuestion
        ? ((question ?? '').trim().isNotEmpty ? (question ?? '').trim() : (beginningToUnderstand ?? '').trim())
        : (observation.isNotEmpty ? observation : application);
    if (text.length <= 100) return text;
    return '${text.substring(0, 100)}...';
  }
}

class ObservationStructured {
  final String leadingContext;
  final String followingContext;
  final String standOut;
  final String repeatedIdeas;

  const ObservationStructured({
    required this.leadingContext,
    required this.followingContext,
    required this.standOut,
    required this.repeatedIdeas,
  });

  static ObservationStructured? fromUnknown(dynamic value) {
    if (value == null) return null;
    if (value is ObservationStructured) return value;
    if (value is Map) {
      final map = value.cast<String, dynamic>();
      final parsed = ObservationStructured.fromJson(map);
      if (parsed.isEffectivelyEmpty) return null;
      return parsed;
    }
    return null;
  }

  bool get isEffectivelyEmpty =>
      leadingContext.trim().isEmpty && followingContext.trim().isEmpty && standOut.trim().isEmpty && repeatedIdeas.trim().isEmpty;

  factory ObservationStructured.fromJson(Map<String, dynamic> json) => ObservationStructured(
    leadingContext: (json['leading_context'] as String?) ?? '',
    followingContext: (json['following_context'] as String?) ?? '',
    standOut: (json['stand_out'] as String?) ?? '',
    repeatedIdeas: (json['repeated_ideas'] as String?) ?? '',
  );

  Map<String, dynamic> toJson() => {
    'leading_context': leadingContext,
    'following_context': followingContext,
    'stand_out': standOut,
    'repeated_ideas': repeatedIdeas,
  };

  ObservationStructured copyWith({
    String? leadingContext,
    String? followingContext,
    String? standOut,
    String? repeatedIdeas,
  }) => ObservationStructured(
    leadingContext: leadingContext ?? this.leadingContext,
    followingContext: followingContext ?? this.followingContext,
    standOut: standOut ?? this.standOut,
    repeatedIdeas: repeatedIdeas ?? this.repeatedIdeas,
  );
}
