import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quickalert/quickalert.dart';
import 'package:sky_p/home_page.dart';
import 'package:sky_p/ui/auth/login_page.dart';
import 'package:sky_p/services/auth_service.dart';
import 'package:sky_p/ui/client/chequier/chequier_list.dart';
import 'package:sky_p/ui/client/ticket%20express/ticketListPage.dart';
import 'package:sky_p/ui/client/transfertTicket/TransferHistory.dart';
import 'package:sky_p/ui/pompiste/pompiste.dart';
import 'package:sky_p/ui/pompiste/ticket_history_page.dart';
import 'package:sky_p/ui/profile/profile_page.dart';

class MainNavigation extends StatefulWidget {
  final String role;
  final int initialIndex;
  const MainNavigation({
    super.key,
    required this.role,
    required this.initialIndex,
  });

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  Color activeThemeColor = const Color(0xFF3473E4);
  late int _selectedIndex;
  String userName = "Chargement...";

  static const Color igsBlue = Color(0xFF3473E4);
  static const Color igsYellow = Color(0xFFFCBF01);
  
  late final List<Widget> _clientPages;
  late final List<Widget> _pompistePages;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    activeThemeColor = (widget.role == 'client') 
      ? const Color(0xFF3473E4) // Orange Client
      : const Color(0xFF3473E4);
    _loadUserInfo();

    _clientPages = [
      HomePage(
        onTabChange: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
      const GroupListPage(),
      const TicketListPage(),
      const TransferHistoryPage(),
      ProfilePage(onProfileUpdated: _loadUserInfo),
    ];

    _pompistePages = [
      const PompisteHomeBody(),
      const TicketHistoryPage(),
      ProfilePage(onProfileUpdated: _loadUserInfo),
    ];
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        userName = prefs.getString('user_name') ?? "Utilisateur";
      });
    }
  }

  Future<void> _logoutWithConfirmation() async {
    QuickAlert.show(
      context: context,
      type: QuickAlertType.confirm,
      title: 'Déconnexion',
      text: 'Voulez-vous vraiment vous déconnecter ?',
      confirmBtnText: 'Oui',
      cancelBtnText: 'Annuler',
      confirmBtnColor: Colors.redAccent,
      headerBackgroundColor: activeThemeColor,
      onConfirmBtnTap: () async {
        Navigator.pop(context);
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        await AuthService.clearAll();
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (c) => const LoginPage()),
          (route) => false,
        );
      },
    );
  }

  String _getPageTitle() {
    if (widget.role == 'client') {
      switch (_selectedIndex) {
        case 2:
          return "";
        case 3:
          return "";
        case 4:
          return "";
        default:
          return "";
      }
    } else {
      switch (_selectedIndex) {
        case 0:
          return "";
        case 1:
          return "";
        case 2:
          return "";
        case 3:
          return "";
        default:
          return "";
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isClient = widget.role == 'client';
    List<Widget> currentPages = isClient ? _clientPages : _pompistePages;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      // On masque l'AppBar si on est sur Chéquiers (index 1) car elle est intégrée à la page
      appBar: (_selectedIndex == 1 && isClient) ? null : _buildGeneralAppBar(),

      // body: IndexedStack(index: _selectedIndex, children: currentPages),
      body: currentPages[_selectedIndex],

      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: isClient
          ? FloatingActionButton(
              onPressed: () => setState(() => _selectedIndex = 2),
              backgroundColor: activeThemeColor,
              elevation: 4,
              shape: const CircleBorder(),
              child: const Icon(
                Icons.qr_code_2_rounded,
                color: Colors.white,
                size: 30,
              ),
            )
          : null,

      bottomNavigationBar: _buildBottomNav(isClient),
    );
  }

  PreferredSizeWidget _buildGeneralAppBar() {
    return AppBar(
      toolbarHeight: 100,
      backgroundColor:Colors.white,
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: SafeArea(
        child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade100, width: 1),
          ),
        ),
        child: Padding(
          
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      // Logo dans un cercle blanc
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
                        "",
                        style: GoogleFonts.montserrat(
                          color: igsBlue,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout_rounded, color: igsBlue),
                    onPressed: _logoutWithConfirmation,
                  ),
                ],
              ),
              const SizedBox(height: 15),
              // LIGNE 2 : TITRE DYNAMIQUE
              if (_getPageTitle().isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _getPageTitle(),
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildBottomNav(bool isClient) {
    if (!isClient) {
      return BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: Colors.white, // Texte/Icône sélectionné en blanc
        unselectedItemColor: Colors.white.withOpacity(
          0.7,
        ), // Texte/Icône non sélectionné en blanc plus clair
        backgroundColor: activeThemeColor,
        showSelectedLabels: true, // Optionnel: pour être sûr de voir le texte
        showUnselectedLabels: true,
        items: _pompisteMenuItems(),
      );
    }

    return BottomAppBar(
      color: activeThemeColor,
      shape: const CircularNotchedRectangle(),
      notchMargin: 8.0,
      clipBehavior: Clip.antiAlias,
      elevation: 15,
      child: SizedBox(
        height: 65,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(
              Icons.home_outlined,
              Icons.home_rounded,
              "Accueil",
              0,
            ),
            _buildNavItem(
              Icons.account_balance_wallet_outlined,
              Icons.account_balance_wallet_rounded,
              "Chéquiers",
              1,
            ),
            const SizedBox(width: 40),
            _buildNavItem(
              Icons.swap_horizontal_circle_outlined,
              Icons.swap_horizontal_circle_rounded,
              "Transferts",
              3,
            ),
            _buildNavItem(
              Icons.person_outline_rounded,
              Icons.person_rounded,
              "Profil",
              4,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
    IconData iconOff,
    IconData iconOn,
    String label,
    int index,
  ) {
    bool isSelected = _selectedIndex == index;
    final Color activeColor = Colors.white; // Blanc pur quand sélectionné
    final Color inactiveColor = Colors.white.withOpacity(0.5);
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSelected ? iconOn : iconOff,
            color: isSelected ? activeColor : inactiveColor,
            size: 26,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.montserrat(
              color: isSelected ? activeColor : inactiveColor,
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  List<BottomNavigationBarItem> _pompisteMenuItems() {
    return [
      const BottomNavigationBarItem(
        icon: Icon(Icons.qr_code_scanner_rounded),
        label: 'Scanner',
      ),
   
      const BottomNavigationBarItem(
        icon: Icon(Icons.fact_check_outlined),
        label: 'Vérifiés',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.person_outline_rounded),
        label: 'Profil',
      ),
    ];
  }
}
