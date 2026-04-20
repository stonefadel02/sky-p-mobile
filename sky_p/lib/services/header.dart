import 'package:shared_preferences/shared_preferences.dart';
import 'package:sky_p/config/api_config.dart';
import 'package:uuid/uuid.dart';

class ApiHeaders {
  static Future<Map<String, String>> getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('token');

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
