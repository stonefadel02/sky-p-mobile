import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quickalert/models/quickalert_type.dart';
import 'package:quickalert/widgets/quickalert_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sky_p/ui/auth/login_page.dart';
import 'package:sky_p/services/auth_service.dart';

class IgsAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showLogout;
  final VoidCallback? onBack;

  const IgsAppBar({
    super.key,
    required this.title,
    this.showLogout = true,
    this.onBack,
  });

  static const Color igsBlue = Color(0xFF3473E4);

  Future<void> _handleLogout(BuildContext context) async {
    QuickAlert.show(
      context: context,
      type: QuickAlertType.confirm,
      title: 'Déconnexion',
      text: 'Voulez-vous vraiment vous déconnecter ?',
      confirmBtnText: 'Oui',
      cancelBtnText: 'Annuler',
      confirmBtnColor: Colors.redAccent,
      onConfirmBtnTap: () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        await AuthService.clearAll();

        if (!context.mounted) return;

        // On vide la pile et on retourne au login
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
  return Container(
    // C'est ce Container qui va créer l'ombre en bas
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.02), // Ombre très légère
          spreadRadius: 1,
          blurRadius: 10,
          offset: const Offset(0, 3), // L'ombre descend vers le bas
        ),
      ],
    ),
    child: AppBar(
      toolbarHeight: 100,
      backgroundColor: Colors.white,
      elevation: 0, // On laisse l'élévation native à 0
      automaticallyImplyLeading: false,
      flexibleSpace: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  // Vérifier si on peut faire un retour avant d'afficher le bouton
                  if (Navigator.canPop(context))
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: igsBlue,
                        size: 20,
                      ),
                      onPressed: onBack ?? () => Navigator.pop(context),
                    ),
                  SizedBox(
                    width: 60, // Réduit légèrement pour un meilleur alignement
                    height: 60,
                    child: Image.asset(
                      'assets/logoremovebg.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "",
                    style: GoogleFonts.montserrat(
                      color: igsBlue,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              if (showLogout)
                IconButton(
                  icon: const Icon(Icons.logout_rounded, color: igsBlue),
                  onPressed: () => _handleLogout(context),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

  @override
  Size get preferredSize => const Size.fromHeight(90);
}
