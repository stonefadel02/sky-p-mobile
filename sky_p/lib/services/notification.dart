import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  static const Color igsBlue = Color(0xFF3473E4);
  static const Color igsYellow = Color(0xFFFCBF01);

  // Exemple de données (À remplacer par ton flux Firebase/API)
  final List<Map<String, dynamic>> notifications = [
    {
      "title": "Ticket Reçu !",
      "body": "Stone vous a envoyé un ticket de 5.000 FCFA.",
      "time": "Il y a 2 min",
      "isRead": false,
      "icon": Icons.confirmation_number_rounded,
    },
    {
      "title": "Transfert Réussi",
      "body": "Votre transfert vers l'agence Calavi a été validé.",
      "time": "Il y a 1 heure",
      "isRead": true,
      "icon": Icons.swap_horizontal_circle_rounded,
    },
    {
      "title": "Alerte Sécurité",
      "body": "Nouvelle connexion détectée sur votre compte.",
      "time": "Hier",
      "isRead": true,
      "icon": Icons.security_rounded,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Gris très clair pour faire ressortir les cartes
      appBar: AppBar(
        title: Text(
          "Notifications",
          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all_rounded),
            onPressed: () {
              // Action pour marquer tout comme lu
            },
          )
        ],
      ),
      body: notifications.isEmpty 
          ? _buildEmptyState() 
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 15),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final item = notifications[index];
                return _buildNotificationItem(item);
              },
            ),
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(15),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: item['isRead'] ? Colors.grey[100] : igsBlue.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            item['icon'],
            color: item['isRead'] ? Colors.grey : igsBlue,
            size: 28,
          ),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              item['title'],
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: item['isRead'] ? Colors.grey[700] : Colors.black,
              ),
            ),
            if (!item['isRead'])
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: igsYellow,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 5),
            Text(
              item['body'],
              style: GoogleFonts.montserrat(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item['time'],
              style: GoogleFonts.montserrat(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: igsBlue.withOpacity(0.7),
              ),
            ),
          ],
        ),
        onTap: () {
          // Action au clic (ex: ouvrir le ticket)
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined, size: 100, color: Colors.grey[300]),
          const SizedBox(height: 20),
          Text(
            "Aucune notification",
            style: GoogleFonts.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}