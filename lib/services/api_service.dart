import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sky_p/config/api_config.dart';
import 'package:sky_p/services/cache_service.dart';
import 'package:sky_p/ui/auth/login_page.dart';
import 'package:sky_p/main.dart'; // Pour récupérer le navigatorKey
import 'package:shared_preferences/shared_preferences.dart';

class IgsHttpClient {
  static final http.Client _client = http.Client();
  static const _storage = FlutterSecureStorage();
  
  // Variables pour empêcher le rafraîchissement multiple simultané
  static bool _isRefreshing = false;
  static Completer<bool>? _refreshCompleter;

  static Future<Map<String, String>> _buildHeaders(Map<String, String>? customHeaders) async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('token') ?? await _storage.read(key: 'access_token');

    // 🛡️ On crée une copie locale pour nettoyer les en-têtes sans modifier la variable de la page d'origine
    final cleanedCustomHeaders = customHeaders != null ? Map<String, String>.from(customHeaders) : null;
    
    if (cleanedCustomHeaders != null) {
      // On supprime l'ancien Token qui a causé le 401 pour éviter qu'il n'écrase le nouveau jeton
      cleanedCustomHeaders.remove('Authorization');
      cleanedCustomHeaders.remove('authorization');
    }

    return {
      "Accept": "application/json",
      "Content-Type": "application/json; charset=UTF-8",
      "ngrok-skip-browser-warning": "true",
      "X-API-KEY": ApiConfig.atmSecretKey,
      if (accessToken != null) "Authorization": "Bearer $accessToken", // 🔥 Le nouveau jeton est injecté ici en toute sécurité
      ...?cleanedCustomHeaders, // On fusionne le reste des en-têtes d'origine (X-TIMESTAMP, X-NONCE, etc.)
    };
  }

  static Future<http.Response> get(
    Uri url, {
    Map<String, String>? headers,
    bool forceRefresh = false,
  }) async {
    final String urlKey = url.toString();

    if (!forceRefresh) {
      final cachedData = await CacheManager.get(urlKey);
      if (cachedData != null) {
        print("📦 CACHE UTILISÉ (Mode normal) : $urlKey");
        return http.Response(jsonEncode(cachedData), 200, headers: {
          "content-type": "application/json; charset=utf-8"
        });
      }
    }

    try {
      var finalHeaders = await _buildHeaders(headers);
      var response = await _client
          .get(url, headers: finalHeaders)
          .timeout(const Duration(seconds: 10));

      print("📡 Réponse serveur : ${response.statusCode} pour $urlKey");

      // 🔐 INTERCEPTEUR 401
      if (response.statusCode == 401) {
        print("🔄 [Auth] Token expiré (401) pour $urlKey. Tentative de rafraîchissement...");
        
        final isRefreshed = await _handleTokenRefresh();

        if (isRefreshed) {
          // 🔥 TRÈS IMPORTANT : On reconstruit les headers avec le TOUT NOUVEAU token fraîchement enregistré !
          finalHeaders = await _buildHeaders(headers);
          print("🔁 [Auth] Relancement de la requête initiale avec le nouveau Token pour $urlKey");
          
          response = await _client
              .get(url, headers: finalHeaders)
              .timeout(const Duration(seconds: 10));
        }
      }

      if (response.statusCode == 200) {
        final String decodedBody = utf8.decode(response.bodyBytes);
        final decodedJson = jsonDecode(decodedBody);

        await CacheManager.save(urlKey, decodedJson);
        
        return http.Response(decodedBody, 200, headers: {
          "content-type": "application/json; charset=utf-8"
        });
      }

      return response;
    } catch (e) {
      print("🌐 ERREUR RÉSEAU ($e) : Tentative cache de secours...");
      final backupCache = await CacheManager.get(urlKey);
      if (backupCache != null) {
        return http.Response(jsonEncode(backupCache), 200);
      }
      throw Exception("Pas de connexion internet et aucune donnée en cache.");
    }
  }

  static Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final String urlKey = url.toString();

    try {
      var finalHeaders = await _buildHeaders(headers);

      var response = await _client
          .post(url, headers: finalHeaders, body: body)
          .timeout(const Duration(seconds: 10));

      print("📡 Réponse serveur (POST) : ${response.statusCode} pour $urlKey");

      // 🔐 INTERCEPTEUR 401 POUR LE POST
      if (response.statusCode == 401) {
        print("🔄 [Auth-POST] Token expiré (401) pour $urlKey. Tentative de rafraîchissement...");
        
        final isRefreshed = await _handleTokenRefresh();

        if (isRefreshed) {
          // On reconstruit les headers avec le nouveau Token généré
          finalHeaders = await _buildHeaders(headers);
          print("🔁 [Auth-POST] Relancement de la requête initiale POST pour $urlKey");
          response = await _client
              .post(url, headers: finalHeaders, body: body)
              .timeout(const Duration(seconds: 10));
        }
      }

      return response;
    } catch (e) {
      print("🌐 ERREUR RÉSEAU POST ($e)");
      throw Exception("Impossible de joindre le serveur pour soumettre les données.");
    }
  }

  static Future<bool> _handleTokenRefresh() async {
    // Si un rafraîchissement est déjà en cours, on attend sa complétion au lieu d'en relancer un
    if (_isRefreshing) {
      print("⏳ [Auth] Rafraîchissement déjà en cours, attente du résultat...");
      return _refreshCompleter?.future ?? Future.value(false);
    }

    _isRefreshing = true;
    _refreshCompleter = Completer<bool>();

    final refreshToken = await _storage.read(key: 'refresh_token');

    if (refreshToken == null) {
      print("❌ Aucun refresh token trouvé dans le stockage sécurisé");
      _isRefreshing = false;
      _refreshCompleter!.complete(false);
      return false;
    }

    try {
      print("📡 Envoi du Refresh Token au Backend...");
      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/token/refresh"),
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/json",
          "X-API-KEY": ApiConfig.atmSecretKey,
        },
        body: jsonEncode({"refresh_token": refreshToken}),
      );

      print("🔁 Réponse du Refresh Endpoint : ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String? newToken = data['token'];
        final String? newRefreshToken = data['refresh_token'] ?? data['refreshToken'];

        if (newToken != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('token', newToken);
          await _storage.write(key: 'access_token', value: newToken);
          print("✅ Nouveau Access Token sauvegardé avec succès.");
        }

        if (newRefreshToken != null) {
          await _storage.write(key: 'refresh_token', value: newRefreshToken.toString());
          print("✅ Nouveau Refresh Token sauvegardé.");
        }

        _isRefreshing = false;
        _refreshCompleter!.complete(true);
        return true;
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        print("❌ Le Refresh Token est lui aussi expiré ou invalide.");
        _isRefreshing = false;
        _refreshCompleter!.complete(false);
        _forceLogout();
        return false;
      }

      _isRefreshing = false;
      _refreshCompleter!.complete(false);
      return false;
    } catch (e) {
      print("⚠️ Erreur lors du rafraîchissement : $e");
      _isRefreshing = false;
      _refreshCompleter!.complete(false);
      return false;
    }
  }

  static Future<http.Response> multipartPost(
    Uri url, {
    Map<String, String>? headers,
    Map<String, String>? fields,
    List<http.MultipartFile>? files,
  }) async {
    final String urlKey = url.toString();

    try {
      var finalHeaders = await _buildHeaders(headers);

      var request = http.MultipartRequest('POST', url);
      finalHeaders.remove('Content-Type');
      finalHeaders.remove('content-type');
      request.headers.addAll(finalHeaders);
      if (fields != null) request.fields.addAll(fields);
      if (files != null) request.files.addAll(files);

      var streamedResponse = await request.send().timeout(const Duration(seconds: 15));
      var response = await http.Response.fromStream(streamedResponse);

      print("📡 Réponse serveur (Multipart) : ${response.statusCode} pour $urlKey");

      // 🔐 INTERCEPTEUR 401 POUR LE MULTIPART
      if (response.statusCode == 401) {
        print("🔄 [Auth-Multipart] Token expiré (401) pour $urlKey. Tentative de rafraîchissement...");
        
        final isRefreshed = await _handleTokenRefresh();

        if (isRefreshed) {
          finalHeaders = await _buildHeaders(headers);
          
          var newRequest = http.MultipartRequest('POST', url);
          newRequest.headers.addAll(finalHeaders);
          if (fields != null) newRequest.fields.addAll(fields);
          
          if (files != null) {
            for (var file in files) {
              newRequest.files.add(file);
            }
          }

          print("🔁 [Auth-Multipart] Relancement de la requête initiale pour $urlKey");
          streamedResponse = await newRequest.send().timeout(const Duration(seconds: 15));
          response = await http.Response.fromStream(streamedResponse);
        }
      }

      return response;
    } catch (e) {
      print("🌐 ERREUR RÉSEAU MULTIPART ($e)");
      throw Exception("Impossible d'envoyer les fichiers au serveur.");
    }
  }

  static void _forceLogout() async {
    print("🚨 [Auth] Session expirée définitivement. Nettoyage complet...");
    await _storage.deleteAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    final context = navigatorKey.currentContext; // Correction du bug : utilise le navigatorKey global de main.dart
    if (context != null) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (c) => const LoginPage()),
        (route) => false,
      );
    } else {
      print("❌ [Auth] Impossible de rediriger : navigatorKey.currentContext est null.");
    }
  }
}