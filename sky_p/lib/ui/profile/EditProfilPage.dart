import 'dart:convert';
import 'package:custom_quick_alert/custom_quick_alert.dart';
import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sky_p/config/api_config.dart';
import 'package:sky_p/services/header.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  // Contrôleurs
  final _nameController = TextEditingController();
  final _prenomController = TextEditingController();
  final _phoneController = TextEditingController();
  final _structureController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isEnterprise = false;
  static const Color igsBlue = Color(0xFF3473E4);
  static const Color darkBrown = Color(0xFF26211E);

  @override
  void initState() {
    super.initState();
    _fillExistingData();
  }

  Future<void> _fillExistingData() async {
    final prefs = await SharedPreferences.getInstance();
    final String role = prefs.getString('role') ?? "";

    if (!mounted) return;
    setState(() {
      _nameController.text = prefs.getString('user_nom') ?? "";
      _prenomController.text = prefs.getString('user_prenoms') ?? "";
      _phoneController.text = prefs.getString('user_phone') ?? "";
      _structureController.text = prefs.getString('user_structure') ?? "";
      _isEnterprise = role != "ROLE_USER" && role.isNotEmpty;
    });

    print(
      "Données chargées - nom: ${_nameController.text}, role: $role, isEnterprise: $_isEnterprise",
    );
  }

  Future<void> _updateProfile() async {
    print("Bouton appuyé !");
    if (!_formKey.currentState!.validate()) return;
    print("Bouton appuyé !");
    setState(() => _isLoading = true);
    // IgsAlerts.showLoading("Mise à jour du profil...");

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('token');
      // final String? role = prefs.getString('role');
      // final String? type = prefs.getString(
      //   'user_type',
      // ); // particulier ou entreprise

      Map<String, dynamic> body = {
        "nom": _nameController.text.trim(),
        "prenoms": _prenomController.text.trim(),
        "telephone": _phoneController.text.trim(),
      };
      if (_structureController.text.isNotEmpty) {
        body["structure"] = _structureController.text.trim();
      }

      // Si l'utilisateur a saisi un mot de passe, on l'ajoute au body
      if (_passwordController.text.isNotEmpty) {
        body["password"] = _passwordController.text;
      }

      print("BODY : ${jsonEncode(body)}");
            final header = await ApiHeaders.getHeaders();


      final response = await http.put(
        Uri.parse("${ApiConfig.baseUrl}/profile/edit"),
        headers:  header,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final user = data['user'];

        await prefs.setString('user_nom', user['nom']);
        await prefs.setString('user_prenoms', user['prenoms']);
        await prefs.setString('user_phone', user['telephone']);
        await prefs.setString(
          'user_structure',
          _structureController.text.trim(),
        );

        // 2. Mise à jour du nom combiné (utilisé par l'AppBar du MainNavigation)
        String fullName =
            "${_nameController.text.trim()} ${_prenomController.text.trim()}";
        await prefs.setString('user_name', fullName);
        CustomQuickAlert.success(
          title: "Succès",
          message: "Votre profil a été mis à jour !",
          confirmBtnColor: igsBlue,
          onConfirm: () {
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) {
                Navigator.of(context).pop(true); // Retourne à l'écran précédent
              }
            });
          },
        ); // Renvoie 'true' pour déclencher le rafraîchissement
      } else {
        final errorData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorData['message'] ?? "Erreur de mise à jour"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Erreur de connexion au serveur"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "Modifier mon profil",
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: darkBrown,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle("Informations Personnelles"),
              const SizedBox(height: 20),
              _buildLabel("Nom"),
              _buildTextField(
                _nameController,
                "Votre nom",
                Icons.person_outline,
              ),
              const SizedBox(height: 15),
              _buildLabel("Prénoms"),
              _buildTextField(
                _prenomController,
                "Vos prénoms",
                Icons.person_outline,
              ),
              const SizedBox(height: 15),
              _buildLabel("Téléphone"),
              _buildTextField(
                _phoneController,
                "00 00 00 00",
                Icons.phone_android_rounded,
                isPhone: true,
              ),
              if (_isEnterprise) ...[
                const SizedBox(height: 15),
                _buildLabel("Structure / Agence (Optionnel)"),
                _buildTextField(
                  _structureController,
                  "Nom de la structure",
                  Icons.apartment_rounded,
                  isOptional: true,
                ),
              ],

              const SizedBox(height: 35),
              _buildSectionTitle("Sécurité (Laissez vide pour ne pas changer)"),
              const SizedBox(height: 20),
              _buildLabel("Nouveau mot de passe"),
              _buildPasswordField(_passwordController, "Minimum 6 caractères"),
              const SizedBox(height: 15),
              _buildLabel("Confirmer le mot de passe"),
              _buildPasswordField(
                _confirmPasswordController,
                "Répétez le mot de passe",
                isConfirm: true,
              ),

              const SizedBox(height: 40),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.montserrat(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: igsBlue,
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 5, bottom: 8),
      child: Text(
        label,
        style: GoogleFonts.montserrat(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool isPhone = false,
    bool isOptional = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
      validator: (v) {
        if (isOptional) return null; // Si c'est optionnel, pas d'erreur
        if (v == null || v.isEmpty) return "Ce champ est requis";
        return null;
      },
      decoration: _inputDecoration(hint, icon),
    );
  }

  Widget _buildPasswordField(
    TextEditingController controller,
    String hint, {
    bool isConfirm = false,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: !_isPasswordVisible,
      validator: (v) {
        if (v!.isNotEmpty && v.length < 6) return "Trop court (min 6)";
        if (isConfirm && v != _passwordController.text)
          return "Les mots de passe ne correspondent pas";
        return null;
      },
      decoration: _inputDecoration(hint, Icons.lock_outline).copyWith(
        suffixIcon: IconButton(
          icon: Icon(
            _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
            color: Colors.grey,
          ),
          onPressed: () =>
              setState(() => _isPasswordVisible = !_isPasswordVisible),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: Colors.grey[400], size: 20),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: igsBlue, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 15),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _updateProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: igsBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                "ENREGISTRER LES MODIFICATIONS",
                style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
              ),
      ),
    );
  }
}
