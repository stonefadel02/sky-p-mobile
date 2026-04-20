import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
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
    final value = Map<String, dynamic>.from(
      event.snapshot.value as Map,
    );

    _controller.add(value);

    // 🔥 IMPORTANT : supprimer après traitement
    event.snapshot.ref.remove();
  }
});
  }
}
