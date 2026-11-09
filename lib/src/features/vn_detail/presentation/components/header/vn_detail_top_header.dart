import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vndb_lite/src/common_widgets/generic_shadowy_text.dart';
import 'package:vndb_lite/src/util/responsive.dart';
import 'package:vndb_lite/src/features/sort_filter/data/devstatus_data.dart';
import 'package:vndb_lite/src/features/vn/domain/p1.dart';
import 'package:vndb_lite/src/features/vn/domain/p2.dart';
import 'package:vndb_lite/src/features/vn/domain/developer_name_override_provider.dart';
import 'package:vndb_lite/src/features/vn_detail/presentation/components/header/vn_detail_top_header_cover.dart';
import 'package:vndb_lite/src/util/context_shortcut.dart';

class VnDetailsTopHeader extends ConsumerWidget {
  const VnDetailsTopHeader({
    super.key,
    required this.p1,
    required this.p2,
    required this.animationController,
  });

  final VnDataPhase01 p1;
  final VnDataPhase02 p2;
  final AnimationController animationController;

  //
  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  //

  String _developersName(BuildContext context, String? override) {
    if (override?.trim().isNotEmpty == true) return override!.trim();
    final List<String> result = p2.developers ?? [];

    if (result.isEmpty) {
      return 'Unknown';
    }
    if (Localizations.localeOf(context).languageCode != 'ja') {
      return result.join(' & ');
    }
    final originalNames = p2.developerOriginals;
    if (originalNames == null || originalNames.isEmpty) {
      return result.join(' & ');
    }
    return [
      for (var index = 0; index < result.length; index++)
        if (index < originalNames.length && originalNames[index].isNotEmpty)
          originalNames[index]
        else
          result[index],
    ].join(' & ');
  }

  //
  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  //

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final developerOverride = ref.watch(developerNameOverrideProvider)[p1.id];
    return Row(
      children: [
        VnDetailTopHeaderCover(
          p1: p1,
          p2: p2,
          animationController: animationController,
        ),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              //
              // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
              // Title
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).width * 0.3,
                ),
                child: SingleChildScrollView(
                  child: Text(
                    p1.displayTitle,
                    style: TextStyle(
                      fontSize: responsiveUI.own(0.05),
                      fontWeight: FontWeight.bold,
                      color: kColor(context).tertiary,
                      // shadows: [Shadow(color: kColor(context).secondary, blurRadius: 3)],
                    ),
                  ),
                ),
              ),
              //
              // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
              // Dev names
              SizedBox(height: responsiveUI.own(0.01)),
              ShadowText(_developersName(context, developerOverride)),
              //
              // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
              // Development status indicator
              Wrap(
                alignment: WrapAlignment.start,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Padding(
                    padding: EdgeInsets.only(right: responsiveUI.own(0.01)),
                    child: Icon(
                      Icons.circle,
                      size: responsiveUI.own(0.027),
                      color: DEVELOPMENT_STATUS[p2.devstatus]!.color,
                      shadows: const [Shadow(color: Colors.black)],
                    ),
                  ),

                  //
                  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                  // Dev status
                  ShadowText(DEVELOPMENT_STATUS[p2.devstatus]!.title),
                  //
                  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                  //
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
