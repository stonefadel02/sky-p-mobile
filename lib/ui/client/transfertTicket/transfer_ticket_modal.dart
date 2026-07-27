import 'package:custom_quick_alert/custom_quick_alert.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sky_p/config/api_config.dart';
import 'dart:convert';

import 'package:sky_p/services/header.dart';
import 'package:sky_p/services/api_service.dart';

class TransferTicketModal extends StatefulWidget {
  final List<Map<String, dynamic>> selectedTickets;

  const TransferTicketModal({super.key, required this.selectedTickets});

  @override
  State<TransferTicketModal> createState() => _TransferTicketModalState();
}

class _TransferTicketModalState extends State<TransferTicketModal> {
  final TextEditingController _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSending = false;

  static const Color igsBlue = Color(0xFF3473E4);
  // static const Color igsYellow = Color(0xFFFCBF01);

  Future<void> _sendInstantNotification(String recipientEmail, double montant) async {
  String safePath = recipientEmail.replaceAll('@', '_').replaceAll('.', '_');
  DatabaseReference ref = FirebaseDatabase.instance.ref("notifications/$safePath");

  // await ref.set({
  //   "title": "🎫 Nouveau ticket IGS !",
  //   "body": "Vous avez reçu un ticket d'une valeure de ${montant.toStringAsFixed(0)} FCFA",
  //   "timestamp": ServerValue.timestamp,
  // });

  await ref.push().set({
  "title": "🎫 Nouveau ticket ATM Energy !",
  "body": "Vous avez reçu un ticket d'une valeur de ${montant.toStringAsFixed(0)} FCFA",
  "timestamp": ServerValue.timestamp,
});
}

  Future<void> _processTransfer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSending = true);
    CustomQuickAlert.loading(title: "Transfert en cours...");

    try {
  
      
      // 1. Calculer le montant total pour la notification
      double totalMontant = 0;
      for (var t in widget.selectedTickets) {
        totalMontant += double.tryParse(t['valeur'].toString()) ?? 0;
      }

      // 2. Boucle de transfert vers ton API PHP
      for (var ticket in widget.selectedTickets) {
         final header = await ApiHeaders.getHeaders();
        final response = await IgsHttpClient.post(
          Uri.parse("${ApiConfig.baseUrl}/tickets/${ticket['id']}/transfer"),
          headers: header,
          body: jsonEncode({"email": _emailController.text.trim()}),
        );

        if (response.statusCode != 200) {
          throw Exception("Erreur lors du transfert du ticket #${ticket['id']}");
        }
      }

      // 3. ENVOI DE LA NOTIFICATION INSTANTANÉE (C'est ici que ça joue !)
      await _sendInstantNotification(_emailController.text.trim(), totalMontant);
      CustomQuickAlert.dismiss();

      if (mounted) {
      CustomQuickAlert.success(
        title: "Transféré !",
        message: "${widget.selectedTickets.length} ticket(s) envoyé(s) avec succès.",
        onConfirm: () {
          Navigator.of(context).pop();
          Navigator.pop(context, true); 
        },
      );
    }
    } catch (e) {
      CustomQuickAlert.dismiss();
      _showError("Une erreur est survenue lors du transfert.");
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

 void _showError(String m) => CustomQuickAlert.error(title: "Oups", message: m);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom, // Ajuste pour le clavier
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 25),
            Text(
              "Transférer ${widget.selectedTickets.length} ticket(s)",
              style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF26211E)),
            ),
            const SizedBox(height: 10),
            Text(
              "Entrez l'adresse email du destinataire",
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 25),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: GoogleFonts.montserrat(),
              decoration: InputDecoration(
                hintText: "exemple@domaine.com",
                prefixIcon: const Icon(Icons.alternate_email, color: igsBlue),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: igsBlue, width: 2)),
              ),
              validator: (value) => (value == null || !value.contains('@')) ? "Email invalide" : null,
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: igsBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 0,
                ),
                onPressed: _isSending ? null : _processTransfer,
                child: _isSending
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text("CONFIRMER LE TRANSFERT", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}