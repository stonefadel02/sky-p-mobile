import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:google_fonts/google_fonts.dart';

class IGSStateDisplay extends StatelessWidget {
  final String animation; // Le nom exact du fichier (avec ou sans .json)
  final String title;
  final String message;
  final VoidCallback? onAction;
  final String? actionLabel;

  const IGSStateDisplay({
    super.key,
    required this.animation,
    required this.title,
    required this.message,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    // Correction : on vérifie si l'extension est déjà présente
    final String assetPath = animation.endsWith('.json') 
        ? 'assets/lotties/$animation' 
        : 'assets/lotties/$animation.json';

    return Center(
      // SingleChildScrollView pour éviter les erreurs d'overflow sur les petits écrans
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animation Lottie optimisée
            Lottie.asset(
              assetPath,
              width: 250,
              height: 250,
              fit: BoxFit.contain,
              renderCache: RenderCache.raster, // Optimisation CPU/Batterie
            ),
            const SizedBox(height: 20),
            // Titre en Bleu IGS (3473e4)
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF3473E4), 
              ),
            ),
            const SizedBox(height: 12),
            // Message descriptif
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                fontSize: 14,
                color: const Color(0xFF26211E).withOpacity(0.7), // DarkBrown adouci
                height: 1.5,
              ),
            ),
            // Bouton d'action en Jaune IGS (fcbf01)
            if (onAction != null) ...[
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFCBF01), 
                    foregroundColor: const Color(0xFF26211E),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: Text(
                    actionLabel?.toUpperCase() ?? "RÉESSAYER",
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}