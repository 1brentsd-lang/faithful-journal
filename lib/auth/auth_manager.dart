// Authentication Manager - Base interface for auth implementations
//
// This abstract class and mixins define the contract for authentication systems.
// Implement this with concrete classes for Firebase, Supabase, or local auth.
//
// Usage:
// 1. Create a concrete class extending AuthManager
// 2. Mix in the required authentication provider mixins
// 3. Implement all abstract methods with your auth provider logic

import 'package:flutter/material.dart';

/// Authentication Manager - base contract for auth implementations.
///
/// Note: This app already has a domain `User` model in `lib/models/user.dart`.
/// However, auth providers (like Supabase/Firebase) also have their own `User`
/// types. To avoid naming collisions, this interface keeps user references
/// provider-agnostic.

// Core authentication operations that all auth implementations must provide
abstract class AuthManager {
  Future signOut();
  Future deleteUser(BuildContext context);
  Future updateEmail({required String email, required BuildContext context});
  Future resetPassword({required String email, required BuildContext context});

  /// Returns a stable identifier for the currently authenticated user, or null
  /// if signed out.
  String? get currentUserId;
}

// Email/password authentication mixin
mixin EmailSignInManager on AuthManager {
  Future<String?> signInWithEmail(
    BuildContext context,
    String email,
    String password,
  );

  Future<String?> createAccountWithEmail(
    BuildContext context,
    String email,
    String password,
  );
}

// Anonymous authentication for guest users
mixin AnonymousSignInManager on AuthManager {
  Future<String?> signInAnonymously(BuildContext context);
}

// Apple Sign-In authentication (iOS/web)
mixin AppleSignInManager on AuthManager {
  Future<String?> signInWithApple(BuildContext context);
}

// Google Sign-In authentication (all platforms)
mixin GoogleSignInManager on AuthManager {
  Future<String?> signInWithGoogle(BuildContext context);
}

// JWT token authentication for custom backends
mixin JwtSignInManager on AuthManager {
  Future<String?> signInWithJwtToken(
    BuildContext context,
    String jwtToken,
  );
}

// Phone number authentication with SMS verification
mixin PhoneSignInManager on AuthManager {
  Future beginPhoneAuth({
    required BuildContext context,
    required String phoneNumber,
    required void Function(BuildContext) onCodeSent,
  });

  Future verifySmsCode({
    required BuildContext context,
    required String smsCode,
  });
}

// Facebook Sign-In authentication
mixin FacebookSignInManager on AuthManager {
  Future<String?> signInWithFacebook(BuildContext context);
}

// Microsoft Sign-In authentication (Azure AD)
mixin MicrosoftSignInManager on AuthManager {
  Future<String?> signInWithMicrosoft(
    BuildContext context,
    List<String> scopes,
    String tenantId,
  );
}

// GitHub Sign-In authentication (OAuth)
mixin GithubSignInManager on AuthManager {
  Future<String?> signInWithGithub(BuildContext context);
}
