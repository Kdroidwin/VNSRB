import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:file/local.dart';
import 'package:file/file.dart' hide FileSystem;
import 'package:flutter_cache_manager/src/storage/file_system/file_system.dart'
    as c;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:vndb_lite/src/constants/network_constants.dart';

const _networkTimeout = Duration(seconds: 25);

// TODO

class IOFileSystem implements c.FileSystem {
  const IOFileSystem(this._cacheKey);

  final String _cacheKey;

  static Future<Directory> createDirectory(String key) async {
    // ! Use documents directory instead of temp directory.
    final baseDir = await getApplicationDocumentsDirectory();
    final path = p.join(baseDir.path, key);

    const fs = LocalFileSystem();
    final directory = fs.directory((path));

    await directory.create(recursive: true);
    return directory;
  }

  @override
  Future<File> createFile(String name) async {
    final directory = await createDirectory(_cacheKey);
    if (!(await directory.exists())) await createDirectory(_cacheKey);

    return directory.childFile(name);
  }
}

class CustomCacheManager extends CacheManager with ImageCacheManager {
  static const String key = "vndb_lite_cache";

  static final CustomCacheManager _instance = CustomCacheManager._();

  factory CustomCacheManager() => _instance;

  CustomCacheManager._()
    : super(
        Config(
          key,
          fileSystem: const IOFileSystem(key),
          fileService: VndbImageFileService(),
        ),
      );
}

/// Downloads images only from VNDB's HTTPS image host, without following
/// redirects, forwarding credentials, or buffering unbounded responses.
class VndbImageFileService extends FileService {
  static const _maxImageBytes = 32 * 1024 * 1024;

  final HttpClient _client = HttpClient()..connectionTimeout = _networkTimeout;

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    final uri = Uri.tryParse(url);
    if (url.length > 2048 ||
        uri == null ||
        uri.scheme.toLowerCase() != 'https' ||
        !NetConsts.TRUSTED_IMAGE_HOSTS.contains(uri.host.toLowerCase()) ||
        uri.port != 443 ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment) {
      throw const FormatException('Blocked an untrusted image URL.');
    }
    if (headers?.keys.any(
          (key) =>
              key.toLowerCase() == HttpHeaders.authorizationHeader ||
              key.toLowerCase() == HttpHeaders.cookieHeader,
        ) ??
        false) {
      throw const FormatException('Image requests cannot include credentials.');
    }

    final request = await _client.getUrl(uri).timeout(_networkTimeout);
    request.followRedirects = false;
    headers?.forEach((name, value) {
      final normalizedName = name.toLowerCase();
      if (normalizedName == HttpHeaders.ifNoneMatchHeader.toLowerCase() ||
          normalizedName == HttpHeaders.ifModifiedSinceHeader.toLowerCase()) {
        request.headers.set(name, value);
      }
    });
    final response = await request.close().timeout(_networkTimeout);

    if (response.statusCode != HttpStatus.ok &&
        response.statusCode != HttpStatus.notModified) {
      await _discard(response);
      throw HttpExceptionWithStatus(
        response.statusCode,
        'Invalid statusCode: ${response.statusCode}',
        uri: uri,
      );
    }
    if (response.statusCode == HttpStatus.ok) {
      final mimeType = response.headers.contentType?.mimeType.toLowerCase();
      if (mimeType == null || !mimeType.startsWith('image/')) {
        await _discard(response);
        throw HttpException('VNDB image response has an invalid content type.');
      }
      if (response.contentLength > _maxImageBytes) {
        await _discard(response);
        throw HttpException('VNDB image response exceeds the size limit.');
      }
    }
    return _VndbImageResponse(response, _maxImageBytes);
  }

  Future<void> _discard(HttpClientResponse response) async {
    try {
      await response.drain<void>().timeout(_networkTimeout);
    } on Object {
      // A rejected response must not keep its connection occupied indefinitely.
    }
  }
}

class _VndbImageResponse implements FileServiceResponse {
  _VndbImageResponse(this._response, this._maxBytes);

  final HttpClientResponse _response;
  final int _maxBytes;
  final DateTime _receivedAt = DateTime.now();

  @override
  Stream<List<int>> get content async* {
    var bytesRead = 0;
    await for (final chunk in _response.timeout(_networkTimeout)) {
      bytesRead += chunk.length;
      if (bytesRead > _maxBytes) {
        throw HttpException('VNDB image response exceeds the size limit.');
      }
      yield chunk;
    }
  }

  @override
  int? get contentLength =>
      _response.contentLength < 0 ? null : _response.contentLength;

  @override
  int get statusCode => _response.statusCode;

  @override
  DateTime get validTill => _receivedAt.add(const Duration(days: 7));

  @override
  String? get eTag => _response.headers.value(HttpHeaders.etagHeader);

  @override
  String get fileExtension {
    final subtype = _response.headers.contentType?.subType.toLowerCase();
    return switch (subtype) {
      'jpeg' || 'pjpeg' => '.jpg',
      'png' => '.png',
      'webp' => '.webp',
      'gif' => '.gif',
      'avif' => '.avif',
      'bmp' => '.bmp',
      _ => '.img',
    };
  }
}
