import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:faithful_journal/services/unsaved_changes_service.dart';
import 'package:faithful_journal/widgets/discard_changes_dialog.dart';

/// Root tab shell for the app.
///
/// Important contract: destination index mapping must match the branch order in
/// `lib/nav.dart`.
///
/// 0: Archive (Home)
/// 1: New Entry
/// 2: Questions
/// 3: Search
class AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final unsaved = context.watch<UnsavedChangesService>();

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: scheme.outline.withValues(alpha: 0.12))),
        ),
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (index) async {
            if (index == navigationShell.currentIndex) {
              navigationShell.goBranch(index, initialLocation: true);
            } else {
              if (unsaved.hasUnsaved) {
                final discard = await showDiscardChangesDialog(context);
                if (!discard) return;
                unsaved.clearAny();
              }
              navigationShell.goBranch(index);
            }
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.library_books_outlined),
              selectedIcon: Icon(Icons.library_books),
              label: 'Archive',
            ),
            NavigationDestination(
              icon: Icon(Icons.add_circle_outline),
              selectedIcon: Icon(Icons.add_circle),
              label: 'New Entry',
            ),
            NavigationDestination(
              icon: Icon(Icons.help_outline),
              selectedIcon: Icon(Icons.help),
              label: 'Questions',
            ),
            NavigationDestination(
              icon: Icon(Icons.search_outlined),
              selectedIcon: Icon(Icons.search),
              label: 'Search',
            ),
          ],
        ),
      ),
    );
  }
}
