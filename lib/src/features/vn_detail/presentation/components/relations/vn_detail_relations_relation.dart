import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:vndb_lite/src/common_widgets/custom_button.dart';
import 'package:vndb_lite/src/common_widgets/generic_shadowy_text.dart';
import 'package:vndb_lite/src/util/responsive.dart';
import 'package:vndb_lite/src/features/settings/presentation/settings_general_state.dart';
import 'package:vndb_lite/src/features/vn/data/local_vn_repo.dart';
import 'package:vndb_lite/src/features/vn/domain/others.dart';
import 'package:vndb_lite/src/features/vn/domain/p3.dart';
import 'package:vndb_lite/src/util/context_shortcut.dart';
import 'package:vndb_lite/src/features/vn_item/presentation/vn_item_grid_.dart';
import 'package:vndb_lite/src/util/app_text.dart';

class VnDetailRelationsRelation extends ConsumerStatefulWidget {
  const VnDetailRelationsRelation({super.key, required this.p3});

  final VnDataPhase03 p3;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _VnDetailRelationsRelationState();
}

class _VnDetailRelationsRelationState
    extends ConsumerState<VnDetailRelationsRelation> {
  bool _onlyOfficial = true;
  late Future<List<Widget>> _relationsList;

  @override
  void initState() {
    super.initState();
    _relationsList = _loadRelations();
  }

  @override
  void didUpdateWidget(covariant VnDetailRelationsRelation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.p3.relations, widget.p3.relations)) {
      _relationsList = _loadRelations();
    }
  }

  //
  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  //

  bool get _isThereRelation {
    final relations = widget.p3.relations;
    return relations != null && relations.isNotEmpty;
  }

  //
  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  //

  Future<List<Widget>> _loadRelations() async {
    if (!_isThereRelation) return [];
    final localVnRepo = ref.read(localVnRepoProvider);
    final relations =
        _arrangedRelations
            .where(
              (relation) => relation.id != null && relation.relation != null,
            )
            .toList();
    final vnData = await Future.wait(
      relations.map((relation) => localVnRepo.getP1(relation.id!)),
    );

    return [
      for (var index = 0; index < relations.length; index++)
        if (vnData[index] != null)
          VnItemGrid(
            key: ValueKey('relation-${relations[index].id}'),
            p1: vnData[index]!,
            labelCode: relations[index].relation!,
            isGridView: true,
          ),
    ];
  }

  //
  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  // Sorting utilities

  bool _isOfficial(VnRelation relation) {
    return relation.relation_official ?? false;
  }

  bool _isHighPriority(VnRelation relation) {
    if (relation.relation == 'seq' ||
        relation.relation == 'preq' ||
        relation.relation == 'orig') {
      return true;
    }

    return false;
  }

  //
  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  //

  List<VnRelation> get _arrangedRelations {
    final List<VnRelation> lowPriorityRelations = [];
    final List<VnRelation> highPriorityRelations = [];

    for (VnRelation relation in (widget.p3.relations ?? [])) {
      // An optimization, whether to include non-official relation or not. Comment the line below to
      // allow non-official relation to be rendered in the UI.
      if (_onlyOfficial) if (!_isOfficial(relation)) continue;

      if (_isHighPriority(relation)) {
        highPriorityRelations.add(relation);
        continue;
      }

      lowPriorityRelations.add(relation);
    }

    // High priority goes first.
    return [...highPriorityRelations, ...lowPriorityRelations];
  }

  //
  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  //

  Widget _relationOfficialSwitchButton({
    required Color color,
    required String title,
  }) {
    return CustomButton(
      margin: EdgeInsets.symmetric(horizontal: responsiveUI.own(0.01)),
      onTap: () {
        setState(() {
          _onlyOfficial = !_onlyOfficial;
          _relationsList = _loadRelations();
        });
      },
      padding: EdgeInsets.symmetric(horizontal: responsiveUI.own(0.025)),
      buttonColor: (_onlyOfficial) ? color : Colors.grey,
      child: ShadowText(title),
    );
  }

  //
  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  //

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsGeneralStateProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShadowText(
          appText(context, 'Related/Similar VNs', '関連作品・類似作品'),
          fontSize: responsiveUI.own(0.045),
          fontWeight: FontWeight.bold,
        ),
        Wrap(
          children: [
            ShadowText('${appText(context, 'Relation', '関係')}: '),
            _relationOfficialSwitchButton(
              color: kColor(context).secondary.withOpacity(0.7),
              title: appText(context, 'Official-only', '公式作品のみ'),
            ),
          ],
        ),
        SizedBox(height: responsiveUI.own(0.025)),
        FutureBuilder(
          future: _relationsList,
          builder: (BuildContext context, AsyncSnapshot snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Padding(
                padding: EdgeInsets.all(responsiveUI.own(0.1)),
                child: const Center(child: CircularProgressIndicator()),
              );
            }

            final relations = snapshot.data;
            if (relations.isEmpty) return ShadowText('--');

            return MasonryGridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverSimpleGridDelegateWithFixedCrossAxisCount(
                crossAxisCount:
                    (MediaQuery.of(context).orientation == Orientation.portrait)
                        ? settings.maxItemPerRowPortrait
                        : settings.maxItemPerRowLandscape,
              ),
              mainAxisSpacing: responsiveUI.own(0.03),
              crossAxisSpacing: responsiveUI.own(0.03),
              itemCount: relations.length,
              itemBuilder: (context, index) {
                return relations[index];
              },
            );
          },
        ),
      ],
    );
  }
}
