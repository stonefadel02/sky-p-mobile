import 'dart:convert';

import 'package:custom_quick_alert/custom_quick_alert.dart';
import 'package:flutter/material.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:kkiapay_flutter_sdk/kkiapay_flutter_sdk.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sky_p/config/api_config.dart';
import 'package:sky_p/services/api_service.dart';
import 'package:sky_p/services/header.dart';
import 'package:sky_p/ui/client/goFuel/list_command.dart';
import 'package:sky_p/ui/widgets/igs_app_bar.dart';
import 'package:uuid/uuid.dart'; // Utilise uniquement celui-ci

class GoFuelOrderPage extends StatefulWidget {
  const GoFuelOrderPage({super.key});

  @override
  State<GoFuelOrderPage> createState() => _GoFuelOrderPageState();
}

class _GoFuelOrderPageState extends State<GoFuelOrderPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isFuelMenuOpen = false;
  final List<Map<String, dynamic>> fuelOptions = [
    {"name": "Essence", "icon": Icons.local_gas_station_rounded},
    {"name": "Gasoil", "icon": Icons.oil_barrel_rounded}, // Icône différente
  ];
  static const Color igsBlue = Color(0xFF3473E4);
  static const Color igsGreen = Color(0xFF4CAF50);
  static const Color darkBrown = Color(0xFF26211E);

  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _coordsController = TextEditingController();
  bool _isProcessing = false;
  bool _isClosing = false;
  double fuelPrice = 0.0;
  bool _isFetchingPrice = true;
  bool _isSubmitting = false;

  String formatPrice(dynamic amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  String _selectedFuel = "Essence";
  // Initialisation avec le LatLng de latlong2
  LatLng _mapCenter = const LatLng(6.3654, 2.4183);

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Le GPS est désactivé sur votre téléphone.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Les permissions de localisation sont refusées.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
        'Les permissions sont définitivement bloquées dans vos réglages.',
      );
    }

    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchFuelPrice();
  }

  Future<void> _fetchFuelPrice() async {
    try {
  
      final header = await ApiHeaders.getHeaders();
      final response = await IgsHttpClient.get(
        Uri.parse("${ApiConfig.baseUrl}/gofuel/tarifs"),
        forceRefresh: true,
        headers: header,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          String key = _selectedFuel.toLowerCase();
          fuelPrice = double.tryParse(data[key].toString()) ?? 0.0;
          _isFetchingPrice = false;
        });
        print("Prix retenu pour $_selectedFuel : $fuelPrice");
      }
    } catch (e) {
      print("Erreur prix: $e");
      setState(() => _isFetchingPrice = false);
    }
  }

  // --- LOGIQUE DE PAIEMENT KKIAPAY ---
  void _handlePaymentResponse(
    Map<String, dynamic> response,
    BuildContext context,
  ) async {
    final String paymentStatus = (response['status']?.toString() ?? '')
        .toUpperCase();

    // Ignorer les événements intermédiaires
    if (paymentStatus == 'PAYMENT_INIT' || paymentStatus == 'PENDING') return;

    String transactionId =
        response['transactionId']?.toString() ??
        response['reference']?.toString() ??
        "TXN_${DateTime.now().millisecondsSinceEpoch}";

    // Fermer la fenêtre Kkiapay
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    if (paymentStatus.contains('SUCCESS') ||
        paymentStatus.contains('COMPLETED')) {
      await Future.delayed(const Duration(milliseconds: 500));
      await _submitOrderToBackend(transactionId, paymentStatus);
    } else {
      _showErrorAlert("Le paiement n'a pas été finalisé.");
    }
  }

  // --- ENVOI DE LA COMMANDE AU BACKEND ---
  Future<void> _submitOrderToBackend(
    String transactionId,
    String status,
  ) async {
    if (!mounted) return;
    setState(() => _isProcessing = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('token');

      // On récupère les valeurs
      double quantity = double.tryParse(_quantityController.text) ?? 0;

      // Extraction des coordonnées depuis "lat, long" vers deux doubles
      List<String> coords = _coordsController.text.split(',');
      double lat = double.parse(coords[0].trim());
      double lng = double.parse(coords[1].trim());

      // Construction du payload exact attendu par le back
      final Map<String, dynamic> bodyPayload = {
        "typeCarburant": _selectedFuel.toLowerCase(), // "essence" ou "gasoil"
        "nombreLitres": quantity,
        "address": _addressController.text,
        "montantTotal": (quantity * fuelPrice).toInt(),
        "longitude": lng,
        "latitude": lat,
        "transaction_id": transactionId,
        "payment_status": status,
      };

      print("PAYLOAD ENVOYÉ AU BACK : ${jsonEncode(bodyPayload)}");
      final header = await ApiHeaders.getHeaders();

      final response = await http.post(
        Uri.parse(
          "${ApiConfig.baseUrl}/fuel/commande",
        ), // Vérifie bien cette URL
        headers: header,
        body: jsonEncode(bodyPayload),
      );

      if (!mounted) return;
      setState(() => _isProcessing = false);

      if (response.statusCode == 201 || response.statusCode == 200) {
        CustomQuickAlert.success(
          title: "Commande validée !",
          message: "Votre carburant vous sera livré sous peu.",
          confirmBtnColor: igsBlue,
          onConfirm: () {
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted)
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const MyOrdersPage()),
                );
            });
          },
        );
      } else {
        final error = jsonDecode(response.body);
        _showErrorAlert(error['message'] ?? "Erreur lors de l'enregistrement");
      }
    } catch (e) {
      if (mounted) setState(() => _isProcessing = false);
      _showErrorAlert("Erreur technique : ${e.toString()}");
    }
  }

 
  void _showErrorAlert(String message) {
    CustomQuickAlert.error(
      title: "Oups !",
      message: message,
      confirmBtnColor: Colors.red,
      onConfirm: () => Navigator.of(context, rootNavigator: true).pop(),
    );
  }

  void _showSnackBar(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.montserrat()),
        backgroundColor: color,
        behavior:
            SnackBarBehavior.floating, // Optionnel : pour un look plus moderne
      ),
    );
  }

  void _onPayPressed() async {
    // Validation locale
    if (!_formKey.currentState!.validate() || _coordsController.text.isEmpty) {
      _showSnackBar(
        "Veuillez remplir tous les champs et localiser le point",
        Color(0xffFE8C00),
      );
      return;
    }

    double quantity = double.tryParse(_quantityController.text) ?? 0;
    if (quantity <= 0) {
      _showSnackBar("Quantité invalide", Color(0xffFE8C00));
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => KKiaPay(
          amount: (quantity * fuelPrice).toInt(),
          apikey: ApiConfig.kkiapayPublicKey,
          sandbox: ApiConfig.isSandbox,
          callback: _handlePaymentResponse,
          reason: "Commande GoFuel : $_selectedFuel",
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

  // Widget de bouton réutilisable pour la map et le formulaire
  Widget _buildActionButton(
    String title,
    VoidCallback onPressed, {
    required bool isPrimary,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? igsBlue : Colors.white,
          foregroundColor: isPrimary ? Colors.white : darkBrown,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Text(
          title,
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Future<void> _showMapPicker() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          const Center(child: CircularProgressIndicator(color: igsBlue)),
    );
    try {
      Position position = await _determinePosition();
      Navigator.pop(context); // Fermer le chargement

      setState(() {
        _mapCenter = LatLng(position.latitude, position.longitude);
      });
    } catch (e) {
      Navigator.pop(context); // Fermer le chargement
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
      // On continue quand même l'ouverture de la carte sur la position par défaut si erreur
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        // Utilise StatefulBuilder pour que la Modal se mette à jour
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  "Ciblez votre lieu de livraison",
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    FlutterMap(
                      options: MapOptions(
                        initialCenter: _mapCenter,
                        initialZoom: 16,
                        onPositionChanged: (position, hasGesture) {
                          if (hasGesture) {
                            // On met à jour la variable globale pour la capture finale
                            _mapCenter = position.center!;
                          }
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.atm_energy.app',
                        ),
                      ],
                    ),
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 25),
                        child: Icon(
                          Icons.location_on_rounded,
                          color: Colors.red,
                          size: 45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: _buildActionButton("CONFIRMER CE POINT", () async {
                  // Sauvegarder les coords avant de fermer
                  final lat = _mapCenter.latitude;
                  final lng = _mapCenter.longitude;

                  Navigator.pop(context); // Fermer la map

                  // Mettre les coords dans le champ map
                  setState(() {
                    _coordsController.text =
                        "${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}";
                  });

                  // Reverse geocoding pour remplir le champ adresse
                  try {
                    final header = await ApiHeaders.getHeaders();
                    final url = Uri.parse(
                      "https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lng&format=json",
                    );
                    final response = await IgsHttpClient.get(
                      url,
                      forceRefresh: true,
                      headers: header ,
                    );

                    if (response.statusCode == 200) {
                      final data = jsonDecode(response.body);
                      if (mounted) {
                        setState(() {
                          _addressController.text =
                              data['display_name'] ?? _coordsController.text;
                        });
                      }
                    }
                  } catch (e) {
                    // Si erreur, l'adresse reste vide, l'utilisateur peut la saisir manuellement
                  }
                }, isPrimary: true),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
       appBar: const IgsAppBar(title: 'Commande GoFuel'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Commande GoFuel",
              style: GoogleFonts.montserrat(
                color: darkBrown,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Faites-vous livrer du carburant où que vous soyez .",
              style: GoogleFonts.montserrat(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 35),

            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInputLabel("Type de carburant"),
                  _buildFuelSelection(),
                  const SizedBox(height: 25),
                  _buildInputLabel("Quantité (Litres)"),
                  _buildTextField(
                    _quantityController,
                    "",
                    Icons.local_gas_station_rounded,
                    isNumber: true,
                    onChanged: (value) => setState(() {}),
                  ),
                  const SizedBox(height: 25),
                  _buildInputLabel("Adresse de livraison"),
                  _buildTextField(
                    _addressController,
                    "",
                    Icons.home_work_rounded,
                  ),
                  const SizedBox(height: 25),
                  _buildInputLabel("Vos coordonnées map"),
                  _buildTextField(
                    _coordsController,
                    "Cliquer pour ouvrir la carte",
                    Icons.map_outlined,
                    readOnly: true,
                    onTap: _showMapPicker,
                    suffix: const Icon(
                      Icons.add_location_alt_rounded,
                      color: igsBlue,
                    ),
                  ),
                  const SizedBox(height: 30),

                  _buildTotalPreview(),
                  const SizedBox(height: 45),
                  _buildSubmitButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

Widget _buildFuelSelection() {
  return Row(
    children: fuelOptions.map((option) {
      bool isSelected = _selectedFuel == option['name'];
      
      return Expanded(
        child: GestureDetector(
          onTap: () {
            setState(() {
              _selectedFuel = option['name'];
              _isFetchingPrice = true;
            });
            _fetchFuelPrice();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            // On ajoute de l'espace entre les deux cartes et de la hauteur
            margin: EdgeInsets.only(
              right: option['name'] == "Essence" ? 6 : 0,
              left: option['name'] == "Gasoil" ? 6 : 0,
            ),
            padding: const EdgeInsets.symmetric(vertical: 20), // Plus de hauteur
            decoration: BoxDecoration(
              color: isSelected ? Colors.white : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? Color(0xffFE8C00) : Colors.white,
                width: 2,
              ),
              boxShadow: isSelected 
                ? [BoxShadow(color: Color(0xffFE8C00).withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))]
                : [],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      option['icon'],
                      color: isSelected ? Color(0xffFE8C00) : Colors.grey[400],
                      size: 32, // Icône plus grande
                    ),
                    const SizedBox(height: 12),
                    Text(
                      option['name'].toUpperCase(),
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 0.5,
                        color: isSelected ? Color(0xffFE8C00) : darkBrown.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
                // La petite coche stylisée
                if (isSelected)
                  Positioned(
                    top: -30, // Ajusté pour ne pas être écrasé
                    right: -5,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xffFE8C00),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 14),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }).toList(),
  );
}

  Widget _buildTotalPreview() {
    // On récupère la quantité et on calcule
    double quantity = double.tryParse(_quantityController.text) ?? 0;
    double total = quantity * fuelPrice;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: igsBlue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: igsBlue.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Total à payer :",
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w500,
                  color: darkBrown.withOpacity(0.7),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    formatPrice(total.toInt()),
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: igsBlue,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "F",
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: igsBlue,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return _buildActionButton(
      "PAYER ET COMMANDER",
      _isFetchingPrice ? () {} : _onPayPressed,
      isPrimary: true,
    );
  }

  Widget _buildFuelDropdown() {
    return Row(
      children: [
        // --- BOUTON + / X ---
        GestureDetector(
          onTap: () => setState(() => _isFuelMenuOpen = !_isFuelMenuOpen),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: igsBlue, width: 1.5),
            ),
            child: AnimatedRotation(
              turns: _isFuelMenuOpen ? 0.125 : 0, // 45 degrés pour faire un X
              duration: const Duration(milliseconds: 300),
              child: const Icon(Icons.add, color: igsBlue, size: 22),
            ),
          ),
        ),

        const SizedBox(width: 8),

        // --- OPTIONS QUI RESTENT OUVERTES ---
        if (_isFuelMenuOpen)
          Expanded(
            child: SizedBox(
              height: 45,
              child: Row(
                children: [
                  _buildCompactOption(
                    "Essence",
                    Icons.local_gas_station_rounded,
                  ),
                  const SizedBox(width: 8),
                  _buildCompactOption("Gasoil", Icons.oil_barrel_rounded),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // Widget pour chaque choix (Reste ouvert après clic)
  Widget _buildCompactOption(String name, IconData icon) {
    bool isSelected = _selectedFuel == name;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() {
          _selectedFuel = name; // On change la sélection
          // suppression de _isFuelMenuOpen = false; ICI
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? igsBlue.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? igsBlue : Colors.grey.withOpacity(0.3),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? igsBlue : Colors.grey[600],
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              name,
              style: GoogleFonts.montserrat(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 13,
                color: isSelected ? igsBlue : darkBrown,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool isNumber = false,
    bool readOnly = false,
    VoidCallback? onTap,
    Widget? suffix,
    Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      onChanged: onChanged,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.grey[400], size: 22),
        suffixIcon: suffix,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: igsBlue, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 15,
        ),
      ),
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
          color: darkBrown.withOpacity(0.8),
        ),
      ),
    );
  }

  
}
