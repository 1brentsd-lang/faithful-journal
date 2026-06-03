import 'package:flutter/material.dart';
import 'package:faithful_journal/auth/supabase_auth_manager.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

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
  bool _isSending = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendMagicLink() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid email address.'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    setState(() => _isSending = true);
    try {
      await context.read<SupabaseAuthManager>().sendMagicLink(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Check your email for a sign-in link.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not send sign-in link. See Debug Console.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
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
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _isSending ? null : _sendMagicLink,
                    child: Text(_isSending ? 'Sending…' : 'Email me a sign-in link'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      widget.onAuthenticated();
                      context.pop();
                    },
                    child: const Text("I'm signed in now"),
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
