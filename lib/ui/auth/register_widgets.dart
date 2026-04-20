import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RegisterFields {
  static const Color igsBlue = Color(0xFF3473E4);
  static const Color darkBrown = Color(0xFF26211E);

  static Widget buildInputLabel(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
        child: Text(label,
            style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w600, color: darkBrown, fontSize: 14)),
      );

  static Widget buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool isPasswordVisible = false,
    VoidCallback? onTogglePassword,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword && !isPasswordVisible,
      keyboardType: keyboardType,
      style: GoogleFonts.montserrat(fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: igsBlue, size: 20),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                    isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                    size: 20),
                onPressed: onTogglePassword)
            : null,
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.grey.shade100)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: igsBlue, width: 1.5)),
      ),
      validator: validator ?? (v) => v!.isEmpty ? "Champ requis" : null,
    );
  }
}