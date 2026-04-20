

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sky_p/config/api_config.dart';
import 'package:sky_p/services/header.dart';
import 'package:sky_p/services/notification_service.dart';
import 'package:sky_p/ui/widgets/annonce_detail_page.dart';

class PromoCarousel extends StatefulWidget {
  const PromoCarousel({super.key});

  @override
  State<PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<PromoCarousel> {
  StreamSubscription? _notifSubscription;
  static const Color igsYellow = Color(0xFFF89945);
  List<dynamic> annonces = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    print("INITSTATE: Lancement du carrousel"); // LOG 1
    _loadSavedAnnonces();
    _fetchAnnonces();
    _notifSubscription = NotificationService().stream.listen((data) {
      if (mounted) {
        _fetchAnnonces(); // Rafraîchit juste la liste
      }
    });
  }

  Future<void> _loadSavedAnnonces() async {
  final prefs = await SharedPreferences.getInstance();
  final String? cached = prefs.getString('cached_annonces');
  if (cached != null) {
    setState(() {
      annonces = json.decode(cached);
      isLoading = false;
    });
  }
}

  @override
  void dispose() {
    _notifSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchAnnonces() async {
     final header = await ApiHeaders.getHeaders();
    try {
      final response = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/annonces"),
        headers: header,
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
      final data = json.decode(response.body);
      
      // SAUVEGARDE EN CACHE
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_annonces', json.encode(data));

      if (!mounted) return;
      setState(() {
        annonces = data;
        isLoading = false;
      });
    }
  } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator(color: igsYellow)),
      );
    }

    if (annonces.isEmpty) return const SizedBox.shrink();

    return CarouselSlider.builder(
      itemCount: annonces.length,
      options: CarouselOptions(
        height: 200.0,
        autoPlay: true,
        autoPlayInterval: const Duration(seconds: 6),
        enlargeCenterPage: true,
        viewportFraction: 0.92,
      ),
      itemBuilder: (context, index, realIndex) {
        final item = annonces[index];

        final String fullImageUrl =
            "${ApiConfig.baseUrl1}/${item['image_url']}";

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 5),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Image distante
                // Image.network(
                //   fullImageUrl,
                //   fit: BoxFit.fill,
                //   errorBuilder: (context, error, stackTrace) => Container(
                //     color: Colors.grey[300],
                //     child: const Icon(
                //       Icons.image_not_supported,
                //       color: Colors.grey,
                //     ),
                //   ),
                // ),
                CachedNetworkImage(
                  imageUrl: fullImageUrl,
                  fit: BoxFit
                      .cover, 
                  httpHeaders: const {"ngrok-skip-browser-warning": "true"},
                  placeholder: (context, url) => Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: CircularProgressIndicator(color: igsYellow),
                    ),
                  ),
                  
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.broken_image, color: Colors.grey),
                  ),
                ),

                // Overlay dégradé
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),

                // Contenu textuel
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['titre']?.toString().toUpperCase() ?? "PROMO",
                        style: GoogleFonts.montserrat(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        item['description'] ?? "",
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.montserrat(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: () {
                          // Redirection vers la page de détails avec les données de l'annonce actuelle
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  AnnonceDetailPage(annonce: item),
                            ),
                          );
                        }, // Action à définir (ex: ouvrir un lien)
                        style: ElevatedButton.styleFrom(
                          backgroundColor: igsYellow,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: Text(
                          "EN SAVOIR PLUS",
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
