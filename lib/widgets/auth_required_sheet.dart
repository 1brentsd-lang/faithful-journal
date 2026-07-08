import 'package:flutter/material.dart';
import 'dart:async';
import 'package:faithful_journal/auth/supabase_auth_manager.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Bottom sheet that helps the user create an auth session when Supabase RLS
/// requires a real `auth.uid()`.
class AuthRequiredSheet extends StatefulWidget {
  const AuthRequiredSheet({super.key, required this.onAuthenticated});

  final VoidCallback onAuthenticated;

  @override
  State<AuthRequiredSheet> createState() => _AuthRequiredSheetState();
}

class _AuthRequiredSheetState extends State<AuthRequiredSheet> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  bool _isSending = false;
  bool _isVerifying = false;
  bool _isSignedIn = false;
  bool _awaitingCode = false;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _isSignedIn = Supabase.instance.client.auth.currentUser != null;
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      if (!mounted) return;
      final signedIn = Supabase.instance.client.auth.currentUser != null;
      setState(() => _isSignedIn = signedIn);
      if (signedIn) {
        // Friction-light: once the session exists, automatically continue.
        widget.onAuthenticated();
        // Return `true` so callers can resume the intended action.
        context.pop(true);
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid email address.'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    setState(() => _isSending = true);
    try {
      await context.read<SupabaseAuthManager>().sendEmailOtp(email: email);
      if (!mounted) return;
      setState(() => _awaitingCode = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Check your email for a one-time code.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final message = _friendlyAuthError(e, when: 'sending');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _verifyCode() async {
    final email = _emailController.text.trim();
    final token = _codeController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid email address.'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    if (token.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the 6-digit code.'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    setState(() => _isVerifying = true);
    try {
      await context.read<SupabaseAuthManager>().verifyEmailOtp(email: email, token: token);
    } catch (e) {
      if (!mounted) return;
      final message = _friendlyAuthError(e, when: 'verifying');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  String _friendlyAuthError(Object error, {required String when}) {
    if (error is AuthException) {
      final status = '${error.statusCode}'.toLowerCase();
      final msgLower = error.message.toLowerCase();
      if (status == '429' || msgLower.contains('rate limit') || msgLower.contains('rate_limit') || msgLower.contains('over_email_send_rate_limit')) {
        return 'Too many attempts. Please wait a minute and try again.';
      }
      if (msgLower.contains('invalid') || msgLower.contains('otp')) return when == 'verifying' ? 'That code didn\'t work. Double-check it and try again.' : error.message;
      final msg = error.message.trim();
      if (msg.isNotEmpty) return msg;
    }
    return when == 'sending' ? 'Could not send code. Please try again shortly.' : 'Could not verify code. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Private journal', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              'To keep entries private, saving requires a signed-in session.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'you@example.com',
              ),
            ),
            if (_awaitingCode) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'One-time code',
                  hintText: '6-digit code',
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _isSending ? null : _sendOtp,
                    child: Text(_isSending ? 'Sending…' : 'Email me a code'),
                  ),
                ),
              ],
            ),
            if (_awaitingCode) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isVerifying ? null : _verifyCode,
                  child: Text(_isVerifying ? 'Verifying…' : 'Verify code'),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: !_isSignedIn
                        ? null
                        : () {
                            widget.onAuthenticated();
                            context.pop(true);
                          },
                    child: Text(_isSignedIn ? "Continue" : "Waiting for sign-in…"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
