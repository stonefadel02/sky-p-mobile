import 'dart:convert';

import 'package:custom_quick_alert/custom_quick_alert.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:kkiapay_flutter_sdk/kkiapay_flutter_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sky_p/config/api_config.dart';
import 'package:sky_p/services/api_service.dart';
import 'package:sky_p/services/header.dart';
import 'package:sky_p/ui/client/chequier/cheque_payment_form.dart';
import 'package:sky_p/ui/widgets/igs_app_bar.dart';

class RequestChequierPage extends StatefulWidget {
  const RequestChequierPage({super.key});

  @override
  State<RequestChequierPage> createState() => _RequestChequierPageState();
}

class _RequestChequierPageState extends State<RequestChequierPage> {
  static const Color igsBlue = Color(0xFF3473E4);
  static const Color igsGreen = Color(0xFF4CAF50);
  static const Color darkBrown = Color(0xFF26211E);

  String formatPrice(dynamic amount) {
    final formatter = NumberFormat('#,###', 'fr_FR');
    return formatter
        .format(amount)
        .replaceAll('\u00a0', '.')
        .replaceAll(' ', '.');
  }

  int? _selectedUnitPrice;
  final List<int> _unitPrices = [1000, 5000, 10000, 50000, 100000];
  int? _selectedTotalValue;
  final List<int> _totalValues = [50000, 250000, 500000, 2500000, 5000000];

  int get _calculatedTicketsCount {
    if (_selectedUnitPrice == null || _selectedTotalValue == null) return 0;
    return (_selectedTotalValue! / _selectedUnitPrice!).floor();
  }

  bool _isProcessing = false;
  bool _isClosing = false;
  bool _showChequeForm = false;

  void _handlePaymentResponse(
    Map<String, dynamic> response,
    BuildContext context,
  ) async {
    final String paymentStatus = (response['status']?.toString() ?? '')
        .toUpperCase();

    if (paymentStatus == 'PAYMENT_INIT' || paymentStatus == 'PENDING') {
      print("⏳ Événement intermédiaire ignoré: $paymentStatus");
      return;
    }

    print("✅ Statut final reçu: $paymentStatus");

    String transactionId =
        response['transactionId']?.toString() ??
        response['reference']?.toString() ??
        "TXN_${DateTime.now().millisecondsSinceEpoch}";

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    if (paymentStatus.contains('SUCCESS') ||
        paymentStatus.contains('COMPLETED')) {
      await _submitRequestToBackend(
        transactionId: transactionId,
        status: paymentStatus,
        paymentMethod: "kkiapay",
      );
    } else {
      _showSnackBar("Paiement en cours de traitement", Colors.orange);
    }
  }

  Future<void> _submitRequestToBackend({
    String? transactionId,
    String? status,
    String? paymentMethod,
    ChequePaymentData? chequeData,
    int attempt = 1,
  }) async {
    if (!mounted) return;
    setState(() => _isProcessing = true);

    const int maxAttempts = 3;

    try {
      final header = await ApiHeaders.getHeaders();
      http.Response response;

      if (chequeData != null) {
        final Map<String, String> fields = {
          "tickets_count": _calculatedTicketsCount.toString(),
          "ticket_price": _selectedUnitPrice.toString(),
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
          Uri.parse("${ApiConfig.baseUrl}/demande-chequier"),
          headers: header,
          fields: fields,
          files: files.isEmpty ? null : files,
        );
      } else {
        response = await IgsHttpClient.post(
          Uri.parse("${ApiConfig.baseUrl}/demande-chequier"),
          headers: header,
          body: jsonEncode({
            "tickets_count": _calculatedTicketsCount,
            "ticket_price": _selectedUnitPrice,
            "transaction_id": transactionId,
            "payment_status": status,
            "provider": "SKY-P",
            "payment_method": paymentMethod,
          }),
        );
      }

      print("Response Body demande chequier: ${response.body}");
      print("STATUS CODE: ${response.statusCode}");

      if (!mounted) return;
      setState(
        () => _isProcessing = false,
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        CustomQuickAlert.success(
          title: "Félicitations !",
          message:
              "Votre commande de carnet de bon d’essence a été bien enregistrée. Nos équipes se chargent de son traitement",
          confirmBtnColor: igsBlue,
          onConfirm: () {
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) Navigator.of(context).pop(true);
            });
          },
        );
      } else {
        print("ERREUR SERVEUR DÉTAILLÉE: ${response.body}");
        if (mounted) setState(() => _isProcessing = false);
        String errorMsg = "Erreur serveur (${response.statusCode})";
        try {
          final data = jsonDecode(response.body);
          errorMsg = data['message'] ?? errorMsg;
        } catch (_) {}
        _showErrorAlert(errorMsg);
      }
    } catch (e, stackTrace) {
      print("❌ ERREUR RÉSEAU [tentative $attempt/$maxAttempts]");
      print("   Type    : ${e.runtimeType}");
      print("   Message : $e");
      print("   Stack   : $stackTrace");
      if (attempt < maxAttempts) {
        print("⚠️ Retry dans 2s...");
        await Future.delayed(const Duration(seconds: 2));
        await _submitRequestToBackend(
          transactionId: transactionId,
          status: status,
          paymentMethod: paymentMethod,
          chequeData: chequeData,
          attempt: attempt + 1,
        );
      } else {
        if (mounted) setState(() => _isProcessing = false);
        _showErrorAlert("Erreur réseau après $maxAttempts tentatives. Vérifiez votre connexion.");
      }
    }
  }

  void _showErrorAlert(String message) {
    if (!mounted) return;
    CustomQuickAlert.error(
      title: "Oups !",
      message: message,
      confirmBtnColor: Colors.red,
      onConfirm: () => Navigator.of(context, rootNavigator: true).pop(),
    );
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.montserrat()),
        backgroundColor: color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const IgsAppBar(title: "SKY-P"),
      body: (_isProcessing || _isClosing)
          ? const Center(child: CircularProgressIndicator(color: igsBlue))
          : _showChequeForm
              ? ChequePaymentForm(
                  totalAmount: _selectedTotalValue ?? 0,
                  onValidated: (data) async {
                    setState(() => _showChequeForm = false);
                    await _submitRequestToBackend(chequeData: data);
                  },
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Demande de carnet de bon d’essence".toUpperCase(),
                        style: GoogleFonts.montserrat(
                          color: darkBrown,
                          fontSize: 24,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Choisissez la valeur de votre ticket et le montant total du carnet de bon d’essence.",
                        style: GoogleFonts.montserrat(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),

                      const SizedBox(height: 35),

                      _buildInputLabel("1. Valeur d'un seul ticket"),
                      _buildGridCards(
                        values: _unitPrices,
                        selectedValue: _selectedUnitPrice,
                        onSelected: (val) =>
                            setState(() => _selectedUnitPrice = val),
                        icon: Icons.confirmation_num_outlined,
                      ),

                      const SizedBox(height: 30),

                      _buildInputLabel("2. Valeur totale du carnet de bon d’essence"),
                      _buildGridCards(
                        values: _totalValues,
                        selectedValue: _selectedTotalValue,
                        onSelected: (val) =>
                            setState(() => _selectedTotalValue = val),
                        icon: Icons.account_balance_wallet_outlined,
                        isTotal: true,
                      ),

                      const SizedBox(height: 35),

                      if (_selectedUnitPrice != null && _selectedTotalValue != null)
                        _buildSummaryCard(),

                      const SizedBox(height: 45),
                      _buildSubmitButton(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildGridCards({
    required List<int> values,
    required int? selectedValue,
    required Function(int) onSelected,
    required IconData icon,
    bool isTotal = false,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values.map((val) {
        bool isSelected = selectedValue == val;
        return GestureDetector(
          onTap: () => onSelected(val),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: (MediaQuery.of(context).size.width / 3) - 22,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? igsBlue.withOpacity(0.05) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? igsGreen : Colors.grey.withOpacity(0.2),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      icon,
                      color: isSelected ? igsGreen : Colors.grey[400],
                      size: 18,
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          "${formatPrice(val)} F",
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: isSelected ? igsGreen : darkBrown,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Positioned(
                  top: -5,
                  right: -5,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: igsGreen,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 10,
                    ),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: igsBlue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: igsBlue.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          _summaryRow(
            "Valeur unitaire",
            "${formatPrice(_selectedUnitPrice)} FCFA",
          ),
          const Divider(height: 20),
          _summaryRow(
            "Nombre de tickets",
            "$_calculatedTicketsCount tickets",
            isHighlight: true,
          ),
          const Divider(height: 20),
          _summaryRow(
            "Total à payer",
            "${formatPrice(_selectedTotalValue)} FCFA",
            isBold: true,
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(
    String label,
    String value, {
    bool isHighlight = false,
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.montserrat(fontSize: 13, color: Colors.grey[700]),
        ),
        Text(
          value,
          style: GoogleFonts.montserrat(
            fontSize: isBold ? 18 : 14,
            fontWeight: (isHighlight || isBold)
                ? FontWeight.bold
                : FontWeight.w600,
            color: isBold ? igsBlue : (isHighlight ? Colors.green : darkBrown),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    bool isDisable = _calculatedTicketsCount <= 0;

    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: isDisable ? null : _onPayPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: igsBlue,
          disabledBackgroundColor: Colors.grey[300],
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: Text(
          "PAYER ET VALIDER",
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  void _onPayPressed() async {
    if (_calculatedTicketsCount <= 0 || _selectedTotalValue == null) {
      _showSnackBar("Veuillez sélectionner les deux montants", Colors.orange);
      return;
    }

    if ((_selectedTotalValue ?? 0) >= 1000000) {
      setState(() => _showChequeForm = true);
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
          amount: _selectedTotalValue!,
          apikey: ApiConfig.kkiapayPublicKey,
          sandbox: ApiConfig.isSandbox,
          callback: _handlePaymentResponse,
          reason: "Achat carnet de bon d’essence SKY-P",
          theme: "#3473E4",
          countries: const ["BJ"],
          paymentMethods: const ["momo", "card"],
          name: prefs.getString('user_name') ?? '',
          email: prefs.getString('user_email') ?? '',
          phone: phoneToUse,
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 10, left: 5),
    child: Text(
      label,
      style: GoogleFonts.montserrat(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: darkBrown.withOpacity(0.8),
      ),
    ),
  );
}
