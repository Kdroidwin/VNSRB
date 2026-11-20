import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vndb_lite/src/constants/defaults.dart';
import 'package:vndb_lite/src/constants/network_constants.dart';
import 'package:vndb_lite/src/core/network/api_service.dart';
import 'package:vndb_lite/src/features/collection/data/collection_status_data.dart';
import 'package:vndb_lite/src/features/collection/data/local/local_collection_repo.dart';
import 'package:vndb_lite/src/features/collection/domain/record.dart';
import 'package:vndb_lite/src/features/sort_filter/data/sortable_data.dart';
import 'package:vndb_lite/src/features/sync/data/remote/remote_sync_repo_helper.dart';

part 'remote_sync_repo.g.dart';

class RemoteSyncRepo {
  RemoteSyncRepo(this._apiService, this._collection);

  final ApiService _apiService;
  final LocalCollectionRepo _collection;

  static const authEndpoint = "${NetConsts.BASE_URL}/kana/authinfo";
  static final _authTokenPattern = RegExp(r'^[A-Za-z0-9-]{28,38}$');

  //
  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  //

  Future<Response> authenticate(String token) async {
    _validateAuthToken(token);
    return await _apiService.get(
      url: authEndpoint,
      options: Options(
        followRedirects: false,
        headers: {'Authorization': 'token $token'},
      ),
    );
  }

  //
  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  //

  Future<void> removeResidualData() async {
    await _collection.cleanAddedViaAppNotBySync();
    await _collection.cleanVnToBeRemovedWhenSync();
    await _collection.refreshCollection();
    cleanFetchLatestData();
    return;
  }

  //
  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  //

  static const _maxSyncedRecords = 50000;
  static final _userIdPattern = RegExp(r'^u[0-9]{1,12}$');
  static final _vnIdPattern = RegExp(r'^v[0-9]{1,10}$');

  Future<List<Map<String, dynamic>>> getLatestDataFromCloud(
    String userId,
  ) async {
    if (!_userIdPattern.hasMatch(userId)) {
      throw const FormatException('Invalid VNDB user ID.');
    }

    // Keep pagination local to this call. The remote response is untrusted,
    // so require a finite result set and validate each entry before syncing.
    final records = <Map<String, dynamic>>[];
    final seenIds = <String>{};
    var page = 1;
    var hasMore = true;
    while (hasMore) {
      final response = await _apiService.post(
        url: "${NetConsts.BASE_URL}/kana/ulist",
        data: {
          "user": userId,
          "sort": SortableCode.added.name,
          "fields": NetConsts.USER_VNS_FIELDS,
          "results": Default.MAX_VN_SEARCH_RESULT,
          "page": page,
        },
      );

      final data = response.data;
      if (data is! Map || data['results'] is! List || data['more'] is! bool) {
        throw const FormatException('Invalid VNDB collection response.');
      }
      final pageRecords = data['results'] as List;
      if (pageRecords.length > Default.MAX_VN_SEARCH_RESULT ||
          records.length > _maxSyncedRecords - pageRecords.length) {
        throw const FormatException('VNDB collection exceeds the sync limit.');
      }

      for (final rawRecord in pageRecords) {
        if (rawRecord is! Map) {
          throw const FormatException('Invalid VNDB collection entry.');
        }
        final record = Map<String, dynamic>.from(rawRecord);
        _validateCloudRecord(record);
        final id = record['id'] as String;
        if (!seenIds.add(id)) {
          throw const FormatException('Duplicate VNDB collection entry.');
        }
        records.add(record);
      }

      hasMore = data['more'] as bool;
      if (hasMore && pageRecords.isEmpty) {
        throw const FormatException(
          'VNDB returned an empty continuation page.',
        );
      }
      page++;
      if (hasMore &&
          page > (_maxSyncedRecords ~/ Default.MAX_VN_SEARCH_RESULT) + 1) {
        throw const FormatException(
          'VNDB collection pagination exceeded limits.',
        );
      }
    }
    return records;
  }

  static void _validateCloudRecord(Map<String, dynamic> record) {
    final id = record['id'];
    final vn = record['vn'];
    final labels = record['labels'];
    final notes = record['notes'];
    final vote = record['vote'];
    final added = record['added'];
    final lastmod = record['lastmod'];
    final started = record['started'];
    final finished = record['finished'];

    if (id is! String ||
        !_vnIdPattern.hasMatch(id) ||
        vn is! Map ||
        vn['title'] is! String ||
        (vn['title'] as String).isEmpty ||
        (vn['title'] as String).length > 4096 ||
        labels is! List ||
        labels.length > 100 ||
        labels.any(
          (label) =>
              label is! Map ||
              label['label'] is! String ||
              (label['label'] as String).length > 128,
        ) ||
        (notes != null && (notes is! String || notes.length > 8192)) ||
        (vote != null &&
            (vote is! num || !vote.isFinite || vote < 0 || vote > 100)) ||
        (added != null && (added is! int || added < 0)) ||
        (lastmod != null && (lastmod is! int || lastmod < 0)) ||
        (started != null && (started is! String || !_isIsoDate(started))) ||
        (finished != null && (finished is! String || !_isIsoDate(finished)))) {
      throw const FormatException('Invalid VNDB collection entry values.');
    }
  }

  static bool _isIsoDate(String value) =>
      RegExp(r'^[0-9]{4}-[0-9]{2}-[0-9]{2}$').hasMatch(value);

  void cleanFetchLatestData() {
    // Kept for existing sync callers; pagination state is local now.
  }

  //
  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  //

  // TODO sync snackbar/user feedback when data is deleted/saved/modified.
  Future<List> filterAndSyncRecords(
    List<VnRecord> localRecords,
    List cloudRecords, {
    required String authToken,
  }) async {
    final List vnRecordsToBeSaved = [];
    final localRecordsById = {
      for (final record in localRecords) record.id: record,
    };
    final cloudRecordsById = <String, Map<String, dynamic>>{
      for (final record in cloudRecords.cast<Map<String, dynamic>>())
        record['id'] as String: record,
    };

    // Debugging purpose.
    // debugPrint("LOCAL RECORDS (${localRecords.length}) \n$localRecords");
    // debugPrint("CLOUD RECORDS (${cloudRecords.length}) \n$cloudRecords");
    // debugPrint(
    //   "VN TO BE REMOVED (${_collection.vnToBeRemovedWhenSync.length}) \n${_collection.vnToBeRemovedWhenSync}",
    // );
    // debugPrint(
    //   "VN ADDED VIA APP (${_collection.addedViaAppNotBySync.length}) \n${_collection.addedViaAppNotBySync}",
    // );

    // *** Filter the cloudRecords.
    for (Map<String, dynamic> cloudRecord in cloudRecords) {
      final cloudRecordInTheLocal = localRecordsById[cloudRecord['id']];

      // ** MODIFYING SECTION
      // * If cloud record exists in the local: Then do nothing. Intersection already handled by
      // * the localRecord filter.

      // ** ADDING/DELETING SECTION CONTD.
      // * If cloud record does not exist in the local.
      if (cloudRecordInTheLocal == null) {
        // * 1. If ever deleted before, then delete the vn too in the cloud.
        if (_collection.getVnToBeRemovedWhenSync().contains(
          cloudRecord['id']!,
        )) {
          await delete(cloudRecord['id']!, authToken: authToken);
          continue;
        }

        // * 2. If never exists before, then save it to the local.
        vnRecordsToBeSaved.add(cloudRecord);
      }
    }

    // *** Filter the localRecords.
    for (VnRecord localRecord in localRecords) {
      final int statusId =
          COLLECTION_STATUS_DATA[localRecord.status.toLowerCase()]!.id;
      final localRecordInTheCloud = cloudRecordsById[localRecord.id];

      // ** MODIFYING SECTION
      // * If local record exists in the cloud. (Just need to be done once)
      if (localRecordInTheCloud != null) {
        // * Preparing for comparing data to check for any changes.
        await compareNewerRecords(
          localRecord,
          localRecordInTheCloud,

          // ? If remote it'll just override the current existing local record.
          ifRemote: () async {
            vnRecordsToBeSaved.add(localRecordInTheCloud);
          },

          // ? If local it'll override the cloud record.
          ifLocal: () async {
            vnRecordsToBeSaved.add(localRecord);

            // * For behavioral issue of the API (or maybe I was drunk at that time, jk), such logic happen:
            // * If vote exists in vn, then delete the vn first, and then repost the record.
            if (localRecord.vote != 0) {
              await delete(localRecordInTheCloud['id']!, authToken: authToken);
            }

            await post(localRecord, authToken: authToken, statusId: statusId);
          },
        );
      }

      // ** ADDING/DELETING SECTION
      // * If local record does not exist in the cloud. Then:
      // * 1. If VN originally added from the app, then backup it to the server.
      if (_collection.getAddedViaAppNotBySync().contains(localRecord.id)) {
        await post(localRecord, authToken: authToken, statusId: statusId);
        vnRecordsToBeSaved.add(localRecord);
        continue;
      }

      // * 2. If not number 1, then the record already deleted from the server,
      // * then sync the deletion to local too.
      await _collection.removeVnRecord(localRecord.id);
      await _collection.refreshCollection();
    }

    // Debugging purpose.
    // print("RESULTS (${vnRecordsToBeSaved.length}): $vnRecordsToBeSaved");
    return vnRecordsToBeSaved;
  }

  //
  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  //

  Future<void> delete(String vnId, {required String authToken}) async {
    _validateVnId(vnId);
    _validateAuthToken(authToken);
    return await Future.delayed(const Duration(milliseconds: 1200), () async {
      await _apiService.delete(
        url: "${NetConsts.BASE_URL}/kana/ulist/$vnId",
        options: Options(
          contentType: 'application/json',
          followRedirects: false,
          headers: {'Authorization': 'token $authToken'},
        ),
      );
    });
  }

  //
  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  //

  Future<void> post(
    VnRecord localRecord, {
    required String authToken,
    required int statusId,
  }) async {
    _validateVnId(localRecord.id);
    _validateAuthToken(authToken);
    return await Future.delayed(const Duration(milliseconds: 1200), () async {
      // Despite how the method name is "patch", it still works logically as if posting
      // a new data related to the user, that is, posting new vnrecord related to the user.
      await _apiService.patch(
        url: "${NetConsts.BASE_URL}/kana/ulist/${localRecord.id}",
        options: Options(
          contentType: 'application/json',
          followRedirects: false,
          headers: {'Authorization': 'token $authToken'},
        ),
        data: {
          'labels': [statusId],
          // * If vote data does exist.
          if (localRecord.vote != 0) 'vote': localRecord.vote * 10,
          'notes': localRecord.notes ?? "",
          'started': getLocalVnDate('started', localRecord.toMap()),
          'finished': getLocalVnDate('finished', localRecord.toMap()),
        },
      );
    });
  }

  static void _validateVnId(String vnId) {
    if (!_vnIdPattern.hasMatch(vnId)) {
      throw const FormatException('Invalid VNDB visual novel ID.');
    }
  }

  static void _validateAuthToken(String token) {
    if (!_authTokenPattern.hasMatch(token)) {
      throw const FormatException('Invalid VNDB authentication token.');
    }
  }

  //
  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  //
}

@Riverpod(dependencies: [apiService, localCollectionRepo])
RemoteSyncRepo remoteSyncRepo(Ref ref) {
  final apiService = ref.watch(apiServiceProvider);
  final localCollectionRepo = ref.watch(localCollectionRepoProvider);
  return RemoteSyncRepo(apiService, localCollectionRepo);
}

@Riverpod(dependencies: [remoteSyncRepo])
Future<Response> authenticate(Ref ref, String token) async {
  final remoteSyncRepo = ref.watch(remoteSyncRepoProvider);
  return await remoteSyncRepo.authenticate(token);
}
