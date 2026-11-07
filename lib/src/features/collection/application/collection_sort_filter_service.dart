import 'package:flutter/material.dart';
import 'package:vndb_lite/src/constants/defaults.dart';
import 'package:vndb_lite/src/features/collection/application/local_filter_service.dart';
import 'package:vndb_lite/src/features/collection/data/collection_status_data.dart';
import 'package:vndb_lite/src/features/collection/data/local/local_collection_repo.dart';
import 'package:vndb_lite/src/features/collection/presentation/collection_content_controller.dart';
import 'package:vndb_lite/src/features/sort_filter/domain/filter_.dart';
import 'package:vndb_lite/src/features/sort_filter/domain/sort_.dart';
import 'package:vndb_lite/src/features/sort_filter/data/sortable_data.dart';
import 'package:vndb_lite/src/features/vn/domain/p1.dart';
import 'package:vndb_lite/src/features/vn_item/presentation/vn_item_grid_.dart';
import 'package:vndb_lite/src/util/alt_provider_reader.dart';

// TODO remote search 'none' should not be as 'searchrank', but instead, jsut
// TODO not including the 'sort' at all. WATCHOUT with the search field too,
// TODO and searching for real empty string is possible, not just space ' '.

/// A service class to do some heavy processing such as sorting and filtering vn data.
class CollectionSortFilterService {
  /// This method sorts all of the adapted vn data based on the given sort configuration.
  static Future<void> sortData(SortData conf) async {
    final sortBy = conf.sort;

    if (sortBy == SortableCode.custom.name) {
      final collection = ref_.read(localCollectionRepoProvider);
      for (String statusName in COLLECTION_STATUS_DATA.keys) {
        final order = collection.getCustomOrder(statusName);
        final positions = <String, int>{
          for (var index = 0; index < order.length; index++)
            order[index]: index,
        };
        rawP1BasedOnStatus[statusName]!.sort(
          (a, b) => (positions[a['id']] ?? order.length).compareTo(
            positions[b['id']] ?? order.length,
          ),
        );
      }
      return;
    }

    for (String statusName in COLLECTION_STATUS_DATA.keys) {
      rawP1BasedOnStatus[statusName]!.sort((a, b) {
        if (a[sortBy] == null || b[sortBy] == null) {
          return _compareValues(a[sortBy], b[sortBy]);
        }
        final primary = _compareValues(a[sortBy], b[sortBy]);
        final directed = conf.reverse! ? -primary : primary;
        if (directed != 0) return directed;
        return _compareValues(a['title'], b['title']);
      });
    }
  }

  static int _compareValues(dynamic left, dynamic right) {
    if (identical(left, right)) return 0;
    if (left == null) return 1;
    if (right == null) return -1;
    if (left is num && right is num) return left.compareTo(right);
    final leftText = left.toString();
    final rightText = right.toString();
    final leftNumber = num.tryParse(leftText);
    final rightNumber = num.tryParse(rightText);
    if (leftNumber != null && rightNumber != null) {
      return leftNumber.compareTo(rightNumber);
    }
    final leftDate = DateTime.tryParse(leftText);
    final rightDate = DateTime.tryParse(rightText);
    if (leftDate != null && rightDate != null) {
      return leftDate.compareTo(rightDate);
    }
    return leftText.toLowerCase().compareTo(rightText.toLowerCase());
  }

  /// This method filters all of the adapted vn data based on the given filter configuration.
  static Future<void> filterData(FilterData filter, SortData sort) async {
    final filterService = ref_.read(localFilterServiceProvider);
    final List<String> searchKeywords = _getSearchKeywords(filter.search);
    final controller = ref_.read(collectionContentControllerProvider.notifier);
    final usesFilter = isUsingFilter(filter);

    for (String statusName in COLLECTION_STATUS_DATA.keys) {
      final matchingItems = <VnItemGrid>[];
      for (Map<String, dynamic> adaptedVnData
          in rawP1BasedOnStatus[statusName]!) {
        // If not using any filter, then simply ignore all the filter check.
        if (!usesFilter) {
          matchingItems.add(_toVnWidget(adaptedVnData, sort));
          continue;
        }

        final Map<String, dynamic> searchFilter = {
          "keywords": searchKeywords,
          "searchQuery": filter.search,
          "dataToBeSearched": _getDataForSearchQuery(
            filter.search,
            adaptedVnData,
          ),
        };

        final bool canContinue = _canVnPassFilters(
          filter,
          filterService,
          searchFilter,
          adaptedVnData,
        );
        if (canContinue) {
          matchingItems.add(_toVnWidget(adaptedVnData, sort));
        }
      }
      controller.add(statusCode: statusName, data: matchingItems);
    }
  }

  //
  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  //

  static bool isUsingFilter(FilterData conf) {
    // Checks whether the current filter is not the same as the default one or
    // the same.
    return conf.copyWith(search: conf.search.trim()) !=
        Default.LOCAL_FILTER_CONF;
  }

  static List<String> _getSearchKeywords(String? searchQuery) {
    if (searchQuery!.length > 4 && searchQuery.substring(0, 4) == 'dev:') {
      return searchQuery.substring(4, searchQuery.length).split(',');
    }

    if (searchQuery.length > 4 && searchQuery.substring(0, 4) == 'tag:') {
      return searchQuery.substring(4, searchQuery.length).split(',');
    }

    return [];
  }

  //
  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  //

  static bool _isSearchingForAll(String? searchQuery) {
    return searchQuery == " " || searchQuery == null || searchQuery.isEmpty;
  }

  static bool _isSearchingForDevs(String searchQuery) {
    return searchQuery.length > 4 && searchQuery.substring(0, 4) == 'dev:';
  }

  static bool _isSearchingForTags(String searchQuery) {
    return searchQuery.length > 4 && searchQuery.substring(0, 4) == 'tag:';
  }

  static String _getDataForSearchQuery(
    String? searchQuery,
    Map<String, dynamic> vnData,
  ) {
    if (_isSearchingForAll(searchQuery)) return " ";
    if (_isSearchingForDevs(searchQuery!)) return "${vnData['devs']}";
    if (_isSearchingForTags(searchQuery)) return "${vnData['tags']}";

    return "${vnData['title']} ${vnData['japaneseTitle']} ${vnData['aliases']}";
  }

  //
  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  //
  static bool _canVnPassFilters(
    FilterData filter,
    LocalFilterService service,
    Map<String, dynamic> searchFilter,
    Map<String, dynamic> adaptedVnData,
  ) {
    //
    // Filter starts from the search query.
    if (service.searchFiltered(searchFilter)) {
      //
      // Minimum age.
      if (service.minageFiltered(filter.minage, adaptedVnData)) {
        //
        //  Development status.
        if (service.devStatFiltered(filter.devstatus, adaptedVnData)) {
          //
          // Original Language.
          if (service.originlangFiltered(filter.olang, adaptedVnData)) {
            //
            // Available platforms.
            if (service.platformFiltered(filter.platform, adaptedVnData)) {
              //
              // Finally the available languages.
              if (service.languagesFiltered(filter.lang, adaptedVnData)) {
                //
                //
                return true;
              }
            }
          }
        }
      }
    }

    return false;
  }

  //
  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  //

  static VnItemGrid _toVnWidget(
    Map<String, dynamic> adaptedVnData,
    SortData sort,
  ) {
    return VnItemGrid(
      key: ValueKey(adaptedVnData['id']),
      p1: VnDataPhase01.fromMap(adaptedVnData),
      labelCode: sort.sort == SortableCode.custom.name ? '' : sort.sort ?? '',
      isGridView: true,
      collectionStatus: adaptedVnData['status']?.toString(),
    );
  }

  //
  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  //
}
