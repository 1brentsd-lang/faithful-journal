import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:faithful_journal/auth/auth_manager.dart';
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

  /// Email OTP sign-in.
  ///
  /// Supabase can send an email that contains both:
  /// - a one-time code the user can type in
  /// - (optionally) a magic link
  ///
  /// On iOS/Safari, relying on Apple Mail opening a deep link can be flaky.
  /// The code-based flow is the most reliable cross-app experience.
  Future<void> sendEmailOtp({required String email}) async {
    try {
      // Use an explicit callback route so the app can reliably complete the
      // code → session exchange on web.
      final redirectTo = kIsWeb ? Uri.base.replace(path: '/auth/callback', queryParameters: {}).toString() : null;
      await _client.auth.signInWithOtp(
        email: email,
        // On web, Supabase appends `?code=...` (PKCE) and/or other auth params.
        // We handle this in AuthCallbackScreen.
        emailRedirectTo: redirectTo,
        shouldCreateUser: true,
      );
    } catch (e) {
      debugPrint('Supabase sendEmailOtp failed: $e');
      rethrow;
    }
  }

  Future<void> verifyEmailOtp({required String email, required String token}) async {
    try {
      await _client.auth.verifyOTP(email: email, token: token, type: OtpType.email);
    } catch (e) {
      debugPrint('Supabase verifyEmailOtp failed: $e');
      rethrow;
    }
  }

  /// Backwards-compatible alias.
  @Deprecated('Use sendEmailOtp + verifyEmailOtp for the most reliable flow.')
  Future<void> sendMagicLink({required String email}) => sendEmailOtp(email: email);

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
