import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:faithful_journal/models/journal_entry.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EntryService extends ChangeNotifier {
  static const String _entriesKey = 'journal_entries';
  static const String _testingUserId = '00000000-0000-0000-0000-000000000000';
  final _uuid = const Uuid();
  List<JournalEntry> _entries = [];
  bool _isLoading = true;

  bool _useSupabase = false;
  SupabaseClient? _supabase;

  List<JournalEntry> get entries => List.unmodifiable(_entries);
  bool get isLoading => _isLoading;

  EntryService() {
    _loadEntries();
  }

  bool get isUsingSupabase => _useSupabase;

  String get currentUserId {
    final supabaseId = _supabase?.auth.currentUser?.id;
    // If Supabase is active but auth isn't configured, we fall back to a fixed
    // testing user id (and upsert a matching row in `public.users`) so FK constraints
    // don't block inserts.
    if (_useSupabase) {
      return (supabaseId != null && supabaseId.isNotEmpty) ? supabaseId : _testingUserId;
    }
    return (supabaseId != null && supabaseId.isNotEmpty) ? supabaseId : 'user_1';
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
      await _supabase!.auth.signInAnonymously();
    } catch (e) {
      // Don't silently fall back to local mode; we want to see and log the error.
      // Common cause: anonymous provider disabled in Supabase Auth settings.
      debugPrint(
        'Supabase sign-in failed (anonymous). Auth uid will be null; RLS may block inserts/selects until auth is configured. Error: $e',
      );
    }
  }

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
      final authedUserId = _supabase!.auth.currentUser?.id;
      dynamic query = _supabase!.from('journal_entries').select();

      // If we have an authenticated user, only load their rows.
      // If auth is not configured (uid == null), we fall back to loading all rows.
      // This is intended ONLY for temporary testing while you configure auth/RLS.
      if (authedUserId != null && authedUserId.isNotEmpty) {
        query = query.eq('user_id', authedUserId);
      } else {
        debugPrint(
          'EntryService: Supabase currentUser is null; loading journal_entries without user_id filter (temporary testing mode).',
        );
      }

      final rows = await query.order('created_at', ascending: false);
      _entries = (rows as List)
          .cast<Map<String, dynamic>>()
          .map(JournalEntry.fromJson)
          .toList();
    } catch (e) {
      debugPrint('Failed to load entries from Supabase: $e');
      _entries = [];
    }
  }

  Future<void> _ensureTestingUserExists() async {
    if (_supabase == null) return;
    try {
      final now = DateTime.now().toIso8601String();
      await _supabase!
          .from('users')
          .upsert({
            'id': _testingUserId,
            'name': 'Testing User',
            'email': 'testing@local',
            'created_at': now,
            'updated_at': now,
          })
          .select('id')
          .maybeSingle();
      debugPrint('EntryService: ensured testing user exists (id=$_testingUserId).');
    } catch (e) {
      if (e is PostgrestException) {
        debugPrint(
          'EntryService: failed to upsert testing user (PostgrestException): message=${e.message} code=${e.code} details=${e.details} hint=${e.hint}',
        );
      } else {
        debugPrint('EntryService: failed to upsert testing user: $e');
      }
      // Do not rethrow; entry insert will surface a clearer error if still blocked.
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
        await _ensureSignedIn();
        final authedUserId = _supabase!.auth.currentUser?.id;
        final effectiveUserId = (authedUserId != null && authedUserId.isNotEmpty) ? authedUserId : _testingUserId;
        if (authedUserId == null || authedUserId.isEmpty) {
          debugPrint(
            'createEntry(): auth.uid() is null. Using testing user_id=$effectiveUserId. '
            'Best fix: enable a real auth provider (Anonymous or Email) in Supabase Auth settings.',
          );
          await _ensureTestingUserExists();
        }

        final insertMap = <String, dynamic>{
          'id': entry.id,
          // In normal operation this is REQUIRED and must match auth.uid().
          // In testing mode (auth.uid() == null), we use a fixed testing user id.
          'user_id': effectiveUserId,
          'scripture_reference': entry.scriptureReference,
          'scripture_text': entry.scriptureText,
          'observation': entry.observation,
          'observation_structured': entry.observationStructured?.toJson(),
          'application': entry.application,
          'prayer': entry.prayer,
          'topic': entry.topic,
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
          final updateMap = {
            'scripture_reference': entry.scriptureReference,
            'scripture_text': entry.scriptureText,
            'observation': entry.observation,
            'observation_structured': entry.observationStructured?.toJson(),
            'application': entry.application,
            'prayer': entry.prayer,
            'topic': entry.topic,
            'updated_at': entry.updatedAt.toIso8601String(),
          };
          await _supabase!
              .from('journal_entries')
              .update(updateMap)
              .eq('id', entry.id);
          notifyListeners();
          return;
        } catch (e) {
          debugPrint('Supabase updateEntry failed, falling back to local: $e');
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
        await _supabase!.from('journal_entries').delete().eq('id', id);
        notifyListeners();
        return;
      } catch (e) {
        debugPrint('Supabase deleteEntry failed, falling back to local: $e');
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
    return _entries.take(limit).toList();
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
