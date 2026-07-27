import 'package:flutter/material.dart';

import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:sky_p/config/api_config.dart';
import 'package:sky_p/services/download.dart';
import 'package:sky_p/services/header.dart';
import 'package:sky_p/services/api_service.dart';


class TicketUsagePage extends StatefulWidget {
  final List<Map<String, dynamic>> selectedTickets;
  final bool isExistingGroup;
  

  const TicketUsagePage({super.key, required this.selectedTickets,this.isExistingGroup = false});

  @override
  State<TicketUsagePage> createState() => _TicketUsagePageState();
}

class _TicketUsagePageState extends State<TicketUsagePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _groupId;
  String? _qrToken;
  String? _errorMessage;

  // Charte Graphique IGS
  static const Color igsBlue = Color(0xFF3473E4);
  static const Color igsYellow = Color(0xffFE8C00);
  static const Color lightGreyBg = Color(0xFFF5F5F5);

  @override
void initState() {
  super.initState();
  _tabController = TabController(length: 2, vsync: this);
  
  if (widget.isExistingGroup) {
    _loadExistingTicket();
  } else {
    _generateGroupToken();
  }
}


void _loadExistingTicket() {
  if (widget.selectedTickets.isEmpty) {
    setState(() => _isLoading = false);
    return;
  }

  final dynamic firstTicket = widget.selectedTickets.first;
  String? rawPath;

  if (firstTicket is Map) {
    rawPath = firstTicket['qr_code']?.toString();
    _groupId = firstTicket['id']?.toString();
  }

  debugPrint("=== _loadExistingTicket → qr_code brut: $rawPath");

  if (rawPath != null && rawPath.isNotEmpty && rawPath != "null") {
    setState(() {
      _qrToken = _formatQrUrl(rawPath!);
      _errorMessage = null;
      _isLoading = false;
    });
    debugPrint("SUCCÈS - URL GÉNÉRÉE : $_qrToken");
  } else {
    // Ne PAS appeler _generateGroupToken() ici
    // Afficher une erreur claire à la place
    setState(() {
      _qrToken = null;
      _errorMessage = "QR Code non disponible pour ce ticket";
      _isLoading = false;
    });
    debugPrint("ERREUR - qr_code absent dans: ${firstTicket.keys}");
  }
}
  Future<void> _generateGroupToken() async {
    try {
   

      final List<int> ticketIds = widget.selectedTickets
          .map<int>((t) => int.parse(t['id'].toString()))
          .toList();
      final header = await ApiHeaders.getHeaders();

      final response = await IgsHttpClient.post(
        Uri.parse("${ApiConfig.baseUrl}/tickets/group"),
        headers: header,
        body: json.encode({"ticket_ids": ticketIds}),
      );
      print("Réponse ticket grouper : ${response.body}");

   if (response.statusCode == 200 || response.statusCode == 201) {
  final data = json.decode(response.body);


  setState(() {
    // On cible la clé spécifique 'group_ticket' qui contient le qr_code
    String? rawPath;
    if (data['group_ticket'] != null) {
      rawPath = data['group_ticket']['qr_code'];
      _groupId = data['group_ticket']['id'].toString();
    }

    if (rawPath != null) {
      _qrToken = _formatQrUrl(rawPath); 
    }
    _isLoading = false;
  });
  print("URL GÉNÉRÉE : $_qrToken");
} else {
        setState(() {
          _errorMessage = "Erreur serveur (${response.statusCode})";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Erreur de connexion";
        _isLoading = false;
      });
    }
  }

  double get totalAmount => widget.selectedTickets.fold(
    0.0,
    (sum, item) => sum + (double.parse(item['valeur'].toString())),
  );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop:
          false, // On désactive le pop automatique pour le gérer manuellement
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        // On force le retour en envoyant 'true'
        Navigator.pop(context, true);
      },

      child: Scaffold(
        backgroundColor: lightGreyBg,
        appBar: AppBar(
          backgroundColor: igsBlue,
          elevation: 0,
          title: Text(
            "Paiement par Ticket",
            style: GoogleFonts.montserrat(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: TabBar(
            controller: _tabController,
            labelColor: igsYellow,
            unselectedLabelColor: Colors.white70,
            indicatorColor: igsYellow,
            indicatorWeight: 3,
            tabs: const [
              Tab(icon: Icon(Icons.qr_code_scanner_rounded), text: "Code QR"),
              Tab(icon: Icon(Icons.receipt_long_rounded), text: "Détails"),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: igsBlue))
            : _errorMessage != null
            ? _buildErrorView()
            : TabBarView(
                controller: _tabController,
                children: [_buildQrView(), _buildDetailsView()],
              ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.red,
              size: 50,
            ),
            const SizedBox(height: 10),
            Text(
              _errorMessage!,
              style: GoogleFonts.montserrat(),
              textAlign: TextAlign.center,
            ),
            TextButton(
              onPressed: () {
                
                setState(() => _isLoading = true);
                _generateGroupToken();
              },
              child: const Text("Réessayer", style: TextStyle(color: igsBlue)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQrView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 30,
            backgroundColor: Color(0xFFE3EDFF),
            child: Icon(Icons.sensors_rounded, color: igsBlue, size: 30),
          ),
          const SizedBox(height: 15),
          Text(
            "Présentez ce code a l'agent SKY-P",
            style: GoogleFonts.montserrat(
              fontSize: 14,
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 30),

          // --- STRUCTURE DU TICKET ---
          SizedBox(
            width: 300,
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Center(
                    child: _qrToken != null
                        ? Image.network(
                            _qrToken!,
                            width: 250,
                            height: 250,
                            fit: BoxFit.contain,
                            // Gestion des erreurs de chargement d'image
                            errorBuilder: (context, error, stackTrace) {
                              return const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.broken_image_rounded,
                                    size: 50,
                                    color: Colors.red,
                                  ),
                                  SizedBox(height: 10),
                                  Text("Impossible de charger l'image"),
                                ],
                              );
                            },
                            // Indicateur de chargement de l'image
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: igsBlue,
                                ),
                              );
                            },
                          )
                        : const Icon(
                            Icons.qr_code_2_rounded,
                            size: 200,
                            color: Colors.grey,
                          ),
                  ),
                ),

                // LIGNE DE POINTILLÉS
                Container(
                  color: Colors.white,
                  child: Row(
                    children: [
                      _buildNotch(isLeft: true),
                      Expanded(
                        child: CustomPaint(
                          size: const Size(double.infinity, 1),
                          painter: DashedLinePainter(
                            color: Colors.grey.shade300,
                          ),
                        ),
                      ),
                      _buildNotch(isLeft: false),
                    ],
                  ),
                ),

                // SECTION BASSE : MONTANT
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 25),
                  decoration: const BoxDecoration(
                    color: igsBlue,
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        "MONTANT TOTAL",
                        style: GoogleFonts.montserrat(
                          color: igsYellow,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "${totalAmount.toStringAsFixed(0)} FCFA",
                        style: GoogleFonts.montserrat(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: ElevatedButton.icon(
              onPressed: () {
                final String idToExport = _groupId ?? widget.selectedTickets.first['id'].toString();

                ExportService().downloadExport(
                  context,
                  "${ApiConfig.baseUrl}/tickets/$idToExport/export",
                  "Ticket_$idToExport",
                );
              },
              icon: const Icon(Icons.picture_as_pdf_rounded),
              label: Text(
                "TÉLÉCHARGER LE PDF",
                style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.redAccent,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                  side: const BorderSide(color: Colors.redAccent, width: 1),
                ),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 25),
          Text(
            "${widget.selectedTickets.length} ticket(s) sécurisé(s)",
            style: GoogleFonts.montserrat(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildNotch({required bool isLeft}) {
    return Container(
      height: 20,
      width: 10,
      decoration: BoxDecoration(
        color: lightGreyBg,
        borderRadius: BorderRadius.only(
          topRight: isLeft ? const Radius.circular(10) : Radius.zero,
          bottomRight: isLeft ? const Radius.circular(10) : Radius.zero,
          topLeft: !isLeft ? const Radius.circular(10) : Radius.zero,
          bottomLeft: !isLeft ? const Radius.circular(10) : Radius.zero,
        ),
      ),
    );
  }

  Widget _buildDetailsView() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: widget.selectedTickets.length,
      itemBuilder: (context, index) {
        final ticket = widget.selectedTickets[index];
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: ListTile(
            title: Text(
              "Ticket ${ticket['nature']} #${ticket['id']}",
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Expire le: ${ticket['expiry']}",
                  style: GoogleFonts.montserrat(
                    fontSize: 10,
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ),
            trailing: Text(
              "${double.parse(ticket['valeur'].toString()).toStringAsFixed(0)} F",
              style: GoogleFonts.montserrat(
                color: igsBlue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }
}

class DashedLinePainter extends CustomPainter {
  final Color color;
  DashedLinePainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    double dashWidth = 5, dashSpace = 3, startX = 0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}


String _formatQrUrl(String rawPath) {
  String cleanPath = rawPath.replaceAll('\\', '');
  if (cleanPath.startsWith('/')) cleanPath = cleanPath.substring(1);
  
  String rootUrl = ApiConfig.baseUrl.replaceAll('/api', '');
  if (!rootUrl.endsWith('/')) rootUrl += '/';
  
  return "$rootUrl$cleanPath";
}