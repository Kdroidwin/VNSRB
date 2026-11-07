import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:go_router/go_router.dart';
import 'package:vndb_lite/src/core/app/navigation.dart';
import 'package:vndb_lite/src/core/local_db/shared_prefs.dart';
import 'package:vndb_lite/src/constants/local_db_constants.dart';
import 'package:vndb_lite/src/features/_base/presentation/main_outer_layout.dart';
import 'package:vndb_lite/src/features/about/presentation/about_screen.dart';
import 'package:vndb_lite/src/features/collection/presentation/collection_screen.dart';
import 'package:vndb_lite/src/features/home/presentation/home_screen.dart';
import 'package:vndb_lite/src/features/others/presentation/others_screen.dart';
import 'package:vndb_lite/src/features/search/presentation/search_screen.dart';
import 'package:vndb_lite/src/features/settings/presentation/settings_screen.dart';
import 'package:vndb_lite/src/features/sync/presentation/auth_screen.dart';
import 'package:vndb_lite/src/features/vn/domain/p1.dart';
import 'package:vndb_lite/src/features/vn_detail/presentation/vn_detail_screen.dart';
import 'package:vndb_lite/src/routing/not_found_screen.dart';

part 'app_router.g.dart';

enum AppRoute {
  home,
  search,
  collection,
  others,
  vnDetail,
  auth,
  settings,
  about,
  unknown;

  const AppRoute();

  // By default is absolute, starting with "/".
  String get path => "/$name";
  String get relPath => name;
}

@Riverpod(keepAlive: true, dependencies: [sharedPref])
GoRouter goRouter(Ref ref) {
  const validTabs = {'home', 'search', 'collection', 'others'};
  final startupTab = ref.read(sharedPrefProvider).getString(DBKeys.STARTUP_TAB);
  final initialLocation =
      validTabs.contains(startupTab)
          ? (startupTab == 'home' ? '/' : '/$startupTab')
          : '/';

  return GoRouter(
    initialLocation: initialLocation,
    debugLogDiagnostics: !kReleaseMode,
    navigatorKey: NavigationService.navigatorKey,
    redirect: null,
    routes: [
      StatefulShellRoute.indexedStack(
        builder:
            (_, state, navigationShell) =>
                MainOuterLayout(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            navigatorKey: GlobalKey<NavigatorState>(
              debugLabel: AppRoute.home.name,
            ),
            routes: [
              GoRoute(
                path: '/',
                name: AppRoute.home.name,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: GlobalKey<NavigatorState>(
              debugLabel: AppRoute.search.name,
            ),
            routes: [
              GoRoute(
                path: AppRoute.search.path,
                name: AppRoute.search.name,
                builder: (context, state) => const SearchScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: GlobalKey<NavigatorState>(
              debugLabel: AppRoute.collection.name,
            ),
            routes: [
              GoRoute(
                path: AppRoute.collection.path,
                name: AppRoute.collection.name,
                builder: (context, state) {
                  return const CollectionScreen();
                },
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: GlobalKey<NavigatorState>(
              debugLabel: AppRoute.others.name,
            ),
            routes: [
              GoRoute(
                path: AppRoute.others.path,
                name: AppRoute.others.name,
                builder: (context, state) {
                  return const OthersScreen();
                },
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/:parent/vnDetail/:vnId',
        name: AppRoute.vnDetail.name,
        pageBuilder: (context, state) {
          final p1 = state.extra as VnDataPhase01;
          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: VnDetailScreen(p1: p1),
            transitionDuration: const Duration(milliseconds: 180),
            reverseTransitionDuration: const Duration(milliseconds: 160),
            transitionsBuilder: (
              context,
              animation,
              secondaryAnimation,
              child,
            ) {
              final easedAnimation = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              );
              return FadeTransition(
                opacity: easedAnimation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.025),
                    end: Offset.zero,
                  ).animate(easedAnimation),
                  child: child,
                ),
              );
            },
          );
        },
      ),
      GoRoute(
        path: AppRoute.auth.path,
        name: AppRoute.auth.name,
        builder: (context, state) {
          return const AuthenticationScreen();
        },
      ),
      GoRoute(
        path: AppRoute.settings.path,
        name: AppRoute.settings.name,
        builder: (context, state) {
          return const SettingsScreen();
        },
      ),
      GoRoute(
        path: AppRoute.about.path,
        name: AppRoute.about.name,
        builder: (context, state) {
          return const AboutScreen();
        },
      ),
    ],
    errorBuilder: (context, state) => const NotFoundScreen(),
  );
}
