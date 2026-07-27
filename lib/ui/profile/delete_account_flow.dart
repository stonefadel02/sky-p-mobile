import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:quickalert/quickalert.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sky_p/config/api_config.dart';
import 'package:sky_p/services/api_service.dart';
import 'package:sky_p/services/header.dart';
import 'package:sky_p/ui/auth/login_page.dart';
import 'package:sky_p/ui/profile/delete_step1_form_dialog.dart';
import 'package:sky_p/ui/profile/delete_step2_verify_dialog.dart';
import 'package:sky_p/ui/profile/delete_step3_warning_dialog.dart';

class DeleteAccountService {
  static const Color darkBrown = Color(0xFF26211E);

  // Déclencheur initial du flux
  static void startFlow(BuildContext context, String currentEmail) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => DeleteStep1FormDialog(currentEmail: currentEmail),
    );
  }

  // Passer à l'étape 2
  static void navigateToStep2(BuildContext context, String email, String reason) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => DeleteStep2VerifyDialog(email: email, reason: reason),
    );
  }

  // Passer à l'étape 3
  static void navigateToStep3(BuildContext context, String email, String reason) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => DeleteStep3WarningDialog(email: email, reason: reason),
    );
  }

  // Action finale d'appel API
  static Future<void> sendDeleteRequest(BuildContext context, String email, String reason) async {
    QuickAlert.show(
      context: context,
      type: QuickAlertType.loading,
      title: 'Traitement',
      text: 'Suppression de votre compte en cours...',
    );

    try {
      final headers = await ApiHeaders.getHeaders();
      final Map<String, dynamic> body = {
        "email": email,
        "motif": reason,
      };

      final response = await IgsHttpClient.post(
        Uri.parse("${ApiConfig.baseUrl}/users/delete-request"),
        headers: headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      Navigator.pop(context); // Ferme le loader QuickAlert

      if (response.statusCode == 200 || response.statusCode == 201) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();

        if (!context.mounted) return;

        QuickAlert.show(
          context: context,
          type: QuickAlertType.success,
          title: 'Compte Supprimé',
          text: 'Votre compte a été supprimé avec succès. Vous allez être redirigé.',
          onConfirmBtnTap: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (c) => const LoginPage()),
              (route) => false,
            );
          },
        );
      } else {
        if (!context.mounted) return;
        _showErrorAlert(context, 'Le serveur a refusé la requête. Vérifiez vos informations.');
      }
    } catch (e) {
      Navigator.pop(context); // Ferme le loader
      if (!context.mounted) return;
      _showErrorAlert(context, 'Impossible de joindre le serveur. Réessayez plus tard.');
    }
  }

  static void _showErrorAlert(BuildContext context, String text) {
    QuickAlert.show(
      context: context,
      type: QuickAlertType.error,
      title: 'Erreur',
      text: text,
    );
  }
}
