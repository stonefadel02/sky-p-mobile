import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:sky_p/config/api_config.dart';

class ApiHeaders {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  static Future<Map<String, String>> getHeaders() async {
    final String? token = await _secureStorage.read(key: 'access_token');
    return {
      "Authorization": "Bearer $token",
      "Accept": "application/json",
      "Content-Type": "application/json",
      "X-Requested-With": "XMLHttpRequest",
      "ngrok-skip-browser-warning": "true",
      "X-API-KEY": ApiConfig.atmSecretKey,
      "X-TIMESTAMP": DateTime.now().millisecondsSinceEpoch.toString(),
      "X-NONCE": const Uuid().v4(),
    };
  }
}
