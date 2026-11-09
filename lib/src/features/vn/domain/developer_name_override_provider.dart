import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vndb_lite/src/constants/local_db_constants.dart';
import 'package:vndb_lite/src/core/local_db/shared_prefs.dart';

/// Per-visual-novel display-name overrides chosen by the user.
final developerNameOverrideProvider =
    NotifierProvider<DeveloperNameOverrides, Map<String, String>>(
      DeveloperNameOverrides.new,
      dependencies: [sharedPrefProvider],
    );

class DeveloperNameOverrides extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() {
    final preferences = ref.read(sharedPrefProvider);
    final overrides = <String, String>{};
    for (final key in preferences.getKeys()) {
      if (!key.startsWith(DBKeys.DEVELOPER_NAME_OVERRIDE)) continue;
      final name = preferences.getString(key)?.trim();
      if (name == null || name.isEmpty) continue;
      overrides[key.substring(DBKeys.DEVELOPER_NAME_OVERRIDE.length)] = name;
    }
    return overrides;
  }

  Future<void> setName(String vnId, String? value) async {
    final key = '${DBKeys.DEVELOPER_NAME_OVERRIDE}$vnId';
    final name = value?.trim() ?? '';
    final preferences = ref.read(sharedPrefProvider);
    if (name.isEmpty) {
      await preferences.remove(key);
      state = {...state}..remove(vnId);
    } else {
      await preferences.setString(key, name);
      state = {...state, vnId: name};
    }
  }
}
