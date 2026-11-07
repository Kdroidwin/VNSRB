// ignore_for_file: use_build_context_synchronously

import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:go_transitions/go_transitions.dart' show GoTransitions;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vndb_lite/src/features/search/presentation/components/search_predefined.dart';
import 'package:vndb_lite/src/features/sort_filter/data/languages_data.dart';
import 'package:vndb_lite/src/features/sort_filter/data/platform_data.dart';
import 'package:vndb_lite/src/features/theme/theme_data_provider.dart';
import 'package:vndb_lite/src/routing/app_router.dart';
import 'package:vndb_lite/src/util/alt_provider_reader.dart';

import 'constants/_constants.dart';
import 'core/_core.dart';

class App extends ConsumerWidget {
  const App({super.key});

  static bool updateIsChecked = false;

  /// This is useful when facing with deep nested vndetail stack.
  static String currentRootRoute = "/";

  static String get currentRoute {
    final routeName =
        GoRouter.maybeOf(NavigationService.currentContext)?.state.name;
    if (routeName != null) return routeName;

    // Default
    return AppRoute.home.name;
  }

  static String get currentFullRoute {
    final fullRoute =
        GoRouter.maybeOf(
          NavigationService.currentContext,
        )?.state.matchedLocation;
    if (fullRoute != null) return fullRoute;

    // Default
    return "/";
  }

  static bool get isInMainTab =>
      isInHomeScreen ||
      isInSearchScreen ||
      isInCollectionScreen ||
      isInOthersScreen;
  static bool get isInHomeScreen => currentRoute.contains(AppRoute.home.name);
  static bool get isInSearchScreen =>
      currentRoute.contains(AppRoute.search.name);
  static bool get isInCollectionScreen =>
      currentRoute.contains(AppRoute.collection.name);
  static bool get isInOthersScreen =>
      currentRoute.contains(AppRoute.others.name);
  static bool get isInVnDetailScreen =>
      currentRoute.contains(AppRoute.vnDetail.name);

  static bool _isImageCached = false;

  /// Asynchronously cache image right before splash screen is closed.
  /// Requiring [BuildContext], so need to be in a widget.
  Future<void> _precacheImages(BuildContext ctx) async {
    if (_isImageCached) return;

    for (PredefinedHomeSearch image in PredefinedHomeSearch.values) {
      await precacheImage(AssetImage(image.path), ctx);
    }

    for (String key in LangData.DEFINED_CODES.keys) {
      final path = LangData.getFlagPath(key);
      await precacheImage(AssetImage(path), ctx);
    }

    for (String key in PlatfData.DEFINED_CODES.keys) {
      final path = PlatfData.getImgPath(key);
      await precacheImage(AssetImage(path), ctx);
    }

    _isImageCached = true;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goRouter = ref.watch(goRouterProvider);
    final theme = ref.watch(appThemeStateProvider);
    final japaneseUi = ref.watch(japaneseUiProvider);
    final amoledAccentHex = ref.watch(amoledAccentHexProvider);
    // Rebuild the routed widget tree when display titles are switched.
    ref.watch(japaneseTitlesProvider);

    // Force removal of splash screen after everything loads.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      FlutterNativeSplash.remove();
      // Do not keep the first usable frame behind the native splash while
      // optional artwork is decoded. Cached images still warm up afterward.
      _precacheImages(context);
    });

    // Assigning an emergency globally-shared state reader.
    ref_ = ref;

    final amoledAccent = _colorFromHex(amoledAccentHex) ?? theme.secondary;
    final accent = theme.isAmoled ? amoledAccent : theme.secondary;
    final baseColorScheme = ColorScheme.fromSeed(
      seedColor: theme.isAmoled ? amoledAccent : theme.seedColor,
      primary: theme.primary,
      secondary: accent,
      tertiary: theme.tertiary,
      brightness: theme.brightness,
    );
    final colorScheme =
        theme.isAmoled
            ? baseColorScheme.copyWith(surface: Colors.black)
            : baseColorScheme;

    return MaterialApp.router(
      title: AppInfo.TITLE,
      restorationScopeId: "app",
      onGenerateTitle: (context) => AppInfo.TITLE,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          sized: false,
          value: SystemUiOverlayStyle(
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
            systemNavigationBarIconBrightness:
                theme.brightness == Brightness.dark
                    ? Brightness.light
                    : Brightness.dark,
            systemNavigationBarContrastEnforced: false,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      //
      // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      //
      theme: ThemeData(
        useMaterial3: true,
        brightness: theme.brightness,
        colorScheme: colorScheme,
        dividerColor: colorScheme.secondary.withAlpha(150),
        scaffoldBackgroundColor: theme.isAmoled ? Colors.black : null,
        canvasColor: theme.isAmoled ? Colors.black : null,
        cardColor: theme.isAmoled ? Colors.black : null,
        dialogTheme:
            theme.isAmoled
                ? const DialogThemeData(backgroundColor: Colors.black)
                : null,
        appBarTheme:
            theme.isAmoled
                ? const AppBarTheme(backgroundColor: Colors.black)
                : null,
        dividerTheme: DividerThemeData(
          color: colorScheme.secondary.withAlpha(150),
        ),
        progressIndicatorTheme: ProgressIndicatorThemeData(
          color: colorScheme.secondary,
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: GoTransitions.fadeUpwards,
            TargetPlatform.iOS: GoTransitions.cupertino,
          },
        ),
        textTheme: TextTheme.primaryOf(context).apply(
          fontFamily: Default.FONT_FAMILY,
          bodyColor: theme.tertiary,
          displayColor: theme.tertiary,
        ),
      ),
      locale: japaneseUi ? const Locale('ja') : const Locale('en'),
      supportedLocales: const [Locale('en'), Locale('ja')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        physics: const BouncingScrollPhysics(),
      ),
      //
      // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      //
      routerConfig: goRouter,
      // routeInformationParser: goRouter.routeInformationParser,
      // routeInformationProvider: goRouter.routeInformationProvider,
      //
      // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      //
    );
  }

  Color? _colorFromHex(String value) {
    final normalized = value.trim().replaceFirst('#', '');
    if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(normalized)) return null;
    return Color(int.parse('FF$normalized', radix: 16));
  }
}
