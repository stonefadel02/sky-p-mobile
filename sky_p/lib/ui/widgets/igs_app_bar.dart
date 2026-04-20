import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quickalert/models/quickalert_type.dart';
import 'package:quickalert/widgets/quickalert_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sky_p/ui/auth/login_page.dart';

class IgsAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showLogout;

  const IgsAppBar({super.key, required this.title, this.showLogout = true});

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
    return AppBar(
      toolbarHeight: 100,
      backgroundColor: igsBlue,
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Container(
                        width: 80,
                        height: 80,
                       

                        child: ClipRRect(

                          child: Image.asset(
                            'assets/logoremovebg.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                  Text(
                    "ATM Energy",
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              if (showLogout)
                IconButton(
                  icon: const Icon(Icons.logout_rounded, color: Colors.white),
                  onPressed: () => _handleLogout(context),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(90);
}
