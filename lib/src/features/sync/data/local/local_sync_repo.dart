import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vndb_lite/src/constants/local_db_constants.dart';
import 'package:vndb_lite/src/core/local_db/shared_prefs.dart';
import 'package:vndb_lite/src/features/sync/domain/user_identity.dart';

part 'local_sync_repo.g.dart';

class LocalSyncRepo {
  LocalSyncRepo(this._sharedPref);

  static const _authTokenKey = 'vndb_auth_token';
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  final SharedPreferences _sharedPref;
  UserIdentity? _account;
  String? _authToken;
  bool _initialized = false;
  bool _secureStorageAvailable = false;

  /// Loads the keyring token and migrates the legacy plaintext account record.
  /// A missing desktop keyring disables sync only; collection browsing remains
  /// available and no token is kept in ordinary preferences.
  Future<void> initialize() async {
    if (_initialized) return;

    String? legacyRaw;
    try {
      legacyRaw = _sharedPref.getString(DBKeys.USER_IDENTITY);
    } catch (_) {
      try {
        await _sharedPref.remove(DBKeys.USER_IDENTITY);
      } catch (_) {
        // Keep startup available if a corrupt preference cannot be removed.
      }
    }
    final legacyIdentity = _readStoredIdentity(legacyRaw);
    final legacyToken = legacyIdentity?.authToken ?? '';
    try {
      var token = await _secureStorage.read(key: _authTokenKey);
      if ((token == null || token.isEmpty) && legacyToken.isNotEmpty) {
        await _secureStorage.write(key: _authTokenKey, value: legacyToken);
        token = legacyToken;
      }

      if (legacyIdentity != null) {
        await _writeAccountMetadata(legacyIdentity);
      } else if (legacyRaw != null) {
        // Discard malformed legacy records too; they could still contain a token.
        await _sharedPref.remove(DBKeys.USER_IDENTITY);
      }

      if (legacyIdentity == null && (token?.isNotEmpty ?? false)) {
        await _secureStorage.delete(key: _authTokenKey);
        token = null;
      }
      _account =
          legacyIdentity != null && (token?.isNotEmpty ?? false)
              ? legacyIdentity.copyWith(authToken: '')
              : null;
      _authToken = _account == null ? null : token;
      if (_account == null) {
        await _sharedPref.setBool(DBKeys.USER_SYNCED, false);
      }
      _secureStorageAvailable = true;
    } catch (_) {
      // Remove a legacy clear-text token even if keyring migration is not
      // possible. The user can re-authenticate after configuring a keyring.
      if (legacyIdentity != null) {
        try {
          await _writeAccountMetadata(legacyIdentity);
        } catch (_) {
          await _sharedPref.remove(DBKeys.USER_IDENTITY);
        }
      } else if (legacyRaw != null) {
        await _sharedPref.remove(DBKeys.USER_IDENTITY);
      }
      _account = null;
      _authToken = null;
      _secureStorageAvailable = false;
      await _sharedPref.setBool(DBKeys.USER_SYNCED, false);
    } finally {
      _initialized = true;
      try {
        await _sharedPref.reload();
      } catch (_) {
        // The sanitized preference value is already written; a reload is optional.
      }
    }
  }

  bool get isUserSynchronized =>
      _sharedPref.getBool(DBKeys.USER_SYNCED) ?? false;

  set isUserSynchronized(bool value) {
    _sharedPref.setBool(DBKeys.USER_SYNCED, value);
    _sharedPref.reload();
  }

  UserIdentity? get userIdentity {
    final account = _account;
    final token = _authToken;
    if (!_initialized || account == null || token == null || token.isEmpty) {
      return null;
    }
    return account.copyWith(authToken: token);
  }

  Future<void> saveUserIdentity(UserIdentity identity) async {
    if (!_initialized || !_secureStorageAvailable) {
      throw StateError('Secure credential storage is unavailable.');
    }
    if (identity.authToken.trim().isEmpty) {
      throw const FormatException('An authentication token is required.');
    }

    await _secureStorage.write(key: _authTokenKey, value: identity.authToken);
    await _writeAccountMetadata(identity);
    _account = UserIdentity(
      username: identity.username,
      id: identity.id,
      authToken: '',
    );
    _authToken = identity.authToken;
  }

  UserIdentity? _readStoredIdentity(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = json.decode(raw);
      if (decoded is! Map) return null;
      final username = decoded['username'];
      final id = decoded['id'];
      if (username is! String || id is! String) return null;
      final token = decoded['authToken'];
      return UserIdentity(
        username: username,
        id: id,
        authToken: token is String ? token : '',
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeAccountMetadata(UserIdentity identity) async {
    final saved = await _sharedPref.setString(
      DBKeys.USER_IDENTITY,
      json.encode({'username': identity.username, 'id': identity.id}),
    );
    if (!saved) throw StateError('Could not persist account metadata.');
  }

  Future<void> reset() async {
    _account = null;
    _authToken = null;
    try {
      await _secureStorage.delete(key: _authTokenKey);
    } finally {
      await _sharedPref.remove(DBKeys.USER_IDENTITY);
      await _sharedPref.remove(DBKeys.USER_SYNCED);
      await _sharedPref.reload();
    }
  }
}

@Riverpod(dependencies: [sharedPref])
LocalSyncRepo localSyncRepo(Ref ref) {
  final sharedPref = ref.watch(sharedPrefProvider);
  return LocalSyncRepo(sharedPref);
}
