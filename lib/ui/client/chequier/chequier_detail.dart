import 'package:flutter/material.dart';

import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sky_p/config/api_config.dart';
import 'package:sky_p/services/api_service.dart';
import 'package:sky_p/services/download.dart';
import 'package:sky_p/services/header.dart';
import 'package:sky_p/ui/client/chequier/ticket_usage_page.dart';
import 'package:sky_p/ui/client/transfertTicket/transfer_ticket_modal.dart';

class GroupDetailPage extends StatefulWidget {
  final String groupId;
  const GroupDetailPage({super.key, required this.groupId});

  @override
  State<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends State<GroupDetailPage> {
  // Charte graphique IGS
  static const Color igsBlue = Color(0xFF3473E4);
  static const Color igsYellow = Color(0xffFE8C00);
  static const Color darkBrown = Color(0xFF26211E);

  List<Map<String, dynamic>> tickets = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchTickets();
  }

  void _showTransferModal() async {
    final selection = tickets.where((t) => t['selected']).toList();

    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) => TransferTicketModal(selectedTickets: selection),
    );

    if (result == true) {
      setState(() {
        isLoading = true; // On affiche le loader pendant le rafraîchissement
      });
      _fetchTickets();

      // Optionnel : Désélectionner tout après un succès pour nettoyer l'interface
      _toggleSelectAll(false);
    }
  }

  Future<void> _fetchTickets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('token');

      if (token == null) throw Exception("Token non trouvé");

      final url = Uri.parse(
        "${ApiConfig.baseUrl}/chequiers/${widget.groupId}/tickets",
      );
      final header = await ApiHeaders.getHeaders();

      final response = await IgsHttpClient.get(
        url,
        forceRefresh: true,
        headers: header,
      );
      print ("Réponse chequier detail : ${response.body}");

      if (response.statusCode == 200) {
        final dynamic decodedData = json.decode(response.body);
        print("Données brutes reçues: $decodedData"); // Log pour debug
        List<dynamic> rawList = [];

        if (decodedData is Map) {
          if (decodedData.containsKey('tickets')) {
            rawList = decodedData['tickets'];
          } else if (decodedData.containsKey('data')) {
            rawList = decodedData['data'];
          }
        } else if (decodedData is List) {
          rawList = decodedData;
        }

        setState(() {
          tickets = rawList.map((t) {
            String expiry = "N/A";
            if (t['expires_at'] != null && t['expires_at'] is Map) {
              expiry = t['expires_at']['date'].toString().split(' ')[0];
            }

            String natureDetectee =
                t['nature']?.toString() ??
                t['type']?.toString() ??
                t['category']?.toString() ??
                "SIMPLE";
            return {
              "id": t['id'],
              "code": t['code'] ?? "",
              "valeur": double.parse(
                t['price']?.toString() ?? t['ticket_price']?.toString() ?? '0',
              ),
              "nature": natureDetectee.toUpperCase(),
              "expiry": expiry,
              "qr_code": t['qr_code'],
              "valid":
                  t['used'] == false ||
                  t['used'] == 0 ||
                  t['status'] == 'available',
              "selected": false,
            };
          }).toList();
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = "Erreur serveur: ${response.statusCode}";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "Erreur: $e";
        isLoading = false;
      });
    }
  }

  double get totalSelected => tickets
      .where((t) => t['selected'] == true)
      .fold(0.0, (sum, item) => sum + (item['valeur'] as double));

  void _toggleSelectAll(bool? value) {
    setState(() {
      for (var t in tickets) {
        if (t['valid']) t['selected'] = value ?? false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final availableTickets = tickets.where((t) => t['valid']).toList();
    final usedTickets = tickets.where((t) => !t['valid']).toList();
    bool isAllSelected =
        availableTickets.isNotEmpty &&
        availableTickets.every((t) => t['selected']);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: Text(
            "Détails du Chéquier",
            style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: igsBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
          ),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (value) async {
  if (value == 'download') {
    final exportUrl = "${ApiConfig.baseUrl}/chequiers/${widget.groupId}/export";
    
    // --- BLOC DE DEBUG ---
    print("--- TENTATIVE D'EXPORT ---");
    print("URL d'export : $exportUrl");
    print("ID du groupe utilisé : ${widget.groupId}");
    
    try {
      // On récupère les headers pour voir si le Token est bien là
      final headers = await ApiHeaders.getHeaders();
      print("Headers envoyés : $headers");

      // On fait un test manuel avant de laisser le service de téléchargement prendre le relais
      final testResponse = await http.get(Uri.parse(exportUrl), headers: headers);
      
      print("Code de réponse : ${testResponse.statusCode}");
      print("Corps de réponse (si erreur) : ${testResponse.body}");
      
      if (testResponse.statusCode == 200) {
        print("Succès ! Lancement du téléchargement réel...");
        // Si le test est OK, on lance le vrai téléchargement
        ExportService().downloadExport(
          context,
          exportUrl,
          "Chequier_${widget.groupId}",
        );
      } else {
        print("ERREUR : Le serveur renvoie une erreur sur cette route.");
      }
    } catch (e) {
      print("ERREUR FATALE lors de l'appel : $e");
    }
    print("--- FIN DEBUG EXPORT ---");
  }
},
              itemBuilder: (BuildContext context) => [
                PopupMenuItem<String>(
                  value: 'download',
                  child: Row(
                    children: [
                      const Icon(
                        Icons.picture_as_pdf_rounded,
                        color: Colors.redAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        "Télécharger PDF",
                        style: GoogleFonts.montserrat(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          bottom: TabBar(
            indicatorColor: igsYellow,
            indicatorWeight: 4,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: GoogleFonts.montserrat(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            unselectedLabelStyle: GoogleFonts.montserrat(
              fontWeight: FontWeight.normal,
              fontSize: 14,
            ),
            tabs: const [
              Tab(
                icon: Icon(Icons.confirmation_num_outlined),
                text: "Disponibles",
              ),
              Tab(
                icon: Icon(Icons.history_toggle_off_rounded),
                text: "Utilisés",
              ),
            ],
          ),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator(color: igsBlue))
            : RefreshIndicator(
                onRefresh: _fetchTickets, // Permet le "Pull to refresh"
                color: igsBlue,
                child: TabBarView(
                  children: [
                    _buildTicketList(
                      availableTickets,
                      canSelect: true,
                      isAllSelected: isAllSelected,
                    ),
                    _buildTicketList(usedTickets, canSelect: false),
                  ],
                ),
              ),
        bottomNavigationBar: totalSelected > 0
            ? _buildSelectionSummaryBar()
            : null,

        floatingActionButton: _buildFloatingMenu(),
      ),
    );
  }

  Widget _buildSelectionSummaryBar() {
    final selectedCount = tickets.where((t) => t['selected']).length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$selectedCount ticket(s) sélectionné(s)",
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  "${totalSelected.toStringAsFixed(0)} FCFA",
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: igsBlue,
                  ),
                ),
              ],
            ),
            // Optionnel : Un petit bouton pour vider la sélection
            TextButton(
              onPressed: () => _toggleSelectAll(false),
              child: Text(
                "Effacer",
                style: GoogleFonts.montserrat(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingMenu() {
    return SpeedDial(
      icon: Icons.add,
      activeIcon: Icons.close,
      backgroundColor: igsYellow,
      foregroundColor: darkBrown,
      overlayColor: Colors.black,
      overlayOpacity: 0.5,
      spacing: 12,
      spaceBetweenChildren: 12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      children: [
        // Action UTILISER
        SpeedDialChild(
          child: const Icon(Icons.confirmation_num_outlined),
          backgroundColor: igsYellow,
          foregroundColor: darkBrown,
          label: 'UTILISER (${totalSelected.toStringAsFixed(0)} FCFA)',
          labelStyle: GoogleFonts.montserrat(
            fontWeight: FontWeight.bold,
            color: darkBrown,
          ),
          labelBackgroundColor: igsYellow,
          onTap: totalSelected > 0
              ? () async {
                  final selection = tickets
                      .where((t) => t['selected'])
                      .toList();
                  bool isAlreadyGrouped =
                      selection.length == 1 &&
                      selection.first['nature'] == "GROUPE";

                  // Un seul ticket SIMPLE → utiliser son QR directement
                  bool isSingleSimple =
                      selection.length == 1 &&
                      selection.first['nature'] == "SIMPLE";

                  // 1. On attend le retour de la page
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (c) => TicketUsagePage(
                        selectedTickets: selection,
                        isExistingGroup: isAlreadyGrouped || isSingleSimple,
                      ),
                    ),
                  );

                  // 2. Si result est true, on rafraîchit la liste
                  if (result == true) {
                    setState(() {
                      isLoading = true; // On affiche le loader
                    });
                    _fetchTickets(); // On recharge les tickets depuis l'API
                  }
                }
              : null,
        ),
        // Action TRANSFÉRER
        SpeedDialChild(
          child: const Icon(Icons.send_rounded),
          backgroundColor: igsBlue,
          foregroundColor: Colors.white,
          label: 'TRANSFÉRER',
          labelStyle: GoogleFonts.montserrat(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          labelBackgroundColor: igsBlue,
          onTap: totalSelected > 0
              ? () => _showTransferModal()
              : () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Veuillez sélectionner au moins un ticket"),
                    ),
                  );
                },
        ),
      ],
    );
  }

  Widget _buildTicketList(
    List<Map<String, dynamic>> filteredTickets, {
    required bool canSelect,
    bool isAllSelected = false,
  }) {
    if (filteredTickets.isEmpty) {
      return Center(
        child: Text(
          "Aucun ticket trouvé",
          style: GoogleFonts.montserrat(color: Colors.grey),
        ),
      );
    }

    return Column(
      children: [
        if (canSelect)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 15, 30, 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(
                10,
              ), // Pour un effet de clic propre
              onTap: () => _toggleSelectAll(!isAllSelected),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    // Cet espace correspond exactement au retrait de l'icône dans la carte
                    const SizedBox(width: 59),
                    Expanded(
                      child: Text(
                        "Tout sélectionner",
                        style: GoogleFonts.montserrat(
                          fontSize: 17,
                          fontWeight: FontWeight
                              .w700, // Un peu plus gras pour l'en-tête
                          color: darkBrown.withOpacity(0.8),
                        ),
                      ),
                    ),
                    _buildCustomCheckbox(isAllSelected),
                  ],
                ),
              ),
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: filteredTickets.length,
            itemBuilder: (context, index) {
              final ticket = filteredTickets[index];
              bool isSelected = ticket['selected'];

              return GestureDetector(
                onTap: canSelect
                    ? () => setState(() => ticket['selected'] = !isSelected)
                    : null,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? igsYellow : Colors.transparent,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: canSelect
                              ? igsBlue.withOpacity(0.1)
                              : Colors.grey[100],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.business_center,
                          color: canSelect ? igsBlue : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ticket ${ticket['nature']} N° ${ticket['id']}',
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              "${ticket['valeur'].toStringAsFixed(0)} FCFA",
                              style: GoogleFonts.montserrat(
                                color: igsYellow,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (canSelect)
                        _buildCustomCheckbox(isSelected)
                      else
                        const Icon(
                          Icons.lock_reset_rounded,
                          color: Colors.grey,
                          size: 22,
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCustomCheckbox(bool isSelected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: isSelected ? igsBlue : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? igsBlue : Colors.grey.shade400,
          width: 2,
        ),
      ),
      child: isSelected
          ? const Icon(Icons.check, size: 16, color: Colors.white)
          : null,
    );
  }
}
