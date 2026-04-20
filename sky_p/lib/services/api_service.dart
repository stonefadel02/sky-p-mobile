import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:sky_p/services/cache_service.dart';

class IgsHttpClient {
  static final http.Client _client = http.Client();

  static Future<http.Response> get(
    Uri url, {
    Map<String, String>? headers,
    bool forceRefresh = false,
  }) async {
    final String urlKey = url.toString();

    // 1. Cache uniquement si pas de forceRefresh
    if (!forceRefresh) {
      final cachedData = await CacheManager.get(urlKey);
      if (cachedData != null) {
        print("📦 CACHE UTILISÉ (Mode normal) : $urlKey");
        return http.Response(jsonEncode(cachedData), 200);
      }
    } else {
      print("🚀 FORCE REFRESH : Appel réseau obligatoire pour $urlKey");
    }

    try {
      final response = await _client
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 10));

      print("📡 Réponse serveur : ${response.statusCode} pour $urlKey");
      print("📄 Body : ${response.body}");

      if (response.statusCode == 200) {
        // Mise en cache uniquement si succès
        await CacheManager.save(urlKey, jsonDecode(response.body));
        return response;
      }

      // ✅ FIX : Retourner la réponse même si non-200
      // au lieu de la jeter silencieusement
      return response;

    } catch (e) {
      print("🌐 ERREUR RÉSEAU ($e) : Tentative cache de secours...");

      // 2. Backup cache si erreur réseau (timeout, pas de connexion)
      final backupCache = await CacheManager.get(urlKey);
      if (backupCache != null) {
        print("📦 CACHE DE SECOURS utilisé suite à échec réseau");
        return http.Response(jsonEncode(backupCache), 200);
      }

      throw Exception("Pas de connexion et aucune donnée en cache.");
    }
  }
}