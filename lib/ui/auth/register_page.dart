import 'dart:io';

import 'package:custom_quick_alert/custom_quick_alert.dart';
import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sky_p/config/api_config.dart';
import 'package:sky_p/core/theme/ui_helpers.dart';
import 'package:sky_p/core/utils/form_validators.dart';
import 'package:sky_p/ui/auth/login_page.dart';
import 'package:sky_p/ui/auth/otp.dart';
import 'package:sky_p/ui/auth/register_widgets.dart';
import 'dart:convert';

import 'package:uuid/uuid.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;

  // Contrôleurs
  final _nameController = TextEditingController();
  final _prenomController = TextEditingController(); // Nouveau
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController(); // Nouveau
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

File? _logoFile;
final ImagePicker _picker = ImagePicker();
  // Entreprise / Optionnel
  bool _acceptTerms = false;
  final _companyNameController = TextEditingController();
  final _ifuController = TextEditingController();
  final _rccmController = TextEditingController();
  final _structureController = TextEditingController(); // Nouveau

  bool _isLoading = false;
  bool _isPasswordVisible = false;
  String _userRoleChoice = 'Agent';
  String _accountType = 'particulier';

  static const Color igsBlue = Color(0xFF3473E4);
  static const Color igsYellow = Color(0xFFFCBF01);
  static const Color darkBrown = Color(0xFF26211E);

  @override
  void initState() {
    super.initState();
    // Si le rôle par défaut est Agent, on charge direct
    if (_userRoleChoice == 'Agent') {}
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

  if (!_acceptTerms) {
    IgsAlerts.showError("Veuillez accepter les conditions d'utilisation pour continuer.");
    return;
  }
    setState(() => _isLoading = true);

    String phone = _phoneController.text.trim();

    if (!phone.startsWith('+')) {
      phone = "+229$phone";
    }

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Optionnel : Auto-résolution sur Android
          print("Tentative d'envoi à : $phone");
          await FirebaseAuth.instance.signInWithCredential(credential);
          _sendDataToServer(); // Envoi final si auto-validé
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() => _isLoading = false);
          String errorMsg = "Une erreur est survenue.";
          switch (e.code) {
            case 'invalid-phone-number':
              errorMsg = "Le numéro de téléphone n'est pas valide.";
              break;
            case 'too-many-requests':
              errorMsg = "Trop de tentatives. Réessayez plus tard.";
              break;
            case 'network-request-failed':
              errorMsg = "Vérifiez votre connexion internet.";
              break;
            default:
              errorMsg = "Numero de telephone incorrecte";
          }
          IgsAlerts.showError(errorMsg);
        },
        codeSent: (String verificationId, int? resendToken) async {
          setState(() => _isLoading = false);

          // On ouvre l'écran OTP
          final bool? isVerified = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OtpVerificationPage(
                verificationId: verificationId,
                phoneNumber: phone,
              ),
            ),
          );

          // Si le code OTP était correct, on enregistre sur ton serveur
          if (isVerified == true) {
            _sendDataToServer();
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      setState(() => _isLoading = false);
      IgsAlerts.showError("Impossible d'envoyer le SMS de validation.");
    }
  }

  String _getFriendlyRegisterMessage(dynamic errorData) {
    String message = "";

    // 1. Extraction du message brut
    if (errorData is Map) {
      if (errorData['errors'] != null && errorData['errors'] is Map) {
        // Si le backend renvoie {"errors": {"email": ["Déjà pris"]}}
        var firstError = (errorData['errors'] as Map).values.first;
        message = (firstError is List)
            ? firstError.first.toString()
            : firstError.toString();
      } else {
        message = errorData['message']?.toString() ?? "";
      }
    } else {
      message = errorData.toString();
    }

    final e = message.toLowerCase();

    // 2. Mapping vers tes messages personnalisés IGS
    if (e.contains("email") && (e.contains("taken") || e.contains("existe"))) {
      return "Cet email est déjà utilisé par un autre utilisateur.";
    }
    if (e.contains("phone") || e.contains("téléphone")) {
      return "Ce numéro de téléphone est déjà associé à un compte.";
    }
    if (e.contains("ifu")) {
      return "Cet IFU est invalide ou déjà enregistré.";
    }
    if (e.contains("password") || e.contains("mot de passe")) {
      return "Le mot de passe ne respecte pas les critères de sécurité.";
    }

    // Si on ne reconnaît pas, on renvoie le message du serveur nettoyé ou un défaut
    return message.isNotEmpty
        ? message
        : "Une erreur est survenue lors de l'inscription.";
  }

  Future<void> _sendDataToServer() async {
  IgsAlerts.showLoading("Création de votre compte en cours...");
  setState(() => _isLoading = true);

  final String registerUrl = "${ApiConfig.baseUrl}/users/new";

  try {
    bool isAgent = _userRoleChoice == 'Agent';
    String rolesValue = isAgent ? "Agent" : "USER";

    var request = http.MultipartRequest('POST', Uri.parse(registerUrl));

    request.headers.addAll({
      "Accept": "application/json",
      "X-Requested-With": "XMLHttpRequest",
      "ngrok-skip-browser-warning": "true",
      "X-API-KEY": ApiConfig.atmSecretKey,
      "X-TIMESTAMP": DateTime.now().millisecondsSinceEpoch.toString(),
      "X-NONCE": const Uuid().v4(),
    });

    request.fields['nom'] = _nameController.text.trim();
    request.fields['prenoms'] = _prenomController.text.trim();
    request.fields['email'] = _emailController.text.trim();
    request.fields['phone'] = _phoneController.text.trim();
    request.fields['structure'] = _structureController.text.trim();
    request.fields['password'] = _passwordController.text;
    request.fields['profil'] = rolesValue;
    request.fields['type'] = isAgent ? "particulier" : _accountType;
    request.fields['is_verified'] = "true";

    if (_structureController.text.trim().isNotEmpty) {
      request.fields['structure'] = _structureController.text.trim();
    }

    if (!isAgent && _accountType == 'entreprise') {
      request.fields['company_name'] = _structureController.text.trim();
      request.fields['ifu'] = _ifuController.text.trim();
      request.fields['rccm'] = _rccmController.text.trim();
    }

    if (_logoFile != null) {
      final logoBytes = await _logoFile!.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes(
          'logo',
          logoBytes,
          filename: 'logo_${_nameController.text.trim()}.png',
          contentType: http.MediaType('image', 'png'),
        ),
      );
    }

    // ✅ Envoi
    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);
    print("Réponse register : ${response.body}");

    if (response.statusCode == 201 || response.statusCode == 200) {
      CustomQuickAlert.dismiss();
      CustomQuickAlert.success(
        title: "Félicitations !",
        message: "Votre compte a été créé avec succès. Connectez-vous.",
        confirmBtnColor: igsBlue,
        onConfirm: () {
          Navigator.of(context, rootNavigator: true).pop();
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                );
              }
            }
          });
        },
      );
    } else {
      final data = jsonDecode(response.body);
      CustomQuickAlert.dismiss();
      IgsAlerts.showError(_getFriendlyRegisterMessage(data));
    }
  } catch (e) {
    CustomQuickAlert.dismiss();
    IgsAlerts.showError("Erreur de connexion : impossible de joindre le serveur.");
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: darkBrown,
      ),
      body: Form(
        key: _formKey,
        child: Stepper(
          type: StepperType.horizontal,
          elevation: 0,
          currentStep: _currentStep,
          onStepContinue: () {
           if (_validateCurrentStep()) {
    if (_currentStep < _getSteps().length - 1) {
      setState(() => _currentStep++);
    } else {
      _register();
    }
  } else {
    // Optionnel : un petit message pour l'utilisateur
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Veuillez remplir tous les champs obligatoires de cette étape.")),
    );
  }
            // // On valide uniquement les champs de l'étape ACTUELLE
            // if (_validateCurrentStep()) {
            //   if (_currentStep < _getSteps().length - 1) {
            //     setState(() => _currentStep++);
            //   } else {
            //     _register();
            //   }
            // } else {
            //   // Optionnel : Une petite alerte pour dire que le formulaire est incomplet
            //   IgsAlerts.showError(
            //     "Veuillez remplir correctement tous les champs de cette étape.",
            //   );
            // }
          },
          onStepCancel: _currentStep > 0
              ? () => setState(() => _currentStep--)
              : null,
          controlsBuilder: (context, details) => _buildStepperControls(details),
          steps: _getSteps(),
        ),
      ),
    );
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0: // Profil & Nom
        if (_nameController.text.isEmpty || _prenomController.text.isEmpty)
          return false;

        return true;
      case 1: // Contact & Entreprise
        if (_phoneController.text.isEmpty || _emailController.text.isEmpty)
          return false;
        if (_userRoleChoice == 'client' && _accountType == 'entreprise') {
          if (_ifuController.text.isEmpty || _rccmController.text.isEmpty)
            return false;
        }
        return true;
      case 2: // Sécurité
        if (_passwordController.text.length < 6) return false;
        if (_passwordController.text != _confirmPasswordController.text)
          return false;
        return true;
      default:
        return false;
    }
  }

  List<Step> _getSteps() {
    return [
      Step(
        state: _currentStep > 0 ? StepState.complete : StepState.indexed,
        isActive: _currentStep >= 0,
        title: const Text("Profil"),
        content: _buildStep1(),
      ),
      Step(
        state: _currentStep > 1 ? StepState.complete : StepState.indexed,
        isActive: _currentStep >= 1,
        title: const Text("Détails"),
        content: _buildStep2(),
      ),
      Step(
        isActive: _currentStep >= 2,
        title: const Text("Sécurité"),
        content: _buildStep3(),
      ),
    ];
  }

  // --- ÉTAPE 1 : CHOIX DU RÔLE ET NOM ---
  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RegisterFields.buildInputLabel("Je suis un :"),
        Row(
          children: [
            Expanded(
              child: _selectionCardRole(
                "Agent",
                "Agent",
                Icons.support_agent_outlined,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _selectionCardRole(
                "client", // Valeur technique claire
                "Client",
                Icons.person_outline,
              ),
            ),
          ],
        ),
        
        if (_userRoleChoice == 'client') ...[
          const SizedBox(height: 20),
          RegisterFields.buildInputLabel("Type de compte :"),
          Row(
            children: [
              Expanded(
                child: _selectionCardType(
                  "particulier",
                  "Particulier",
                  Icons.person_pin_outlined,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _selectionCardType(
                  "entreprise",
                  "Agence de voyage",
                  Icons.business_center_outlined,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 25),
        RegisterFields.buildInputLabel("Nom"),
        RegisterFields.buildTextField(
          controller: _nameController,
          hint: "Votre nom",
          icon: Icons.person_outline,
          validator: (v) => _currentStep == 0 ? FormValidators.nom(v) : null,
        ),
        const SizedBox(height: 15),
        RegisterFields.buildInputLabel("Prénoms"),
        RegisterFields.buildTextField(
          controller: _prenomController,
          hint: "Vos prénoms",
          icon: Icons.person_outline,
          validator: (v) => _currentStep == 0 ? FormValidators.prenom(v) : null,
        ),
      ],
    );
  }

  // --- ÉTAPE 2 : CONTACT ET ENTREPRISE ---
  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RegisterFields.buildInputLabel("Téléphone"),
        RegisterFields.buildTextField(
          controller: _phoneController,
          hint: "00 00 00 00 00",
          icon: Icons.phone_android_rounded,
          keyboardType: TextInputType.phone,
          validator: (v) =>
              _currentStep == 1 ? FormValidators.telephone(v) : null,
        ),
        const SizedBox(height: 15),
        RegisterFields.buildInputLabel("Email"),
        RegisterFields.buildTextField(
          controller: _emailController,
          hint: "email@igs.com",
          icon: Icons.alternate_email,
          keyboardType: TextInputType.emailAddress,
          validator: (v) => _currentStep == 1 ? FormValidators.email(v) : null,
        ),

        if (_accountType == 'entreprise' && _userRoleChoice == 'client') ...[
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 10),
          RegisterFields.buildInputLabel("IFU (13 chiffres)"),
          RegisterFields.buildTextField(
            controller: _ifuController,
            hint: "Identifiant Fiscal",
            icon: Icons.pin_outlined,
            validator: (v) => (_currentStep == 1 && _accountType == 'entreprise') 
      ? FormValidators.ifu(v) 
      : null,
          ),
          const SizedBox(height: 15),
          RegisterFields.buildInputLabel("RCCM"),
          RegisterFields.buildTextField(
            controller: _rccmController,
            hint: "Registre de commerce",
            icon: Icons.assignment_outlined,
            validator: (v) => (_currentStep == 1 && _accountType == 'entreprise') 
      ? (v!.isEmpty ? "Le registre de commerce est obligatoire" : null) 
      : null,
          ),
          const SizedBox(height: 15),
          RegisterFields.buildInputLabel("Structure / Agence"),
          RegisterFields.buildTextField(
            controller: _structureController,
            hint: "Nom de la structure",
            icon: Icons.apartment_rounded,
            validator: (v) => (_currentStep == 1 && _accountType == 'entreprise') 
      ? (v!.isEmpty ? "La structure est obligatoire" : null) 
      : null,
          ),
          const SizedBox(height: 15),
  _buildLogoPicker(),
        ],
      ],
    );
  }

  // --- ÉTAPE 3 : MOT DE PASSE ---
  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RegisterFields.buildInputLabel("Mot de passe"),
        RegisterFields.buildTextField(
          controller: _passwordController,
          hint: "Minimum 6 caractères",
          icon: Icons.lock_outline,
          isPassword: true,
          isPasswordVisible: _isPasswordVisible,
          onTogglePassword: () =>
              setState(() => _isPasswordVisible = !_isPasswordVisible),
          validator: (v) =>
              _currentStep == 2 ? FormValidators.motDePasse(v) : null,
        ),
        const SizedBox(height: 15),
        RegisterFields.buildInputLabel("Confirmer le mot de passe"),
        RegisterFields.buildTextField(
          controller: _confirmPasswordController,
          hint: "Répétez le mot de passe",
          icon: Icons.lock_reset,
          isPassword: true,
          isPasswordVisible: _isPasswordVisible,
          onTogglePassword: () =>
              setState(() => _isPasswordVisible = !_isPasswordVisible),
          validator: (v) => _currentStep == 2
              ? FormValidators.confirmerMotDePasse(_passwordController.text)(v)
              : null,
        ),
        const SizedBox(height: 30),

        // --- SECTION CONDITIONS D'UTILISATION ---
        Row(
          children: [
            SizedBox(
              height: 24,
              width: 24,
              child: Checkbox(
                value: _acceptTerms,
                activeColor: igsBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                onChanged: (val) => setState(() => _acceptTerms = val!),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  // Action pour ouvrir un lien ou une modale avec les CGU
                  print("Ouverture des conditions d'utilisation");
                },
                child: RichText(
                  text: TextSpan(
                    style: GoogleFonts.montserrat(
                      color: darkBrown,
                      fontSize: 13,
                    ),
                    children: [
                      const TextSpan(text: "Accepter les "),
                      TextSpan(
                        text: "conditions d'utilisation",
                        style: GoogleFonts.montserrat(
                          color: igsBlue,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        // Petit message d'erreur si non coché lors de la validation
        if (_currentStep == 2 && !_acceptTerms && _isLoading)
          const Padding(
            padding: EdgeInsets.only(top: 8.0),
            child: Text(
              "Vous devez accepter les conditions",
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }

  // --- UI HELPERS (BOUTONS ET SELECTION) ---
  Widget _buildStepperControls(ControlsDetails details) {
    return Padding(
      padding: const EdgeInsets.only(top: 30),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: (_isLoading || (_currentStep == 2 && !_acceptTerms)) ? null : details.onStepContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: igsYellow,
                foregroundColor: darkBrown,
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
                        strokeWidth: 2,
                        color: darkBrown,
                      ),
                    )
                  : Text(
                      _currentStep == 2 ? "FINALISER" : "SUIVANT",
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          if (_currentStep > 0) ...[
            const SizedBox(width: 15),
            TextButton(
              onPressed: details.onStepCancel,
              child: Text(
                "RETOUR",
                style: GoogleFonts.montserrat(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLogoPicker() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      RegisterFields.buildInputLabel("Logo de l'entreprise (Optionnel)"),
      const SizedBox(height: 10),
      GestureDetector(
        onTap: () async {
          final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
          if (image != null) {
            setState(() => _logoFile = File(image.path));
          }
        },
        child: Container(
          height: 100,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: _logoFile != null ? igsBlue : Colors.grey.shade300,
              style: BorderStyle.solid,
            ),
          ),
          child: _logoFile == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_photo_alternate_outlined, color: igsBlue),
                    Text(
                      "Cliquez pour choisir un logo",
                      style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                )
              : Stack(
                  children: [
                    Center(child: Image.file(_logoFile!, height: 80)),
                    Positioned(
                      top: 5,
                      right: 5,
                      child: GestureDetector(
                        onTap: () => setState(() => _logoFile = null),
                        child: const CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.red,
                          child: Icon(Icons.close, size: 15, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    ],
  );
}

  // (Méthodes de sélection identiques à ton code d'origine pour le design)
  Widget _selectionCardRole(String role, String label, IconData icon) {
    bool isSelected = _userRoleChoice == role;
    return _selectionBase(
      isSelected,
      label,
      icon,
      () => setState(() {
        _userRoleChoice = role;
        // Si on choisit Agent, le type est forcément particulier
        if (role == 'Agent') {
          _accountType = 'particulier';
        }
      }),
    );
  }

  Widget _selectionCardType(String type, String label, IconData icon) {
    bool isSelected = _accountType == type;
    return _selectionBase(
      isSelected,
      label,
      icon,
      () => setState(() => _accountType = type),
    );
  }

  Widget _selectionBase(
    bool isSelected,
    String label,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected ? igsBlue : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? igsBlue : Colors.grey, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.montserrat(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? igsBlue : Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
