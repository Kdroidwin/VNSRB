import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:vndb_lite/src/common_widgets/custom_label.dart';
import 'package:vndb_lite/src/common_widgets/generic_shadowy_text.dart';
import 'package:vndb_lite/src/features/sort_filter/presentation/local/local_sort_filter_controller.dart';
import 'package:vndb_lite/src/features/sort_filter/data/sortable_data.dart';
import 'package:vndb_lite/src/util/responsive.dart';
import 'package:vndb_lite/src/features/_base/presentation/upper_parts/buttons/refresh_button.dart';
import 'package:vndb_lite/src/features/collection/presentation/collection_content_controller.dart';
import 'package:vndb_lite/src/features/settings/presentation/components/settings_item_per_row.dart';
import 'package:vndb_lite/src/features/settings/presentation/components/settings_listview_scroll_items.dart';
import 'package:vndb_lite/src/features/settings/presentation/dialog/settings_dialog.dart';
import 'package:vndb_lite/src/features/settings/presentation/settings_general_state.dart';
import 'package:vndb_lite/src/util/context_shortcut.dart';
import 'package:vndb_lite/src/util/app_text.dart';
import 'package:vndb_lite/src/features/collection/data/collection_status_data.dart';
import 'package:flutter/material.dart';

class SettingsGeneral extends ConsumerStatefulWidget {
  const SettingsGeneral({super.key});

  @override
  ConsumerState<SettingsGeneral> createState() => _SettingsGeneralState();
}

class _SettingsGeneralState extends ConsumerState<SettingsGeneral>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();

    _offsetAnimation = _animationController
        .drive(CurveTween(curve: Curves.easeInOut))
        .drive(
          Tween<Offset>(begin: const Offset(0, -0.5), end: const Offset(0, 0)),
        );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  //
  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  //

  Future<void> _refreshApp() async {
    await AppBarRefreshButton.tap();
    if (mounted) setState(() {});
  }

  //
  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  //

  void _censorCoverSwitch() {
    final showCoverCensor =
        ref.read(settingsGeneralStateProvider).showCoverCensor;
    ref.read(settingsGeneralStateProvider.notifier).showCoverCensor =
        !showCoverCensor;
  }

  Future<void> _chooseStartupTab() async {
    final tabs = <String, String>{
      'home': appText(context, 'Home', 'ホーム'),
      'search': appText(context, 'Search', '検索'),
      'collection': appText(context, 'Collection', 'コレクション'),
      'others': appText(context, 'Others', 'その他'),
    };
    final selected = ref.read(settingsGeneralStateProvider).startupTab;
    final tab = await showDialog<String>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(appText(context, 'Open on startup', '起動時に開くタブ')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final entry in tabs.entries)
                  RadioListTile<String>(
                    value: entry.key,
                    groupValue: selected,
                    title: Text(entry.value),
                    onChanged:
                        (value) => Navigator.of(dialogContext).pop(value),
                  ),
              ],
            ),
          ),
    );
    if (tab != null) {
      ref.read(settingsGeneralStateProvider.notifier).startupTab = tab;
    }
  }

  Future<void> _chooseDefaultCollectionStatus() async {
    final selected =
        ref.read(settingsGeneralStateProvider).defaultCollectionStatus;
    final status = await showDialog<String>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(
              appText(context, 'Default collection status', '追加時の既定ステータス'),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final entry in COLLECTION_STATUS_DATA.entries)
                  RadioListTile<String>(
                    value: entry.key,
                    groupValue: selected,
                    title: Text(collectionStatusText(context, entry.key)),
                    onChanged:
                        (value) => Navigator.of(dialogContext).pop(value),
                  ),
              ],
            ),
          ),
    );
    if (status != null) {
      ref.read(settingsGeneralStateProvider.notifier).defaultCollectionStatus =
          status;
    }
  }

  Future<void> _collectionLabelsSwitch() async {
    final visible =
        ref.read(settingsGeneralStateProvider).showCollectionItemLabels;
    ref.read(settingsGeneralStateProvider.notifier).showCollectionItemLabels =
        !visible;
  }

  void _collectionCoverDatesSwitch() {
    final visible =
        ref.read(settingsGeneralStateProvider).showCollectionCoverDates;
    ref.read(settingsGeneralStateProvider.notifier).showCollectionCoverDates =
        !visible;
  }

  void _collectionDeveloperHeadersSwitch() {
    final visible =
        ref.read(settingsGeneralStateProvider).showCollectionDeveloperHeaders;
    ref
        .read(settingsGeneralStateProvider.notifier)
        .showCollectionDeveloperHeaders = !visible;
  }

  Future<void> _groupCollectionByDeveloperSwitch() async {
    final enabled =
        ref.read(settingsGeneralStateProvider).groupCollectionByDeveloper;
    ref.read(settingsGeneralStateProvider.notifier).groupCollectionByDeveloper =
        !enabled;
    if (!enabled) {
      final sortController = ref.read(localSortControllerProvider.notifier);
      sortController.sort = SortableCode.released.name;
      sortController.reverse = false;
      await ref
          .read(collectionContentControllerProvider.notifier)
          .separateVNsByStatus(
            ref.read(localFilterControllerProvider),
            ref.read(localSortControllerProvider),
          );
    }
    await _refreshApp();
  }

  //
  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  //

  Widget _getDragAndDropItem({required String key, required String title}) {
    // Need to be given an exact length so it can be measured easily,
    // as the parent widget's constraints.
    return SizedBox(
      key: ValueKey<String>(key),
      height: responsiveUI.own(0.13),
      child: ListTile(
        dense: true,
        tileColor: kColor(context).secondary.withOpacity(0.7),
        contentPadding: EdgeInsets.symmetric(
          horizontal: responsiveUI.own(0.045),
        ),
        trailing: Icon(
          Icons.format_list_bulleted,
          size: responsiveUI.own(0.05),
          color: kColor(context).tertiary.withAlpha(180),
        ),
        title: ShadowText(title),
      ),
    );
  }

  //
  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  //

  Future<void> _arrangeCollectionTab() async {
    final collectionStatusArrangement = List<String>.from(
      ref.read(settingsGeneralStateProvider).collectionStatusTabArrangement,
    );

    await showSettingsDialog(
      title: appText(context, 'Re-arrange Tab Collection', 'コレクションタブの並び替え'),
      yesOrNo: true,
      yesFunction: () async {
        ref
            .read(settingsGeneralStateProvider.notifier)
            .collectionStatusTabArrangement = collectionStatusArrangement;

        final filterData = ref.read(localFilterControllerProvider);
        final sortData = ref.read(localSortControllerProvider);
        await ref
            .read(collectionContentControllerProvider.notifier)
            .separateVNsByStatus(filterData, sortData);
        await _refreshApp();
      },
      content: StatefulBuilder(
        builder:
            (context, setDialogState) => Container(
              width: double.maxFinite,
              height:
                  collectionStatusArrangement.length * responsiveUI.own(0.13) +
                  responsiveUI.own(0.035),
              padding: EdgeInsets.only(top: responsiveUI.own(0.03)),
              child: ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder:
                    (ctx, idx) => _getDragAndDropItem(
                      key: collectionStatusArrangement[idx],
                      title: collectionStatusText(
                        context,
                        toBeginningOfSentenceCase<String>(
                          collectionStatusArrangement[idx],
                        ),
                      ),
                    ),
                itemCount: collectionStatusArrangement.length,
                onReorder: (oldItemIndex, newItemIndex) {
                  if (newItemIndex > oldItemIndex) newItemIndex--;
                  setDialogState(() {
                    final movedItem = collectionStatusArrangement.removeAt(
                      oldItemIndex,
                    );
                    collectionStatusArrangement.insert(newItemIndex, movedItem);
                  });
                },
              ),
            ),
      ),
    );
  }

  //
  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  //

  Future<void> _previewItemCount() async {
    int maxPreviewItem = ref.read(settingsGeneralStateProvider).maxPreviewItem;

    await showSettingsDialog(
      title: appText(context, 'Home VN item previews count', 'ホームの作品プレビュー数'),
      yesOrNo: true,
      yesFunction: () async {
        ref.read(settingsGeneralStateProvider.notifier).maxPreviewItem =
            maxPreviewItem;
        await _refreshApp();
      },
      content: Padding(
        padding: EdgeInsets.only(
          top: responsiveUI.own(0.02),
          left: responsiveUI.own(0.05),
          right: responsiveUI.own(0.05),
          bottom: responsiveUI.own(0.01),
        ),
        child: Container(
          width: responsiveUI.own(0.1),
          height: responsiveUI.own(0.25),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Color.alphaBlend(
                kColor(context).secondary.withOpacity(0.4),
                kColor(context).tertiary.withOpacity(0.6),
              ),
              width: 1.5,
            ),
          ),
          child: ListviewScrollItem(
            // Minus one in the UI to align with the list index which starts at 0
            initialItemController: maxPreviewItem - 1,
            onSelectedItemChanged: (value) {
              // Plus one to ignore UI list index and focus with real length value.
              setState(() => maxPreviewItem = value + 1);
            },
            children: List.generate(30, (idx) {
              return ShadowText(
                // Index start at 0, but in the context 0 is not possible, so incrementing 1 (only affect visual).
                (idx + 1).toString(),
                fontSize: responsiveUI.own(0.04),
                color: Colors.white,
              );
            }),
          ),
        ),
      ),
    );
  }

  //
  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  //

  Future<void> _chartSwitch() async {
    final showChart = ref.read(settingsGeneralStateProvider).showChart;
    ref.read(settingsGeneralStateProvider.notifier).showChart = !showChart;
  }

  //
  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  //

  Future<void> _vnItemsPerRow() async {
    int valueIdxPortrait =
        ref.read(settingsGeneralStateProvider).maxItemPerRowPortrait;
    int valueIdxLandscape =
        ref.read(settingsGeneralStateProvider).maxItemPerRowLandscape;

    await showSettingsDialog(
      title: appText(context, 'VN item per row count', '1行あたりの作品数'),
      yesOrNo: true,
      yesFunction: () async {
        ref.read(settingsGeneralStateProvider.notifier).maxItemPerRowPortrait =
            valueIdxPortrait;
        ref.read(settingsGeneralStateProvider.notifier).maxItemPerRowLandscape =
            valueIdxLandscape;
        await _refreshApp();
      },
      content: SettingsItemPerRow(
        initialPortraitValue: valueIdxPortrait,
        initialLandscapeValue: valueIdxLandscape,
        onSelectedItemChangedPortrait: (value) {
          // Index start at 0, but in the context, 0 is not possible.
          // This time incrementing 2 as it starts from 2.
          setState(() => valueIdxPortrait = value + 2);
        },
        onSelectedItemChangedLandscape: (value) {
          // Index start at 0, but in the context 0 is not possible.
          // This time incrementing 2 as it starts from 4.
          setState(() => valueIdxLandscape = value + 4);
        },
      ),
    );
  }

  //
  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  //

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsGeneralStateProvider);

    return SlideTransition(
      position: _offsetAnimation,
      child: FadeTransition(
        opacity: _animationController.drive(
          CurveTween(curve: Curves.easeInToLinear),
        ),
        child: Container(
          alignment: Alignment.centerLeft,
          padding: EdgeInsets.all(responsiveUI.own(0.04)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              //
              // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
              // Censor
              CustomLabel(
                useBorder: true,
                borderRadius: 12,
                isSelected: false,
                borderColor: kColor(context).secondary,
                padding: EdgeInsets.all(responsiveUI.own(0.02)),
                onTap: _censorCoverSwitch,
                children: [
                  ShadowText(
                    appText(
                      context,
                      'Blur sensitive VN covers ',
                      '刺激の強い作品カバーをぼかす：',
                    ),
                  ),
                  ShadowText(
                    settings.showCoverCensor
                        ? appText(context, ' ON', ' オン')
                        : appText(context, ' OFF', ' オフ'),
                    fontWeight: FontWeight.bold,
                    color:
                        (settings.showCoverCensor) ? Colors.green : Colors.red,
                    shadows: [
                      Shadow(
                        color: Color.alphaBlend(
                          Colors.black.withOpacity(0.5),
                          kColor(context).primary,
                        ),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                ],
              ),

              if (settings.groupCollectionByDeveloper) ...[
                SizedBox(height: responsiveUI.own(0.03)),
                CustomLabel(
                  useBorder: true,
                  borderRadius: 12,
                  isSelected: false,
                  borderColor: kColor(context).secondary,
                  padding: EdgeInsets.all(responsiveUI.own(0.02)),
                  onTap: _collectionDeveloperHeadersSwitch,
                  children: [
                    ShadowText(
                      appText(context, 'Developer group names: ', 'メーカー名の見出し：'),
                    ),
                    ShadowText(
                      settings.showCollectionDeveloperHeaders
                          ? appText(context, ' ON', ' オン')
                          : appText(context, ' OFF', ' オフ'),
                      fontWeight: FontWeight.bold,
                      color:
                          settings.showCollectionDeveloperHeaders
                              ? Colors.green
                              : Colors.red,
                    ),
                  ],
                ),
              ],

              SizedBox(height: responsiveUI.own(0.03)),
              CustomLabel(
                useBorder: true,
                borderRadius: 12,
                isSelected: false,
                borderColor: kColor(context).secondary,
                padding: EdgeInsets.all(responsiveUI.own(0.02)),
                onTap: _chooseDefaultCollectionStatus,
                children: [
                  ShadowText(
                    appText(
                      context,
                      'Default status when adding: ',
                      '追加時の既定ステータス：',
                    ),
                  ),
                  ShadowText(
                    collectionStatusText(
                      context,
                      settings.defaultCollectionStatus,
                    ),
                    color: kColor(context).tertiary.withAlpha(180),
                  ),
                ],
              ),

              SizedBox(height: responsiveUI.own(0.03)),
              CustomLabel(
                useBorder: true,
                borderRadius: 12,
                isSelected: false,
                borderColor: kColor(context).secondary,
                padding: EdgeInsets.all(responsiveUI.own(0.02)),
                onTap: _collectionCoverDatesSwitch,
                children: [
                  ShadowText(
                    appText(context, 'Collection cover dates: ', 'カバー上の日付表示：'),
                  ),
                  ShadowText(
                    settings.showCollectionCoverDates
                        ? appText(context, ' ON', ' オン')
                        : appText(context, ' OFF', ' オフ'),
                    fontWeight: FontWeight.bold,
                    color:
                        settings.showCollectionCoverDates
                            ? Colors.green
                            : Colors.red,
                  ),
                ],
              ),

              SizedBox(height: responsiveUI.own(0.03)),
              CustomLabel(
                useBorder: true,
                borderRadius: 12,
                isSelected: false,
                borderColor: kColor(context).secondary,
                padding: EdgeInsets.all(responsiveUI.own(0.02)),
                onTap: _groupCollectionByDeveloperSwitch,
                children: [
                  ShadowText(
                    appText(
                      context,
                      'Group collection by developer: ',
                      'メーカーごとに分類：',
                    ),
                  ),
                  ShadowText(
                    settings.groupCollectionByDeveloper
                        ? appText(context, ' ON', ' オン')
                        : appText(context, ' OFF', ' オフ'),
                    fontWeight: FontWeight.bold,
                    color:
                        settings.groupCollectionByDeveloper
                            ? Colors.green
                            : Colors.red,
                  ),
                ],
              ),

              //
              // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
              // Arrange Tab
              SizedBox(height: responsiveUI.own(0.03)),
              CustomLabel(
                useBorder: true,
                borderRadius: 12,
                isSelected: false,
                borderColor: kColor(context).secondary,
                padding: EdgeInsets.all(responsiveUI.own(0.02)),
                onTap: () async => await _arrangeCollectionTab(),
                children: [
                  ShadowText(
                    appText(
                      context,
                      'Arrange collection status tabs',
                      'コレクションタブの並び替え',
                    ),
                  ),
                ],
              ),

              SizedBox(height: responsiveUI.own(0.03)),
              CustomLabel(
                useBorder: true,
                borderRadius: 12,
                isSelected: false,
                borderColor: kColor(context).secondary,
                padding: EdgeInsets.all(responsiveUI.own(0.02)),
                onTap: _chooseStartupTab,
                children: [
                  ShadowText(
                    appText(context, 'Open on startup: ', '起動時に開く画面：'),
                  ),
                  ShadowText(switch (settings.startupTab) {
                    'home' => appText(context, 'Home', 'ホーム'),
                    'search' => appText(context, 'Search', '検索'),
                    'collection' => appText(context, 'Collection', 'コレクション'),
                    _ => appText(context, 'Others', 'その他'),
                  }, color: kColor(context).tertiary.withAlpha(180)),
                ],
              ),

              SizedBox(height: responsiveUI.own(0.03)),
              CustomLabel(
                useBorder: true,
                borderRadius: 12,
                isSelected: false,
                borderColor: kColor(context).secondary,
                padding: EdgeInsets.all(responsiveUI.own(0.02)),
                onTap: _collectionLabelsSwitch,
                children: [
                  ShadowText(
                    appText(
                      context,
                      'Collection cover labels: ',
                      'カバー上のラベル表示：',
                    ),
                  ),
                  ShadowText(
                    settings.showCollectionItemLabels
                        ? appText(context, ' ON', ' オン')
                        : appText(context, ' OFF', ' オフ'),
                    fontWeight: FontWeight.bold,
                    color:
                        settings.showCollectionItemLabels
                            ? Colors.green
                            : Colors.red,
                  ),
                ],
              ),

              //
              // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
              // Preview item count
              SizedBox(height: responsiveUI.own(0.03)),
              CustomLabel(
                useBorder: true,
                borderRadius: 12,
                isSelected: false,
                borderColor: kColor(context).secondary,
                padding: EdgeInsets.all(responsiveUI.own(0.02)),
                onTap: () async => await _previewItemCount(),
                children: [
                  ShadowText(
                    appText(
                      context,
                      'Home VN item previews: ',
                      'ホームの作品プレビュー数：',
                    ),
                  ),
                  ShadowText(
                    // Because index starts at 0, and 0 is not valid
                    (settings.maxPreviewItem != 20)
                        ? '${settings.maxPreviewItem}'
                        : appText(context, 'Default (20)', '既定（20）'),
                    color: kColor(context).tertiary.withAlpha(180),
                  ),
                ],
              ),
              //
              // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
              // Show PieChart
              SizedBox(height: responsiveUI.own(0.03)),
              CustomLabel(
                useBorder: true,
                borderRadius: 12,
                isSelected: false,
                borderColor: kColor(context).secondary,
                padding: EdgeInsets.all(responsiveUI.own(0.02)),
                onTap: () async => await _chartSwitch(),
                children: [
                  ShadowText(
                    appText(context, 'Show VNDB stats chart ', 'VNDB統計チャート：'),
                  ),
                  ShadowText(
                    settings.showChart
                        ? appText(context, ' YES', ' 表示')
                        : appText(context, ' NO', ' 非表示'),
                    fontWeight: FontWeight.bold,
                    color: (settings.showChart) ? Colors.green : Colors.red,
                    shadows: [
                      Shadow(
                        color: Color.alphaBlend(
                          Colors.black.withOpacity(0.5),
                          kColor(context).primary,
                        ),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                ],
              ),

              //
              // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
              // Vn Items per row
              SizedBox(height: responsiveUI.own(0.03)),
              CustomLabel(
                useBorder: true,
                borderRadius: 12,
                isSelected: false,
                borderColor: kColor(context).secondary,
                padding: EdgeInsets.all(responsiveUI.own(0.02)),
                onTap: () async => await _vnItemsPerRow(),
                children: [
                  ShadowText(
                    appText(context, 'VN item per row: ', '1行あたりの作品数：'),
                  ),
                  ShadowText(
                    '${appText(context, 'Portrait', '縦')}: ${(settings.maxItemPerRowPortrait == 2) ? appText(context, 'Default (2)', '既定（2）') : settings.maxItemPerRowPortrait} | '
                    '${appText(context, 'Landscape', '横')}: ${(settings.maxItemPerRowLandscape == 4) ? appText(context, 'Default (4)', '既定（4）') : settings.maxItemPerRowLandscape}',
                    color: kColor(context).tertiary.withAlpha(180),
                  ),
                ],
              ),

              //
              // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
              //
            ],
          ),
        ),
      ),
    );
  }
}
