import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:sky_p/config/api_config.dart';
import 'dart:convert';
import 'dart:async';
import 'package:uuid/uuid.dart';
import 'package:custom_quick_alert/custom_quick_alert.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  // Contrôleurs
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  // États UI
  int _step = 1; 
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmVisible = false;
  String? _resetToken;

  // Minuteur
  Timer? _timer;
  int _secondsRemaining = 300; // 5 minutes (300s) pour l'expiration
  bool _canResend = false;
  int _resendCountdown = 60; // 60s pour le bouton renvoyer

  static const Color igsBlue = Color(0xFF3473E4);

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _canResend = false;
    _resendCountdown = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_secondsRemaining > 0) _secondsRemaining--;
        if (_resendCountdown > 0) {
          _resendCountdown--;
        } else {
          _canResend = true;
        }
      });
    });
  }

  // --- LOGIQUE API AVEC GESTION DES ERREURS BACKEND ---
  
  Map<String, String> get _headers => {
    "Accept": "application/json",
    "Content-Type": "application/json",
    "X-Requested-With": "XMLHttpRequest",
    "ngrok-skip-browser-warning": "true",
    "X-API-KEY": ApiConfig.atmSecretKey,
    "X-TIMESTAMP": DateTime.now().millisecondsSinceEpoch.toString(),
    "X-NONCE": const Uuid().v4(),
  };

  void _handleBackError(dynamic data, int statusCode) {
    String message = data['message'] ?? "Une erreur est survenue";
    
    // Mapping des erreurs de ton PasswordResetController.php
    if (statusCode == 429) message = "Trop de tentatives. Patientez un instant.";
    if (message.contains("Code invalide")) message = "Le code saisi est incorrect.";
    if (message.contains("expiré")) message = "Votre session a expiré. Recommencez.";
    
    CustomQuickAlert.error(message: message);
  }

  Future<void> _requestOtp() async {
    if (_emailController.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/password/forgot"),
        headers: _headers,
        body: jsonEncode({"email": _emailController.text.trim()}),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        setState(() {
          _resetToken = data['token'];
          _step = 2;
          _secondsRemaining = 300;
        });
        _startTimer();
        CustomQuickAlert.success(message: "Un code a été envoyé à votre adresse email.");
      } else {
        _handleBackError(data, response.statusCode);
      }
    } catch (e) {
      CustomQuickAlert.error(message: "Serveur injoignable");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/password/verify"),
        headers: _headers,
        body: jsonEncode({"token": _resetToken, "code": _otpController.text.trim()}),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        setState(() => _step = 3);
      } else {
        _handleBackError(data, response.statusCode);
      }
    } catch (e) {
      CustomQuickAlert.error(message: "Erreur réseau");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_passwordController.text != _confirmController.text) {
      CustomQuickAlert.error(message: "Les mots de passe ne correspondent pas");
      return;
    }
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/password/reset"),
        headers: _headers,
        body: jsonEncode({
          "token": _resetToken,
          "password": _passwordController.text,
          "confirm": _confirmController.text,
        }),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        CustomQuickAlert.success(
          message: "Votre mot de passe a été modifié avec succès !",
          onConfirm: () => Navigator.pop(context),
        );
      } else {
        _handleBackError(data, response.statusCode);
      }
    } catch (e) {
      CustomQuickAlert.error(message: "Erreur lors de la modification");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- UI COMPONENTS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, foregroundColor: Colors.black),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildIconHeader(),
              const SizedBox(height: 30),
              _buildStepTitle(),
              const SizedBox(height: 40),
              _buildCurrentForm(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconHeader() {
    IconData icon;
    if (_step == 1) icon = Icons.mark_email_read_outlined;
    else if (_step == 2) icon = Icons.vibration_outlined;
    else icon = Icons.lock_reset_outlined;

    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(color: igsBlue.withOpacity(0.1), shape: BoxShape.circle),
      child: Icon(icon, size: 70, color: igsBlue),
    );
  }

  Widget _buildStepTitle() {
    String title = _step == 1 ? "Mot de passe oublié" : _step == 2 ? "Vérification" : "Nouveau mot de passe";
    String subtitle = _step == 1 
        ? "Entrez votre email pour recevoir un code" 
        : _step == 2 ? "Entrez le code à 6 chiffres reçu" : "Créez votre nouveau mot de passe sécurisé";
    
    return Column(
      children: [
        Text(title, style: GoogleFonts.montserrat(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Text(subtitle, textAlign: TextAlign.center, style: GoogleFonts.montserrat(color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildCurrentForm() {
    if (_step == 1) {
      return Column(
        children: [
          _buildTextField(_emailController, "Email", Icons.email_outlined),
          const SizedBox(height: 30),
          _buildMainButton("ENVOYER LE CODE", _requestOtp),
        ],
      );
    } else if (_step == 2) {
      String timeStr = "${(_secondsRemaining ~/ 60)}:${(_secondsRemaining % 60).toString().padLeft(2, '0')}";
      return Column(
        children: [
          _buildTextField(_otpController, "Code de validation", Icons.security, isOtp: true),
          const SizedBox(height: 20),
          Text("Expire dans : $timeStr", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
          const SizedBox(height: 30),
          _buildMainButton("VÉRIFIER", _verifyOtp),
          const SizedBox(height: 15),
          if (_canResend)
            TextButton(onPressed: _requestOtp, child: const Text("Renvoyer le code", style: TextStyle(color: igsBlue, fontWeight: FontWeight.bold)))
          else
            Text("Renvoyer possible dans $_resendCountdown s", style: const TextStyle(color: Colors.grey)),
        ],
      );
    } else {
      return Column(
        children: [
          _buildTextField(_passwordController, "Nouveau mot de passe", Icons.lock_outline, isPassword: true, 
            isVisible: _isPasswordVisible, onToggle: () => setState(() => _isPasswordVisible = !_isPasswordVisible)),
          const SizedBox(height: 20),
          _buildTextField(_confirmController, "Confirmer le mot de passe", Icons.lock_outline, isPassword: true, 
            isVisible: _isConfirmVisible, onToggle: () => setState(() => _isConfirmVisible = !_isConfirmVisible)),
          const SizedBox(height: 30),
          _buildMainButton("RÉINITIALISER", _resetPassword),
        ],
      );
    }
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, 
      {bool isPassword = false, bool isVisible = false, VoidCallback? onToggle, bool isOtp = false}) {
    return TextField(
      controller: controller,
      obscureText: isPassword && !isVisible,
      keyboardType: isOtp ? TextInputType.number : TextInputType.text,
      maxLength: isOtp ? 6 : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: igsBlue),
        counterText: "",
        suffixIcon: isPassword ? IconButton(icon: Icon(isVisible ? Icons.visibility : Icons.visibility_off), onPressed: onToggle) : null,
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: igsBlue, width: 2)),
      ),
    );
  }

  Widget _buildMainButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(backgroundColor: igsBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
        child: _isLoading 
            ? const CircularProgressIndicator(color: Colors.white) 
            : Text(text, style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }
}