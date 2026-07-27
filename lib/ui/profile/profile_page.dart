import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quickalert/models/quickalert_type.dart';
import 'package:quickalert/widgets/quickalert_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sky_p/ui/auth/login_page.dart';
import 'package:sky_p/ui/profile/EditProfilPage.dart';
import 'package:sky_p/ui/profile/delete_account_flow.dart';
import 'package:sky_p/services/auth_service.dart';

class ProfilePage extends StatefulWidget {
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

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      String nom = prefs.getString('user_nom') ?? "";
      String prenoms = prefs.getString('user_prenoms') ?? "";
      
      userName = (nom.isEmpty && prenoms.isEmpty) 
          ? "Utilisateur" 
          : "$nom $prenoms".trim();
          
      userEmail = prefs.getString('user_email') ?? "email@exemple.com"; 
    });
  }

  Future<void> _navigateToEditProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EditProfilePage()),
    );
    
    if (result == true) {
      await _loadUserData();
      
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
        await AuthService.clearAll();
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
                  onTap: _navigateToEditProfile,
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

          const SizedBox(height: 30),

          // Section Mon Portefeuille
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Mon Portefeuille",
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[500],
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                _buildWalletCard(),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Options du menu
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Mon Compte",
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[500],
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                _buildMenuTile(
                  Icons.person_outline, 
                  "Informations personnelles", 
                  _navigateToEditProfile
                ),
                _buildMenuTile(Icons.lock_outline, "Sécurité & Mot de passe", () {
                  _navigateToEditProfile();
                }),
                _buildMenuTile(Icons.notifications_none_rounded, "Notifications", () {}),
                _buildMenuTile(Icons.help_outline_rounded, "Aide & Support", () {}),
                
                _buildMenuTile(
                  Icons.delete_forever_outlined, 
                  "Supprimer mon compte", 
                  () => DeleteAccountService.startFlow(context, userEmail),
                  isDanger: true,
                ),
                
                const SizedBox(height: 25),
                
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

  Widget _buildWalletCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.black, igsBlue],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.add_card_rounded, color: Colors.white, size: 24),
        ),
        title: Text(
          "SKY Paiement",
          style: GoogleFonts.montserrat(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        subtitle: Text(
          "Gérez votre compte SKY",
          style: GoogleFonts.montserrat(
            fontSize: 12,
            color: Colors.white.withOpacity(0.75),
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white),
        onTap: () {},
      ),
    );
  }

  Widget _buildMenuTile(IconData icon, String title, VoidCallback onTap, {bool isDanger = false}) {
    Color itemColor = isDanger ? Colors.redAccent : igsBlue;
    
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
            color: itemColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: itemColor, size: 20),
        ),
        title: Text(
          title, 
          style: GoogleFonts.montserrat(
            fontSize: 14, 
            fontWeight: FontWeight.w600,
            color: isDanger ? Colors.redAccent.shade700 : Colors.black87,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}