import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vndb_lite/src/app.dart';
import 'package:vndb_lite/src/common_widgets/generic_background.dart';
import 'package:vndb_lite/src/common_widgets/generic_image_error.dart';
import 'package:vndb_lite/src/routing/app_router.dart';
import 'package:vndb_lite/src/util/responsive.dart';
import 'package:vndb_lite/src/features/collection_selection/application/collection_selection_remote_service.dart';
import 'package:vndb_lite/src/features/collection_selection/presentation/fab/vn_detail_fab.dart';
import 'package:vndb_lite/src/features/collection_selection/presentation/fab/vn_detail_fab_state.dart';
import 'package:vndb_lite/src/features/settings/presentation/settings_general_state.dart';
import 'package:vndb_lite/src/features/vn/data/local_vn_repo.dart';
import 'package:vndb_lite/src/features/vn/data/remote_vn_repo.dart';
import 'package:vndb_lite/src/features/vn/domain/p1.dart';
import 'package:vndb_lite/src/features/vn_detail/presentation/components/vn_detail_appbar.dart';
import 'package:vndb_lite/src/features/vn_detail/presentation/vn_detail_entrance.dart';
import 'package:vndb_lite/src/util/context_shortcut.dart';
import 'package:vndb_lite/src/util/custom_cache_manager.dart';

class VnDetailScreen extends ConsumerStatefulWidget {
  const VnDetailScreen({super.key, required this.p1});

  final VnDataPhase01 p1;

  @override
  ConsumerState<VnDetailScreen> createState() {
    return _VnDetailScreenState();
  }
}

class _VnDetailScreenState extends ConsumerState<VnDetailScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final String _vnId;
  late VnDataPhase01 _p1;

  @override
  void initState() {
    super.initState();
    _vnId = widget.p1.id;
    _p1 = widget.p1;

    // Animation for background image.
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 220),
      vsync: this,
    )..forward();
    _refreshMissingCover();
  }

  bool _hasUsableCover(VnDataPhase01 data) {
    final image = data.image;
    return image != null &&
        ((image.thumbnail?.isNotEmpty ?? false) ||
            (image.url?.isNotEmpty ?? false));
  }

  Future<void> _refreshMissingCover() async {
    if (_hasUsableCover(_p1)) return;
    try {
      final localRepo = ref.read(localVnRepoProvider);
      final cachedP1 = await localRepo.getP1(_vnId);
      if (cachedP1 != null && _hasUsableCover(cachedP1)) {
        if (mounted) setState(() => _p1 = cachedP1);
        return;
      }

      final response = await ref.read(remoteVnRepoProvider).fetchP1Data(_vnId);
      final dynamic results = response.data['results'];
      if (results is! List || results.isEmpty || results.first is! Map) return;

      final refreshedP1 = VnDataPhase01.fromMap(
        Map<String, dynamic>.from(results.first as Map),
      );
      if (!_hasUsableCover(refreshedP1)) return;
      await localRepo.saveVnContent(refreshedP1);
      if (mounted) setState(() => _p1 = refreshedP1);
    } catch (_) {
      // Keep the detail content accessible if the image refresh is offline.
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  //
  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  //
  // TODO remove this all in controller?
  bool get _vnHasCover {
    return _hasUsableCover(_p1);
  }

  bool get _coverNeedCensor {
    if (!_vnHasCover) return false;

    final settings = ref.read(settingsGeneralStateProvider);

    if (settings.showCoverCensor) {
      if (_vnMatchCensorRequirement) return true;
    }

    return false;
  }

  bool get _vnMatchCensorRequirement {
    return (_p1.image!.sexual ?? 0) >= 1 || (_p1.image!.violence ?? 0) >= 1;
  }

  //
  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  //

  Future<void> _onRefresh() async {
    if (!mounted) return;
    final localVnRepo = ref.read(localVnRepoProvider);

    // This removes all corresponded vn detail data, to be redownloaded.
    await localVnRepo.removeVnContent(phase: 2, vnId: _vnId);
    await localVnRepo.removeVnContent(phase: 3, vnId: _vnId);
    await localVnRepo.refresh();

    // Set providers back to its default state.
    ref.invalidate(vnDetailFabStateProvider(widget.p1.id));
    ref.invalidate(fetchAndSaveP2DataProvider(widget.p1.id));
    ref.invalidate(getP2Provider(widget.p1.id));
    ref.invalidate(localVnRepoProvider);
    await _refreshMissingCover();
  }

  //
  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  //

  Widget _imgCover({required bool isCensor}) {
    final isNotSearch = !App.currentRootRoute.contains(AppRoute.search.name);
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: CachedNetworkImage(
        imageUrl:
            (_p1.image?.thumbnail?.isNotEmpty ?? false)
                ? _p1.image!.thumbnail!
                : (_p1.image?.url ?? ''),
        fit: BoxFit.cover,
        width: MediaQuery.sizeOf(context).width,
        placeholder:
            (context, str) => SizedBox(
              width: responsiveUI.own(0.25),
              height: responsiveUI.own(0.4),
            ),
        errorWidget: (context, url, error) => const GenericErrorImage(),
        cacheKey: "BG-${_p1.id}",
        cacheManager: (isNotSearch) ? CustomCacheManager() : null,
        // High quality to make the pixels smooth when censor mode is on.
        filterQuality: (isCensor) ? FilterQuality.high : FilterQuality.medium,
        maxHeightDiskCache: (isCensor) ? 35 : 1400,
        maxWidthDiskCache: (isCensor) ? 35 : 1400,
      ),
    );
  }

  //
  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  //

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Scaffold(
        extendBody: true,
        extendBodyBehindAppBar: true,
        backgroundColor: kColor(context).primary.withOpacity(0.3),
        body: Stack(
          children: [
            GenericBackground(
              useGradientOverlay: true,
              imageWidget: FadeTransition(
                opacity: _animationController.drive(
                  CurveTween(curve: Curves.ease),
                ),
                child: ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (rect) {
                    return const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color.fromARGB(140, 0, 0, 0),
                        Color.fromARGB(70, 0, 0, 0),
                        Colors.transparent,
                      ],
                    ).createShader(
                      Rect.fromLTRB(0, 0, rect.width, rect.height),
                    );
                  },
                  child: _imgCover(isCensor: _coverNeedCensor),
                ),
              ),
            ),
            NestedScrollView(
              headerSliverBuilder: (_, bool inBoxScrolled) {
                return [VnDetailAppBar(p1: _p1)];
              },
              //
              // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
              // Double scaffold to prevent snackbar ui conflicting with floating action button
              body: Scaffold(
                backgroundColor: Colors.transparent,
                floatingActionButton: VnDetailFab(p1: _p1),
                body: RefreshIndicator(
                  onRefresh: _onRefresh,
                  color: kColor(context).tertiary,
                  backgroundColor: kColor(context).primary.withOpacity(0.75),
                  displacement: responsiveUI.own(0.02),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      top: responsiveUI.own(0.03),
                      bottom: responsiveUI.own(0.24),
                    ),
                    child: VnDetailsEntrance(p1: _p1),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
