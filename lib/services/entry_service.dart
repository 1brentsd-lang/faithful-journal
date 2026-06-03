import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:faithful_journal/models/journal_entry.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum QuestionFilter { all, stillWrestling, developingUnderstanding }

class EntryService extends ChangeNotifier {
  static const String _entriesKey = 'journal_entries';
  /// Temporary testing-mode owner id when no Supabase session exists.
  ///
  /// This keeps the existing schema intact (`user_id` is NOT NULL), while
  /// allowing public/anonymous CRUD during live testing.
  static const String publicTestUserId = '00000000-0000-0000-0000-000000000001';

  final _uuid = const Uuid();
  List<JournalEntry> _entries = [];
  bool _isLoading = true;

  bool _useSupabase = false;
  SupabaseClient? _supabase;
  bool _anonAuthUnavailable = false;

  List<JournalEntry> get entries => List.unmodifiable(_entries);
  bool get isLoading => _isLoading;

  EntryService() {
    _loadEntries();
  }

  bool get isUsingSupabase => _useSupabase;

  /// Returns a stable identifier for the current user.
  ///
  /// - When using Supabase, this prefers the authenticated user id if present.
  /// - During the current testing phase (no auth required), this falls back to
  ///   [publicTestUserId] so DB inserts still satisfy the NOT NULL `user_id`.
  /// - When running locally (no Supabase), this falls back to a stable local id.
  String get currentUserId {
    if (_useSupabase) {
      final id = _supabase?.auth.currentUser?.id;
      if (id != null && id.isNotEmpty) return id;
      return publicTestUserId;
    }
    return 'user_1';
  }

  String? get supabaseUserId => _supabase?.auth.currentUser?.id;

  Future<void> _loadEntries() async {
    try {
      _supabase = _tryGetSupabaseClient();
      if (_supabase != null) {
        _useSupabase = true;
        await _ensureSignedIn();
        await _loadEntriesFromSupabase();
      } else {
        _useSupabase = false;
        await _loadEntriesFromLocal();
      }
    } catch (e) {
      debugPrint('Failed to load entries: $e');
      await _loadEntriesFromLocal();
    } finally {
      _isLoading = false;
      notifyListeners();
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

  Future<void> _ensureSignedIn() async {
    if (_supabase == null) return;
    try {
      if (_supabase!.auth.currentUser != null) return;
      if (_anonAuthUnavailable) return;
      await _supabase!.auth.signInAnonymously();
    } catch (e) {
      // If anonymous auth is disabled, remember it so we don't repeatedly hit auth.
      final msg = e.toString();
      if (msg.contains('anonymous_provider_disabled') || msg.contains('Anonymous sign-ins are disabled')) {
        _anonAuthUnavailable = true;
      }
      debugPrint(
        'Supabase sign-in failed (anonymous). User must authenticate before reading/writing journal entries. Error: $e',
      );
    }
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
    await _ensureSignedIn();
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
    if (_useSupabase && _supabase != null) {
      try {
        debugPrint('createEntry(): Save triggered. useSupabase=$_useSupabase');
        // Testing mode: auth is optional. We still attempt anonymous sign-in
        // (when enabled), but we do not require it.
        await _ensureSignedIn();
        final ownerId = _supabase!.auth.currentUser?.id ?? publicTestUserId;

        final s = entry.observationStructured;
        final insertMap = <String, dynamic>{
          'id': entry.id,
          'user_id': ownerId,
          'entry_type': entry.entryType == JournalEntryType.question ? 'question' : 'soap',
          'highlighted': entry.highlighted,
          'scripture_reference': entry.scriptureReference,
          'scripture_text': entry.scriptureText,
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
        final row = await _supabase!
            .from('journal_entries')
            .insert(insertMap)
            .select()
            .single();
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
    final index = _entries.indexWhere((e) => e.id == entry.id);
    if (index != -1) {
      _entries[index] = entry;
      if (_useSupabase && _supabase != null) {
        try {
          await _ensureSignedIn();
          final s = entry.observationStructured;
          final updateMap = {
              'entry_type': entry.entryType == JournalEntryType.question ? 'question' : 'soap',
              'highlighted': entry.highlighted,
            'scripture_reference': entry.scriptureReference,
            'scripture_text': entry.scriptureText,
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
          await _supabase!
              .from('journal_entries')
              .update(updateMap)
              .eq('id', entry.id);
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
    _entries.removeWhere((e) => e.id == id);
    if (_useSupabase && _supabase != null) {
      try {
        await _ensureSignedIn();
        await _supabase!.from('journal_entries').delete().eq('id', id);
        notifyListeners();
        return;
      } catch (e) {
        debugPrint('Supabase deleteEntry failed: $e');
        rethrow;
      }
    }
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

  List<String> getAllTopics() {
    final topics = _entries.map((e) => e.topic).toSet().toList();
    topics.sort();
    return topics;
  }

  List<String> getAllBooks() {
    final books = _entries.map((e) => e.book).toSet().toList();
    books.sort();
    return books;
  }

  String generateId() => _uuid.v4();
}
