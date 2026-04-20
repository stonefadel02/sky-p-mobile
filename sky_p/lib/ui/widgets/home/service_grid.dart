import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ServiceGrid extends StatelessWidget {
  final VoidCallback onTicketTap;
  final VoidCallback onTransferTap;
  final VoidCallback? onEssenceTap;
  final VoidCallback? onGasoilTap;

  const ServiceGrid({
    super.key,
    required this.onTicketTap,
    required this.onTransferTap,
    this.onEssenceTap,
    this.onGasoilTap,
  });

  // Définition de la couleur Jaune IGS pour la réutiliser
  static const Color igsYellow = Color(0xFFF89945);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- TITRE DE LA SECTION ---
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Text(
            "Que voulez-vous faire ?",
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),

        LayoutBuilder(
          builder: (context, constraints) {
            // On divise la largeur totale par 4 pour que ça s'adapte comme votre GridView
            // On retire 20 pour compenser le padding horizontal (10 gauche + 10 droite)
            double itemWidth = (constraints.maxWidth - 20) / 4;

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _scrollableWrapper(_circularItem(Icons.add_card_rounded, "Sky Payment", onEssenceTap ?? () {}), itemWidth),
                  _scrollableWrapper(_circularItem(Icons.style_outlined, "Chéquiers", onGasoilTap ?? () {}), itemWidth),
                  _scrollableWrapper(_circularItem(Icons.qr_code_scanner_rounded, "Tickets Express", onTicketTap), itemWidth),
                  _scrollableWrapper(_circularItem(Icons.local_gas_station_rounded, "Go Fuel", onTransferTap), itemWidth),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // On passe maintenant la largeur calculée dynamiquement
  Widget _scrollableWrapper(Widget child, double width) {
    return SizedBox(
      width: width, 
      child: child,
    );
  }

  Widget _circularItem(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: igsYellow.withOpacity(0.15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: Icon(
                icon,
                color: igsYellow,
                size: 26,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2, // Permet d'éviter de couper le texte
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.montserrat(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}