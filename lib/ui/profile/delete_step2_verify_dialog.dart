import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sky_p/ui/profile/delete_account_flow.dart';

class DeleteStep2VerifyDialog extends StatefulWidget {
  final String email;
  final String reason;

  const DeleteStep2VerifyDialog({super.key, required this.email, required this.reason});

  @override
  State<DeleteStep2VerifyDialog> createState() => _DeleteStep2VerifyDialogState();
}

class _DeleteStep2VerifyDialogState extends State<DeleteStep2VerifyDialog> {
  final _textController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  static const String _expectedPhrase = "je veux supprimer mon compte";

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        "Confirmation de sécurité",
        style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Pour confirmer, veuillez saisir la phrase exacte ci-dessous :",
              style: GoogleFonts.montserrat(fontSize: 13),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              width: double.infinity,
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
              child: Text(
                _expectedPhrase,
                style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.redAccent, fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: _textController,
              style: GoogleFonts.montserrat(fontSize: 14),
              decoration: InputDecoration(
                hintText: "Saisissez la phrase ici",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) {
                if (v == null || v.trim() != _expectedPhrase) {
                  return "La phrase ne correspond pas";
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("Retour", style: GoogleFonts.montserrat(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context); // Ferme l'étape 2
              DeleteAccountService.navigateToStep3(context, widget.email, widget.reason); // Lance l'étape 3
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
          child: Text("Vérifier", style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
