

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheManager {
  static const String _prefix = "igs_cache_";

  // dynamic permet de sauvegarder soit une Map {}, soit une List []
  static Future<void> save(String urlKey, dynamic data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefix + urlKey, jsonEncode(data));
  }

  static Future<dynamic>? get(String urlKey) async {
    final prefs = await SharedPreferences.getInstance();
    String? cached = prefs.getString(_prefix + urlKey);
    return cached != null ? jsonDecode(cached) : null;
  }
}
