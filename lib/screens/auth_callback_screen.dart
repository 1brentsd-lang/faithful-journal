import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Web auth callback page for Supabase email magic-links.
///
/// Supabase redirects to this route with auth params (commonly `?code=...`).
/// We exchange the code for a session, then send the user back home.
class AuthCallbackScreen extends StatefulWidget {
  const AuthCallbackScreen({super.key});

  @override
  State<AuthCallbackScreen> createState() => _AuthCallbackScreenState();
}

class _AuthCallbackScreenState extends State<AuthCallbackScreen> {
  bool _isWorking = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _completeSignIn();
  }

  Future<void> _completeSignIn() async {
    try {
      if (!kIsWeb) {
        setState(() {
          _isWorking = false;
          _error = 'This page is only used for the web build.';
        });
        return;
      }

      final uri = Uri.base;
      final code = uri.queryParameters['code'];
      final errorDescription = uri.queryParameters['error_description'];
      if (errorDescription != null && errorDescription.trim().isNotEmpty) {
        throw Exception(errorDescription);
      }
      if (code == null || code.isEmpty) {
        throw Exception('Missing sign-in code in callback URL.');
      }

      await Supabase.instance.client.auth.exchangeCodeForSession(code);

      if (!mounted) return;
      setState(() => _isWorking = false);

      // Return to the main app experience.
      context.go('/');
    } catch (e) {
      debugPrint('AuthCallbackScreen failed: $e');
      if (!mounted) return;
      setState(() {
        _isWorking = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, color: cs.primary, size: 32),
              const SizedBox(height: 12),
              Text(
                _error == null ? 'Signing you in…' : 'Could not sign you in',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _error == null
                    ? 'You can close this tab if it doesn\'t redirect automatically.'
                    : _error!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (_isWorking) const CircularProgressIndicator(),
              if (!_isWorking)
                FilledButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Back to journal'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
