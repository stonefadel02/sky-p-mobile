import 'package:flutter/material.dart';
import 'package:custom_quick_alert/custom_quick_alert.dart';

class IgsAlerts {
  static const Color igsBlue = Color(0xFF3473E4);
  static const Color igsYellow = Color(0xFFFCBF01);

  static String friendlyError({
    Object? error,
    int? statusCode,
    String? backendMessage,
    String fallback = 'Une erreur est survenue. Veuillez réessayer.',
  }) {
    if (statusCode != null) {
      switch (statusCode) {
        case 401:
          return 'Votre session a expiré. Veuillez vous reconnecter.';
        case 403:
          return 'Vous n’avez pas l’autorisation d’effectuer cette action.';
        case 404:
          return 'La ressource demandée est introuvable.';
        case 422:
          return 'Certaines informations sont incorrectes. Vérifiez votre saisie.';
        case 429:
          return 'Trop de demandes. Patientez un instant puis réessayez.';
        case 500:
        case 502:
        case 503:
        case 504:
          return 'Le service est momentanément indisponible. Réessayez plus tard.';
      }
    }

    final message = (backendMessage ?? error?.toString() ?? '').toLowerCase();
    if (message.contains('socket') ||
        message.contains('connection') ||
        message.contains('timeout') ||
        message.contains('internet') ||
        message.contains('network')) {
      return 'Connexion impossible. Vérifiez votre accès internet puis réessayez.';
    }
    if (message.contains('invalid credential') ||
        message.contains('invalid password') ||
        message.contains('identifiant') ||
        message.contains('mot de passe')) {
      return 'Adresse e-mail ou mot de passe incorrect.';
    }
    if (message.contains('already') || message.contains('existe déjà')) {
      return 'Cette information est déjà utilisée.';
    }
    return fallback;
  }

  // Alerte de succès
  static void showSuccess(String message) {
    CustomQuickAlert.success(
      title: 'Succès',
      message: message,
      confirmBtnColor: igsBlue,
      useGradientButtons: true,
    );
  }

  // Alerte d'erreur
  static void showError(String message) {
    CustomQuickAlert.error(
      title: 'Erreur',
      message: message,
      confirmBtnColor: Colors.red,
    );
  }

  // Alerte de chargement (Loading)
  static void showLoading(String message) {
    CustomQuickAlert.loading(
      title: 'Patientez',
      message: message,
    );
  }

  // Alerte de confirmation (pour suppression ou déconnexion)
  static void showConfirm({
    required String title,
    required String message,
    required VoidCallback onConfirm,
  }) {
    CustomQuickAlert.confirm(
      title: title,
      message: message,
      confirmText: 'Confirmer',
      cancelText: 'Annuler',
      confirmBtnColor: igsBlue,
      onConfirm: onConfirm,
    );
  }
}