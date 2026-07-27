import 'dart:convert';
import 'dart:developer' as dev;

import 'package:custom_quick_alert/custom_quick_alert.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:kkiapay_flutter_sdk/kkiapay_flutter_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sky_p/config/api_config.dart';
import 'package:sky_p/core/theme/ui_helpers.dart';
import 'package:sky_p/services/api_service.dart';
import 'package:sky_p/services/header.dart';
import 'package:sky_p/ui/client/chequier/cheque_payment_form.dart';
import 'package:sky_p/ui/widgets/igs_app_bar.dart';

class CreateTicketPage extends StatefulWidget {
  const CreateTicketPage({super.key});

  @override
  State<CreateTicketPage> createState() => _CreateTicketPageState();
}

class _CreateTicketPageState extends State<CreateTicketPage> {
  final _formKey = GlobalKey<FormState>();

  static const Color igsBlue = Color(0xFF3473E4);
  static const Color darkBrown = Color(0xFF26211E);

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _labelController = TextEditingController();

  bool _isSaving = false;
  bool _showChequeForm = false;
  int _paymentAmount = 0;
  String? _qrCodeUrl;

  static const double _minAmount = 1000;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amountController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  bool get _isAmountValid =>
      (double.tryParse(_amountController.text) ?? 0) >= _minAmount;

  void _startPayment() async {
    if (!_formKey.currentState!.validate()) return;

    final double amount = double.parse(_amountController.text);
    if (amount <= 0) {
      _showSnackBar("Le montant doit être supérieur à 0", Colors.orange);
      return;
    }

    if (amount >= 1000000) {
      setState(() {
        _paymentAmount = amount.toInt();
        _showChequeForm = true;
      });
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    String phoneToUse = prefs.getString('user_phone') ?? '';
    if (ApiConfig.isSandbox) {
      phoneToUse = "61000000";
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => KKiaPay(
          amount: amount.toInt(),
          apikey: ApiConfig.kkiapayPublicKey,
          sandbox: ApiConfig.isSandbox,
          callback: _handlePaymentResponse,
          reason: "Émission de ticket SKY-P : ${_labelController.text}",
          theme: "#3473E4",
          countries: const ["BJ"],
          paymentMethods: const ["momo", "card"],
          name: prefs.getString('user_name') ?? '',
          phone: phoneToUse,
        ),
      ),
    );
  }

  void _handlePaymentResponse(
    Map<String, dynamic> response,
    BuildContext context,
  ) async {
    final String status = response['status']?.toString() ?? 'FAILED';
    final String transactionId = response['transactionId']?.toString() ?? '';
    print("Réponse Kkiapay: $response");

    final String statusUpper = status.toUpperCase();
    if (statusUpper.contains('SUCCESS') || statusUpper.contains('COMPLETED')) {
      Navigator.pop(context); // Ferme l'interface Kkiapay

      _submitData(transactionId: transactionId, paymentStatus: status, paymentMethod: "kkiapay");
    } else {
      _showSnackBar("Paiement en validation", Colors.orange);
    }
  }

  Future<void> _submitData({
    String? transactionId,
    String? paymentStatus,
    String? paymentMethod,
    ChequePaymentData? chequeData,
  }) async {
    IgsAlerts.showLoading("Création de votre ticket en cours...");

    try {
      final header = await ApiHeaders.getHeaders();
      http.Response response;

      if (chequeData != null) {
        final Map<String, String> fields = {
          "price": chequeData.amount,
          "label": _labelController.text,
          "provider": "SKY-P",
          "payment_method": chequeData.paymentMethod,
          "payment_status": "PENDING",
          "bank_name": chequeData.bankName,
          "transaction_id": chequeData.paymentMethod == 'cheque'
              ? "CHQ_${chequeData.chequeNumber}"
              : "VIR_${chequeData.transferReference}",
        };

        if (chequeData.paymentMethod == 'cheque') {
          fields['cheque_number'] = chequeData.chequeNumber ?? '';
        } else {
          fields['transfer_reference'] = chequeData.transferReference ?? '';
        }

        final List<http.MultipartFile> files = [];
        if (chequeData.proofImage != null) {
          final imageBytes = await chequeData.proofImage!.readAsBytes();
          files.add(
            http.MultipartFile.fromBytes(
              'proof_image',
              imageBytes,
              filename: 'proof_image_${DateTime.now().millisecondsSinceEpoch}.png',
            ),
          );
        }

        response = await IgsHttpClient.multipartPost(
          Uri.parse("${ApiConfig.baseUrl}/tickets"),
          headers: header,
          fields: fields,
          files: files.isEmpty ? null : files,
        );
      } else {
        final Map<String, dynamic> requestBody = {
          "price": double.parse(_amountController.text),
          "label": _labelController.text,
          "transaction_id": transactionId,
          "payment_status": paymentStatus,
          "provider": "SKY-P",
          "payment_method": paymentMethod,
        };
        response = await IgsHttpClient.post(
          Uri.parse("${ApiConfig.baseUrl}/tickets"), 
          headers: header,
          body: jsonEncode(requestBody),
        );
      }

      print("📡 [EXPRESS TICKET BACKEND RESPONSE] Status: ${response.statusCode} | Body: ${response.body}");

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          String qrPath = data['ticket']['qr_code'].toString().replaceAll(
            '\\',
            '',
          );
          _qrCodeUrl = "${ApiConfig.baseUrl1}/$qrPath";
        });
        CustomQuickAlert.dismiss();
        CustomQuickAlert.success(
          title: "Succès",
          message: "Paiement validé et Ticket émis !",
          confirmBtnColor: igsBlue,
        );
      } else {
        CustomQuickAlert.dismiss();
        String errorMsg = "Erreur serveur : ${response.statusCode}";
        try {
          final resData = jsonDecode(response.body);
          errorMsg = resData['message'] ?? errorMsg;
        } catch (_) {}
        IgsAlerts.showError(errorMsg);
      }
    } catch (e, stackTrace) {
      print("❌ [EXPRESS TICKET ERROR]: $e");
      print(stackTrace);
      CustomQuickAlert.dismiss();
      IgsAlerts.showError("Erreur de connexion au serveur");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w500),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _qrCodeUrl == null,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_qrCodeUrl != null) {
          Navigator.pop(context, true);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: IgsAppBar(
          title: "SKY-P",
          showLogout: true,
          onBack: () {
            if (_qrCodeUrl != null) {
              Navigator.pop(context, true);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        body: _isSaving
            ? const Center(child: CircularProgressIndicator(color: igsBlue))
            : _showChequeForm
                ? ChequePaymentForm(
                    totalAmount: _paymentAmount,
                    onValidated: (data) async {
                      setState(() => _showChequeForm = false);
                      await _submitData(chequeData: data);
                    },
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        if (_qrCodeUrl == null) ...[
                          Text(
                            "NOUVEAU BON A L'UNITÉ",
                            style: GoogleFonts.montserrat(
                              color: darkBrown,
                              fontSize: 20,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "Renseignez le champ ci-après et validez votre ticket",
                            style: GoogleFonts.montserrat(
                              color: Colors.grey[600],
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 35),
                        ],
                        _qrCodeUrl == null ? _buildForm() : _buildQrCodeDisplay(),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInputLabel("Libellé du ticket"),
          _buildTextField(
            _labelController,
            "",
            Icons.edit_note_rounded,
          ),
          const SizedBox(height: 25),
          _buildInputLabel("Montant du ticket valeur (FCFA)"),
          _buildTextField(
            _amountController,
            "",
            Icons.payments_rounded,
            isNumber: true,
          ),
          const SizedBox(height: 40),
          _buildSubmitButton(),
        ],
      ),
    );
  }

  Widget _buildQrCodeDisplay() {
    return Column(
      children: [
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 25),
            ],
          ),
          child: Column(
            children: [
              Text(
                "TICKET VALEUR",
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w800,
                  color: igsBlue,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 25),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.network(
                  _qrCodeUrl!,
                  width: 220,
                  height: 220,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const SizedBox(
                      height: 220,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    dev.log("Erreur chargement image: $_qrCodeUrl");
                    return Column(
                      children: [
                        const Icon(
                          Icons.broken_image_outlined,
                          size: 80,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "Image introuvable sur le serveur",
                          style: GoogleFonts.montserrat(fontSize: 12),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 25),
              Text(
                "${_amountController.text} FCFA",
                style: GoogleFonts.montserrat(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: darkBrown,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _labelController.text.toUpperCase(),
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 5, bottom: 8),
      child: Text(
        label,
        style: GoogleFonts.montserrat(
          fontWeight: FontWeight.w700,
          fontSize: 13,
          color: darkBrown.withOpacity(0.7),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool isNumber = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.montserrat(color: Colors.grey[400], fontWeight: FontWeight.w400),
        prefixIcon: Icon(icon, color: Colors.grey[400], size: 22),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.3), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: igsBlue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
      ),
      validator: (v) => v!.isEmpty ? "Ce champ est obligatoire" : null,
    );
  }

  Widget _buildSubmitButton() {
    return _buildActionButton(
      "VALIDER L'ACHAT",
      _startPayment,
      isPrimary: true,
      enabled: _isAmountValid,
    );
  }

  Widget _buildActionButton(
    String title,
    VoidCallback onPressed, {
    required bool isPrimary,
    bool enabled = true,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? igsBlue : Colors.white,
          disabledBackgroundColor: Colors.grey[300],
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.grey[500],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Text(
          title,
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
