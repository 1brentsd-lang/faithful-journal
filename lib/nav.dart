import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:faithful_journal/screens/home_screen.dart';
import 'package:faithful_journal/screens/new_entry_screen.dart';
import 'package:faithful_journal/screens/archive_screen.dart';
import 'package:faithful_journal/screens/entry_detail_screen.dart';
import 'package:faithful_journal/screens/search_screen.dart';
import 'package:faithful_journal/screens/weekly_review_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
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
        pageBuilder: (context, state) => const MaterialPage(
          child: SearchScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.weeklyReview,
        name: 'weekly-review',
        pageBuilder: (context, state) => const MaterialPage(
          child: WeeklyReviewScreen(),
        ),
      ),
    ],
  );
}

class AppRoutes {
  static const String home = '/';
  static const String newEntry = '/new-entry';
  static const String editEntry = '/edit-entry/:id';
  static const String archive = '/archive';
  static const String entryDetail = '/entry/:id';
  static const String search = '/search';
  static const String weeklyReview = '/weekly-review';
}
