import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:faithful_journal/screens/new_entry_screen.dart';
import 'package:faithful_journal/screens/archive_screen.dart';
import 'package:faithful_journal/screens/entry_detail_screen.dart';
import 'package:faithful_journal/screens/weekly_review_screen.dart';
import 'package:faithful_journal/screens/questions_screen.dart';
import 'package:faithful_journal/screens/question_editor_screen.dart';
import 'package:faithful_journal/screens/search_screen.dart';
import 'package:faithful_journal/screens/auth_callback_screen.dart';
import 'package:faithful_journal/widgets/app_shell.dart';

class _RouteParamMissingScreen extends StatelessWidget {
  final String message;

  const _RouteParamMissingScreen({required this.message});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Navigation Error')),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: () => context.go(AppRoutes.home), child: const Text('Go to Archive')),
          ],
        ),
      ),
    ),
  );
}

class AppRouter {
  static final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.home,
    redirect: (context, state) {
      // Legacy: older builds used /archive as the landing route.
      if (state.uri.path == AppRoutes.archiveLegacy) return AppRoutes.home;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.authCallback,
        name: 'auth-callback',
        pageBuilder: (context, state) => const NoTransitionPage(child: AuthCallbackScreen()),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                name: 'archive',
                pageBuilder: (context, state) => const NoTransitionPage(child: ArchiveScreen()),
              ),
            ],
          ),
          // IMPORTANT: Index mapping is the tab contract.
          // 0: Archive (Home), 1: New Entry, 2: Questions, 3: Search
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.newEntry,
                name: 'new-entry',
                pageBuilder: (context, state) => const NoTransitionPage(child: NewEntryScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.questions,
                name: 'questions',
                pageBuilder: (context, state) => const NoTransitionPage(child: QuestionsScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.search,
                name: 'search',
                pageBuilder: (context, state) => const NoTransitionPage(child: SearchScreen()),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.weeklyReview,
        name: 'weekly-review',
        pageBuilder: (context, state) => const MaterialPage(
          child: WeeklyReviewScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.newQuestion,
        name: 'new-question',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => const MaterialPage(
          fullscreenDialog: true,
          child: QuestionEditorScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.editQuestion,
        name: 'edit-question',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final entryId = state.pathParameters['id'];
          if (entryId == null || entryId.isEmpty) {
            return const MaterialPage(
              fullscreenDialog: true,
              child: _RouteParamMissingScreen(message: 'Missing question id.'),
            );
          }
          return MaterialPage(
            fullscreenDialog: true,
            child: QuestionEditorScreen(entryId: entryId),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.editEntry,
        name: 'edit-entry',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final entryId = state.pathParameters['id'];
          if (entryId == null || entryId.isEmpty) {
            return const MaterialPage(
              fullscreenDialog: true,
              child: _RouteParamMissingScreen(message: 'Missing entry id.'),
            );
          }
          return MaterialPage(
            fullscreenDialog: true,
            child: NewEntryScreen(entryId: entryId),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.entryDetail,
        name: 'entry-detail',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final entryId = state.pathParameters['id'];
          if (entryId == null || entryId.isEmpty) {
            return const MaterialPage(child: _RouteParamMissingScreen(message: 'Missing entry id.'));
          }
          return MaterialPage(child: EntryDetailScreen(entryId: entryId));
        },
      ),
      GoRoute(
        path: AppRoutes.savedEntry,
        name: 'saved-entry',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final entryId = state.pathParameters['id'];
          if (entryId == null || entryId.isEmpty) {
            return const MaterialPage(child: _RouteParamMissingScreen(message: 'Missing saved entry id.'));
          }
          return MaterialPage(child: EntryDetailScreen(entryId: entryId, isSavedView: true));
        },
      ),
    ],
  );
}

class AppRoutes {
  static const String home = '/';
  static const String authCallback = '/auth/callback';
  static const String newEntry = '/new-entry';
  static const String editEntry = '/edit-entry/:id';
  static const String archiveLegacy = '/archive';
  static const String entryDetail = '/entry/:id';
  static const String savedEntry = '/saved-entry/:id';
  static const String search = '/search';
  static const String weeklyReview = '/weekly-review';
  static const String questions = '/questions';
  static const String newQuestion = '/questions/new';
  static const String editQuestion = '/questions/edit/:id';
}
