import 'package:flutter/material.dart';
import 'package:custom_quick_alert/custom_quick_alert.dart';

class IgsAlerts {
  static const Color igsBlue = Color(0xFF3473E4);
  static const Color igsYellow = Color(0xFFFCBF01);

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