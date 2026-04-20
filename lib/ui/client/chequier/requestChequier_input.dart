import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class IgsTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool isNumber;
  final VoidCallback? onTap;
  final bool readOnly;
  final Function(String)? onChanged;

  const IgsTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.isNumber = false,
    this.onTap,
    this.readOnly = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
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
              color: const Color(0xFF26211E).withOpacity(0.8)
            )
          ),
        ),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          onTap: onTap,
          onChanged: onChanged,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: Colors.grey[400], size: 22),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12), 
              borderSide: BorderSide(color: Colors.grey.withOpacity(0.3))
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12), 
              borderSide: const BorderSide(color: Color(0xFF3473E4), width: 1.5)
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 15),
          ),
        ),
      ],
    );
  }
}