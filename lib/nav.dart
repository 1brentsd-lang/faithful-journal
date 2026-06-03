import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:faithful_journal/screens/home_screen.dart';
import 'package:faithful_journal/screens/new_entry_screen.dart';
import 'package:faithful_journal/screens/archive_screen.dart';
import 'package:faithful_journal/screens/entry_detail_screen.dart';
import 'package:faithful_journal/screens/weekly_review_screen.dart';
import 'package:faithful_journal/screens/questions_screen.dart';
import 'package:faithful_journal/screens/question_editor_screen.dart';
import 'package:faithful_journal/screens/auth_callback_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.home,
    redirect: (context, state) {
      // Some web reloads / cached tabs can preserve older URLs (e.g. /search, /search/).
      // Force anything under /search to the Questions experience.
      final p = state.uri.path;
      if (p == AppRoutes.search || p.startsWith('${AppRoutes.search}/')) return AppRoutes.questions;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.authCallback,
        name: 'auth-callback',
        pageBuilder: (context, state) => const NoTransitionPage(child: AuthCallbackScreen()),
      ),
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: HomePage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.newEntry,
        name: 'new-entry',
        pageBuilder: (context, state) => const MaterialPage(
          fullscreenDialog: true,
          child: NewEntryScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.editEntry,
        name: 'edit-entry',
        pageBuilder: (context, state) {
          final entryId = state.pathParameters['id']!;
          return MaterialPage(
            fullscreenDialog: true,
            child: NewEntryScreen(entryId: entryId),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.archive,
        name: 'archive',
        pageBuilder: (context, state) => const MaterialPage(
          child: ArchiveScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.entryDetail,
        name: 'entry-detail',
        pageBuilder: (context, state) {
          final entryId = state.pathParameters['id']!;
          return MaterialPage(
            child: EntryDetailScreen(entryId: entryId),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.search,
        name: 'search',
        // Legacy/deep-link compatibility: older builds used /search.
        // We now route that experience to Questions.
        redirect: (context, state) => AppRoutes.questions,
      ),
      GoRoute(
        path: AppRoutes.weeklyReview,
        name: 'weekly-review',
        pageBuilder: (context, state) => const MaterialPage(
          child: WeeklyReviewScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.questions,
        name: 'questions',
        pageBuilder: (context, state) => const MaterialPage(child: QuestionsScreen()),
      ),
      GoRoute(
        path: AppRoutes.newQuestion,
        name: 'new-question',
        pageBuilder: (context, state) => const MaterialPage(
          fullscreenDialog: true,
          child: QuestionEditorScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.editQuestion,
        name: 'edit-question',
        pageBuilder: (context, state) {
          final entryId = state.pathParameters['id']!;
          return MaterialPage(
            fullscreenDialog: true,
            child: QuestionEditorScreen(entryId: entryId),
          );
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
  static const String archive = '/archive';
  static const String entryDetail = '/entry/:id';
  static const String search = '/search';
  static const String weeklyReview = '/weekly-review';
  static const String questions = '/questions';
  static const String newQuestion = '/questions/new';
  static const String editQuestion = '/questions/edit/:id';
}
