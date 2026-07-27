import 'package:custom_quick_alert/custom_quick_alert.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:sky_p/config/api_config.dart';
import 'package:sky_p/core/theme/ui_helpers.dart';
import 'package:sky_p/services/header.dart';
import 'package:sky_p/services/auth_service.dart';
import 'package:sky_p/ui/auth/forgot_password_page.dart';
import 'package:sky_p/ui/auth/roleWrapper.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'register_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isLoading = false;

  static const Color igsBlue = Color(0xFF3473E4);
  // static const Color igsYellow = Color(0xFFFCBF01);

  String _getFriendlyMessage(String error) {
    final e = error.toLowerCase();

    if (e.contains("invalid credentials") || e.contains("unauthorized")) {
      return "Email ou mot de passe incorrect. Veuillez vérifier vos accès.";
    }
    if (e.contains("accès interdit") || e.contains("forbidden")) {
      return "Accès interdit pour cette application. Veuillez contacter le support.";
    }
    if (e.contains("user not found")) {
      return "Ce compte n'existe pas. Veuillez vous inscrire.";
    }
    if (e.contains("too many attempts")) {
      return "Trop de tentatives. Veuillez patienter quelques minutes.";
    }
    if (e.contains("email has already been taken")) {
      return "Cet email est déjà utilisé par un autre utilisateur.";
    }

    // Si l'erreur n'est pas répertoriée, on renvoie un message propre par défaut
    return "Une erreur est survenue lors de la connexion.";
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    // Fermer le clavier
    FocusScope.of(context).unfocus();

    IgsAlerts.showLoading("Vérification de vos identifiants...");

    try {
      final header = await ApiHeaders.getHeaders();
      print("Réponse du serveur test");
      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/login"),
        headers: header,
        body: jsonEncode({
          "email": _emailController.text.trim(),
          "password": _passwordController.text,
        }),
      );

      final data = jsonDecode(response.body);
      print("Réponse du serveur : $data");
      print("STATUT CONNEXION : ${response.statusCode}");
      print("CORPS DE RÉPONSE : ${response.body}");

      if (response.statusCode == 200 && data['token'] != null) {
        String token = data['token'];
        final user = data['user'];

        String? fcmToken;
        try {
          fcmToken = await FirebaseMessaging.instance.getToken();
          print("TOKEN FCM GÉNÉRÉ : $fcmToken");
        } catch (e) {
          print("ERREUR FCM : $e");
        }

        if (fcmToken != null) {
          await _sendFcmTokenToBack(token, fcmToken);
        }

        final refreshToken = data['refresh_token'] ?? data['refreshToken'];
        if (refreshToken != null) {
          await AuthService.saveTokens(
            accessToken: token,
            refreshToken: refreshToken.toString(),
          );
        }

        // Sauvegarde SharedPreferences
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', token);
        await prefs.setString('user_nom', user['nom'] ?? "");
        await prefs.setString('user_prenoms', user['prenoms'] ?? "");
        String displayName = "${user['nom']} ${user['prenoms']}".trim();
        await prefs.setString(
          'user_name',
          displayName.isNotEmpty ? displayName : "Utilisateur",
        );
        await prefs.setString('user_email', user['email'] ?? "");
        await prefs.setString('user_phone', user['telephone'] ?? "");

        await prefs.setString(
          'role',
          (user['roles'] as List).isNotEmpty ? user['roles'][0] : "ROLE_USER",
        );
        if (user['structure'] != null) {
          await prefs.setString('user_structure', user['structure']);
        }
        await prefs.setString('user_email', user['email']);

        CustomQuickAlert.dismiss(); // Ferme le loading

        // Dans votre fonction _login(), au moment du succès :
        CustomQuickAlert.success(
          title: "Bienvenue !",
          message: "Connexion réussie, ravi de vous revoir ${user['prenoms']}",
          confirmBtnColor: igsBlue,
          onConfirm: () {
            Navigator.of(context, rootNavigator: true).pop();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (c) => const RoleWrapper()),
                (route) => false,
              );
            });
          },
        );
      } else {
        CustomQuickAlert.dismiss();

        // 2. INTERCEPTION DU MESSAGE DE LA DB
        String rawError = data['message'] ?? "";
        String customMessage = _getFriendlyMessage(rawError);

        IgsAlerts.showError(customMessage);
      }
    } catch (e) {
      CustomQuickAlert.dismiss();
      print(
        "ERREUR LOGIN DÉTAILLÉE: $e",
      ); // Utilise print pour débugger simplement

      IgsAlerts.showError(
        "Impossible de joindre le serveur. Vérifiez votre connexion ou l'URL Ngrok.",
      );
    }
  }

  // LA FONCTION QUI ENVOIE LE TOKEN AU BACKEND
  Future<void> _sendFcmTokenToBack(String apiToken, String fcmToken) async {
    try {
      final response = await http.post(
        Uri.parse(
          "${ApiConfig.baseUrl}/fcm-token",
        ), // Vérifie l'URL avec ton dev back
        headers: {
          "Authorization": "Bearer $apiToken",
          "Accept": "application/json",
          "Content-Type": "application/json",
          "X-Requested-With": "XMLHttpRequest",
          "ngrok-skip-browser-warning": "true",
          "X-API-KEY": ApiConfig.atmSecretKey,
          "X-TIMESTAMP": DateTime.now().millisecondsSinceEpoch.toString(),
          "X-NONCE": const Uuid().v4(),
        },
        body: jsonEncode({"fcm_token": fcmToken}),
      );

      if (response.statusCode == 200) {
        print("FCM Token enregistré avec succès sur le serveur");
      } else {
        print("Échec de l'enregistrement FCM : ${response.body}");
      }
    } catch (e) {
      print("Erreur réseau lors de l'envoi du Token FCM : $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 60),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 50),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: igsBlue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner_rounded,
                    size: 80,
                    color: igsBlue,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Text(
                "Connexion",
                style: GoogleFonts.montserrat(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),

              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: _inputDecoration("Email", Icons.email_outlined),
                validator: (v) =>
                    (v == null || !v.contains('@')) ? "Email invalide" : null,
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                decoration: _inputDecoration("Mot de passe", Icons.lock_outline)
                    .copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () => setState(
                          () => _isPasswordVisible = !_isPasswordVisible,
                        ),
                      ),
                    ),
                validator: (v) =>
                    (v == null || v.length < 6) ? "Minimum 6 caractères" : null,
              ),


              const SizedBox(height: 20),
              // Entre le champ password et le bouton de connexion
Align(
  alignment: Alignment.centerRight,
  child: TextButton(
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ForgotPasswordPage()),
      );
    },
    child: Text(
      "Mot de passe oublié ?",
      style: GoogleFonts.montserrat(color: igsBlue, fontWeight: FontWeight.w600),
    ),
  ),
),

              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: igsBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          "SE CONNECTER",
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 25),
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (c) => const RegisterPage()),
                  ),
                  child: RichText(
                    text: TextSpan(
                      text: "Pas de compte ? ",
                      style: GoogleFonts.montserrat(color: Colors.black),
                      children: [
                        TextSpan(
                          text: "S'inscrire",
                          style: GoogleFonts.montserrat(
                            color: igsBlue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: igsBlue),
      filled: true,
      fillColor: Colors.grey[50],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: igsBlue, width: 2),
      ),
    );
  }
}
