import 'dart:convert';
import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sky_p/config/api_config.dart';
import 'package:sky_p/services/header.dart';
import 'package:sky_p/ui/widgets/home/history_page.dart';

class LastOperations extends StatefulWidget {
  final VoidCallback onSeeAll;

  const LastOperations({super.key, required this.onSeeAll});

  @override
  State<LastOperations> createState() => _LastOperationsState();
}

class _LastOperationsState extends State<LastOperations> {
  List<dynamic> _lastTransfers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedOperations(); // 1. Charger le cache d'abord
    _fetchLastTransfers(); // 2. Tenter de rafraîchir via réseau
  }

  Future<void> _loadSavedOperations() async {
    final prefs = await SharedPreferences.getInstance();
    final String? cachedData = prefs.getString('cached_operations');
    if (cachedData != null) {
      setState(() {
        _lastTransfers = json.decode(cachedData);
        _isLoading = false; // On arrête le loader car on a des données
      });
    }
  }

  Future<void> _fetchLastTransfers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final header = await ApiHeaders.getHeaders();
      final response = await http
          .get(
            Uri.parse("${ApiConfig.baseUrl}/user/history"),
            headers: header,
          )
          .timeout(const Duration(seconds: 8));

      print("Derniere operations: ${response.body}");

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);

        // Logique pour prendre 1 de chaque type (jusqu'à 3 types différents)
        final Map<String, dynamic> uniqueTypes = {};
        for (var item in data) {
          String type = item['type'] ?? 'unknown';
          if (!uniqueTypes.containsKey(type) && uniqueTypes.length < 3) {
            uniqueTypes[type] = item;
          }
        }

        final smallList = uniqueTypes.values.toList();

        // SAUVEGARDE EN CACHE
        await prefs.setString('cached_operations', json.encode(smallList));

        setState(() {
          _lastTransfers = smallList;
          _isLoading = false;
        });
      } else {
        print("Erreur Transferts: ${response.statusCode}");
        print("Erreur Transferts: ${response.body}");
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  String _formatDate(String dateStr) {
    try {
      DateTime dt = DateTime.parse(dateStr);
      DateTime now = DateTime.now();
      if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
        return "Aujourd'hui, ${DateFormat('HH:mm').format(dt)}";
      }
      return DateFormat('dd MMM, HH:mm', 'fr_FR').format(dt);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête de section (Exactement ton design)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Dernières opérations",
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: const Color(0xFF26211E),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AllOperationsPage(),
                    ),
                  );
                },
                child: Text(
                  "Voir tout",
                  style: GoogleFonts.montserrat(
                    color: const Color(0xFF3473E4),
                    fontWeight: FontWeight.w700,
                    fontSize: 13, // Ajustement léger de la taille
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),

          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF3473E4),
                ),
              ),
            )
          else if (_lastTransfers.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  "Aucune opération",
                  style: GoogleFonts.montserrat(color: Colors.grey),
                ),
              ),
            )
          else
            // On génère dynamiquement les cards avec ton design
            ..._lastTransfers.map((data) {
              String type = data['type'] ?? '';
              String title = "Opération IGS";
              String amount = "0 F";
              bool isPositive = false;
              String date = _formatDate(
                data['date'] ?? data['transferred_at'] ?? "",
              );

              // Mapping intelligent selon le type pour éviter les erreurs "null"
              switch (type) {
                case 'go_fuel_order':
                  title = "Commande GoFuel (${data['carburant_type']})";
                  amount = "- ${double.parse(data['amount'] ?? '0').toInt()} F";
                  isPositive = false;
                  break;
                case 'ticket_validation':
                  title = "Validation de Ticket";
                  amount = "- ${double.parse(data['price'] ?? '0').toInt()} F";
                  isPositive = false;
                  break;
                case 'ticket_transfer':
                  // Ici on gère ton ancien crash : on vérifie si receiver est String ou Map
                  String receiverName = data['receiver'] is Map
                      ? "${data['receiver']['prenoms'] ?? ''} ${data['receiver']['nom'] ?? ''}"
                      : (data['receiver']?.toString() ?? "Utilisateur");
                  title = "Transfert à $receiverName";
                  amount = "- ${double.parse(data['price'] ?? '0').toInt()} F";
                  isPositive = false;
                  break;
                case 'chequier_request':
                  title = "Demande de Chéquier";
                  amount = "${double.parse(data['amount'] ?? '0').toInt()} F";
                  isPositive = true;
                  break;
                default:
                  title = "Opération ${type.replaceAll('_', ' ')}";
                  amount = "${data['amount'] ?? data['price'] ?? '0'} F";
              }

              return _buildOperationCard(
                title: title,
                date: date,
                amount: amount,
                isPositive: isPositive,
              );
            }).toList(),
        ],
      ),
    );
  }

  // TON WIDGET DE DESIGN (Inchangé visuellement)
  Widget _buildOperationCard({
    required String title,
    required String date,
    required String amount,
    required bool isPositive,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Barre latérale Jaune IGS
            Container(
              width: 6,
              decoration: const BoxDecoration(
                color: Color(0xFF3473E4), // Ta couleur d'origine
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Icône de l'opération (Ton icône history_toggle_off_rounded)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.history_toggle_off_rounded, // Icône conservée
                        color: Colors.grey,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 15),
                    // Textes (Titre et Date)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF26211E),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.access_time_rounded,
                                size: 12,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                date,
                                style: GoogleFonts.montserrat(
                                  fontSize: 11,
                                  color: Colors.blueGrey[700],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Le montant (Dynamique mais garde ton style de badge)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        amount,
                        style: GoogleFonts.montserrat(
                          // Optionnel : on met en rouge/vert juste le texte pour la clarté
                          color: isPositive
                              ? Colors.green[700]
                              : Colors.red[700],
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
