class JournalEntry {
  final String id;
  /// Supabase: may be null in temporary testing mode when no auth provider is configured.
  /// Local mode: typically a stable string like `user_1`.
  final String? userId;
  final String scriptureReference;
  final String? scriptureText;
  final String observation;
  final ObservationStructured? observationStructured;
  final String application;
  final String prayer;
  final String topic;
  final DateTime createdAt;
  final DateTime updatedAt;

  JournalEntry({
    required this.id,
    required this.userId,
    required this.scriptureReference,
    this.scriptureText,
    required this.observation,
    this.observationStructured,
    required this.application,
    required this.prayer,
    required this.topic,
    required this.createdAt,
    required this.updatedAt,
  });

  factory JournalEntry.fromJson(Map<String, dynamic> json) => JournalEntry(
    id: json['id'] as String,
    userId: json['user_id'] as String?,
    scriptureReference: json['scripture_reference'] as String,
    scriptureText: json['scripture_text'] as String?,
    observation: json['observation'] as String,
    observationStructured: _parseObservationStructured(json),
    application: json['application'] as String,
    prayer: json['prayer'] as String,
    topic: json['topic'] as String,
    createdAt: _parseDateTime(json['created_at']),
    updatedAt: _parseDateTime(json['updated_at'] ?? json['created_at']),
  );

  static ObservationStructured? _parseObservationStructured(Map<String, dynamic> json) {
    // Preferred: JSON blob stored under observation_structured
    final fromStructured = ObservationStructured.fromUnknown(json['observation_structured']);
    if (fromStructured != null) return fromStructured;

    // Backing columns (Supabase schema): before_passage / after_passage / repeated_theme / author / audience
    final hasAnyColumn = json.containsKey('before_passage') ||
        json.containsKey('after_passage') ||
        json.containsKey('repeated_theme') ||
        json.containsKey('author') ||
        json.containsKey('audience');
    if (!hasAnyColumn) return null;

    String read(String key) => (json[key] as String?)?.trim() ?? '';
    return ObservationStructured(
      leadingContext: read('before_passage'),
      followingContext: read('after_passage'),
      standOut: '',
      repeatedIdeas: read('repeated_theme'),
      author: read('author'),
      audience: read('audience'),
    );
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
    'observation': observation,
    'observation_structured': observationStructured?.toJson(),
    'application': application,
    'prayer': prayer,
    'topic': topic,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  JournalEntry copyWith({
    String? id,
    String? userId,
    String? scriptureReference,
    String? scriptureText,
    String? observation,
    ObservationStructured? observationStructured,
    String? application,
    String? prayer,
    String? topic,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => JournalEntry(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    scriptureReference: scriptureReference ?? this.scriptureReference,
    scriptureText: scriptureText ?? this.scriptureText,
    observation: observation ?? this.observation,
    observationStructured: observationStructured ?? this.observationStructured,
    application: application ?? this.application,
    prayer: prayer ?? this.prayer,
    topic: topic ?? this.topic,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  String get book {
    final parts = scriptureReference.split(' ');
    if (parts.isEmpty) return '';
    
    final numberMatch = RegExp(r'^\d+').firstMatch(parts[0]);
    if (numberMatch != null && parts.length > 1) {
      return '${parts[0]} ${parts[1]}';
    }
    return parts[0];
  }

  String get preview {
    final text = observation.isNotEmpty ? observation : application;
    if (text.length <= 100) return text;
    return '${text.substring(0, 100)}...';
  }
}

class ObservationStructured {
  final String leadingContext;
  final String followingContext;
  final String standOut;
  final String repeatedIdeas;
  final String author;
  final String audience;

  const ObservationStructured({
    required this.leadingContext,
    required this.followingContext,
    required this.standOut,
    required this.repeatedIdeas,
    required this.author,
    required this.audience,
  });

  static ObservationStructured? fromUnknown(dynamic value) {
    if (value == null) return null;
    if (value is ObservationStructured) return value;
    if (value is Map) {
      final map = value.cast<String, dynamic>();
      return ObservationStructured.fromJson(map);
    }
    return null;
  }

  factory ObservationStructured.fromJson(Map<String, dynamic> json) => ObservationStructured(
    leadingContext: (json['leading_context'] as String?) ?? '',
    followingContext: (json['following_context'] as String?) ?? '',
    standOut: (json['stand_out'] as String?) ?? '',
    repeatedIdeas: (json['repeated_ideas'] as String?) ?? '',
    // Back-compat: older versions stored these as genre/purpose.
    author: (json['author'] as String?) ?? (json['genre'] as String?) ?? '',
    audience: (json['audience'] as String?) ?? (json['purpose'] as String?) ?? '',
  );

  Map<String, dynamic> toJson() => {
    'leading_context': leadingContext,
    'following_context': followingContext,
    'stand_out': standOut,
    'repeated_ideas': repeatedIdeas,
    'author': author,
    'audience': audience,
  };

  ObservationStructured copyWith({
    String? leadingContext,
    String? followingContext,
    String? standOut,
    String? repeatedIdeas,
    String? author,
    String? audience,
  }) => ObservationStructured(
    leadingContext: leadingContext ?? this.leadingContext,
    followingContext: followingContext ?? this.followingContext,
    standOut: standOut ?? this.standOut,
    repeatedIdeas: repeatedIdeas ?? this.repeatedIdeas,
    author: author ?? this.author,
    audience: audience ?? this.audience,
  );
}
