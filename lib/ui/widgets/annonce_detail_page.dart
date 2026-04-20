import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sky_p/config/api_config.dart';

class AnnonceDetailPage extends StatelessWidget {
  final Map<String, dynamic>? annonce;

  const AnnonceDetailPage({super.key, this.annonce});

  // Couleurs de ta charte IGS
  static const Color igsBlue = Color(0xFF3473E4);
  static const Color igsYellow = Color(0xFFFCBF01);
  static const Color lightGrey = Color(0xFFF5F5F5);

  @override
  Widget build(BuildContext context) {
    // Récupération des données
    final String titre = annonce?['titre'] ?? "OFFRE SKY-P";
    final String description = annonce?['description'] ?? "Description de l'offre indisponible pour le moment.";
    
    // Image par défaut si l'URL est vide
    String imageUrl = "https://images.unsplash.com/photo-1563986768609-322da13575f3?q=80&w=1000"; 
    if (annonce != null && annonce!['image_url'] != null) {
       imageUrl = "${ApiConfig.baseUrl1}/${annonce!['image_url']}";
    }

    return Scaffold(
      backgroundColor: lightGrey,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black), // Style "Modal"
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Détail de l'annonce",
          style: GoogleFonts.montserrat(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. La Photo (Propre, sans texte dessus comme demandé)
            Container(
              margin: const EdgeInsets.all(16),
              height: 250,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => 
                    Container(color: Colors.grey[300], child: const Icon(Icons.image)),
                ),
              ),
            ),

            // 2. Section Texte (Inspirée de tes cartes de services)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(20),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge catégorie
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: igsBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "PROMOTION",
                      style: GoogleFonts.montserrat(
                        color: igsBlue,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Titre
                  Text(
                    titre.toUpperCase(),
                    style: GoogleFonts.montserrat(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Séparateur discret
                  Container(
                    height: 2,
                    width: 40,
                    color: igsYellow,
                  ),
                  const SizedBox(height: 20),
                  
                  // Description
                  Text(
                    description,
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      color: Colors.black54,
                      height: 1.6,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            
            // 3. Section d'info supplémentaire (Optionnel - Rue / Station)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: igsYellow),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Rendez-vous dans la station IGS la plus proche pour en profiter.",
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          color: Colors.black45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}