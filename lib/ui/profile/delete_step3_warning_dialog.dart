import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sky_p/ui/profile/delete_account_flow.dart';

class DeleteStep3WarningDialog extends StatelessWidget {
  final String email;
  final String reason;

  const DeleteStep3WarningDialog({super.key, required this.email, required this.reason});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: const Color(0xFFFFF5F5),
      title: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
          const SizedBox(width: 10),
          Text(
            "Dernier avertissement",
            style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 16),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "La suppression de votre compte inclut :",
            style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 14, color: DeleteAccountService.darkBrown),
          ),
          const SizedBox(height: 12),
          _buildBulletItem("La suppression définitive de vos données personnelles."),
          _buildBulletItem("L'annulation de tous vos carnet de bon d’essence et tickets actifs."),
          _buildBulletItem("La perte de l'accès à l'historique de vos consommations."),
          _buildBulletItem("Cette action est irréversible."),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("Annuler", style: GoogleFonts.montserrat(color: Colors.grey, fontWeight: FontWeight.bold)),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context); // Ferme l'étape 3
            DeleteAccountService.sendDeleteRequest(context, email, reason); // Envoi final au serveur
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: Text("SUPPRIMER DÉFINITIVEMENT", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 11)),
        ),
      ],
    );
  }

  Widget _buildBulletItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("• ", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.montserrat(fontSize: 13, color: DeleteAccountService.darkBrown),
            ),
          ),
        ],
      ),
    );
  }
}
