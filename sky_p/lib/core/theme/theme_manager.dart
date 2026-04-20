import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class IgsTheme {
  static const Color orangeClient = Color(0xffFE8C00);
  static const Color bluePompiste = Color(0xFF3473E4);

  // Cette fonction récupère la couleur selon le rôle
  static Future<Color> getThemeColor() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('role') ?? 'ROLE_USER';
    
    // Si c'est un client (ROLE_USER), on renvoie Orange
    // Si c'est un pompiste (ROLE_POMPISTE ou autre), on renvoie Bleu
    return (role == 'ROLE_USER') ? orangeClient : bluePompiste;
  }
}