import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '/auth/auth_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAuthManager extends AuthManager with AnonymousSignInManager {
  SupabaseAuthManager({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  String? get currentUserId => _client.auth.currentUser?.id;

  @override
  Future<String?> signInAnonymously(BuildContext context) async {
    try {
      if (_client.auth.currentUser != null) return _client.auth.currentUser!.id;
      final res = await _client.auth.signInAnonymously();
      return res.user?.id;
    } catch (e) {
      debugPrint('Supabase anonymous sign-in failed: $e');
      return null;
    }
  }

  @override
  Future signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      debugPrint('Supabase signOut failed: $e');
      rethrow;
    }
  }

  @override
  Future deleteUser(BuildContext context) async {
    // Deleting a Supabase auth user requires service role key (server-side).
    debugPrint('deleteUser is not supported client-side for Supabase.');
    throw UnsupportedError('deleteUser must be performed server-side.');
  }

  @override
  Future updateEmail({required String email, required BuildContext context}) async {
    try {
      await _client.auth.updateUser(UserAttributes(email: email));
    } catch (e) {
      debugPrint('Supabase updateEmail failed: $e');
      rethrow;
    }
  }

  @override
  Future resetPassword({required String email, required BuildContext context}) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
    } catch (e) {
      debugPrint('Supabase resetPassword failed: $e');
      rethrow;
    }
  }
}
