import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sky_p/config/api_config.dart';

class TicketDetailPage extends StatelessWidget {
  final dynamic ticket;
  const TicketDetailPage({super.key, required this.ticket});

  @override
  Widget build(BuildContext context) {
    String status = (ticket['status'] ?? '').toString();
    List<String> parts = ticket['created_at'].toString().split(' ');
    String datePart = parts[0];
    List<String> d = datePart.split('-');
    String dateFriendly = "${d[2]}-${d[1]}-${d[0]}";

    String rawPath = (ticket['qrcode'] ?? ticket['qr_code'] ?? "").toString();

    String qrPath = rawPath.replaceAll('\\', '');

    String qrUrl = "${ApiConfig.baseUrl1}/$qrPath";

    print("Tentative de chargement QR : $qrUrl");

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          "Détails du Ticket",
          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    "VOTRE TICKET",
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF3473E4),
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 25),
                  // Affichage du QR Code avec gestion d'erreur
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.network(
                      qrUrl,
                      height: 250,
                      width: 250,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Column(
                          children: [
                            const Icon(
                              Icons.qr_code_scanner,
                              size: 100,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "Erreur de chargement de l'image",
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 25),
                  Text(
                    "${double.parse(ticket['price'].toString()).toInt()} FCFA",
                    style: GoogleFonts.montserrat(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Divider(height: 40),
                  _detailRow(
                    "Statut",
                    status.isEmpty ? "Inconnu" : status.toUpperCase(),
                    isStatus: true,
                    isValid: status.toLowerCase() == 'valid',
                  ),
                  _detailRow("Nature", "Ticket ${ticket['nature']}"),

                  _detailRow("Date d'émission", "$dateFriendly à ${parts[1]}"),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(
    String label,
    String value, {
    bool isStatus = false,
    bool isValid = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.montserrat(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          if (isStatus)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isValid
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                value,
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.bold,
                  color: isValid ? Colors.green : Colors.red,
                  fontSize: 12,
                ),
              ),
            )
          else
            Text(
              value,
              style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
            ),
        ],
      ),
    );
  }
}
