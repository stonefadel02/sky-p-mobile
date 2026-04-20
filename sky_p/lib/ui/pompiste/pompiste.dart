import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:sky_p/config/api_config.dart';
import 'package:sky_p/services/api_service.dart';
import 'dart:convert';

import 'package:sky_p/services/header.dart';
import 'package:sky_p/ui/pompiste/scanner_page.dart';


class PompisteHomeBody extends StatefulWidget {
  const PompisteHomeBody({super.key});

  @override
  State<PompisteHomeBody> createState() => _PompisteHomeBodyState();
}

class _PompisteHomeBodyState extends State<PompisteHomeBody> {
  static const Color igsBlue = Color(0xFF3473E4);
  static const Color igsYellow = Color(0xFFFCBF01);
  static const Color darkBrown = Color(0xFF26211E);

  // Variables pour les stats
  int totalTickets = 0;
  double totalServi = 0.0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  // On récupère l'historique pour calculer les stats en temps réel
  Future<void> _fetchStats() async {
    setState(() => isLoading = true);
    try {
     
      final header = await ApiHeaders.getHeaders();
      final response = await IgsHttpClient.get(
        Uri.parse("${ApiConfig.baseUrl}/tickets/history"),
        forceRefresh: true,
        headers: header,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> history = data is List ? data : (data['data'] ?? []);

        // CALCUL DYNAMIQUE
        int count = 0;
        double sum = 0.0;

        for (var item in history) {
          final ticket = item['ticket'] ?? item;
          // On ne compte que les tickets validés avec succès (pas les erreurs de scan)
          if (item['status'] != 'used' && item['status'] != 'utilisé') {
            count++;
            sum += double.parse((ticket['price'] ?? 0).toString());
          }
        }
        if (!mounted) return;

        setState(() {
          totalTickets = count;
          totalServi = sum;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Erreur stats: $e");
      if (!mounted) return;
      setState(() => isLoading = false);
    }finally {
    // S'exécute TOUJOURS, que ça marche ou que ça crash
    if (mounted) {
      setState(() => isLoading = false);
    }
  }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      width: double.infinity,
      child: Column(
        children: [
          const SizedBox(height: 30),
          Text(
            "ESPACE AGENT",
            style: GoogleFonts.montserrat(
              color: igsBlue.withOpacity(0.6),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Prêt pour le service ?",
            style: GoogleFonts.montserrat(
              color: darkBrown,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            "Scannez les tickets pour valider",
            style: GoogleFonts.montserrat(color: Colors.grey, fontSize: 13),
          ),

          // 2. BOUTON DE SCANNER
          Expanded(
            child: Center(
              child: GestureDetector(
                onTap: () async {
                  // On attend le retour du scanner pour rafraîchir les stats
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const TicketScannerPage()),
                  );
                  _fetchStats(); // Rafraîchit après un scan
                },
                child: Container(
                  width: 180, 
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: igsBlue.withOpacity(0.15),
                        blurRadius: 30,
                        spreadRadius: 2,
                      )
                    ],
                    border: Border.all(color: igsYellow, width: 6),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.qr_code_scanner_rounded, size: 70, color: igsBlue),
                      const SizedBox(height: 10),
                      Text(
                        "SCANNER",
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w900,
                          color: igsBlue,
                          fontSize: 14,
                          letterSpacing: 2,
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 3. STATISTIQUES DYNAMIQUES
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 25),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Colors.grey.shade100),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15)
                ]
              ),
              child: isLoading 
                ? const Center(child: CircularProgressIndicator(color: igsBlue))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statWidget("$totalTickets", "Tickets"),
                      Container(width: 1, height: 30, color: Colors.grey[200]),
                      _statWidget("${totalServi.toStringAsFixed(0)} F", "Servi"),
                    ],
                  ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _statWidget(String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 18, color: igsBlue)),
        Text(label, style: GoogleFonts.montserrat(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }
}