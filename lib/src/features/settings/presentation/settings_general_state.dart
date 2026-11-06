import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vndb_lite/src/constants/defaults.dart';
import 'package:vndb_lite/src/constants/local_db_constants.dart';
import 'package:vndb_lite/src/core/local_db/shared_prefs.dart';
import 'package:vndb_lite/src/features/collection/data/collection_status_data.dart';
import 'package:vndb_lite/src/features/home/data/preview_sections_data.dart';
import 'package:vndb_lite/src/features/settings/domain/settings_general_conf.dart';

part 'settings_general_state.g.dart';

@Riverpod(dependencies: [sharedPref])
class SettingsGeneralState extends _$SettingsGeneralState {
  @override
  SettingsGeneralConf build() {
    return SettingsGeneralConf(
      showCoverCensor: _showCoverCensor,
      showChart: _showChart,
      maxPreviewItem: _maxPreviewItem,
      maxItemPerRowPortrait: _maxItemPerRowPortrait,
      maxItemPerRowLandscape: _maxItemPerRowLandscape,
      homeSectionsArrangement: _homeSectionsArrangement,
      collectionStatusTabArrangement: _collectionStatusTabArrangement,
      startupTab: _startupTab,
      showCollectionItemLabels: _showCollectionItemLabels,
      groupCollectionByDeveloper: _groupCollectionByDeveloper,
      showCollectionCoverDates: _showCollectionCoverDates,
      showCollectionDeveloperHeaders: _showCollectionDeveloperHeaders,
      defaultCollectionStatus: _defaultCollectionStatus,
    );
  }

  bool get _showCoverCensor {
    final sharedPref = ref.read(sharedPrefProvider);
    final bool? coverCensor = sharedPref.getBool(DBKeys.COVER_CENSOR_CONF);

    // Validate
    if (coverCensor != null) return coverCensor;
    return Default.COVER_CENSOR_CONF;
  }

  bool get _showChart {
    final sharedPref = ref.read(sharedPrefProvider);
    final bool? showChart = sharedPref.getBool(DBKeys.SHOW_CHART_CONF);

    // Validate
    if (showChart != null) {
      return showChart;
    }

    return Default.SHOW_CHART_CONF;
  }

  int get _maxPreviewItem {
    final sharedPref = ref.read(sharedPrefProvider);
    final int? maxPreview = sharedPref.getInt(DBKeys.MAX_PREVIEW_ITEMS_CONF);

    // Validate
    if (maxPreview != null && maxPreview >= 1) {
      return maxPreview;
    }

    return Default.MAX_PREVIEW_ITEMS_CONF;
  }

  int get _maxItemPerRowPortrait {
    final sharedPref = ref.read(sharedPrefProvider);
    final int? maxItem = sharedPref.getInt(
      DBKeys.MAX_ITEMS_PER_ROW_PORTRAIT_CONF,
    );

    // Validate
    if (maxItem != null && maxItem >= 2) {
      return maxItem;
    }

    return Default.MAX_ITEM_PER_ROW_PORTRAIT_CONF;
  }

  int get _maxItemPerRowLandscape {
    final sharedPref = ref.read(sharedPrefProvider);
    final int? maxItem = sharedPref.getInt(
      DBKeys.MAX_ITEMS_PER_ROW_LANDSCAPE_CONF,
    );

    // Validate
    if (maxItem != null && maxItem >= 4) {
      return maxItem;
    }

    return Default.MAX_ITEM_PER_ROW_LANDSCAPE_CONF;
  }

  List<HomeSectionsCode> get _homeSectionsArrangement {
    final sharedPref = ref.read(sharedPrefProvider);
    final List<String>? arrangement = sharedPref.getStringList(
      DBKeys.HOME_ARRANGEMENT,
    );

    // Validate
    if (arrangement != null &&
        arrangement.isNotEmpty &&
        arrangement.length >= HomeSectionsCode.values.length) {
      return arrangement
          .map((code) => HomeSectionsCode.values.byName(code))
          .toList();
    }

    return Default.HOME_SECTION_ARRANGEMENT;
  }

  List<String> get _collectionStatusTabArrangement {
    final sharedPref = ref.read(sharedPrefProvider);
    final List<String>? arrangement = sharedPref.getStringList(
      DBKeys.COLLECTION_ARRANGEMENT,
    );

    // Validate
    if (arrangement != null &&
        arrangement.isNotEmpty &&
        arrangement.length >= CollectionStatusCode.values.length) {
      return arrangement;
    }

    return Default.COLLECTION_STATUS_TAB_ARRANGEMENT;
  }

  String get _startupTab {
    const validTabs = {'home', 'search', 'collection', 'others'};
    final tab = ref.read(sharedPrefProvider).getString(DBKeys.STARTUP_TAB);
    return validTabs.contains(tab) ? tab! : 'home';
  }

  bool get _showCollectionItemLabels =>
      ref
          .read(sharedPrefProvider)
          .getBool(DBKeys.SHOW_COLLECTION_ITEM_LABELS) ??
      true;

  bool get _groupCollectionByDeveloper =>
      ref
          .read(sharedPrefProvider)
          .getBool(DBKeys.GROUP_COLLECTION_BY_DEVELOPER) ??
      false;

  bool get _showCollectionCoverDates =>
      ref
          .read(sharedPrefProvider)
          .getBool(DBKeys.SHOW_COLLECTION_COVER_DATES) ??
      true;

  bool get _showCollectionDeveloperHeaders =>
      ref
          .read(sharedPrefProvider)
          .getBool(DBKeys.SHOW_COLLECTION_DEVELOPER_HEADERS) ??
      true;

  String get _defaultCollectionStatus {
    final status = ref
        .read(sharedPrefProvider)
        .getString(DBKeys.DEFAULT_COLLECTION_STATUS);
    return COLLECTION_STATUS_DATA.containsKey(status)
        ? status!
        : CollectionStatusCode.finished.name;
  }

  set showChart(bool value) {
    final sharedPref = ref.read(sharedPrefProvider);
    sharedPref.setBool(DBKeys.SHOW_CHART_CONF, value);
    sharedPref.reload();

    state = state.copyWith(showChart: value);
  }

  set showCoverCensor(bool value) {
    final sharedPref = ref.read(sharedPrefProvider);
    sharedPref.setBool(DBKeys.COVER_CENSOR_CONF, value);
    sharedPref.reload();

    state = state.copyWith(showCoverCensor: value);
  }

  set maxPreviewItem(int value) {
    final sharedPref = ref.read(sharedPrefProvider);
    sharedPref.setInt(DBKeys.MAX_PREVIEW_ITEMS_CONF, value);
    sharedPref.reload();

    state = state.copyWith(maxPreviewItem: value);
  }

  set maxItemPerRowPortrait(int value) {
    final sharedPref = ref.read(sharedPrefProvider);
    sharedPref.setInt(DBKeys.MAX_ITEMS_PER_ROW_PORTRAIT_CONF, value);
    sharedPref.reload();

    state = state.copyWith(maxItemPerRowPortrait: value);
  }

  set maxItemPerRowLandscape(int value) {
    final sharedPref = ref.read(sharedPrefProvider);
    sharedPref.setInt(DBKeys.MAX_ITEMS_PER_ROW_LANDSCAPE_CONF, value);
    sharedPref.reload();

    state = state.copyWith(maxItemPerRowLandscape: value);
  }

  set homeSectionsArrangement(List<HomeSectionsCode> value) {
    final sharedPref = ref.read(sharedPrefProvider);
    sharedPref.setStringList(
      DBKeys.HOME_ARRANGEMENT,
      HomeSectionsCode.values.map((e) => e.name).toList(),
    );
    sharedPref.reload();

    state = state.copyWith(homeSectionsArrangement: value);
  }

  set collectionStatusTabArrangement(List<String> value) {
    final sharedPref = ref.read(sharedPrefProvider);
    sharedPref.setStringList(DBKeys.COLLECTION_ARRANGEMENT, value);
    sharedPref.reload();

    state = state.copyWith(collectionStatusTabArrangement: value);
  }

  set startupTab(String value) {
    ref.read(sharedPrefProvider).setString(DBKeys.STARTUP_TAB, value);
    state = state.copyWith(startupTab: value);
  }

  set showCollectionItemLabels(bool value) {
    ref
        .read(sharedPrefProvider)
        .setBool(DBKeys.SHOW_COLLECTION_ITEM_LABELS, value);
    state = state.copyWith(showCollectionItemLabels: value);
  }

  set groupCollectionByDeveloper(bool value) {
    ref
        .read(sharedPrefProvider)
        .setBool(DBKeys.GROUP_COLLECTION_BY_DEVELOPER, value);
    state = state.copyWith(groupCollectionByDeveloper: value);
  }

  set showCollectionCoverDates(bool value) {
    ref
        .read(sharedPrefProvider)
        .setBool(DBKeys.SHOW_COLLECTION_COVER_DATES, value);
    state = state.copyWith(showCollectionCoverDates: value);
  }

  set showCollectionDeveloperHeaders(bool value) {
    ref
        .read(sharedPrefProvider)
        .setBool(DBKeys.SHOW_COLLECTION_DEVELOPER_HEADERS, value);
    state = state.copyWith(showCollectionDeveloperHeaders: value);
  }

  set defaultCollectionStatus(String value) {
    if (!COLLECTION_STATUS_DATA.containsKey(value)) return;
    ref
        .read(sharedPrefProvider)
        .setString(DBKeys.DEFAULT_COLLECTION_STATUS, value);
    state = state.copyWith(defaultCollectionStatus: value);
  }
}
