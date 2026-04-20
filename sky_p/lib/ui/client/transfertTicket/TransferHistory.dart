import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sky_p/config/api_config.dart';
import 'package:sky_p/services/api_service.dart';
import 'package:sky_p/services/header.dart';
import 'package:sky_p/ui/widgets/state_handler.dart';
import 'package:uuid/uuid.dart';

class TransferHistoryPage extends StatefulWidget {
  const TransferHistoryPage({super.key});

  @override
  State<TransferHistoryPage> createState() => _TransferHistoryPageState();
}

class _TransferHistoryPageState extends State<TransferHistoryPage> {
  // Couleurs de la charte IGS
  static const Color igsBlue = Color(0xFF3473E4);
  // static const Color igsYellow = Color(0xFFFCBF01);
  static const Color darkBrown = Color(0xFF26211E);

  List<dynamic> transferHistory = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchTransferHistory();
  }

  Future<void> _fetchTransferHistory() async {
    setState(() => isLoading = true);
    try {
      final header = await ApiHeaders.getHeaders();
      final response = await IgsHttpClient.get(
        Uri.parse("${ApiConfig.baseUrl}/tickets/transfers/history"),
        forceRefresh: true,

        headers: header,
      );

      if (response.statusCode == 200) {
        setState(() {
          transferHistory = json.decode(response.body);
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = "Erreur serveur (${response.statusCode})";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "Erreur de connexion : $e";
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: RefreshIndicator(
        onRefresh: _fetchTransferHistory,
        color: igsBlue,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: igsBlue));
    }

    if (errorMessage != null) {
      return IGSStateDisplay(
        animation: 'no_internet', // Ton fichier renommé
        title: "Un petit souci...",
        message:
            "Nous n'avons pas pu charger votre historique. Vérifiez votre connexion.",
        onAction: _fetchTransferHistory,
        actionLabel: "RÉESSAYER",
      );
    }
    if (transferHistory.isEmpty) {
      return IGSStateDisplay(
        animation: 'empty_box', // Ton fichier renommé
        title: "Aucun mouvement",
        message: "Vous n'avez pas encore envoyé ou reçu de tickets IGS.",
        onAction: _fetchTransferHistory,
        actionLabel: "ACTUALISER",
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: transferHistory.length,
      itemBuilder: (context, index) {
        final transfer = transferHistory[index];
        return _buildTransferCard(transfer);
      },
    );
  }

  Widget _buildTransferCard(Map<String, dynamic> data) {
    final bool isSent = data['type'] == 'sent';
    final ticket = data['ticket'] ?? {};
    final sender = data['sender'] ?? {};
    final receiver = data['receiver'] ?? {};
    final String dateStr = data['transferred_at'] ?? "";

    // Détermination du nom à afficher
    final String partnerName = isSent
        ? "${receiver['prenoms'] ?? ''} ${receiver['nom'] ?? ''}"
        : "${sender['prenoms'] ?? ''} ${sender['nom'] ?? ''}";

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: darkBrown.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icône circulaire stylisée
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSent
                  ? Color(0xffFE8C00).withOpacity(0.1)
                  : igsBlue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isSent ? Icons.north_east_rounded : Icons.south_west_rounded,
              color: isSent ? Color(0xffFE8C00) : igsBlue,
              size: 20,
            ),
          ),
          const SizedBox(width: 15),

          // Infos du transfert
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSent ? "Transfert envoyé" : "Transfert reçu",
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: darkBrown,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isSent ? "À: $partnerName" : "De: $partnerName",
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    color: Colors.blueGrey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Ticket #${ticket['id']} • ${_formatDate(dateStr)}",
                  style: GoogleFonts.montserrat(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),

          // Prix et Badge
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "${double.parse(ticket['price'] ?? '0').toStringAsFixed(0)} F",
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.bold,
                  color: darkBrown,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isSent
                      ? Color(0xffFE8C00).withOpacity(0.1)
                      : igsBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isSent ? "ENVOYÉ" : "REÇU",
                  style: GoogleFonts.montserrat(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: isSent ? Color(0xffFE8C00) : igsBlue,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      DateTime dt = DateTime.parse(dateStr);
      // Format: 21 Fév 2026 à 15:58
      return DateFormat('dd MMM yyyy à HH:mm', 'fr_FR').format(dt);
    } catch (e) {
      return dateStr;
    }
  }
}
