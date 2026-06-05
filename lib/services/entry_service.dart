import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:faithful_journal/models/journal_entry.dart';
import 'package:faithful_journal/services/bible_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum QuestionFilter { all, stillWrestling, developingUnderstanding }

class EntryService extends ChangeNotifier {
  static const String _entriesKey = 'journal_entries';
  static const String _scriptureBackfillV2Key = 'scripture_metadata_backfill_v2_done';

  /// Thrown when Supabase is enabled but there is no signed-in user.
  ///
  /// We use this to keep UI behavior stable and intentional under RLS: instead
  /// of red-screening on Postgrest 401/403 errors, screens can prompt the user
  /// to sign in.
  static const String _authRequiredMessage = 'AUTH_REQUIRED';

  final _uuid = const Uuid();
  List<JournalEntry> _entries = [];
  bool _isLoading = true;

  bool _useSupabase = false;
  SupabaseClient? _supabase;

  /// Subscription for auth state changes so the app stays in sync.
  StreamSubscription<AuthState>? _authSub;

  List<JournalEntry> get entries => List.unmodifiable(_entries);
  bool get isLoading => _isLoading;

  EntryService() {
    _loadEntries();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  bool get isUsingSupabase => _useSupabase;

  /// Returns a stable identifier for the current user.
  ///
  /// - When using Supabase, this requires a signed-in user.
  /// - When running locally (no Supabase), this falls back to a stable local id.
  String get currentUserId {
    if (_useSupabase) {
      return requireUserId();
    }
    return 'user_1';
  }

  String? get supabaseUserId => _supabase?.auth.currentUser?.id;

  String requireUserId() {
    final id = _supabase?.auth.currentUser?.id;
    if (id == null || id.isEmpty) {
      throw StateError(_authRequiredMessage);
    }
    return id;
  }

  Future<void> _loadEntries() async {
    try {
      _supabase = _tryGetSupabaseClient();
      if (_supabase != null) {
        _useSupabase = true;
        _bindAuthListenerIfNeeded();
        await _loadEntriesFromSupabase();
        await _backfillScriptureMetadataIfNeeded();
      } else {
        _useSupabase = false;
        await _loadEntriesFromLocal();
        await _backfillScriptureMetadataIfNeeded();
      }
    } catch (e) {
      debugPrint('Failed to load entries: $e');
      await _loadEntriesFromLocal();
      await _backfillScriptureMetadataIfNeeded();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _backfillScriptureMetadataIfNeeded() async {
    // One-time backfill to correct previously imported/parsed entries,
    // especially numbered books ("1 Corinthians", "2 Timothy", etc.).
    try {
      final prefs = await SharedPreferences.getInstance();
      final already = prefs.getBool(_scriptureBackfillV2Key) ?? false;
      if (already) return;

      var changedCount = 0;
      final updatedEntries = <JournalEntry>[];
      final updatesById = <String, ScriptureReferenceMetadata>{};

      for (final e in _entries) {
        final meta = BibleService.parseReferenceMetadata(e.scriptureReference);

        // If we can't parse anything meaningful, skip.
        final hasAny = (meta.book?.trim().isNotEmpty ?? false) || meta.chapter != null || meta.translation != null;
        if (!hasAny) {
          updatedEntries.add(e);
          continue;
        }

        bool differs(String? a, String? b) => (a ?? '').trim() != (b ?? '').trim();
        bool needsUpdate = false;

        if (differs(e.bookName, meta.book)) needsUpdate = true;
        if (e.chapter != meta.chapter) needsUpdate = true;
        if (e.verseStart != meta.verseStart) needsUpdate = true;
        if (e.verseEnd != meta.verseEnd) needsUpdate = true;
        if (differs(e.translation, meta.translation)) needsUpdate = true;

        if (!needsUpdate) {
          updatedEntries.add(e);
          continue;
        }

        changedCount += 1;
        updatesById[e.id] = meta;
        updatedEntries.add(
          e.copyWith(
            bookName: (meta.book?.trim().isEmpty ?? true) ? null : meta.book?.trim(),
            chapter: meta.chapter,
            verseStart: meta.verseStart,
            verseEnd: meta.verseEnd,
            translation: (meta.translation?.trim().isEmpty ?? true) ? null : meta.translation?.trim(),
          ),
        );
      }

      if (changedCount == 0) {
        await prefs.setBool(_scriptureBackfillV2Key, true);
        return;
      }

      _entries = updatedEntries;
      notifyListeners();

      if (_useSupabase && _supabase != null) {
        // Update only the metadata columns; do NOT touch scripture_reference.
        // We avoid updating updated_at here to prevent noisy "edit" signals.
        for (final entryId in updatesById.keys) {
          final meta = updatesById[entryId]!;
          final updateMap = <String, dynamic>{
            'book': meta.book,
            'chapter': meta.chapter,
            'verse_start': meta.verseStart,
            'verse_end': meta.verseEnd,
            'translation': meta.translation,
          };
          try {
            await _updateJournalEntryWithSchemaFallback(entryId, updateMap);
          } catch (err) {
            debugPrint('Scripture metadata backfill update failed for entry=$entryId: $err');
          }
        }
      } else {
        await _saveEntries();
      }

      await prefs.setBool(_scriptureBackfillV2Key, true);
      debugPrint('Scripture metadata backfill v2 completed. Updated $changedCount entries.');
    } catch (e) {
      debugPrint('Scripture metadata backfill v2 failed: $e');
    }
  }

  SupabaseClient? _tryGetSupabaseClient() {
    try {
      // Throws if Supabase.initialize() wasn't called.
      return Supabase.instance.client;
    } catch (e) {
      debugPrint('Supabase not available: $e');
      return null;
    }
  }

  void _bindAuthListenerIfNeeded() {
    if (_supabase == null) return;
    _authSub ??= _supabase!.auth.onAuthStateChange.listen((data) async {
      // Keep this extremely defensive: auth changes can happen during route
      // transitions or when the app is backgrounded.
      try {
        await refresh();
      } catch (e) {
        debugPrint('EntryService auth refresh failed: $e');
      }
    });
  }

  bool get needsAuth => _useSupabase && (_supabase?.auth.currentUser == null);

  /// Ensures a Supabase auth session exists (anonymous by default).
  /// Safe to call even when Supabase isn't configured.
  Future<void> ensureAuthenticated() async {
    if (_supabase == null) {
      _supabase = _tryGetSupabaseClient();
      _useSupabase = _supabase != null;
    }
    if (_supabase == null) return;
    _bindAuthListenerIfNeeded();
  }

  Future<void> refresh() async {
    if (_useSupabase && _supabase != null) {
      await _loadEntriesFromSupabase();
    } else {
      await _loadEntriesFromLocal();
      _entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    notifyListeners();
  }

  Future<void> _loadEntriesFromSupabase() async {
    if (_supabase == null) return;
    try {
      if (needsAuth) {
        _entries = [];
        return;
      }
      final rows = await _supabase!
          .from('journal_entries')
          .select()
          .order('created_at', ascending: false);
      _entries = (rows as List)
          .cast<Map<String, dynamic>>()
          .map(JournalEntry.fromJson)
          .toList();
    } catch (e) {
      debugPrint('Failed to load entries from Supabase: $e');
      _entries = [];
    }
  }

  Future<void> _loadEntriesFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final entriesJson = prefs.getString(_entriesKey);

      if (entriesJson != null) {
        final List<dynamic> decoded = json.decode(entriesJson);
        _entries = decoded.map((e) {
          try {
            return JournalEntry.fromJson(e as Map<String, dynamic>);
          } catch (err) {
            debugPrint('Skipping corrupted entry: $err');
            return null;
          }
        }).whereType<JournalEntry>().toList();

        if (_entries.length != decoded.length) {
          await _saveEntries();
        }
      } else {
        await _initializeSampleData();
      }
    } catch (e) {
      debugPrint('Failed to load local entries: $e');
      await _initializeSampleData();
    }
  }

  Future<void> _saveEntries() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final entriesJson = json.encode(_entries.map((e) => e.toJson()).toList());
      await prefs.setString(_entriesKey, entriesJson);
    } catch (e) {
      debugPrint('Failed to save entries: $e');
    }
  }

  Future<void> _initializeSampleData() async {
    final now = DateTime.now();
    _entries = [
      JournalEntry(
        id: _uuid.v4(),
        userId: 'user_1',
        scriptureReference: 'Psalm 23:1-3',
        scriptureText: null,
        observation: 'The imagery of the shepherd is so comforting. God is portrayed not as distant, but as intimately caring for His flock. The shepherd knows each sheep by name, leads them to green pastures and still waters. This speaks of provision and rest.',
        application: 'I often strive and worry, forgetting that God leads me to places of rest. Today I will choose to trust His guidance rather than forcing my own path.',
        prayer: 'Lord, help me to trust You as my Shepherd. Lead me beside still waters when my soul is restless. Restore me when I am weary.',
        topic: 'Trust',
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now.subtract(const Duration(days: 2)),
      ),
      JournalEntry(
        id: _uuid.v4(),
        userId: 'user_1',
        scriptureReference: 'Philippians 4:6-7',
        scriptureText: null,
        observation: 'Paul writes "do not be anxious about anything" - a command, not a suggestion. But it comes with a method: prayer and thanksgiving. The peace of God is promised as a result, and it transcends understanding.',
        application: 'Instead of letting anxiety spiral today, I will bring my concerns to God in prayer. I will intentionally add thanksgiving, even for small things.',
        prayer: 'Father, I bring my worries to You: work deadlines, family concerns, financial pressures. Thank You for Your faithfulness in the past. Guard my heart with Your peace.',
        topic: 'Peace',
        createdAt: now.subtract(const Duration(days: 5)),
        updatedAt: now.subtract(const Duration(days: 5)),
      ),
      JournalEntry(
        id: _uuid.v4(),
        userId: 'user_1',
        scriptureReference: 'Romans 8:28',
        scriptureText: null,
        observation: 'This promise is conditional: "for those who love God and are called according to His purpose." God works ALL things together for good - not that all things are good, but that He can weave even painful things into His redemptive plan.',
        application: 'That difficult situation at work - I can trust God is working even through this. It may not feel good now, but I can look for how He might be shaping me through it.',
        prayer: 'Lord, help me trust Your sovereignty. When I cannot see the good, help me remember You are working all things together according to Your purpose.',
        topic: 'Trust',
        createdAt: now.subtract(const Duration(days: 8)),
        updatedAt: now.subtract(const Duration(days: 8)),
      ),
      JournalEntry(
        id: _uuid.v4(),
        userId: 'user_1',
        scriptureReference: 'John 15:4-5',
        scriptureText: null,
        observation: 'Jesus uses the vine and branches metaphor. "Apart from me you can do nothing" is absolute. The key word is "remain" - it suggests ongoing, active connection, not a one-time decision.',
        application: 'I cannot produce spiritual fruit through effort alone. I need to remain connected to Jesus daily through prayer, Scripture, and surrender. What does remaining look like today?',
        prayer: 'Jesus, I want to remain in You. Help me to stay connected, to abide in Your presence throughout this day. May my life bear fruit that glorifies You.',
        topic: 'Abiding',
        createdAt: now.subtract(const Duration(days: 12)),
        updatedAt: now.subtract(const Duration(days: 12)),
      ),
      JournalEntry(
        id: _uuid.v4(),
        userId: 'user_1',
        scriptureReference: 'Matthew 11:28-30',
        scriptureText: null,
        observation: 'Jesus invites the weary and burdened to come to Him. He promises rest for our souls. His yoke is easy and burden is light - contrasting with the heavy religious burdens the Pharisees placed on people.',
        application: 'What burdens am I carrying that Jesus never asked me to carry? Am I trying to earn His approval through performance? I need to accept His invitation to rest.',
        prayer: 'Jesus, I am weary. I come to You now. Teach me Your way of rest. Help me to release the burdens I was never meant to carry.',
        topic: 'Rest',
        createdAt: now.subtract(const Duration(days: 15)),
        updatedAt: now.subtract(const Duration(days: 15)),
      ),
    ];
    
    _entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await _saveEntries();
  }

  Future<void> createEntry(JournalEntry entry) async {
    entry = entry.copyWith(topic: canonicalizeTopic(entry.topic));
    if (_useSupabase && _supabase != null) {
      try {
        debugPrint('createEntry(): Save triggered. useSupabase=$_useSupabase');
        if (needsAuth) throw StateError(_authRequiredMessage);
        final ownerId = requireUserId();

        final s = entry.observationStructured;
        final meta = _effectiveScriptureMetadata(entry);
        final insertMap = <String, dynamic>{
          'id': entry.id,
          'user_id': ownerId,
          'entry_type': entry.entryType == JournalEntryType.question ? 'question' : 'soap',
          'highlighted': entry.highlighted,
          'scripture_reference': entry.scriptureReference,
          'scripture_text': entry.scriptureText,
          'book': meta.book,
          'chapter': meta.chapter,
          'verse_start': meta.verseStart,
          'verse_end': meta.verseEnd,
          'translation': meta.translation,
          'observation': entry.observation,
          'application': entry.application,
          'prayer': entry.prayer,
          'question': entry.question,
          // DB column name is `resolution` (model field is `beginningToUnderstand`).
          'resolution': entry.beginningToUnderstand,
          'topic': entry.topic,
          'before_passage': s?.leadingContext,
          'after_passage': s?.followingContext,
          'created_at': entry.createdAt.toIso8601String(),
          'updated_at': entry.updatedAt.toIso8601String(),
        };

        debugPrint('createEntry(): Inserting into journal_entries. keys=${insertMap.keys.toList()}');

        // Select the inserted row to get the DB-generated id and timestamps.
        final row = await _insertJournalEntryWithSchemaFallback(insertMap);
        debugPrint('createEntry(): Insert success. Returned row id=${row['id']}');
        final created = JournalEntry.fromJson(row);
        _entries.insert(0, created);
        notifyListeners();
        return;
      } catch (e) {
        if (e is PostgrestException) {
          debugPrint(
            'Supabase createEntry failed (PostgrestException): message=${e.message} code=${e.code} details=${e.details} hint=${e.hint}',
          );
        } else {
          debugPrint('Supabase createEntry failed: $e');
        }
        // IMPORTANT: Do not silently fall back to local; bubble this up so the UI can show an error.
        rethrow;
      }
    }
    _entries.insert(0, entry);
    await _saveEntries();
    notifyListeners();
  }

  Future<void> updateEntry(JournalEntry entry) async {
    entry = entry.copyWith(topic: canonicalizeTopic(entry.topic));
    final index = _entries.indexWhere((e) => e.id == entry.id);
    if (index != -1) {
      _entries[index] = entry;
      if (_useSupabase && _supabase != null) {
        try {
          if (needsAuth) throw StateError(_authRequiredMessage);
          final s = entry.observationStructured;
          final meta = _effectiveScriptureMetadata(entry);
          final updateMap = {
              'entry_type': entry.entryType == JournalEntryType.question ? 'question' : 'soap',
              'highlighted': entry.highlighted,
            'scripture_reference': entry.scriptureReference,
            'scripture_text': entry.scriptureText,
              'book': meta.book,
              'chapter': meta.chapter,
              'verse_start': meta.verseStart,
              'verse_end': meta.verseEnd,
              'translation': meta.translation,
            'observation': entry.observation,
            'application': entry.application,
            'prayer': entry.prayer,
              'question': entry.question,
            'resolution': entry.beginningToUnderstand,
            'topic': entry.topic,
            'before_passage': s?.leadingContext,
            'after_passage': s?.followingContext,
            'updated_at': entry.updatedAt.toIso8601String(),
          };
          await _updateJournalEntryWithSchemaFallback(entry.id, updateMap);
          notifyListeners();
          return;
        } catch (e) {
          debugPrint('Supabase updateEntry failed: $e');
          rethrow;
        }
      }
      await _saveEntries();
      notifyListeners();
    }
  }

  Future<void> deleteEntry(String id) async {
    // Delete should be atomic from the UI's perspective:
    // - If Supabase delete fails, do NOT remove locally.
    // - Only remove locally after the backend call succeeds.
    final existingIndex = _entries.indexWhere((e) => e.id == id);

    if (_useSupabase && _supabase != null) {
      try {
        if (needsAuth) throw StateError(_authRequiredMessage);
        await _supabase!.from('journal_entries').delete().eq('id', id);
        if (existingIndex != -1) _entries.removeAt(existingIndex);
        notifyListeners();
        return;
      } catch (e) {
        debugPrint('Supabase deleteEntry failed: $e');
        // Keep local state intact on failure.
        rethrow;
      }
    }

    if (existingIndex != -1) _entries.removeAt(existingIndex);
    await _saveEntries();
    notifyListeners();
  }

  JournalEntry? getEntryById(String id) {
    try {
      return _entries.firstWhere((e) => e.id == id);
    } catch (e) {
      return null;
    }
  }

  List<JournalEntry> getRecentEntries({int limit = 5}) {
    final soap = _entries.where((e) => e.entryType == JournalEntryType.soap).toList();
    return soap.take(limit).toList();
  }

  List<JournalEntry> getRecentQuestions({int limit = 5}) {
    final questions = _entries.where((e) => e.entryType == JournalEntryType.question).toList();
    return questions.take(limit).toList();
  }

  List<JournalEntry> getQuestions({QuestionFilter filter = QuestionFilter.all}) {
    final questions = _entries.where((e) => e.entryType == JournalEntryType.question);
    switch (filter) {
      case QuestionFilter.all:
        return questions.toList();
      case QuestionFilter.stillWrestling:
        return questions.where((e) => !e.hasBeginningToUnderstand).toList();
      case QuestionFilter.developingUnderstanding:
        return questions.where((e) => e.hasBeginningToUnderstand).toList();
    }
  }

  List<JournalEntry> getEntriesByTopic(String topic) {
    return _entries.where((e) => e.topic.toLowerCase() == topic.toLowerCase()).toList();
  }

  List<JournalEntry> getEntriesByBook(String book) {
    return _entries.where((e) => e.book.toLowerCase() == book.toLowerCase()).toList();
  }

  List<JournalEntry> getWeeklyEntries() {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    return _entries.where((e) => e.createdAt.isAfter(weekAgo)).toList();
  }

  List<JournalEntry> searchEntries(String query) {
    final lowerQuery = query.toLowerCase();
    return _entries.where((e) {
      return e.scriptureReference.toLowerCase().contains(lowerQuery) ||
          (e.question ?? '').toLowerCase().contains(lowerQuery) ||
          (e.beginningToUnderstand ?? '').toLowerCase().contains(lowerQuery) ||
          e.observation.toLowerCase().contains(lowerQuery) ||
          e.application.toLowerCase().contains(lowerQuery) ||
          e.prayer.toLowerCase().contains(lowerQuery) ||
          e.topic.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  List<JournalEntry> getRelatedByTopic(String entryId, String topic, {int limit = 3}) {
    return _entries
        .where((e) => e.id != entryId && e.topic.toLowerCase() == topic.toLowerCase())
        .take(limit)
        .toList();
  }

  List<JournalEntry> getRelatedByBook(String entryId, String book, {int limit = 3}) {
    return _entries
        .where((e) => e.id != entryId && e.book.toLowerCase() == book.toLowerCase())
        .take(limit)
        .toList();
  }

  /// Returns a quiet, archival "resurfacing" list of entries that feel like
  /// "you've been here before".
  ///
  /// Matching priority:
  /// 1) Same chapter
  /// 2) Fill remaining slots with same book
  ///
  /// Ordering: oldest -> newest.
  List<JournalEntry> getResurfacingForEntry(String entryId, {int maxItems = 5}) {
    final seed = getEntryById(entryId);
    if (seed == null) return const [];

    int? parseChapterFromKey(String key) {
      final m = RegExp(r'\b(\d+)\b').firstMatch(key);
      if (m == null) return null;
      return int.tryParse(m.group(1)!);
    }

    final seedBook = seed.book.trim().toLowerCase();
    final seedChapter = seed.chapter ?? parseChapterFromKey(seed.chapterKey);

    String normalizeChapterKey(String key) => key.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
    final seedKey = normalizeChapterKey(seed.chapterKey);

    final matches = <JournalEntry>[];
    final seen = <String>{};

    void addAll(Iterable<JournalEntry> items) {
      for (final e in items) {
        if (e.id == entryId) continue;
        if (seen.add(e.id)) matches.add(e);
      }
    }

    bool sameBookChapter(JournalEntry e) {
      if (seedBook.isEmpty || seedChapter == null) return false;
      final b = e.book.trim().toLowerCase();
      final ch = e.chapter ?? parseChapterFromKey(e.chapterKey);
      if (b.isNotEmpty && ch != null && b == seedBook && ch == seedChapter) return true;
      if (seedKey.isEmpty) return false;
      final eKey = normalizeChapterKey(e.chapterKey);
      return eKey.isNotEmpty && eKey == seedKey;
    }

    // First priority: same chapter.
    addAll(_entries.where(sameBookChapter));

    // Second priority: same book (to fill remaining slots).
    if (matches.length < maxItems && seedBook.isNotEmpty) {
      addAll(_entries.where((e) => e.id != entryId && e.book.trim().toLowerCase() == seedBook));
    }

    matches.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (matches.length <= maxItems) return matches;
    return matches.take(maxItems).toList();
  }

  /// Related entries for the "Saved" confirmation view.
  ///
  /// Priority:
  /// 1) Same Book + Same Chapter
  /// 2) Same Topic
  /// 3) Same Book (oldest entries first)
  ///
  /// Ordering: oldest -> newest, so the list highlights long-term growth.
  List<JournalEntry> getRelatedForSavedEntry(String entryId, {int limit = 5}) {
    final seed = getEntryById(entryId);
    if (seed == null) return const [];

    final results = <JournalEntry>[];
    final seen = <String>{entryId};

    bool add(JournalEntry e) {
      if (seen.add(e.id)) {
        results.add(e);
        return true;
      }
      return false;
    }

    String norm(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
    final seedChapterKey = norm(seed.chapterKey);
    final seedBook = seed.book.trim().toLowerCase();
    final seedTopic = normalizeTopic(seed.topic).trim().toLowerCase();

    final sameChapter = _entries.where((e) {
      if (seen.contains(e.id)) return false;
      final ck = norm(e.chapterKey);
      if (seedChapterKey.isEmpty || ck.isEmpty) return false;
      return ck == seedChapterKey;
    }).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    for (final e in sameChapter) {
      if (results.length >= limit) return results;
      add(e);
    }

    final sameTopic = _entries.where((e) {
      if (seen.contains(e.id)) return false;
      final t = normalizeTopic(e.topic).trim().toLowerCase();
      if (seedTopic.isEmpty || t.isEmpty) return false;
      return t == seedTopic;
    }).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    for (final e in sameTopic) {
      if (results.length >= limit) return results;
      add(e);
    }

    if (seedBook.isNotEmpty) {
      final sameBook = _entries.where((e) {
        if (seen.contains(e.id)) return false;
        return e.book.trim().toLowerCase() == seedBook;
      }).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      for (final e in sameBook) {
        if (results.length >= limit) return results;
        add(e);
      }
    }

    return results;
  }

  List<String> getAllTopics() {
    final topics = _entries
        .map((e) => canonicalizeTopic(e.topic))
        .where((t) => t.trim().isNotEmpty)
        .toSet()
        .toList();
    topics.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return topics;
  }

  /// Normalizes a topic so casing/spacing stays consistent over time.
  ///
  /// - trims
  /// - collapses whitespace
  /// - Title Cases each word
  String normalizeTopic(String raw) {
    final trimmed = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.isEmpty) return '';
    return trimmed
        .split(' ')
        .map((w) {
          if (w.isEmpty) return w;
          final lower = w.toLowerCase();
          return '${lower[0].toUpperCase()}${lower.substring(1)}';
        })
        .join(' ');
  }

  /// Returns the canonical stored topic casing if it already exists; otherwise
  /// returns a normalized new topic.
  String canonicalizeTopic(String raw) {
    final normalized = normalizeTopic(raw);
    if (normalized.isEmpty) return '';
    final key = normalized.toLowerCase();
    for (final e in _entries) {
      final existing = normalizeTopic(e.topic);
      if (existing.isNotEmpty && existing.toLowerCase() == key) return existing;
    }
    return normalized;
  }

  List<String> getAllBooks() {
    final books = _entries.map((e) => e.book).toSet().toList();
    books.sort();
    return books;
  }

  /// Returns unique [JournalEntry.chapterKey] values (e.g. "John 3").
  ///
  /// Empty / unparseable chapter keys are excluded.
  List<String> getAllChapterKeys() {
    final keys = _entries.map((e) => e.chapterKey.trim()).where((k) => k.isNotEmpty).toSet().toList();
    keys.sort((a, b) {
      // Sort by book then numeric chapter when possible.
      final aBook = a.replaceAll(RegExp(r'\s+\d+\b.*$'), '').trim();
      final bBook = b.replaceAll(RegExp(r'\s+\d+\b.*$'), '').trim();
      final bookCmp = aBook.toLowerCase().compareTo(bBook.toLowerCase());
      if (bookCmp != 0) return bookCmp;

      int? parseChapter(String v) {
        final m = RegExp(r'(\d+)\b').firstMatch(v);
        if (m == null) return null;
        return int.tryParse(m.group(1)!);
      }

      final aCh = parseChapter(a);
      final bCh = parseChapter(b);
      if (aCh != null && bCh != null) return aCh.compareTo(bCh);
      if (aCh != null) return -1;
      if (bCh != null) return 1;
      return a.toLowerCase().compareTo(b.toLowerCase());
    });
    return keys;
  }

  String generateId() => _uuid.v4();

  ScriptureReferenceMetadata _effectiveScriptureMetadata(JournalEntry entry) {
    // Prefer already-parsed fields on the model.
    final hasAny = (entry.bookName?.trim().isNotEmpty ?? false) || entry.chapter != null || entry.translation != null;
    if (hasAny) {
      return ScriptureReferenceMetadata(
        book: (entry.bookName?.trim().isEmpty ?? true) ? null : entry.bookName?.trim(),
        chapter: entry.chapter,
        verseStart: entry.verseStart,
        verseEnd: entry.verseEnd,
        translation: (entry.translation?.trim().isEmpty ?? true) ? null : entry.translation?.trim(),
      );
    }

    // Fall back to parsing the free-form string.
    return BibleService.parseReferenceMetadata(entry.scriptureReference);
  }

  Future<Map<String, dynamic>> _insertJournalEntryWithSchemaFallback(Map<String, dynamic> insertMap) async {
    if (_supabase == null) throw StateError('Supabase not initialized');
    try {
      return await _supabase!.from('journal_entries').insert(insertMap).select().single();
    } catch (e) {
      if (e is PostgrestException) {
        final msg = e.message.toLowerCase();
        final looksLikeMissingColumn = msg.contains('column') && (msg.contains('book') || msg.contains('chapter') || msg.contains('verse') || msg.contains('translation'));
        if (looksLikeMissingColumn) {
          debugPrint('Supabase schema is missing scripture metadata columns. Retrying insert without metadata. Error: ${e.message}');
          final stripped = Map<String, dynamic>.from(insertMap)
            ..remove('book')
            ..remove('chapter')
            ..remove('verse_start')
            ..remove('verse_end')
            ..remove('translation');
          return await _supabase!.from('journal_entries').insert(stripped).select().single();
        }
      }
      rethrow;
    }
  }

  Future<void> _updateJournalEntryWithSchemaFallback(String entryId, Map<String, dynamic> updateMap) async {
    if (_supabase == null) throw StateError('Supabase not initialized');
    try {
      await _supabase!.from('journal_entries').update(updateMap).eq('id', entryId);
    } catch (e) {
      if (e is PostgrestException) {
        final msg = e.message.toLowerCase();
        final looksLikeMissingColumn = msg.contains('column') && (msg.contains('book') || msg.contains('chapter') || msg.contains('verse') || msg.contains('translation'));
        if (looksLikeMissingColumn) {
          debugPrint('Supabase schema is missing scripture metadata columns. Retrying update without metadata. Error: ${e.message}');
          final stripped = Map<String, dynamic>.from(updateMap)
            ..remove('book')
            ..remove('chapter')
            ..remove('verse_start')
            ..remove('verse_end')
            ..remove('translation');
          await _supabase!.from('journal_entries').update(stripped).eq('id', entryId);
          return;
        }
      }
      rethrow;
    }
  }
}
