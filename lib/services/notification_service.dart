import 'dart:async';
import 'dart:io';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final StreamController<Map<String, dynamic>> _controller =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get stream => _controller.stream;

  bool _isListening = false;

  Future<void> startListening() async {
    if (_isListening) return; // ✅ Une seule fois
    _isListening = true;

    final prefs = await SharedPreferences.getInstance();
    final String? email = prefs.getString('user_email');
    if (email == null) return;

    final String safePath = email.replaceAll('@', '_').replaceAll('.', '_');
    final DatabaseReference ref = FirebaseDatabase.instance.ref(
      "notifications/$safePath",
    );

    Set<String> processedKeys = {};

    ref.onChildAdded.listen((event) {
      final key = event.snapshot.key;

      if (key == null || processedKeys.contains(key)) return;
      processedKeys.add(key);

      if (event.snapshot.value != null) {
        final value = Map<String, dynamic>.from(event.snapshot.value as Map);

        _controller.add(value);

        // 🔥 IMPORTANT : supprimer après traitement
        event.snapshot.ref.remove();
      }
    });
  }

Future<String> downloadAndSaveFile(String url, String fileName) async {
  final directory = await getApplicationDocumentsDirectory();
  
  // Extraction propre de l'extension
  final uri = Uri.parse(url);
  final String rawExt = uri.pathSegments.last.split('.').last;
  final String extension = rawExt.isNotEmpty ? rawExt : 'jpg';
  
  // Nom unique pour éviter le cache d'une ancienne image
  final String filePath = '${directory.path}/${fileName}_${DateTime.now().millisecondsSinceEpoch}.$extension';
  
  final response = await http.get(Uri.parse(url));
  if (response.statusCode != 200) {
    throw Exception("Échec téléchargement image : ${response.statusCode}");
  }
  
  final file = File(filePath);
  await file.writeAsBytes(response.bodyBytes);
  return filePath;
}
}
