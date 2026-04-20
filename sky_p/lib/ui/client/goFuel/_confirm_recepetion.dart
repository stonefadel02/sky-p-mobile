import 'package:custom_quick_alert/custom_quick_alert.dart';
import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:signature/signature.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:sky_p/config/api_config.dart';
import 'package:sky_p/services/header.dart';
import 'package:sky_p/ui/widgets/igs_app_bar.dart';


class ConfirmDeliveryPage extends StatefulWidget {
  final Map<String, dynamic> orderData;
  final String orderId;

  const ConfirmDeliveryPage({
    super.key,
    required this.orderId,
    required this.orderData,
  });

  @override
  State<ConfirmDeliveryPage> createState() => _ConfirmDeliveryPageState();
}

class _ConfirmDeliveryPageState extends State<ConfirmDeliveryPage> {
  // --- VARIABLES ---
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: const Color(0xFF26211E),
    exportBackgroundColor: Colors.white,
  );

  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;
  bool _isLoading = true; // Pour l'état de chargement initial
  Map<String, dynamic>? _orderData; // Contiendra les détails du back

  static const Color igsBlue = Color(0xFF3473E4);
  static const Color darkBrown = Color(0xFF26211E);

  @override
  void initState() {
    super.initState();
    _orderData = widget.orderData;
    final String status =
        widget.orderData['livraison_status']?.toString().toLowerCase() ?? '';
    _isAlreadyDelivered = status == 'done';
    _isLoading = false;
  }

  bool _isAlreadyDelivered = false;

  Future<void> _submitConfirmation() async {
    if (_signatureController.isEmpty) return;

    setState(() => _isSubmitting = true);
    CustomQuickAlert.loading(title: "Envoi du fichier...");

    try {
      // 1. Convertir la signature en bytes (Uint8List)
      final signatureBytes = await _signatureController.toPngBytes();
      if (signatureBytes == null) return;

 

      // 2. Créer une requête Multipart (au lieu d'un http.post classique)
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(
          "${ApiConfig.baseUrl}/fuel-livraisons/${widget.orderId}/complete",
        ),
      );
      final header = await ApiHeaders.getHeaders();
      // 3. Ajouter les headers
      request.headers.addAll(header);

      // 4. Ajouter les champs texte simples
      request.fields['livraison_id'] = widget.orderId;
      request.fields['commentaire'] = _commentController.text;

      // 5. Ajouter le FICHIER (la signature)
      request.files.add(
        http.MultipartFile.fromBytes(
          'signature',
          signatureBytes,
          filename: 'signature_${widget.orderId}.png',
          contentType: http.MediaType('image', 'png'),
        ),
      );

      // 6. Envoyer la requête
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      print("Body confirm : ${response.body}");

      CustomQuickAlert.dismiss();

      if (response.statusCode == 200 || response.statusCode == 201) {
        CustomQuickAlert.success(
          title: "Succès",
          message: "Livraison confirmée !",
          onConfirm: () {
            Navigator.of(context).pop(); // Ferme l'alerte
            Navigator.of(context).pop(true); // ✅ Retourne à la liste
          },
        );
      } else {
        _showError("Erreur serveur : ${response.statusCode}");
      }
    } catch (e) {
      CustomQuickAlert.dismiss();
      _showError("Erreur de connexion.");
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String msg) {
    CustomQuickAlert.error(
      title: "Oups",
      message: msg,
      confirmBtnColor: Colors.red,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const IgsAppBar(title: 'Confirmation'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: igsBlue))
          : SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Confirmation",
                    style: GoogleFonts.montserrat(
                      color: darkBrown,
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    "Vérifiez les détails et signez pour terminer.",
                    style: GoogleFonts.montserrat(
                      color: Colors.grey[600],
                      fontSize: 13.sp,
                    ),
                  ),

                  SizedBox(height: 25.h),

                  // --- RÉCAPITULATIF DYNAMIQUE ---
                  Container(
                    padding: EdgeInsets.all(16.r),
                    decoration: BoxDecoration(
                      color: igsBlue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(15.r),
                      border: Border.all(color: igsBlue.withOpacity(0.1)),
                    ),
                    child: Column(
                      children: [
                        _buildDetailRow(
                          "Produit",
                          (_orderData?['type_carburant'] ?? '---')
                              .toString()
                              .toUpperCase(),
                        ),
                        // FORMATAGE QUANTITÉ (Enlève les .00)
                        _buildDetailRow(
                          "Quantité",
                          _formatQuantity(
                            _orderData?['nombre_litres'] ??
                                _orderData?['litres'],
                          ),
                        ),

                        // AFFICHAGE MONTANT (Clé montant_total vue dans ton log)
                        _buildDetailRow(
                          "Montant",
                          "${_formatAmount(_orderData?['montant_total'] ?? _orderData?['montant'])} F CFA",
                        ),
                        const Divider(),
                        _buildDetailRow("Référence", "#${widget.orderId}"),
                      ],
                    ),
                  ),

                  // ... à l'intérieur de ta Column après le récapitulatif ...
                  if (!_isAlreadyDelivered) ...[
                    // ON AFFICHE SI PAS ENCORE LIVRÉ
                    _buildSectionTitle("Signature du client"),
                    SizedBox(height: 12.h),
                    _buildSignatureZone(),

                    SizedBox(height: 25.h),
                    _buildSectionTitle("Commentaires (Optionnel)"),
                    SizedBox(height: 10.h),
                    _buildCommentField(),

                    SizedBox(height: 40.h),
                    _buildSubmitButton(),
                  ] else ...[
                    // ON AFFICHE UN MESSAGE DE SUCCÈS SI DÉJÀ LIVRÉ
                    Container(
                      width: double.infinity,
                      margin: EdgeInsets.only(top: 20.h),
                      padding: EdgeInsets.all(16.r),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(15.r),
                        border: Border.all(
                          color: Colors.green.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.verified_rounded,
                            color: Colors.green,
                            size: 40,
                          ),
                          SizedBox(height: 10.h),
                          Text(
                            "LIVRAISON TERMINÉE",
                            style: GoogleFonts.montserrat(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 16.sp,
                            ),
                          ),
                          Text(
                            "Cette commande a déjà été confirmée.",
                            style: GoogleFonts.montserrat(
                              color: Colors.green[700],
                              fontSize: 12.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  // --- WIDGETS DE CONSTRUCTION ---
  Widget _buildSignatureZone() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(15.r),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(15.r)),
            child: Signature(
              controller: _signatureController,
              height: 180.h,
              backgroundColor: const Color(0xFFF9F9F9),
            ),
          ),
          TextButton.icon(
            onPressed: () => _signatureController.clear(),
            icon: const Icon(
              Icons.refresh_rounded,
              color: Colors.red,
              size: 18,
            ),
            label: Text(
              "Effacer la signature",
              style: GoogleFonts.montserrat(color: Colors.red, fontSize: 12.sp),
            ),
          ),
        ],
      ),
    );
  }

  // Transforme "10.00" ou 10.0 en "10"
  String _formatQuantity(dynamic value) {
    if (value == null) return "0";
    double? parsed = double.tryParse(value.toString());
    if (parsed == null) return value.toString();
    return parsed.toInt().toString(); // .toInt() supprime les décimales
  }

  // Transforme "10000.00" en "10 000" (ou juste 10000)
  String _formatAmount(dynamic value) {
    if (value == null) return "0";
    double? parsed = double.tryParse(value.toString());
    if (parsed == null) return value.toString();

    final formatter = NumberFormat("#,###", "fr_FR");
    return formatter.format(parsed.toInt()).replaceAll(',', ' ');
  }

  Widget _buildCommentField() {
    return TextField(
      controller: _commentController,
      maxLines: 2,
      decoration: InputDecoration(
        hintText: "Tout s'est bien passé ?",
        filled: true,
        fillColor: const Color(0xFFF9F9F9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 55.h,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitConfirmation,
        style: ElevatedButton.styleFrom(
          backgroundColor: igsBlue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
        ),
        child: _isSubmitting
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
                "VALIDER LA RÉCEPTION",
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.montserrat(
        fontWeight: FontWeight.w700,
        fontSize: 14.sp,
        color: darkBrown,
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 13.sp,
              color: Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: GoogleFonts.montserrat(
              fontSize: 13.sp,
              fontWeight: FontWeight.bold,
              color: darkBrown,
            ),
          ),
        ],
      ),
    );
  }
}
