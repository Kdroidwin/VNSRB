// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:flutter/foundation.dart';

import 'package:vndb_lite/src/features/home/data/preview_sections_data.dart';

class SettingsGeneralConf {
  const SettingsGeneralConf({
    required this.showCoverCensor,
    required this.showChart,
    required this.maxPreviewItem,
    required this.maxItemPerRowPortrait,
    required this.maxItemPerRowLandscape,
    required this.homeSectionsArrangement,
    required this.collectionStatusTabArrangement,
    required this.startupTab,
    required this.showCollectionItemLabels,
    required this.groupCollectionByDeveloper,
    required this.showCollectionCoverDates,
    required this.showCollectionDeveloperHeaders,
    required this.defaultCollectionStatus,
    required this.showNavigationLabelsOnTap,
    required this.hideCollectionBarsOnScroll,
  });

  final bool showCoverCensor;
  final bool showChart;
  final int maxPreviewItem;
  final int maxItemPerRowPortrait;
  final int maxItemPerRowLandscape;
  final List<HomeSectionsCode> homeSectionsArrangement;
  final List<String> collectionStatusTabArrangement;
  final String startupTab;
  final bool showCollectionItemLabels;
  final bool groupCollectionByDeveloper;
  final bool showCollectionCoverDates;
  final bool showCollectionDeveloperHeaders;
  final String defaultCollectionStatus;
  final bool showNavigationLabelsOnTap;
  final bool hideCollectionBarsOnScroll;

  SettingsGeneralConf copyWith({
    bool? showCoverCensor,
    bool? showChart,
    int? maxPreviewItem,
    int? maxItemPerRowPortrait,
    int? maxItemPerRowLandscape,
    List<HomeSectionsCode>? homeSectionsArrangement,
    List<String>? collectionStatusTabArrangement,
    String? startupTab,
    bool? showCollectionItemLabels,
    bool? groupCollectionByDeveloper,
    bool? showCollectionCoverDates,
    bool? showCollectionDeveloperHeaders,
    String? defaultCollectionStatus,
    bool? showNavigationLabelsOnTap,
    bool? hideCollectionBarsOnScroll,
  }) {
    return SettingsGeneralConf(
      showCoverCensor: showCoverCensor ?? this.showCoverCensor,
      showChart: showChart ?? this.showChart,
      maxPreviewItem: maxPreviewItem ?? this.maxPreviewItem,
      maxItemPerRowPortrait:
          maxItemPerRowPortrait ?? this.maxItemPerRowPortrait,
      maxItemPerRowLandscape:
          maxItemPerRowLandscape ?? this.maxItemPerRowLandscape,
      homeSectionsArrangement:
          homeSectionsArrangement ?? this.homeSectionsArrangement,
      collectionStatusTabArrangement:
          collectionStatusTabArrangement ?? this.collectionStatusTabArrangement,
      startupTab: startupTab ?? this.startupTab,
      showCollectionItemLabels:
          showCollectionItemLabels ?? this.showCollectionItemLabels,
      groupCollectionByDeveloper:
          groupCollectionByDeveloper ?? this.groupCollectionByDeveloper,
      showCollectionCoverDates:
          showCollectionCoverDates ?? this.showCollectionCoverDates,
      showCollectionDeveloperHeaders:
          showCollectionDeveloperHeaders ?? this.showCollectionDeveloperHeaders,
      defaultCollectionStatus:
          defaultCollectionStatus ?? this.defaultCollectionStatus,
      showNavigationLabelsOnTap:
          showNavigationLabelsOnTap ?? this.showNavigationLabelsOnTap,
      hideCollectionBarsOnScroll:
          hideCollectionBarsOnScroll ?? this.hideCollectionBarsOnScroll,
    );
  }

  @override
  String toString() {
    return 'SettingsGeneralConf(showCoverCensor: $showCoverCensor, showChart: $showChart, maxPreviewItem: $maxPreviewItem, maxItemPerRowPortrait: $maxItemPerRowPortrait, maxItemPerRowLandscape: $maxItemPerRowLandscape, homeSectionsArrangement: $homeSectionsArrangement, collectionStatusTabArrangement: $collectionStatusTabArrangement, startupTab: $startupTab, showCollectionItemLabels: $showCollectionItemLabels, groupCollectionByDeveloper: $groupCollectionByDeveloper, showCollectionCoverDates: $showCollectionCoverDates, showCollectionDeveloperHeaders: $showCollectionDeveloperHeaders, defaultCollectionStatus: $defaultCollectionStatus, showNavigationLabelsOnTap: $showNavigationLabelsOnTap, hideCollectionBarsOnScroll: $hideCollectionBarsOnScroll)';
  }

  @override
  bool operator ==(covariant SettingsGeneralConf other) {
    if (identical(this, other)) return true;

    return other.showCoverCensor == showCoverCensor &&
        other.showChart == showChart &&
        other.maxPreviewItem == maxPreviewItem &&
        other.maxItemPerRowPortrait == maxItemPerRowPortrait &&
        other.maxItemPerRowLandscape == maxItemPerRowLandscape &&
        listEquals(other.homeSectionsArrangement, homeSectionsArrangement) &&
        listEquals(
          other.collectionStatusTabArrangement,
          collectionStatusTabArrangement,
        ) &&
        other.startupTab == startupTab &&
        other.showCollectionItemLabels == showCollectionItemLabels &&
        other.groupCollectionByDeveloper == groupCollectionByDeveloper &&
        other.showCollectionCoverDates == showCollectionCoverDates &&
        other.showCollectionDeveloperHeaders ==
            showCollectionDeveloperHeaders &&
        other.defaultCollectionStatus == defaultCollectionStatus &&
        other.showNavigationLabelsOnTap == showNavigationLabelsOnTap &&
        other.hideCollectionBarsOnScroll == hideCollectionBarsOnScroll;
  }

  @override
  int get hashCode {
    return showCoverCensor.hashCode ^
        showChart.hashCode ^
        maxPreviewItem.hashCode ^
        maxItemPerRowPortrait.hashCode ^
        maxItemPerRowLandscape.hashCode ^
        homeSectionsArrangement.hashCode ^
        collectionStatusTabArrangement.hashCode ^
        startupTab.hashCode ^
        showCollectionItemLabels.hashCode ^
        groupCollectionByDeveloper.hashCode ^
        showCollectionCoverDates.hashCode ^
        showCollectionDeveloperHeaders.hashCode ^
        defaultCollectionStatus.hashCode ^
        showNavigationLabelsOnTap.hashCode ^
        hideCollectionBarsOnScroll.hashCode;
  }
}
