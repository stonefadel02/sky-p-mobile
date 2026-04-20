import 'package:flutter/material.dart';

import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:sky_p/config/api_config.dart';
import 'package:sky_p/services/api_service.dart';
import 'package:sky_p/services/header.dart';
import 'package:sky_p/ui/widgets/state_handler.dart';


class TicketHistoryPage extends StatefulWidget {
  const TicketHistoryPage({super.key});

  @override
  State<TicketHistoryPage> createState() => _TicketHistoryPageState();
}

class _TicketHistoryPageState extends State<TicketHistoryPage> {
  static const Color igsBlue = Color(0xFF3473E4);
  // static const Color igsYellow = Color(0xFFFCBF01);

  List<dynamic> scanHistory = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() => isLoading = true);
    try {
  
      final header = await ApiHeaders.getHeaders();
      final response = await IgsHttpClient.get(

        Uri.parse("${ApiConfig.baseUrl}/tickets/history"),
        forceRefresh: true,
        headers: header,
      );
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print("historique scannee reçues : $data");
        setState(() {
          scanHistory = data is List ? data : (data['data'] ?? []);
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
        errorMessage = "Erreur de connexion";
        isLoading = false;
      });
    }finally {
    // CE BLOC S'EXÉCUTE TOUJOURS
    if (mounted) {
      setState(() => isLoading = false);
    }
  }
  }

  @override
  Widget build(BuildContext context) {
    // AJOUT DU SCAFFOLD POUR ÉVITER L'ÉCRAN NOIR
    return Scaffold(
      backgroundColor: Colors.grey[50], // Fond très clair pro
      // appBar: AppBar(
      //   title: Text(
      //     "HISTORIQUE",
      //     style: GoogleFonts.montserrat(
      //       fontWeight: FontWeight.bold,
      //       fontSize: 16,
      //     ),
      //   ),
      //   backgroundColor: Colors.white,
      //   foregroundColor: igsBlue,
      //   elevation: 0,
      //   centerTitle: true,
      //   leading: IconButton(
      //     icon: const Icon(Icons.arrow_back_ios_new, size: 20),
      //     onPressed: () => Navigator.of(context).pushAndRemoveUntil(
      //       MaterialPageRoute(
      //         // ATTENTION : Remplace 'PompisteMainPage' par le vrai nom de ton
      //         // widget qui contient le Scaffold principal et la BottomNav
      //         builder: (context) => const PompisteHomeBody(),
      //       ),
      //       (route) => false,
      //     ),
      //   ),
      // ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading)
      return const Center(child: CircularProgressIndicator(color: igsBlue));
    if (errorMessage != null) return _buildErrorView();

    return RefreshIndicator(
      onRefresh: _fetchHistory,
      color: igsBlue,
      child: scanHistory.isEmpty ? _buildEmptyView() : _buildList(),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      itemCount: scanHistory.length,
      itemBuilder: (context, index) {
        final item = scanHistory[index];
        final ticket = item['ticket'] ?? item;
        final String dateStr = item['scanned_at'] ?? item['created_at'] ?? "";

        // Logique de statut : adapter selon les valeurs réelles de ton API
        final bool isUsed =
            item['status'] == 'used' || item['status'] == 'utilisé';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
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
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            // ICÔNE DYNAMIQUE : CROIX ROUGE OU CHECK VERT
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isUsed
                    ? Colors.red.withOpacity(0.1)
                    : Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isUsed ? Icons.close : Icons.check,
                color: isUsed ? Colors.red : Colors.green,
                size: 24,
              ),
            ),
            title: Text(
              "Ticket #${ticket['id'] ?? 'N/A'}",
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  _formatDate(dateStr),
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
                Text(
                  isUsed ? "Déjà utilisé" : "Validé avec succès",
                  style: GoogleFonts.montserrat(
                    fontSize: 11,
                    color: isUsed ? Colors.red[300] : Colors.green[300],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            trailing: Text(
              "${ticket['price'] ?? '0'} F",
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w900,
                color: igsBlue,
                fontSize: 16,
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatDate(dynamic dateData) {
    if (dateData == null || dateData == "") return "N/A";

    String dateString;
    if (dateData is Map && dateData.containsKey('date')) {
      dateString = dateData['date'].toString();
    } else {
      dateString = dateData.toString();
    }

    try {
      DateTime dt = DateTime.parse(dateString);
      return "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} à ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return dateString.split('.')[0];
    }
  }

  Widget _buildEmptyView() {
    return IGSStateDisplay(
      animation: 'empty_box', // Ton fichier renommé
      title: "Historique vide",
      message: "Vous n'avez encore scanné aucun ticket pour le moment.",
      onAction: _fetchHistory,
      actionLabel: "ACTUALISER",
    );
  }

  Widget _buildErrorView() {
    return IGSStateDisplay(
      animation: 'no_internet', // Ton fichier renommé
      title: "Oups !",
      message:
          errorMessage ??
          "Une erreur est survenue lors de la récupération de l'historique.",
      onAction: _fetchHistory,
      actionLabel: "RÉESSAYER",
    );
  }
}
