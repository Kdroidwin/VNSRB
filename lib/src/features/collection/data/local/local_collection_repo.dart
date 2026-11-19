// ignore_for_file: unnecessary_brace_in_string_interps

import 'dart:async';
import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vndb_lite/src/constants/local_db_constants.dart';
import 'package:vndb_lite/src/core/local_db/shared_prefs.dart';
import 'package:vndb_lite/src/features/collection/data/collection_status_data.dart';
import 'package:vndb_lite/src/features/collection/domain/record.dart';
import 'package:vndb_lite/src/features/home/data/local/local_home_repo.dart';

part 'local_collection_repo.g.dart';

class LocalCollectionRepo {
  const LocalCollectionRepo(this._sharedPref, this._localHomeRepo);

  static const _maxBackupRecords = 50000;
  static const _maxRecordBytes = 65536;
  static const _maxCachedVnBytes = 4 * 1024 * 1024;

  final SharedPreferences _sharedPref;
  final LocalHomeRepoImpl _localHomeRepo;

  Future<void> refreshCollection() async {
    await _sharedPref.reload();
  }

  //
  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  //

  Future<void> saveVnRecord(VnRecord vnRecord) async {
    final int? sectionRange = getSectionFromId(vnRecord.id);

    if (sectionRange == null) {
      // TODO do this more.
      throw Exception(
        'Bad sectionRange. Please check the typical vn id (e.g v12345).',
      );
    }

    final List<String> collection =
        _sharedPref.getStringList(
          '${DBKeys.SAVED_COLLECTION_OF_SECTION_V}$sectionRange',
        ) ??
        [];

    // In order to prevent duplication, if vn record exists, then remove first.
    collection.removeWhere((record) => record.contains('"${vnRecord.id}"'));

    // ! Breaking change for version > 2.0.0, assign lastmod property for VN record.
    collection.add(
      vnRecord
          .copyWith(
            lastmod: (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString(),
          )
          .toJson(),
    );

    // Override data
    await _sharedPref.setStringList(
      '${DBKeys.SAVED_COLLECTION_OF_SECTION_V}$sectionRange',
      collection,
    );

    // Updates home interface
    await _updateSectionRangeList(vnRecord.id);
    await _localHomeRepo.insertCollectionPreview(vnRecord.id);
  }

  //
  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  //

  Future<void> removeVnRecord(String vnId) async {
    final int? sectionRange = getSectionFromId(vnId);

    if (sectionRange == null) {
      throw Exception(
        'Bad sectionRange. Please check the typical vn id (e.g v12345).',
      );
    }

    // If section never exists, just ignore it.
    if (!_sharedPref.containsKey(
      '${DBKeys.SAVED_COLLECTION_OF_SECTION_V}$sectionRange',
    ))
      return;

    final List<String> collection =
        _sharedPref.getStringList(
          '${DBKeys.SAVED_COLLECTION_OF_SECTION_V}$sectionRange',
        ) ??
        [];

    collection.removeWhere((vnRecord) => vnRecord.contains('"$vnId"'));

    await _sharedPref.setStringList(
      '${DBKeys.SAVED_COLLECTION_OF_SECTION_V}$sectionRange',
      collection,
    );

    await _updateSectionRangeList(vnId);
    await _localHomeRepo.popCollectionPreview(vnId);
  }

  //
  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  //

  Future<void> _updateSectionRangeList(String vnId) async {
    final List<String> currentSectionRangeLists =
        _sharedPref.getStringList(DBKeys.SAVED_COLLECTION_SECTIONS) ?? [];
    final int sectionRange = getSectionFromId(vnId)!;

    if (currentSectionRangeLists.contains('$sectionRange')) {
      final VnRecord? vnInCollection = getVnRecordFromId(vnId);

      // If a section found have nothing inside, then delete the section.
      if (vnInCollection == null) {
        await _sharedPref.remove(
          '${DBKeys.SAVED_COLLECTION_OF_SECTION_V}$sectionRange',
        );
        currentSectionRangeLists.remove('$sectionRange');
      }
      //
    } else {
      //
      currentSectionRangeLists.add('$sectionRange');
    }

    await _sharedPref.setStringList(
      DBKeys.SAVED_COLLECTION_SECTIONS,
      currentSectionRangeLists,
    );
  }

  //
  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  //

  VnRecord? getVnRecordFromId(String vnId) {
    final int? sectionRange = getSectionFromId(vnId);
    final List<String> collection = getVnRecordsFromSection('$sectionRange');

    final rawVnRecord = collection.firstWhereOrNull(
      (savedVn) => savedVn.contains('"$vnId"'),
    );

    if (rawVnRecord == null) return null;
    return VnRecord.fromMap(json.decode(rawVnRecord));
  }

  //
  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  //

  int? getSectionFromId(String vnId) {
    final int vnRecordsPerSection = 100;

    // Expected raw vnId is one letter prefix, the rest are numbers. (v34522)
    final int? extractedVnId = int.tryParse(
      vnId.toLowerCase().replaceAll("v", ""),
    );
    if (extractedVnId == null) return null;

    // (~/) is dart's floor division operator syntax, not to confuse with (%) modulo.
    final int sectionCode = extractedVnId ~/ vnRecordsPerSection;
    if (sectionCode == 0) return vnRecordsPerSection;

    // Added one to prevent having a sectionRange with 200 items, since V100 used for those
    // id under 100 (see above), and if sectionCode == 1 comes to play, it will also have the same
    // sectionRange of V100 (sectionCode * 100), so afterwards, the sectionRange must be incremented
    // specifically by one except for sectionCode of 0.
    return (sectionCode + 1) * vnRecordsPerSection;
  }

  //
  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  //

  List<String> getVnRecordsFromSection(String sectionRange) {
    return _sharedPref.getStringList(
          '${DBKeys.SAVED_COLLECTION_OF_SECTION_V}$sectionRange',
        ) ??
        [];
  }

  //
  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  //

  List<String> get rawAllRecords {
    final collectionSections =
        _sharedPref.getStringList(DBKeys.SAVED_COLLECTION_SECTIONS) ?? [];
    List<String> fullCollectionList = [];

    for (String sectionRange in collectionSections) {
      final List<String> collectionPerSection = getVnRecordsFromSection(
        sectionRange,
      );

      // Appending the previous results.
      if (collectionPerSection.isNotEmpty) {
        fullCollectionList = [...fullCollectionList, ...collectionPerSection];
      }
    }

    return fullCollectionList;
  }

  //
  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  //

  Future<void> removeAllCollection({required bool includeSync}) async {
    // A case scenario where user already once synchronized with the server, and for some reason,
    // they want to delete or remove all of their collections, then the below operation must also
    // be executed, in order to also remove those collections in their cloud account too.
    // But ONLY will happen, if they're clicking the sync button again.
    final List<String> removeVnIds = getVnToBeRemovedWhenSync();
    if (includeSync) {
      final allRecords = await getAllRecords();
      for (VnRecord record in allRecords) {
        removeVnIds.add(record.id);
      }

      await setVnToBeRemovedWhenSync(removeVnIds);
    }

    final collectionSections =
        _sharedPref.getStringList(DBKeys.SAVED_COLLECTION_SECTIONS) ??
        <String>[];
    for (String sectionRange in collectionSections) {
      //
      if (_sharedPref.containsKey(
        '${DBKeys.SAVED_COLLECTION_OF_SECTION_V}$sectionRange',
      )) {
        await _sharedPref.remove(
          '${DBKeys.SAVED_COLLECTION_OF_SECTION_V}$sectionRange',
        );
      }
    }

    await _sharedPref.remove(DBKeys.SAVED_COLLECTION_SECTIONS);
    await _localHomeRepo.clearAllLocalCachedPreviews();
  }

  //
  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  //

  Future<void> cleanVnToBeRemovedWhenSync() async {
    await _sharedPref.setStringList(DBKeys.VN_RECORDS_TO_BE_REMOVED, []);
  }

  Future<void> setVnToBeRemovedWhenSync(List<String> vnId) async {
    List<String> vns =
        _sharedPref.getStringList(DBKeys.VN_RECORDS_TO_BE_REMOVED) ?? [];
    vns = [...vns, ...vnId];

    await _sharedPref.setStringList(DBKeys.VN_RECORDS_TO_BE_REMOVED, vns);
  }

  List<String> getVnToBeRemovedWhenSync() {
    return _sharedPref.getStringList(DBKeys.VN_RECORDS_TO_BE_REMOVED) ?? [];
  }

  /// Returns the user-defined order for one collection status tab.
  List<String> getCustomOrder(String status) =>
      _sharedPref.getStringList('${DBKeys.COLLECTION_CUSTOM_ORDER}$status') ??
      [];

  /// Saves only IDs, keeping custom display order local and independent from
  /// VNDB synchronization data.
  Future<void> saveCustomOrder(String status, List<String> ids) => _sharedPref
      .setStringList('${DBKeys.COLLECTION_CUSTOM_ORDER}$status', ids);

  Map<String, dynamic> exportBackup() {
    final records = rawAllRecords;
    final cachedVnData = <String, Map<String, String>>{};
    for (final rawRecord in records) {
      final id = VnRecord.fromJson(rawRecord).id;
      final p1 = _sharedPref.getString('${DBKeys.P1}$id');
      final p2 = _sharedPref.getString('${DBKeys.P2}$id');
      if (p1 != null || p2 != null) {
        cachedVnData[id] = {if (p1 != null) 'p1': p1, if (p2 != null) 'p2': p2};
      }
    }

    return {
      'format': 'vnpockets-collection-backup',
      'version': 2,
      'records': records,
      'vnData': cachedVnData,
      'customOrders': {
        for (final status in CollectionStatusCode.values)
          status.name: getCustomOrder(status.name),
      },
    };
  }

  Future<int> importBackup(Map<String, dynamic> backup) async {
    final records = recordsFromBackup(backup);
    final importedIds = records.map((record) => record.id).toSet();
    for (final record in records) {
      await saveVnRecord(record);
    }

    final vnData = backup['vnData'];
    if (vnData is Map) {
      for (final entry in vnData.entries) {
        final id = entry.key;
        final data = entry.value;
        if (id is! String || !importedIds.contains(id) || data is! Map) {
          continue;
        }
        await _restoreCachedVnData(id, 1, data['p1']);
        await _restoreCachedVnData(id, 2, data['p2']);
      }
    }

    final orders = backup['customOrders'];
    if (orders is Map) {
      for (final status in CollectionStatusCode.values) {
        final values = orders[status.name];
        if (values is List) {
          await saveCustomOrder(
            status.name,
            values.whereType<String>().where(importedIds.contains).toList(),
          );
        }
      }
    }
    return records.length;
  }

  /// Performs side-effect-free structural validation before a full archive
  /// import starts writing files or preferences.
  static List<VnRecord> recordsFromBackup(Map<String, dynamic> backup) {
    if (backup['format'] != 'vnpockets-collection-backup' ||
        backup['records'] is! List) {
      throw const FormatException('This is not a VNSRB collection backup.');
    }
    final version = backup['version'];
    if (version != null && (version is! int || version < 1 || version > 2)) {
      throw const FormatException('Unsupported collection backup version.');
    }

    final rawRecords = backup['records'] as List;
    if (rawRecords.length > _maxBackupRecords) {
      throw const FormatException('Collection backup has too many entries.');
    }
    final recordsById = <String, VnRecord>{};
    for (final raw in rawRecords) {
      try {
        if (raw is String && raw.length <= _maxRecordBytes) {
          final record = VnRecord.fromJson(raw);
          _validateRecord(record);
          recordsById[record.id] = record;
        } else if (raw is Map) {
          final record = VnRecord.fromMap(Map<String, dynamic>.from(raw));
          _validateRecord(record);
          recordsById[record.id] = record;
        } else {
          throw const FormatException('Invalid collection entry.');
        }
      } catch (_) {
        throw const FormatException('Invalid collection entry in backup.');
      }
    }

    _validateCachedVnData(backup['vnData'], recordsById.keys.toSet());
    _validateCustomOrders(backup['customOrders']);
    return recordsById.values.toList(growable: false);
  }

  static void _validateRecord(VnRecord record) {
    final validStatus = CollectionStatusCode.values.any(
      (status) => status.name == record.status,
    );
    if (!RegExp(r'^v[0-9]{1,10}$').hasMatch(record.id) ||
        record.title.trim().isEmpty ||
        record.title.length > 4096 ||
        !validStatus ||
        record.vote < -1 ||
        record.vote > 10 ||
        (record.notes?.length ?? 0) > 8192 ||
        (record.added?.length ?? 0) > 128 ||
        (record.started?.length ?? 0) > 128 ||
        (record.finished?.length ?? 0) > 128 ||
        (record.lastmod?.length ?? 0) > 128) {
      throw const FormatException('Invalid collection entry values.');
    }
  }

  static void _validateCachedVnData(dynamic rawData, Set<String> recordIds) {
    if (rawData == null) return;
    if (rawData is! Map || rawData.length > _maxBackupRecords) {
      throw const FormatException('Invalid cached VN data.');
    }
    for (final entry in rawData.entries) {
      if (entry.key is! String ||
          !recordIds.contains(entry.key) ||
          entry.value is! Map) {
        throw const FormatException('Invalid cached VN data entry.');
      }
      final data = entry.value as Map;
      if (data.keys.any((key) => key != 'p1' && key != 'p2')) {
        throw const FormatException('Unknown cached VN data.');
      }
      for (final phase in const ['p1', 'p2']) {
        final value = data[phase];
        if (value == null) continue;
        if (value is! String || value.length > _maxCachedVnBytes) {
          throw const FormatException('Cached VN data exceeds limits.');
        }
        try {
          final decoded = jsonDecode(value);
          if (decoded is! Map || decoded['id'] != entry.key) {
            throw const FormatException('Cached VN ID does not match.');
          }
        } on FormatException {
          rethrow;
        } catch (_) {
          throw const FormatException('Invalid cached VN data.');
        }
      }
    }
  }

  static void _validateCustomOrders(dynamic rawOrders) {
    if (rawOrders == null) return;
    if (rawOrders is! Map || rawOrders.length > CollectionStatusCode.values.length) {
      throw const FormatException('Invalid custom collection order.');
    }
    for (final entry in rawOrders.entries) {
      final validStatus = CollectionStatusCode.values.any(
        (status) => status.name == entry.key,
      );
      final values = entry.value;
      if (!validStatus ||
          values is! List ||
          values.length > _maxBackupRecords ||
          values.any(
            (id) => id is! String || !RegExp(r'^v[0-9]{1,10}$').hasMatch(id),
          )) {
        throw const FormatException('Invalid custom collection order.');
      }
    }
  }

  Future<void> _restoreCachedVnData(
    String vnId,
    int phase,
    dynamic value,
  ) async {
    if (value is! String) return;
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map || decoded['id'] != vnId) return;
      await _sharedPref.setString(
        '${phase == 1 ? DBKeys.P1 : DBKeys.P2}$vnId',
        value,
      );
    } catch (_) {
      // Invalid or older cache data does not prevent restoring collection records.
    }
  }

  //
  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  //

  Future<void> cleanAddedViaAppNotBySync() async {
    await _sharedPref.setStringList(DBKeys.VN_RECORDS_ADDED_BY_APP, []);
  }

  /// Returns an ID of VNs that are added directly by the app in order
  /// to not conflict with VNs that are added by synchronizing from the
  /// cloud.
  Future<void> setAddedViaAppNotBySync(List<String> vnId) async {
    List<String> vns =
        _sharedPref.getStringList(DBKeys.VN_RECORDS_ADDED_BY_APP) ?? [];
    vns = [...vns, ...vnId];

    await _sharedPref.setStringList(DBKeys.VN_RECORDS_ADDED_BY_APP, vns);
  }

  /// Returns an ID of VNs that are added directly by the app in order
  /// to not conflict with VNs that are added by synchronizing from the
  /// cloud.
  List<String> getAddedViaAppNotBySync() {
    return _sharedPref.getStringList(DBKeys.VN_RECORDS_ADDED_BY_APP) ?? [];
  }

  //
  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  //

  List<String> getRawRecords(List<VnRecord> records) {
    final List<String> tempDB = [];
    for (VnRecord vnRecord in records) {
      tempDB.add(json.encode(vnRecord.toMap()));
    }

    return tempDB;
  }

  //
  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  //

  Future<List<VnRecord>> getAllRecords([
    List<String>? partialCollection,
  ]) async {
    final List<String> dbCollection = partialCollection ?? rawAllRecords;
    return [
      for (String rawRecord in dbCollection) VnRecord.fromJson(rawRecord),
    ];
  }

  //
  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  //
}

@Riverpod(dependencies: [sharedPref, localHomeRepo])
LocalCollectionRepo localCollectionRepo(Ref ref) {
  final sharedPref = ref.watch(sharedPrefProvider);
  final localHomeRepo = ref.watch(localHomeRepoProvider);
  return LocalCollectionRepo(sharedPref, localHomeRepo);
}
