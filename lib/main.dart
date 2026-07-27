import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:custom_quick_alert/custom_quick_alert.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sky_p/config/api_config.dart';
import 'package:sky_p/firebase_options.dart';
import 'package:sky_p/home_page.dart';
import 'package:sky_p/services/api_service.dart';
import 'package:sky_p/services/header.dart';
import 'package:sky_p/services/notification_service.dart';
import 'package:sky_p/ui/auth/login_page.dart';
import 'package:sky_p/ui/auth/roleWrapper.dart';
import 'package:sky_p/ui/client/chequier/chequier_detail.dart';
import 'package:sky_p/ui/client/chequier/chequier_list.dart';


@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  NotificationService().startListening();
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  const secureStorage = FlutterSecureStorage();
  final String? token = await secureStorage.read(key: 'access_token');
  final bool isLoggedIn = token != null && token.isNotEmpty;
  final prefs = await SharedPreferences.getInstance();
  runApp(MyApp(isLoggedIn: isLoggedIn));
  try {
    await dotenv.load(fileName: ".env.local");
    print("✅ Configuration .env.local chargée");
  } catch (e) {
    print("❌ Impossible de charger .env.local : $e");
  }
  await ScreenUtil.ensureScreenSize();
  CustomQuickAlert.initialize(navigatorKey);
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);


  // 1. Initialisation sécurisée de Firebase
  bool isFirebaseSupported = Platform.isAndroid || Platform.isIOS;

  if (isFirebaseSupported) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // --- MESSAGING ---
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      final String? email = prefs.getString('user_email');
      if (token != null) {
        // 1. Synchro immédiate au démarrage si le token a changé
        syncFcmToken(token);

        // 2. Écouteur en temps réel si le token change pendant que l'app est ouverte
        FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
          syncFcmToken(token);
        });
      }

      if (token != null && email != null) {
        String safeTopic = email.replaceAll('@', '_').replaceAll('.', '_');
        await FirebaseMessaging.instance.subscribeToTopic(safeTopic);

        await FirebaseMessaging.instance.subscribeToTopic("annonces");
        print("Abonné au topic annonces");
      }

      // --- CRASHLYTICS (Seulement si Firebase est initialisé) ---
      FlutterError.onError = (errorDetails) {
        FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    } catch (e) {
      debugPrint("Erreur Initialisation Firebase: $e");
    }
  } else {
    // Sur Linux/Windows/Web, on utilise un logger classique pour ne pas crash
    FlutterError.onError = (errorDetails) {
      debugPrint("Flutter Error: ${errorDetails.exception}");
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint("Async Error: $error");
      return true;
    };
  }




  FlutterNativeSplash.remove();

}

Future<void> syncFcmToken(String apiToken) async {
  try {
    String? currentFcmToken = await FirebaseMessaging.instance.getToken();
    final prefs = await SharedPreferences.getInstance();
    String? storedFcmToken = prefs.getString('fcm_token');

    // On n'envoie au back que si le token a changé ou n'existe pas en local
    if (currentFcmToken != null && currentFcmToken != storedFcmToken) {
      final header = await ApiHeaders.getHeaders();
      final response = await IgsHttpClient.post(
        Uri.parse("${ApiConfig.baseUrl}/fcm-token"),
        headers: header,
        body: jsonEncode({"fcm_token": currentFcmToken}),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        await prefs.setString('fcm_token', currentFcmToken);
        print("FCM Token synchronisé avec succès");
      }
    }
  } catch (e) {
    print("Erreur synchro FCM: $e");
  }
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  const MyApp({super.key, required this.isLoggedIn});

  // Charte graphique IGS (Mise à jour selon tes préférences)
  static const Color igsBlue = Color(0xFF3473E4);
  static const Color igsYellow = Color(0xFFFCBF01);
  static const Color igsOrange = Color(0xffFE8C00);
  static const Color darkBrown = Color(0xFF26211E);

  @override
  Widget build(BuildContext context) {
    // --- INITIALISATION DE SCREENUTIL ---
    return ScreenUtilInit(
      designSize: const Size(
        360,
        690,
      ), // Taille de référence (Standard Android)
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          title: 'IGS Ticket Manager',

          theme: ThemeData(
            useMaterial3: true,
            // Adaptation des polices avec .sp
            textTheme: GoogleFonts.montserratTextTheme(
              Theme.of(context).textTheme,
            ),
            colorScheme: ColorScheme.fromSeed(
              seedColor: igsBlue,
              primary: igsBlue,
              secondary: igsOrange,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: igsBlue,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: igsOrange,
                foregroundColor: darkBrown,
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),

          initialRoute: isLoggedIn ? '/wrapper' : '/login',
          routes: {
            '/login': (context) => const LoginPage(),
            '/home': (context) => HomePage(onTabChange: (index) {}),
            '/chequiers': (context) => const GroupListPage(),
            '/detail': (context) => const GroupDetailPage(groupId: ''),
            '/wrapper': (context) => const RoleWrapper(),
          },
        );
      },
    );
  }
}
