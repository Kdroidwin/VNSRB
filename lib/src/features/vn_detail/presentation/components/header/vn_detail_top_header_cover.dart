import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vndb_lite/src/app.dart';
import 'package:vndb_lite/src/common_widgets/generic_image_error.dart';
import 'package:vndb_lite/src/common_widgets/status_label.dart';
import 'package:vndb_lite/src/routing/app_router.dart';
import 'package:vndb_lite/src/util/responsive.dart';
import 'package:vndb_lite/src/features/settings/presentation/settings_general_state.dart';
import 'package:vndb_lite/src/features/vn/domain/p1.dart';
import 'package:vndb_lite/src/features/vn/domain/p2.dart';
import 'package:vndb_lite/src/features/vn_item/presentation/detail_non_summary/vn_record_state.dart';
import 'package:vndb_lite/src/util/custom_cache_manager.dart';
import 'package:vndb_lite/src/util/context_shortcut.dart';
import 'package:vndb_lite/src/common_widgets/widget_zoom/widget_zoom.dart';

class VnDetailTopHeaderCover extends ConsumerStatefulWidget {
  const VnDetailTopHeaderCover({
    super.key,
    required this.p1,
    required this.p2,
    required this.animationController,
  });

  final VnDataPhase01 p1;
  final VnDataPhase02 p2;
  final AnimationController animationController;

  @override
  ConsumerState<VnDetailTopHeaderCover> createState() =>
      _VnDetailTopHeaderCoverState();
}

class _VnDetailTopHeaderCoverState
    extends ConsumerState<VnDetailTopHeaderCover> {
  // bool _imageCached = false;
  bool _censorCover = false;

  @override
  void initState() {
    super.initState();
    _censorCover = _coverNeedCensor;

    // Checks whether vn image already cached or not.
    // didMediaCache(widget.p1.id).then((value) {
    //   _imageCached = value;
    // });
  }

  @override
  void dispose() {
    super.dispose();
  }

  //
  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  //

  bool get _vnHasCover {
    final image = widget.p1.image;
    return image != null &&
        ((image.url?.isNotEmpty ?? false) ||
            (image.thumbnail?.isNotEmpty ?? false));
  }

  bool get _coverNeedCensor {
    final settings = ref.read(settingsGeneralStateProvider);

    if (settings.showCoverCensor) {
      if (_vnMatchCensorRequirement) return true;
    }

    return false;
  }

  bool get _vnMatchCensorRequirement {
    return (widget.p1.image!.sexual ?? 0) >= 1 ||
        (widget.p1.image!.violence ?? 0) >= 1;
  }

  //
  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  //

  Widget _imgCover({required bool isCensor}) {
    final isNotSearch = !App.currentRootRoute.contains(AppRoute.search.name);
    final imageUrl =
        (widget.p1.image?.url?.isNotEmpty ?? false)
            ? widget.p1.image!.url!
            : widget.p1.image?.thumbnail ?? '';
    final image = CachedNetworkImage(
      imageUrl: (_vnHasCover) ? imageUrl : '',
      fit: BoxFit.cover,
      height: responsiveUI.own(0.6),
      filterQuality: FilterQuality.high,
      placeholder:
          (context, str) => SizedBox(
            width: responsiveUI.own(0.4),
            height: responsiveUI.own(0.45),
          ),
      errorWidget: (context, url, error) => const GenericErrorImage(),
      cacheKey:
          (isCensor)
              // * Using the same cache key as that of VnItemGrid's censor key.
              ? "CENSORED-PREVIEW-${widget.p1.id}"
              : 'DETAIL-${widget.p1.id}-${imageUrl.hashCode}',
      cacheManager: (isNotSearch) ? CustomCacheManager() : null,
      maxHeightDiskCache: 1600,
      maxWidthDiskCache: 1200,
    );

    if (!isCensor) return image;
    return ImageFiltered(
      imageFilter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: image,
    );
  }

  //
  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  //

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(right: responsiveUI.own(0.045)),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.45,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ScaleTransition(
          scale: widget.animationController.drive(
            CurveTween(curve: Curves.ease),
          ),
          child: FadeTransition(
            opacity: widget.animationController.drive(
              CurveTween(curve: Curves.linear),
            ),
            child: Stack(
              children: [
                //
                // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                // Cover
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Card(
                    elevation: 10,
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.hardEdge,
                    color: const Color.fromARGB(120, 0, 0, 0),
                    shadowColor: kColor(context).primary.withOpacity(0.8),
                    child: Consumer(
                      builder: (context, ref, child) {
                        return GestureDetector(
                          onDoubleTap: () {
                            setState(() {
                              _censorCover = !_censorCover;
                            });
                          },
                          child: Stack(
                            children: [
                              WidgetZoom(
                                heroAnimationTag: widget.p1.id,
                                zoomWidget: Center(
                                  child: _imgCover(isCensor: _censorCover),
                                ),
                              ),
                              if (_censorCover)
                                Positioned.fill(
                                  child: Material(
                                    color: Colors.black26,
                                    child: InkWell(
                                      onTap:
                                          () => setState(
                                            () => _censorCover = false,
                                          ),
                                      child: Center(
                                        child: Icon(
                                          Icons.visibility,
                                          color: Colors.white,
                                          size: responsiveUI.own(0.09),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                //
                // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                // Status label
                Consumer(
                  builder: (context, ref, child) {
                    final record = ref.watch(
                      vnRecordStateProvider(widget.p1.id),
                    );
                    String status = "";

                    // If vn exists in collection, then show the status label.
                    if (record != null) status = record.status;
                    return StatusLabel(labelCode: status);
                  },
                ),
                //
                // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                //
              ],
            ),
          ),
        ),
      ),
    );
  }
}
