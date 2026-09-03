import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 轻量本地持久化封装(shared_preferences + JSON)。
///
/// v1 数据量小,JSON 足够;书籍规模扩大后可替换为 sqlite/isar,
/// 接口保持不变即可平滑迁移。
class LocalStore {
  LocalStore(this._prefs);

  final SharedPreferences _prefs;

  static Future<LocalStore> open() async =>
      LocalStore(await SharedPreferences.getInstance());

  Map<String, dynamic>? readJson(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  List<dynamic>? readJsonList(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as List<dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> writeJson(String key, Object value) =>
      _prefs.setString(key, jsonEncode(value));

  Future<void> remove(String key) => _prefs.remove(key);
}

/// 持久化键名集中管理。
abstract final class StoreKeys {
  static const shelf = 'shelf.v1';
  static const progress = 'progress.v1';
  static const annotations = 'annotations.v1';
  static const stats = 'stats.v1';
  static const readerSettings = 'readerSettings.v1';
}
