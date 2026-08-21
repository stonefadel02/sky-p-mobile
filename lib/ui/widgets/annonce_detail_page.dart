import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sky_p/config/api_config.dart';

class AnnonceDetailPage extends StatelessWidget {
  final Map<String, dynamic>? annonce;

  const AnnonceDetailPage({super.key, this.annonce});

  static const Color igsBlue = Color(0xFF3473E4);
  static const Color igsYellow = Color(0xFFFCBF01);
  static const Color ink = Color(0xFF20252B);
  static const Color canvas = Color(0xFFF7F8FA);

  @override
  Widget build(BuildContext context) {
    final title = annonce?['titre']?.toString().trim().isNotEmpty == true
        ? annonce!['titre'].toString()
        : 'OFFRE SKY-P';
    final description = annonce?['description']?.toString().trim().isNotEmpty == true
        ? annonce!['description'].toString()
        : "Description de l'offre indisponible pour le moment.";
    final imagePath = annonce?['image_url']?.toString();
    final imageUrl = imagePath == null || imagePath.isEmpty
        ? 'https://images.unsplash.com/photo-1563986768609-322da13575f3?q=80&w=1000'
        : '${ApiConfig.baseUrl1}/$imagePath';

    return Scaffold(
      backgroundColor: canvas,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 330,
            pinned: true,
            backgroundColor: igsBlue,
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: _circleButton(
                icon: Icons.arrow_back_rounded,
                onPressed: () => Navigator.pop(context),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: igsBlue,
                      child: const Icon(
                        Icons.image_not_supported_outlined,
                        color: Colors.white70,
                        size: 52,
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.08),
                          Colors.black.withOpacity(0.58),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 22,
                    right: 22,
                    bottom: 28,
                    child: Text(
                      title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.montserrat(
                        color: Colors.white,
                        fontSize: 26,
                        height: 1.12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 26, 22, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: igsYellow.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'PROMOTION',
                          style: GoogleFonts.montserrat(
                            color: const Color(0xFF9A6500),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.campaign_outlined, color: igsBlue, size: 22),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: igsBlue,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    description,
                    style: GoogleFonts.montserrat(
                      color: ink.withOpacity(0.72),
                      fontSize: 15,
                      height: 1.75,
                    ),
                  ),
                  const SizedBox(height: 30),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: igsBlue.withOpacity(0.12)),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: igsBlue.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.storefront_outlined, color: igsBlue),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Comment en profiter ?',
                                style: GoogleFonts.montserrat(
                                  color: ink,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Rendez-vous dans la station IGS la plus proche pour profiter de cette offre.',
                                style: GoogleFonts.montserrat(
                                  color: ink.withOpacity(0.6),
                                  fontSize: 12,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleButton({required IconData icon, required VoidCallback onPressed}) {
    return Material(
      color: Colors.black.withOpacity(0.28),
      shape: const CircleBorder(),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
        tooltip: 'Retour',
      ),
    );
  }
}
