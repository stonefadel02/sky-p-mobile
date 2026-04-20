import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pinput/pinput.dart';

class OtpVerificationPage extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;

  const OtpVerificationPage({
    super.key,
    required this.verificationId,
    required this.phoneNumber
  });

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage> {
  // Couleurs de ta charte IGS
  static const Color igsBlue = Color(0xFF3473E4);
  // static const Color igsYellow = Color(0xFFFCBF01);
  bool _isLoading = false;

  final defaultPinTheme = PinTheme(
    width: 50,
    height: 55,
    textStyle: GoogleFonts.montserrat(
      fontSize: 22, 
      fontWeight: FontWeight.bold, 
      color: Colors.black
    ),
    decoration: BoxDecoration(
      color: Colors.grey[50],
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade300),
    ),
  );

  Future<void> _verifyOtp(String code) async {
    setState(() => _isLoading = true);
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: code,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);
      
      if (mounted) Navigator.pop(context, true); 
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Code incorrect ou expiré", style: GoogleFonts.montserrat()), 
          backgroundColor: Colors.redAccent
        ),
      );
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
        backgroundColor: Colors.transparent, 
        foregroundColor: Colors.black
      ),
      body: Center( // Centre tout le contenu verticalement
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icône visuelle avec fond coloré
              Container(
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: igsBlue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.vibration_rounded, // Ou Icons.mark_email_read_outlined
                  size: 60,
                  color: igsBlue,
                ),
              ),
              const SizedBox(height: 30),
              
              // Texte mis à jour
              Text(
                "Vérification de votre\nnuméro de téléphone",
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontSize: 24, 
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 15),
              
              Text(
                "Nous avons envoyé un code de confirmation au",
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(color: Colors.grey[600], fontSize: 14),
              ),
              Text(
                widget.phoneNumber,
                style: GoogleFonts.montserrat(
                  color: igsBlue, 
                  fontWeight: FontWeight.bold,
                  fontSize: 16
                ),
              ),
              const SizedBox(height: 40),

              // Champ de saisie OTP
              Pinput(
                length: 6,
                defaultPinTheme: defaultPinTheme,
                focusedPinTheme: defaultPinTheme.copyWith(
                  decoration: defaultPinTheme.decoration!.copyWith(
                    border: Border.all(color: igsBlue, width: 2),
                    color: Colors.white,
                  ),
                ),
                onCompleted: _verifyOtp,
              ),
              const SizedBox(height: 40),

              if (_isLoading) 
                const CircularProgressIndicator(color: igsBlue)
              else 
                TextButton(
                  onPressed: () {
                    // Logique pour renvoyer le code si besoin
                  },
                  child: RichText(
                    text: TextSpan(
                      text: "Vous n'avez pas reçu de code ? ",
                      style: GoogleFonts.montserrat(color: Colors.grey, fontSize: 13),
                      children: const [
                        TextSpan(
                          text: "Renvoyer",
                          style: TextStyle(
                            color: igsBlue, 
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}