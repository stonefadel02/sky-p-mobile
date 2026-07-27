import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sky_p/ui/profile/delete_account_flow.dart';

class DeleteStep1FormDialog extends StatefulWidget {
  final String currentEmail;
  const DeleteStep1FormDialog({super.key, required this.currentEmail});

  @override
  State<DeleteStep1FormDialog> createState() => _DeleteStep1FormDialogState();
}

class _DeleteStep1FormDialogState extends State<DeleteStep1FormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  final _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.currentEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        "Suppression de compte",
        style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 18),
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Cette action initiée nécessite des vérifications.",
                style: GoogleFonts.montserrat(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 15),
              Text("Confirmer votre Email", style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: GoogleFonts.montserrat(fontSize: 14),
                decoration: InputDecoration(
                  hintText: "votre.email@igs.com",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.alternate_email, size: 18),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? "L'email est requis" : null,
              ),
              const SizedBox(height: 15),
              Text("Motif de votre départ", style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              TextFormField(
                controller: _reasonController,
                maxLines: 3,
                style: GoogleFonts.montserrat(fontSize: 14),
                decoration: InputDecoration(
                  hintText: "Dites-nous pourquoi vous souhaitez nous quitter...",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? "Le motif est obligatoire" : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("Annuler", style: GoogleFonts.montserrat(color: Colors.grey, fontWeight: FontWeight.bold)),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              String email = _emailController.text.trim();
              String reason = _reasonController.text.trim();
              Navigator.pop(context); // Ferme l'étape 1
              DeleteAccountService.navigateToStep2(context, email, reason); // Lance l'étape 2
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text("Continuer", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
