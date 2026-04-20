// Version Actuelle

import 'package:custom_quick_alert/custom_quick_alert.dart';
import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:kkiapay_flutter_sdk/kkiapay_flutter_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:sky_p/config/api_config.dart';
import 'dart:convert';

import 'package:sky_p/services/header.dart';
import 'package:sky_p/ui/widgets/igs_app_bar.dart';


class RequestChequierPage extends StatefulWidget {
  const RequestChequierPage({super.key});

  @override
  State<RequestChequierPage> createState() => _RequestChequierPageState();
}

class _RequestChequierPageState extends State<RequestChequierPage> {
  // Charte graphique IGS
  static const Color igsBlue = Color(0xFF3473E4);
  // static const Color igsYellow = Color(0xFFFCBF01);
  static const Color igsGreen = Color(0xFF4CAF50);
  static const Color darkBrown = Color(0xFF26211E);
  String formatPrice(dynamic amount) {
    // 'fr_FR' utilise l'espace, mais tu peux forcer le point ainsi :
    final formatter = NumberFormat('#,###', 'fr_FR');
    return formatter
        .format(amount)
        .replaceAll('\u00a0', '.')
        .replaceAll(' ', '.');
  }

  // final TextEditingController _countController = TextEditingController();

  // Valeurs pour la liste déroulante
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

  void _handlePaymentResponse(
    Map<String, dynamic> response,
    BuildContext context,
  ) async {
    final String paymentStatus = (response['status']?.toString() ?? '')
        .toUpperCase();

    // ✅ Ignorer les événements intermédiaires
    if (paymentStatus == 'PAYMENT_INIT' || paymentStatus == 'PENDING') {
      print("⏳ Événement intermédiaire ignoré: $paymentStatus");
      return; // On sort sans rien faire
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
      await Future.delayed(const Duration(milliseconds: 500));
      await _submitRequestToBackend(transactionId, paymentStatus);
    } else {
      _showErrorAlert("Le paiement n'a pas été finalisé.");
    }
  }

  Future<void> _submitRequestToBackend(
    String transactionId,
    String status,
  ) async {
    if (!mounted) return;
    setState(() => _isProcessing = true); // ✅ Remplace CustomQuickAlert.loading

    try {
   
      final header = await ApiHeaders.getHeaders();

      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/demande-chequier"),
        headers: header,
        body: jsonEncode({
          "tickets_count": _calculatedTicketsCount,
          "ticket_price": _selectedUnitPrice,
          "transaction_id": transactionId,
          "payment_status": status,
           "provider": "SKY-P",
        }),
      );
      print("Response Body demande chequier: ${response.body}");
      print("STATUS CODE: ${response.statusCode}");

      if (!mounted) return;
      setState(
        () => _isProcessing = false,
      ); // ✅ Remplace CustomQuickAlert.dismiss

      if (response.statusCode == 201 || response.statusCode == 200) {
        CustomQuickAlert.success(
          title: "Félicitations !",
          message:
              "Votre commande de chéquier a été bien enregistrée. Nos équipes se chargent de son traitement",
          confirmBtnColor: igsBlue,
          onConfirm: () {
          
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) Navigator.of(context).pop(true);
            });
          },
        );
      } else {
        final data = jsonDecode(response.body);
        print("ERREUR SERVEUR DÉTAILLÉE: ${response.body}");
        _showErrorAlert(

          data['message'] ?? "Erreur serveur (${response.statusCode})",
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isProcessing = false);
      _showErrorAlert("Erreur réseau : Vérifiez votre connexion. ($e)");
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
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Demande de Chéquier",
                    style: GoogleFonts.montserrat(
                      color: darkBrown,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Choisissez la valeur de votre ticket et le montant total du chéquier.",
                    style: GoogleFonts.montserrat(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 35),

                  // 1. CHOIX DE LA VALEUR UNITAIRE
                  _buildInputLabel("1. Valeur d'un seul ticket"),
                  _buildGridCards(
                    values: _unitPrices,
                    selectedValue: _selectedUnitPrice,
                    onSelected: (val) =>
                        setState(() => _selectedUnitPrice = val),
                    icon: Icons.confirmation_num_outlined,
                  ),

                  const SizedBox(height: 30),

                  // 2. CHOIX DE LA VALEUR TOTALE
                  _buildInputLabel("2. Valeur totale du chéquier"),
                  _buildGridCards(
                    values: _totalValues,
                    selectedValue: _selectedTotalValue,
                    onSelected: (val) =>
                        setState(() => _selectedTotalValue = val),
                    icon: Icons.account_balance_wallet_outlined,
                    isTotal: true,
                  ),

                  const SizedBox(height: 35),

                  // 3. RÉCAPITULATIF CALCULÉ
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
        color: const Color(0xFFF0F5FF),
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

  Widget buildIgsTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isNumber = false,
    Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 5, bottom: 8),
          child: Text(
            label,
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: const Color(0xFF26211E).withOpacity(0.8),
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: Colors.grey[400], size: 22),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF3473E4),
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 15,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    // Le bouton s'active si le nombre de tickets calculé est > 0
    bool isDisable = _calculatedTicketsCount <= 0;

    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: isDisable ? null : _onPayPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: igsBlue,
          disabledBackgroundColor: Colors.grey[300], // Couleur quand désactivé
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

    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => KKiaPay(
          amount: _selectedTotalValue!, // On utilise le montant total choisi
          apikey: ApiConfig.kkiapayPublicKey,
          sandbox: ApiConfig.isSandbox,
          callback: _handlePaymentResponse,
          reason: "Achat Chéquier ATM Energy",
          theme: "#3473E4",
          countries: const ["BJ"],
          paymentMethods: const ["momo", "card"],
          name: prefs.getString('user_name') ?? '',
          email: prefs.getString('user_email') ?? '',
          phone: prefs.getString('user_phone') ?? '',
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
