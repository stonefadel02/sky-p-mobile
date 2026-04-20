import 'dart:convert';
import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:sky_p/config/api_config.dart';
import 'package:sky_p/services/header.dart';
import 'package:sky_p/ui/widgets/igs_app_bar.dart';

class AllOperationsPage extends StatefulWidget {
  const AllOperationsPage({super.key});

  @override
  State<AllOperationsPage> createState() => _AllOperationsPageState();
}

class _AllOperationsPageState extends State<AllOperationsPage> {
  List<dynamic> _allOperations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchFullHistory();
  }

  Future<void> _fetchFullHistory() async {
    try {
    
      final header = await ApiHeaders.getHeaders();

      final response = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/user/history"),
        headers: header,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        setState(() {
          _allOperations = json.decode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDate(String dateStr) {
    try {
      DateTime dt = DateTime.parse(dateStr);
      return DateFormat('dd MMMM yyyy, HH:mm', 'fr_FR').format(dt);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
     appBar: const IgsAppBar(
      title: "Historique des opérations", // Si ton widget accepte un titre
    ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF3473E4)))
          : _allOperations.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _allOperations.length,
                  itemBuilder: (context, index) {
                    return _buildDynamicCard(_allOperations[index]);
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 10),
          Text("Aucune opération trouvée", style: GoogleFonts.montserrat(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildDynamicCard(dynamic data) {
    String type = data['type'] ?? '';
    String title = "Opération IGS";
    String amount = "0 F";
    bool isPositive = false;
    String date = _formatDate(data['date'] ?? data['transferred_at'] ?? "");

    // Même logique de mapping que sur l'accueil
    switch (type) {
      case 'go_fuel_order':
        title = "Commande GoFuel (${data['carburant_type']})";
        amount = "- ${double.parse(data['amount'] ?? '0').toInt()} F";
        break;
      case 'ticket_validation':
        title = "Validation de Ticket";
        amount = "- ${double.parse(data['price'] ?? '0').toInt()} F";
        break;
      case 'ticket_transfer':
        String receiverName = data['receiver'] is Map 
            ? "${data['receiver']['prenoms'] ?? ''} ${data['receiver']['nom'] ?? ''}"
            : (data['receiver']?.toString() ?? "Utilisateur");
        title = "Transfert à $receiverName";
        amount = "- ${double.parse(data['price'] ?? '0').toInt()} F";
        break;
      case 'chequier_request':
        title = "Demande de Chéquier";
        amount = "+ ${double.parse(data['amount'] ?? '0').toInt()} F";
        isPositive = true;
        break;
      default:
        title = "Opération ${type.replaceAll('_', ' ')}";
        amount = "${data['amount'] ?? data['price'] ?? '0'} F";
    }

    // Réutilisation exacte de ton design de carte
    return _operationDesign(title, date, amount, isPositive);
  }

  Widget _operationDesign(String title, String date, String amount, bool isPositive) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 6,
              decoration: const BoxDecoration(
                color: Color(0xffFE8C00),
                borderRadius: BorderRadius.only(topLeft: Radius.circular(20), bottomLeft: Radius.circular(20)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3473E4).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.history_toggle_off_rounded, color: Color(0xFF3473E4), size: 28),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(date, style: GoogleFonts.montserrat(fontSize: 11, color: Colors.blueGrey[700])),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
                      child: Text(amount, style: GoogleFonts.montserrat(color: isPositive ? Colors.green[700] : Colors.red[700], fontSize: 12, fontWeight: FontWeight.bold)),
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