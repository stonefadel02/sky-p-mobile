import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WalletCard extends StatelessWidget {
  final double balance;
  final VoidCallback onRecharge;

  const WalletCard({super.key, required this.balance, required this.onRecharge});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF3473E4), // IGS Blue
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Portefeuille", style: GoogleFonts.montserrat(color: Colors.white70)),
              Text("${balance.toStringAsFixed(0)} F", 
                style: GoogleFonts.montserrat(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          ),
          GestureDetector(
            onTap: onRecharge,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.add, color: Color(0xFF3473E4)),
            ),
          )
        ],
      ),
    );
  }
}