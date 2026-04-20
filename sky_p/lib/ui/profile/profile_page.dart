import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:quickalert/models/quickalert_type.dart';
import 'package:quickalert/widgets/quickalert_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sky_p/ui/auth/login_page.dart';
import 'package:sky_p/ui/profile/EditProfilPage.dart';

class ProfilePage extends StatefulWidget {
  // Le callback pour prévenir MainNavigation que le nom a changé
  final VoidCallback? onProfileUpdated; 

  const ProfilePage({super.key, this.onProfileUpdated});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String userName = "Utilisateur";
  String userEmail = "email@exemple.com";
  
  static const Color igsBlue = Color(0xFF3473E4);
  static const Color igsYellow = Color(0xFFFCBF01);

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

// Dans _ProfilePageState
Future<void> _loadUserData() async {
  final prefs = await SharedPreferences.getInstance();
  setState(() {
    // Récupération des noms et prénoms séparés pour construire le nom complet
    String nom = prefs.getString('user_nom') ?? "";
    String prenoms = prefs.getString('user_prenoms') ?? "";
    
    // Si les deux sont vides, on affiche "Utilisateur" (cas de secours)
    userName = (nom.isEmpty && prenoms.isEmpty) 
        ? "Utilisateur" 
        : "$nom $prenoms".trim();
        
    userEmail = prefs.getString('user_email') ?? "email@exemple.com"; 
  });
}

  // Fonction centralisée pour la navigation vers l'édition
  Future<void> _navigateToEditProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EditProfilePage()),
    );
    
    // Si on revient avec "true", cela signifie qu'une modification a eu lieu
    if (result == true) {
      await _loadUserData(); // Update local (Nom/Email sur cette page)
      
      // SI le callback existe, on l'appelle pour mettre à jour l'AppBar du parent
      if (widget.onProfileUpdated != null) {
        widget.onProfileUpdated!();
      }
    }
  }

  Future<void> _logoutWithQuickAlert(BuildContext context) async {
    QuickAlert.show(
      context: context,
      type: QuickAlertType.confirm,
      title: 'Déconnexion',
      text: 'Voulez-vous vraiment vous déconnecter ?',
      confirmBtnText: 'Oui',
      cancelBtnText: 'Annuler',
      confirmBtnColor: Colors.redAccent,
      headerBackgroundColor: igsBlue,
      onConfirmBtnTap: () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        if (!context.mounted) return;
        
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (c) => const LoginPage()),
          (route) => false,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          const SizedBox(height: 30),

          // Section Avatar & Nom
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: _navigateToEditProfile, // Cliquer sur l'avatar ouvre aussi l'édition
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: igsBlue.withOpacity(0.1),
                        child: const Icon(Icons.person, size: 60, color: igsBlue),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(color: igsYellow, shape: BoxShape.circle),
                        child: const Icon(Icons.edit, size: 16, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  userName,
                  style: GoogleFonts.montserrat(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  userEmail,
                  style: GoogleFonts.montserrat(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // Options du menu
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                _buildMenuTile(
                  Icons.person_outline, 
                  "Informations personnelles", 
                  _navigateToEditProfile
                ),
                _buildMenuTile(Icons.lock_outline, "Sécurité & Mot de passe", () {
                  // Tu peux rediriger vers EditProfilePage aussi pour le MDP
                  _navigateToEditProfile();
                }),
                _buildMenuTile(Icons.notifications_none_rounded, "Notifications", () {}),
                _buildMenuTile(Icons.help_outline_rounded, "Aide & Support", () {}),
                
                const SizedBox(height: 30),
                
                // Bouton Déconnexion
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () => _logoutWithQuickAlert(context),
                    icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                    label: Text(
                      "SE DÉCONNECTER", 
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent,
                      )
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                        side: BorderSide(color: Colors.redAccent.withOpacity(0.2)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuTile(IconData icon, String title, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: igsBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: igsBlue, size: 20),
        ),
        title: Text(
          title, 
          style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w600)
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}