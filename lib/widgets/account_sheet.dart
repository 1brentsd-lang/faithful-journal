import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:faithful_journal/auth/supabase_auth_manager.dart';
import 'package:faithful_journal/services/entry_service.dart';
import 'package:faithful_journal/theme.dart';
import 'package:faithful_journal/widgets/auth_required_sheet.dart';

/// Minimal account sheet:
/// - shows signed-in email (if any)
/// - lets the user sign in (email magic link)
/// - lets the user sign out
class AccountSheet extends StatefulWidget {
  const AccountSheet({super.key});

  @override
  State<AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends State<AccountSheet> {
  StreamSubscription<AuthState>? _authSub;
  User? _user;

  @override
  void initState() {
    super.initState();
    _user = Supabase.instance.client.auth.currentUser;
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      if (!mounted) return;
      setState(() => _user = Supabase.instance.client.auth.currentUser);
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _signOut() async {
    try {
      await context.read<SupabaseAuthManager>().signOut();
      if (!mounted) return;
      await context.read<EntryService>().refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signed out'), behavior: SnackBarBehavior.floating),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('AccountSheet: signOut failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not sign out. See Debug Console.'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _signIn() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AuthRequiredSheet(
        onAuthenticated: () {
          context.read<EntryService>().refresh();
        },
      ),
    );
    if (!mounted) return;
    if (ok == true) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final email = _user?.email;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Account', style: context.textStyles.titleLarge),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: cs.outline.withValues(alpha: 0.10)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_user == null ? Icons.lock_outline : Icons.verified_user, color: cs.onSurfaceVariant),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          _user == null ? 'Not signed in' : 'Signed in',
                          style: context.textStyles.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  if (_user != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      email ?? 'Email not available',
                      style: context.textStyles.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: _user == null
                        ? FilledButton.icon(
                            onPressed: _signIn,
                            icon: Icon(Icons.email, color: cs.onPrimary),
                            label: const Text('Sign in with email link'),
                          )
                        : OutlinedButton.icon(
                            onPressed: _signOut,
                            icon: const Icon(Icons.logout),
                            label: const Text('Sign out'),
                          ),
                  ),
                ],
              ),
            ),
            SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
          ],
        ),
      ),
    );
  }
}
