import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ServiceGrid extends StatelessWidget {
  final VoidCallback onTicketTap;
  final VoidCallback? onEssenceTap;
  final VoidCallback? onGasoilTap;

  const ServiceGrid({
    super.key,
    required this.onTicketTap,
    this.onEssenceTap,
    this.onGasoilTap,
  });

  // Utilisation de tes couleurs de marque sauvegardées
  static const Color igsBlue = Color(0xFF3473E4); //
  static const Color igsYellow = Color(0xFFFCBF01); //

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
            style: GoogleFonts.montserrat( //
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),

        // --- GRILLE JUSTIFIÉE ---
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            // C'est ici que la magie opère pour "justifier" les éléments
            mainAxisAlignment: MainAxisAlignment.spaceBetween, 
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Utilisation de Expanded ou Flexible pour que chaque item prenne sa place
              Expanded(child: _circularItem(Icons.add_card_rounded, "Sky Payment", onEssenceTap ?? () {})),
              Expanded(child: _circularItem(Icons.style_outlined, "Chéquiers", onGasoilTap ?? () {})),
              Expanded(child: _circularItem(Icons.qr_code_scanner_rounded, "Tickets Express", onTicketTap)),
              // Ajoute le 4ème ici si besoin, il se placera automatiquement
            ],
          ),
        ),
      ],
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
                // On utilise le jaune IGS avec une légère opacité
                color: igsYellow.withOpacity(0.15),
              ),
              child: Icon(
                icon,
                color: igsYellow, //
                size: 28, // Taille légèrement augmentée
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.visible, // On laisse le texte respirer
              style: GoogleFonts.montserrat( //
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}