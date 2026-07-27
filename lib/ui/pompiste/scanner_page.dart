import 'package:custom_quick_alert/custom_quick_alert.dart';
import 'package:flutter/material.dart';

import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sky_p/config/api_config.dart';
import 'package:sky_p/services/api_service.dart';
import 'package:sky_p/services/header.dart';
import 'package:sky_p/ui/widgets/appBarGeneral.dart';

class TicketScannerPage extends StatefulWidget {
  const TicketScannerPage({super.key});

  @override
  State<TicketScannerPage> createState() => _TicketScannerPageState();
}

class _TicketScannerPageState extends State<TicketScannerPage> {
  // Charte graphique IGS
  static const Color igsBlue = Color(0xFF3473E4);
  static const Color igsYellow = Color(0xFFFCBF01);
  static const Color darkBrown = Color(0xFF26211E);

  bool isProcessing = false;
  final MobileScannerController cameraController = MobileScannerController();

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  String _getFriendlyErrorMessage(String serverMessage) {
    final msg = serverMessage.toLowerCase();
    if (msg.contains("used") || msg.contains("déjà utilisé")) {
      return "Ce ticket a déjà été encaissé.";
    }
    if (msg.contains("expired") || msg.contains("expiré")) {
      return "La date de validité de ce ticket est dépassée.";
    }
    if (msg.contains("not found") || msg.contains("invalid")) {
      return "Ticket inconnu ou signature falsifiée.";
    }
    if (msg.contains("timeout") || msg.contains("connexion")) {
      return "Problème de réseau. Veuillez réessayer.";
    }
    return "Une erreur est survenue lors de la vérification.";
  }

  Future<void> verifyTicket(String code) async {
    if (isProcessing) return;
    setState(() => isProcessing = true);
    await cameraController.stop();

    String cleanSignature = code.trim();
    print("📡 [DEBUG SCANNER] Code scanné : '$cleanSignature'");

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? rawToken = prefs.getString('token');
      final String? token = rawToken?.trim().replaceAll('"', '');

      debugPrint("🔑 TOKEN NETTOYÉ : $token");

      if (token == null || token.isEmpty) {
        _showStatusError("Session expirée. Veuillez vous reconnecter.");
        setState(() => isProcessing = false);
        return;
      }

      final String apiUrl = ApiConfig.validateTicket(cleanSignature);
      print("📡 [DEBUG SCANNER] URL de validation (POST) : $apiUrl");

      final header = await ApiHeaders.getHeaders();
      print("📡 [DEBUG SCANNER] En-têtes envoyés : $header");

      final response = await IgsHttpClient.post(
        Uri.parse(apiUrl),
        headers: header,
      ).timeout(const Duration(seconds: 50));

      print("📡 [DEBUG SCANNER] Code Statut : ${response.statusCode}");
      print("📡 [DEBUG SCANNER] Content-Type : ${response.headers['content-type']}");
      print("📡 [DEBUG SCANNER] Corps de réponse brut : ${response.body}");

      // Vérification du JSON
      if (response.headers['content-type']?.contains('application/json') ??
          false) {
        final data = jsonDecode(response.body);
        print("📡 [DEBUG SCANNER] Données décodées : $data");

        if (response.statusCode == 200) {
          _showTicketDetailsSheet(data);
        } else {
          // ERREUR MÉTIER : Ticket utilisé ou expiré
          final String apiMsg = data['message']?.toString() ?? "Invalide";
          _showCustomError(_getFriendlyErrorMessage(apiMsg));
        }
      } else {
        // ERREUR SERVEUR (404, 500, etc.)
        _showCustomError("Impossible de valider ce ticket pour le moment (${response.statusCode}).");
      }
    } catch (e, stack) {
      print("❌ [DEBUG SCANNER ERREUR] Exception : $e");
      print("❌ [DEBUG SCANNER STACK] : $stack");
      _showCustomError("Erreur de connexion. Vérifiez votre internet. ($e)");
    } finally {
      if (mounted) setState(() => isProcessing = false);
    }
  }

  void _showCustomError(String message) {
    CustomQuickAlert.error(
      
      message: message,
      confirmBtnColor: Colors.red,
      confirmText: "RETOUR",
      onConfirm: () {
  // Supprime le Navigator.pop() complètement
  Future.microtask(() {
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const MainNavigation(
            role: 'pompiste',
            initialIndex: 1,
          ),
        ),
        (route) => false,
      );
    }
  });
},
    );
  }

  void _showTicketDetailsSheet(Map<String, dynamic> data) {
    final bool isValid = data['valid'] ?? false;

    final info = data['data'] is Map ? data['data'] : {};

    String displayMessage = "";
    if (data['message'] != null) {
      displayMessage = data['message'] is Map
          ? data['message'].toString()
          : data['message'].toString();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 20),

            CircleAvatar(
              radius: 35,
              backgroundColor: isValid
                  ? Colors.green.withOpacity(0.1)
                  : Colors.red.withOpacity(0.1),
              child: Icon(
                isValid ? Icons.check_circle_outline : Icons.cancel_outlined,
                color: isValid ? Colors.green : Colors.red,
                size: 45,
              ),
            ),
            const SizedBox(height: 15),
            Text(
              isValid ? "TICKET VALIDE" : "TICKET REFUSÉ",
              style: GoogleFonts.montserrat(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isValid ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 5),

            // MESSAGE SÉCURISÉ
            Text(
              displayMessage,
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(color: Colors.grey[600]),
            ),

            const SizedBox(height: 25),
            const Divider(),

            // On vérifie que les clés existent dans 'info' avant d'afficher
            _buildInfoRow(
              "Valeur",
              "${info['price'] ?? '0'} FCFA",
              isBold: true,
            ),
            _buildInfoRow(
              "Propriétaire",
              info['owner']?.toString() ?? "Client SKY-P",
            ),
            _buildInfoRow("Expire le", _formatDate(info['expires_at'])),

            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isValid ? igsBlue : Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),

                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MainNavigation(
                        role: 'pompiste',
                        initialIndex:
                            1, // 1 correspond à TicketHistoryPage dans votre liste _pompistePages
                      ),
                    ),
                    (route) => false,
                  );
                },

                child: Text(
                  "SUIVANT",
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic dateData) {
    if (dateData == null) return "N/A";

    String dateString;

    if (dateData is Map && dateData.containsKey('date')) {
      dateString = dateData['date'].toString();
    } else {
      dateString = dateData.toString();
    }

    try {
      DateTime dt = DateTime.parse(dateString);
      return "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}";
    } catch (e) {
      return dateString.split(' ')[0];
    }
  }

  void _showStatusError(String message) {
    showDialog(
      context: context,
      barrierDismissible: false, // Force l'utilisateur à cliquer sur OK
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "NOTIFICATION",
          style: GoogleFonts.montserrat(
            color: Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(message, style: GoogleFonts.montserrat()),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => const MainNavigation(
                    role: 'pompiste',
                    initialIndex:
                        1, // 1 correspond à TicketHistoryPage dans votre liste _pompistePages
                  ),
                ),
                (route) => false,
              );
            },

            child: Text(
              "VOIR L'HISTORIQUE",
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.bold,
                color: igsBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.montserrat(
              color: Colors.grey[500],
              fontSize: 13,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.montserrat(
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              fontSize: 14,
              color: isBold ? igsBlue : darkBrown,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty && !isProcessing) {
                final String? code = barcodes.first.rawValue;
                if (code != null) verifyTicket(code);
              }
            },
          ),
          CustomPaint(
            painter: IGSScannerPainter(igsBlue, igsYellow),
            child: Container(),
          ),
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CircleAvatar(
                  backgroundColor: igsBlue,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: igsYellow),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                Text(
                  "SCANNER",
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                CircleAvatar(
                  backgroundColor: igsBlue,
                  child: ValueListenableBuilder(
                    valueListenable: cameraController,
                    builder: (context, state, child) {
                      return IconButton(
                        icon: Icon(
                          state.torchState == TorchState.on
                              ? Icons.flash_on
                              : Icons.flash_off,
                          color: igsYellow,
                        ),
                        onPressed: () => cameraController.toggleTorch(),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          if (isProcessing)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: igsYellow),
                    const SizedBox(height: 20),
                    Text(
                      "VÉRIFICATION...",
                      style: GoogleFonts.montserrat(
                        color: igsYellow,
                        fontWeight: FontWeight.bold,
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
}

class IGSScannerPainter extends CustomPainter {
  final Color overlayColor;
  final Color borderColor;
  IGSScannerPainter(this.overlayColor, this.borderColor);

  @override
  void paint(Canvas canvas, Size size) {
    final double scanBoxSize = 250.0;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: scanBoxSize,
      height: scanBoxSize,
    );
    final paintBackground = Paint()..color = overlayColor.withOpacity(0.5);
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()
          ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(30))),
      ),
      paintBackground,
    );
    final paintBorder = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(30)),
      paintBorder,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
