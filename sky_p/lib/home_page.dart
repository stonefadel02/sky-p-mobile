import 'package:flutter/material.dart';
import 'package:sky_p/core/theme/shimmer.dart';
import 'package:sky_p/ui/client/goFuel/list_command.dart';
import 'package:sky_p/ui/client/ticket%20express/create_ticket_page.dart';
import 'package:sky_p/ui/widgets/home/last_operations.dart';
import 'package:sky_p/ui/widgets/home/promo_carousel.dart';
import 'package:sky_p/ui/widgets/home/service_grid.dart';


class HomePage extends StatefulWidget {
  final Function(int) onTabChange;
  const HomePage({super.key, required this.onTabChange});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isGlobalLoading = true;

  @override
  void initState() {
    super.initState();
    _initHome();
  }

  Future<void> _initHome() async {
    // Simule le chargement initial (API + Cache)
    // C'est ici que tu peux appeler tes fetch initiaux si besoin
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) {
      setState(() {
        _isGlobalLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isGlobalLoading 
          ? const HomeShimmerPlaceholder() // Affiche le Shimmer complet
          : RefreshIndicator(
              onRefresh: _initHome, // Permet de rafraîchir manuellement
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    const PromoCarousel(),
                    const SizedBox(height: 20),
                    ServiceGrid(
                      onTicketTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateTicketPage())),
                      onTransferTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MyOrdersPage())),
                      onEssenceTap: () => debugPrint("Top Up"),
                      onGasoilTap: () => widget.onTabChange(1),
                    ),
                    LastOperations(
                      onSeeAll: () => widget.onTabChange(3),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}