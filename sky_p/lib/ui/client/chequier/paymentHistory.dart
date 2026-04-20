import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sky_p/ui/widgets/state_handler.dart';
// import 'package:http/http.dart' as http; // À décommenter lors de l'appel API

class PaymentHistoryPage extends StatefulWidget {
  const PaymentHistoryPage({super.key});

  @override
  State<PaymentHistoryPage> createState() => _PaymentHistoryPageState();
}

class _PaymentHistoryPageState extends State<PaymentHistoryPage> {
  // Couleurs de ta marque IGS
  static const Color igsBlue = Color(0xFF3473E4);
  // static const Color igsYellow = Color(0xFFFCBF01);
  static const Color darkBrown = Color(0xFF26211E);

  bool _isLoading = false;
  List<dynamic> _payments = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchPayments();
  }

  // Simulation de l'appel API
  Future<void> _fetchPayments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Simule un délai réseau
      await Future.delayed(const Duration(seconds: 2));
      
      // TEST: Pour voir l'état vide, laisse la liste vide []
      // TEST: Pour voir l'erreur, décommente la ligne 'throw Exception'
      // throw Exception("Connexion impossible");

      setState(() {
        _payments = []; // Remplace par tes données API
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: RefreshIndicator(
        onRefresh: _fetchPayments,
        color: igsBlue,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: igsBlue));
    }

    // UTILISATION DE TON LOTTIE : no_internet.json
    if (_errorMessage != null) {
      return IGSStateDisplay(
        animation: 'no_internet',
        title: "Erreur de chargement",
        message: "Nous n'avons pas pu récupérer vos paiements.",
        onAction: _fetchPayments,
        actionLabel: "RÉESSAYER",
      );
    }

    // UTILISATION DE TON LOTTIE : empty_box.json
    if (_payments.isEmpty) {
      return IGSStateDisplay(
        animation: 'empty_box',
        title: "Aucun paiement",
        message: "Votre historique d'achat de chéquiers est vide pour le moment.",
        onAction: _fetchPayments,
        actionLabel: "ACTUALISER",
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      itemCount: _payments.length,
      itemBuilder: (context, index) {
        return _buildPaymentCard(_payments[index]);
      },
    );
  }

  Widget _buildPaymentCard(dynamic payment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
              color: darkBrown.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 10))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15)),
            child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.green),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Achat Chéquier",
                  style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.bold, color: darkBrown, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  "18 Fév 2026 • 14:20",
                  style: GoogleFonts.montserrat(
                      fontSize: 12,
                      color: Colors.blueGrey[400],
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "+25 000 F",
                style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.bold, color: igsBlue, fontSize: 16),
              ),
              const Icon(Icons.check_circle, size: 14, color: Colors.green),
            ],
          ),
        ],
      ),
    );
  }
}