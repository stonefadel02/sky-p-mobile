import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import 'package:flutter_screenutil/flutter_screenutil.dart'; // Pour gérer les tailles fines
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sky_p/services/api_service.dart';
import 'package:sky_p/services/header.dart';
import 'package:sky_p/ui/client/ticket%20express/create_ticket_page.dart';
import 'package:sky_p/ui/client/ticket%20express/ticketDetailPage.dart';
import '../../../config/api_config.dart';

class TicketListPage extends StatefulWidget {
  const TicketListPage({super.key});

  @override
  State<TicketListPage> createState() => _TicketListPageState();
}

class _TicketListPageState extends State<TicketListPage> {
  static const Color igsBlue = Color(0xFF3473E4);
  static const Color darkBrown = Color(0xFF26211E);
  List<dynamic> _tickets = [];
  bool _isLoading = true;
  StreamSubscription? _firebaseSubscription;

  @override
  void initState() {
    super.initState();
    _loadTickets(force: true); // Chargement initial
    _listenForNewTickets();
  }

  @override
  void dispose() {
    _firebaseSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadTickets({bool force = false}) async {
    try {
      final tickets = await _fetchTickets(force: force);
      if (mounted) {
        // ✅ On crée une copie de la liste pour éviter les erreurs sur les listes immuables
        List<dynamic> sortedTickets = List.from(tickets);

        sortedTickets.sort((a, b) {
          try {
            final dateA = DateTime.parse(a['created_at'].toString());
            final dateB = DateTime.parse(b['created_at'].toString());
            return dateB.compareTo(dateA);
          } catch (e) {
            return 0; // Sécurité si la date est mal formatée
          }
        });

        setState(() {
          _tickets = sortedTickets;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("ERREUR FETCH TICKETS: $e"); // Log pour debugger
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ✅ Écoute Firebase : refresh auto dès qu'un nouveau ticket arrive
  Future<void> _listenForNewTickets() async {
    final prefs = await SharedPreferences.getInstance();
    final String? email = prefs.getString('user_email');
    if (email == null) return;

    final String safePath = email.replaceAll('@', '_').replaceAll('.', '_');
    final DatabaseReference ref = FirebaseDatabase.instance.ref(
      "notifications/$safePath",
    );

    _firebaseSubscription = ref.onValue.listen((event) {
      if (event.snapshot.value != null && mounted) {
        // Nouveau ticket détecté → refresh de la liste
        _loadTickets(force: true);
      }
    });
  }

  Future<List<dynamic>> _fetchTickets({bool force = false}) async {
  
    final header = await ApiHeaders.getHeaders();
    final response = await IgsHttpClient.get(
      Uri.parse("${ApiConfig.baseUrl}/tickets/individuals"),
      forceRefresh: true,
      headers: header,
    );
    print("Response body: ${response.body}");

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Erreur de chargement");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(
        0xFFFBFBFC,
      ), // Gris très clair, presque blanc
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre de section identique à tes autres pages
          Padding(
            padding: EdgeInsets.fromLTRB(24.w, 20.h, 24.w, 10.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Mes Tickets",
                  style: GoogleFonts.montserrat(
                    color: darkBrown,
                    fontSize: 20.sp, // Taille affinée
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  "Gérez vos accès et tickets disponibles.",
                  style: GoogleFonts.montserrat(
                    color: Colors.grey[600],
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: RefreshIndicator(
              // Permet aussi de tirer vers le bas pour actualiser
              onRefresh: () => _loadTickets(force: true),
              color: igsBlue,
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: igsBlue,
                        strokeWidth: 2,
                      ),
                    )
                  : _tickets.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.symmetric(
                        horizontal: 20.w,
                        vertical: 10.h,
                      ),
                      itemCount: _tickets.length,
                      itemBuilder: (context, index) =>
                          _buildTicketItem(_tickets[index]),
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: 30.h),
        child: FloatingActionButton.extended(
          heroTag: 'unique_ticket_fab',
          onPressed: () async {
            // 1. On attend le retour de la page
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CreateTicketPage()),
            );
            print("🔄 Retour détecté : Rafraîchissement forcé de la liste");

            setState(() => _isLoading = true);

            // On attend 500ms pour laisser au backend le temps de bien enregistrer
            await Future.delayed(const Duration(milliseconds: 500));

            await _loadTickets(force: true);
          },
          backgroundColor: igsBlue,
          elevation: 2,
          icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
          label: Text(
            "Nouveau Ticket",
            style: GoogleFonts.montserrat(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13.sp,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTicketItem(dynamic ticket) {
    bool isValid = ticket['status'] == 'valid';
    // Récupération des nouvelles données
    String nature = ticket['nature'] ?? 'N/A';
    bool isTransfered = ticket['is_transfer'] ?? false;

    String price = "${double.parse(ticket['price'].toString()).toInt()} FCFA";
    String rawDate = ticket['created_at'].toString();
    String displayDate = rawDate.split(' ')[0];

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TicketDetailPage(ticket: ticket),
        ),
      ),
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(14.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              height: 45.r,
              width: 45.r,
              decoration: BoxDecoration(
                color: igsBlue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(
                Icons.confirmation_num_outlined,
                color: igsBlue,
                size: 20.r,
              ),
            ),
            SizedBox(width: 15.w),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ticket de $price',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.sp,
                      color: darkBrown,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  // Ligne avec Nature et Statut de transfert
                  Row(
                    children: [
                      // Nature du ticket (ex: Simple)
                      _buildSmallTag(
                        nature.toUpperCase(),
                        Icons.label_outline_rounded,
                        Colors.blueGrey,
                      ),
                      SizedBox(width: 8.w),
                      // Indicateur de transfert
                      if (isTransfered)
                        _buildSmallTag(
                          "TRANSFÉRÉ",
                          Icons.swap_horiz_rounded,
                          Colors.orange[700]!,
                        ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    "Émis le $displayDate",
                    style: GoogleFonts.montserrat(
                      fontSize:
                          10.sp, // Un peu plus petit pour laisser de la place
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),

            // Badge Statut
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
              decoration: BoxDecoration(
                color: isValid
                    ? Colors.green.withAlpha(25)
                    : Colors.red.withAlpha(25),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                isValid ? "VALIDE" : "UTILISÉ",
                style: GoogleFonts.montserrat(
                  color: isValid ? Colors.green[700] : Colors.red[700],
                  fontSize: 10.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Petit helper pour les tags (Nature / Transfert)
  Widget _buildSmallTag(String text, IconData icon, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12.sp, color: color.withOpacity(0.7)),
        SizedBox(width: 3.w),
        Text(
          text,
          style: GoogleFonts.montserrat(
            fontSize: 9.sp,
            fontWeight: FontWeight.w600,
            color: color.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.confirmation_number_outlined,
            size: 40.r,
            color: Colors.grey[300],
          ),
          SizedBox(height: 10.h),
          Text(
            "Aucun ticket",
            style: GoogleFonts.montserrat(color: Colors.grey, fontSize: 13.sp),
          ),
        ],
      ),
    );
  }
}
