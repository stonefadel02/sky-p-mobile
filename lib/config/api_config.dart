import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  // static const String baseUrl = "http://192.168.1.89:8000/api";
  // static const String baseUrl1 = "http://192.168.1.89:8000";
  static const String baseUrl = "https://lyricist-corridor-energetic.ngrok-free.dev/api";
  static const String baseUrl1 = "https://lyricist-corridor-energetic.ngrok-free.dev";
  // static const String baseUrl = "https://admin.atmenergy.net/api";
  // static const String baseUrl1 = "https://admin.atmenergy.net";

  static String get atmSecretKey =>
      dotenv.env['APP_SECRET_SKYP'] ?? 'default_key';
  // Kkiapay Config
  // static const String kkiapayPublicKey = "f00d7849eca15103703e9a469db9df97feebe2d5";
  // static const bool isSandbox = false; // Mettre à false en production

  static const String kkiapayPublicKey = "2a979ec0068611f1977721ec7ffb7674";
  static const bool isSandbox = true; // Mettre à false en production
  // Endpoints
  static const String loginEndpoint = "$baseUrl/login";
  static const String registerEndpoint = "$baseUrl1/register";
  static const String requestChequierEndpoint = "$baseUrl/chequiers/request";
  // static String validateTicket(String code) =>
  //     "$code";

  // static String validateTicket(String code) {
  //   if (code.startsWith("http")) {
  //     String cleanUrl = code.replaceAll("127.0.0.1", "192.168.1.89")
  //                           .replaceAll("localhost", "192.168.1.89")
  //                           .replaceFirst("http://", "https://");

  //     if (!cleanUrl.contains("/validate")) {
  //       if (cleanUrl.endsWith("/")) {

  //         cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
  //       }
  //       return "$cleanUrl/validate";
  //     }
  //     return cleanUrl;
  //   }

  //   return "$baseUrl/tickets/$code/validate";
  // }

  static String validateTicket(String code) {
    if (code.startsWith("http")) {
      // 1. On remplace toutes les adresses locales par l'hôte Ngrok actuel
      // On récupère l'hôte de ton baseUrl (sans le /api)
      String prodHost = "admin.atmenergy.net";

      String cleanUrl = code
          .replaceAll("127.0.0.1:8000", prodHost)
          .replaceAll("localhost:8000", prodHost)
          .replaceAll("192.168.1.89:8000", prodHost)
          .replaceAll("127.0.0.1", prodHost)
          .replaceAll("localhost", prodHost)
          .replaceAll("192.168.1.89", prodHost)
          .replaceAll("unscooped-unwarrantably-ember.ngrok-free.dev", prodHost);

      // 2. On s'assure d'utiliser HTTPS pour Ngrok
      if (cleanUrl.startsWith("http://")) {
        cleanUrl = cleanUrl.replaceFirst("http://", "https://");
      }

      // 3. Gestion du point de terminaison /validate
      if (!cleanUrl.contains("/validate")) {
        // Nettoyage du slash final pour éviter les doubles //
        if (cleanUrl.endsWith("/")) {
          cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
        }
        return "$cleanUrl/validate";
      }
      return cleanUrl;
    }

    // Si c'est juste un code brut
    return "$baseUrl/tickets/$code/validate";
  }
}


// APP_SECRET_ATMENERGY=c9b33caa4cd7cb565468706f568276c45d29f2d3c81c801890cf1ff02ca85a9b
// APP_SECRET_SKYP=0bd9327357f2c63b57c1adf291ed0ea48c7cd3cd7b8a15cc1958ae21702886cd