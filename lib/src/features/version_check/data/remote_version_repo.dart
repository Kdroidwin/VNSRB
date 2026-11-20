import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:version/version.dart';

import '../../../constants/_constants.dart';
import '../../../core/_core.dart';
import '../domain/version_check.dart';
import 'version_repo_.dart';

part 'remote_version_repo.g.dart';

class RemoteVersionCheckRepo implements VersionCheckRepo {
  RemoteVersionCheckRepo(this._apiService);

  final ApiService _apiService;

  // ! Fetched data is expected to be in this particular format:
  // ! {"requiredV": "1.2.0", "latestV": "1.2.5"}
  // ! See VERSION.json for example.
  /// Fetch formatted version data.
  @override
  Future<VersionCheck> getVersionCheck() async {
    final response = await fetchLatestVersion();
    return _parseVersionFromResponse(response);
  }

  /// Fetch raw latest version data.
  Future<Response> fetchLatestVersion() async {
    return await _apiService.get(
      url: NetConsts.URL_CHECK_VERSION,
      options: Options(responseType: ResponseType.plain),
    );
  }

  VersionCheck _parseVersionFromResponse(Response resp) {
    final payload = resp.data;
    final dynamic mappedResp;
    if (payload is Map) {
      mappedResp = payload;
    } else if (payload is String && payload.length <= 4096) {
      mappedResp = json.decode(payload);
    } else {
      throw const FormatException('Invalid version metadata response.');
    }
    if (mappedResp is! Map ||
        mappedResp['latestV'] is! String ||
        mappedResp['requiredV'] is! String ||
        (mappedResp['latestV'] as String).length > 64 ||
        (mappedResp['requiredV'] as String).length > 64) {
      throw const FormatException('Invalid version metadata response.');
    }
    final latestVer = _parseToVersion(mappedResp['latestV'] as String);
    final currentVer = _parseToVersion(AppInfo.CURRENT_VERSION);
    final requiredToUpdateVer = _parseToVersion(
      mappedResp['requiredV'] as String,
    );

    return VersionCheck(
      latestVersion: latestVer,
      canUpdate: latestVer > currentVer,
      mustUpdate: requiredToUpdateVer > currentVer,
      requiredToUpdateVer: requiredToUpdateVer,
    );
  }

  Version _parseToVersion(String raw) => Version.parse(raw);

  @visibleForTesting
  VersionCheck parseVersionFromResponse(Response resp) =>
      _parseVersionFromResponse(resp);

  @visibleForTesting
  Version parseToVersion(String raw) => _parseToVersion(raw);
}

@Riverpod(dependencies: [apiService])
VersionCheckRepo versionCheckRepo(Ref ref) {
  final apiService = ref.watch(apiServiceProvider);
  return RemoteVersionCheckRepo(apiService);
}
