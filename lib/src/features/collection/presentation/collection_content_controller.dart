import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vndb_lite/src/core/_core.dart';
import 'package:vndb_lite/src/features/_base/presentation/lower_parts/bottom_progress_indicator_state.dart';
import 'package:vndb_lite/src/features/collection/application/collection_vn_service.dart';
import 'package:vndb_lite/src/features/collection/data/collection_status_data.dart';
import 'package:vndb_lite/src/features/collection/data/local/local_collection_repo.dart';
import 'package:vndb_lite/src/features/collection/domain/adapted_vn.dart';
import 'package:vndb_lite/src/features/collection/domain/record.dart';
import 'package:vndb_lite/src/features/collection/application/collection_sort_filter_service.dart';
import 'package:vndb_lite/src/features/sort_filter/domain/filter_.dart';
import 'package:vndb_lite/src/features/sort_filter/domain/sort_.dart';
import 'package:vndb_lite/src/features/vn/data/local_vn_repo.dart';
import 'package:vndb_lite/src/features/vn/data/remote_vn_repo.dart';
import 'package:vndb_lite/src/features/vn/domain/others.dart';
import 'package:vndb_lite/src/features/vn/domain/p1.dart';
import 'package:vndb_lite/src/features/vn/domain/p2.dart';
import 'package:vndb_lite/src/features/vn_item/presentation/vn_item_grid_.dart';

part 'collection_content_controller.g.dart';

//TODO delete unnecessary notifier.

// Containing raw vn data.
final Map<String, List<Map<String, dynamic>>> rawP1BasedOnStatus = {};

/// This notifier is to forcefully update the UI.
@riverpod
class CollectionContentNotifier extends _$CollectionContentNotifier {
  @override
  bool build() {
    return true;
  }

  void ring() => state = true;
  void end() => state = false;
}

@Riverpod(
  keepAlive: true,
  dependencies: [
    localCollectionRepo,
    sharedPref,
    localVnRepo,
    remoteVnRepo,
    validateVnAndSaveToLocal,
  ],
)
class CollectionContentController extends _$CollectionContentController {
  bool _upgradingDeveloperNames = false;

  @override
  Map<String, List<VnItemGrid>> build() => {};

  void add({required String statusCode, required List<VnItemGrid> data}) {
    if (state.containsKey(statusCode)) {
      final tempData = state[statusCode];
      tempData!.addAll(data);

      state[statusCode] = tempData;
    } else {
      state[statusCode] = data;
    }
  }

  //
  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  //

  Future<void> separateVNsByStatus(
    FilterData localFilter,
    SortData localSort, {
    bool searchOnly = false,
  }) async {
    final alreadyThereAProcess = ref.read(bottomProgressIndicatorProvider);

    // For the sake of simplicity, the progress indicator will be treated in here
    if (!alreadyThereAProcess) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        ref.read(bottomProgressIndicatorProvider.notifier).show = true;
      });
    }

    final localCollectionRepo = ref.read(localCollectionRepoProvider);

    try {
      await localCollectionRepo.refreshCollection();
      final List<String> dbCollection = localCollectionRepo.rawAllRecords;
      cleanCurrentData(searchOnly);

      if (dbCollection.isEmpty) return;

      if (!searchOnly) {
        await _adaptingRawData(localFilter);
        await CollectionSortFilterService.sortData(localSort);
        await localCollectionRepo.refreshCollection();
      }

      await CollectionSortFilterService.filterData(localFilter, localSort);
      ref.read(collectionContentNotifierProvider.notifier).ring();
      if (!searchOnly) unawaited(_upgradeLegacyDeveloperNames());
      //
    } catch (e) {
      // TODO snackbar telling something's wrong.
      debugPrint(e.toString());
    } finally {
      // Expecting that the caller of this function has another process and will handle the progress indicator
      // further, so it doesn't have to be turned off.
      if (!alreadyThereAProcess) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          ref.read(bottomProgressIndicatorProvider.notifier).show = false;
        });
      }
    }

    return;
  }

  /// Adds VNDB's original-script developer names to older cached collection
  /// entries. The refresh runs after the collection is already visible.
  Future<void> _upgradeLegacyDeveloperNames() async {
    if (_upgradingDeveloperNames) return;

    final legacyEntries = [
      for (final entries in rawP1BasedOnStatus.values)
        for (final entry in entries)
          if (entry['devsOriginal'] == null &&
              entry['devs'] is List &&
              (entry['devs'] as List).isNotEmpty)
            entry,
    ];
    if (legacyEntries.isEmpty) return;

    _upgradingDeveloperNames = true;
    var updated = false;
    try {
      final localVnRepo = ref.read(localVnRepoProvider);
      final remoteVnRepo = ref.read(remoteVnRepoProvider);
      final ids =
          legacyEntries.map((entry) => entry['id'] as String).toSet().toList();

      for (var start = 0; start < ids.length; start += 100) {
        final end = (start + 100 < ids.length) ? start + 100 : ids.length;
        final chunk = ids.sublist(start, end);
        final response = await remoteVnRepo.fetchDeveloperNames(chunk);
        final dynamic results = response.data['results'];
        if (results is! List) continue;

        for (final result in results) {
          if (result is! Map) continue;
          final data = Map<String, dynamic>.from(result);
          final id = data['id']?.toString();
          final developers = data['developers'];
          if (id == null || developers is! List || developers.isEmpty) {
            continue;
          }

          final names = <String>[];
          final originals = <String>[];
          for (final developer in developers) {
            if (developer is! Map) continue;
            final name = developer['name']?.toString() ?? '';
            if (name.isEmpty) continue;
            names.add(name);
            final original = developer['original']?.toString();
            originals.add(
              (original == null || original.isEmpty) ? name : original,
            );
          }
          if (names.isEmpty) continue;

          final cached = await localVnRepo.getP2(id);
          if (cached == null || cached.developerOriginals != null) continue;
          final refreshed = cached.copyWith(
            developers: names,
            developerOriginals: originals,
          );
          await localVnRepo.saveVnContent(refreshed);

          for (final entry in legacyEntries.where(
            (entry) => entry['id'] == id,
          )) {
            entry['devs'] = names;
            entry['devsOriginal'] = originals;
          }
          updated = true;
        }
      }

      if (updated) ref.read(collectionContentNotifierProvider.notifier).ring();
    } catch (error) {
      // Keep the collection usable offline; retry the migration next time it
      // is loaded.
      debugPrint('Could not refresh VNDB original developer names: $error');
    } finally {
      _upgradingDeveloperNames = false;
    }
  }

  //
  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  //

  void cleanCurrentData(bool searchOnly) {
    for (String statusName in COLLECTION_STATUS_DATA.keys) {
      // This means that when searching only, rawdata is safe and can be processed
      // into widget with the new given filter or sort configuration, without having to
      // generate all the raw vnData again.
      if (!searchOnly) {
        rawP1BasedOnStatus[statusName] = [];
      }

      state[statusName] = []; // Widgets clean
    }
  }

  /// Moves an item within a status tab and persists the custom order by VN ID.
  Future<void> reorderCustom(
    String statusName,
    int oldIndex,
    int newIndex,
  ) async {
    final widgets = [...?state[statusName]];
    if (newIndex > oldIndex) newIndex--;
    if (oldIndex < 0 ||
        newIndex < 0 ||
        oldIndex >= widgets.length ||
        newIndex >= widgets.length) {
      return;
    }

    final movedWidget = widgets.removeAt(oldIndex);
    widgets.insert(newIndex, movedWidget);
    state = {...state, statusName: widgets};

    final raw = rawP1BasedOnStatus[statusName];
    if (raw != null && oldIndex < raw.length) {
      final movedRaw = raw.removeAt(oldIndex);
      raw.insert(newIndex, movedRaw);
    }

    await ref.read(localCollectionRepoProvider).saveCustomOrder(statusName, [
      for (final item in widgets) item.p1.id,
    ]);
  }

  //
  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  //

  Future<void> _adaptingRawData(FilterData conf) async {
    final localCollectionRepo = ref.read(localCollectionRepoProvider);
    final networkInfo = ref.read(connectivityNotifierProvider);
    final localVnRepo = ref.read(localVnRepoProvider);

    for (VnRecord vnRecord in await localCollectionRepo.getAllRecords()) {
      final String vnId = vnRecord.id;
      final String statusName = vnRecord.status.toLowerCase();

      // Prevent duplication, will remove duplication and skip the current vn.
      if (_hasDuplicate(statusName, vnId)) {
        _removeDuplication(statusName, vnId);
        continue;
      }

      // Checks whether either p1 or p2 data is null for the corresponding vn.
      if (!localVnRepo.p1Exist(vnId) || !localVnRepo.p2Exist(vnId)) {
        bool isConnected = false;

        final valid = await ref.read(
          validateVnAndSaveToLocalProvider(vnId).future,
        );
        isConnected = networkInfo;

        // Skip the loop. Ignore the current record.
        if (!valid) {
          // Will delete current vn record, if even with internet connection access, the corresponding
          // vn is not valid.
          if (isConnected) {
            await localCollectionRepo.removeVnRecord(vnId);
          }
          continue;
        }
      }

      // Clustering each vn item collection record by its status.
      final AdaptedVnData vnData = await getAdaptedVnData(vnRecord);
      rawP1BasedOnStatus[statusName]!.add(vnData.toMap());
    }
  }

  //
  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  //

  bool _hasDuplicate(String statusName, String vnId) {
    return (state[statusName] ?? [])
        .where((item) => item.p1.id == vnId)
        .isNotEmpty;
  }

  void _removeDuplication(String statusName, String vnId) {
    rawP1BasedOnStatus[statusName]!.removeWhere(
      (record) => record['id'] == vnId,
    );
    state[statusName]!.removeWhere((record) => record.p1.id == vnId);
  }

  Future<AdaptedVnData> getAdaptedVnData(VnRecord vnRecord) async {
    final localVnRepo = ref.read(localVnRepoProvider);

    final VnDataPhase01 p1 = (await localVnRepo.getP1(vnRecord.id))!;
    final VnDataPhase02 p2 = (await localVnRepo.getP2(vnRecord.id))!;

    final AdaptedVnData adaptedData = AdaptedVnData(
      id: vnRecord.id,
      status: vnRecord.status,
      title: vnRecord.title,
      started: vnRecord.started ?? '0',
      added: vnRecord.added ?? '0',
      vote: vnRecord.vote,
      // Using full p1, since at the end of the filtering process, it will be used by VnItemrid.
      p1: p1,
      aliases: p2.aliases!,
      length_minutes: p2.length_minutes!,
      devs: p2.developers!,
      devsOriginal: p2.developerOriginals,
      devstatus: p2.devstatus!,
      languages: p2.languages!,
      minage: p2.minage!,
      tags: [for (VnTag tag in p2.tags!) tag.name!],
      platforms: p2.platforms!,
    );

    // Uncomment either one below for optimization.
    // Unknown minage will be treated as All-ages.
    // if (adaptedData.minage.isEmpty) final newData = adaptedData.copyWith(minage: [0, 1]);

    // Unknown minage will be treated as Adult-only.
    // if (adaptedData.minage.isEmpty) final newData = adaptedData.copyWith(minage: [19, 20]);

    return adaptedData;
  }

  //
  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  //
}
