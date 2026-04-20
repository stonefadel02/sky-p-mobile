import 'package:animated_icon/animated_icon.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NewsSection extends StatelessWidget {
  const NewsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(15.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Nouveautés IGS", 
            style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 16)
          ),
          const SizedBox(height: 12),
          Row(
            children: [
             _newsCard("Assurance", AnimateIcons.bell, Colors.blue),
              const SizedBox(width: 12),
              // 'shoppingCart' ou 'briefcase' pour la boutique.
              _newsCard("Boutique", AnimateIcons.checkbox, Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

 Widget _newsCard(String text, AnimateIcons animIcon, Color color) {
  return Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          AnimateIcon(
            key: UniqueKey(),
            onTap: () {},
            iconType: IconType.animatedOnTap, // S'anime quand l'utilisateur clique
            height: 40,
            width: 40,
            color: color,
            animateIcon: animIcon,
          ),
          const SizedBox(height: 8),
          Text(text, style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    ),
  );
}
}