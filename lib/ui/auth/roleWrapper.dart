import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sky_p/ui/widgets/appBarGeneral.dart';

class RoleWrapper extends StatefulWidget {
  const RoleWrapper({super.key});

  @override
  State<RoleWrapper> createState() => _RoleWrapperState();
}

class _RoleWrapperState extends State<RoleWrapper> {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  @override
  void initState() {
    super.initState();
    // _setupLocalNotifications();
    // _initNotificationCheck();
    // _setupFCM(); // ✅ Ajoute
  }

  Future<void> _setupFCM() async {
    // ✅ Uniquement le listener foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null && mounted) {
        _showSystemNotification(
          message.notification!.title ?? "IGS Update",
          message.notification!.body ?? "",
        );
      }
    });
  }

  Future<void> _setupLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('notification_icon');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    final InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
        );

    // ✅ DOC V20 : "settings:" est un argument NOMMÉ obligatoire
    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint("Clic notification : ${response.payload}");
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Demande permission Android 13+
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  Future<void> _showSystemNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'igs_high_importance_channel',
          'Transferts IGS',
          channelDescription: 'Notifications pour les transferts IGS',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          color: Color(0xFF3473E4),
        );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    // ✅ DOC V20 : show() avec arguments nommés
    await flutterLocalNotificationsPlugin.show(
      id: DateTime.now().millisecondsSinceEpoch % 10000,
      title: title,
      body: body,
      notificationDetails: platformDetails,
    );
  }

Future<void> _initNotificationCheck() async {
  final prefs = await SharedPreferences.getInstance();
  final String? email = prefs.getString('user_email');
  if (email == null) return;

  final String safePath = email.replaceAll('@', '_').replaceAll('.', '_');
  final DatabaseReference ref = FirebaseDatabase.instance.ref("notifications/$safePath");

  final snapshot = await ref.get();
  if (snapshot.exists && mounted) {
    final data = snapshot.value;
    if (data is Map) {
      data.forEach((key, value) {
        _handleNotificationData(value);
        ref.child(key).remove();
      });
    }
  }

  ref.onChildAdded.listen((event) {
    if (event.snapshot.value != null && mounted) {
      _handleNotificationData(event.snapshot.value);
      event.snapshot.ref.remove();
    }
  });
}

  void _handleNotificationData(Object? value) {
    if (value == null) return;
    final Map<String, dynamic> data = Map<String, dynamic>.from(value as Map);
    final String title = data['title'] ?? "🎫 Nouveau ticket ATM Energy !";
    final String body = data['body'] ?? "Vous avez reçu un nouveau ticket";

    _showSystemNotification(title, body);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "$title\n$body",
            style: GoogleFonts.montserrat(color: Colors.white),
          ),
          backgroundColor: const Color(0xFF3473E4),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
    Future.delayed(const Duration(seconds: 2), () {});
  }

  Future<String> _getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    final String role = prefs.getString('role') ?? 'ROLE_USER';
    if (role.contains('AGENT')) {
    return 'Agent';
  } else {
    return 'client';
  }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _getUserRole(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF3473E4)),
            ),
          );
        }
        return MainNavigation(role: snapshot.data ?? 'client', initialIndex: 0);
      },
    );
  }
}

// ✅ OBLIGATOIRE V20 : fonction TOP-LEVEL hors de toute classe
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  debugPrint("Notification arrière-plan : ${notificationResponse.payload}");
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Message background FCM: ${message.notification?.title}");
}
