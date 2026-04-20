import 'dart:async';
import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sky_p/config/api_config.dart';
import 'package:sky_p/services/api_service.dart';
import 'package:sky_p/services/header.dart';
import 'package:sky_p/ui/client/goFuel/_confirm_recepetion.dart';
import 'package:sky_p/ui/client/goFuel/goFuel_form.dart';
import 'package:sky_p/ui/widgets/igs_app_bar.dart';

class MyOrdersPage extends StatefulWidget {
  const MyOrdersPage({super.key});

  @override
  State<MyOrdersPage> createState() => _MyOrdersPageState();
}

class _MyOrdersPageState extends State<MyOrdersPage> {

  StreamSubscription? _firebaseSubscription;
  // --- VARIABLES D'ÉTAT ---
  List<dynamic> _orders = [];
  bool _isLoading = true;
  int _currentPage = 1;
  int _totalPages = 1;

  
  static const Color igsBlue = Color(0xFF3473E4);
  static const Color darkBrown = Color(0xFF26211E);

  @override
  void initState() {
    super.initState();
    _fetchOrders(page: 1);
     _listenForOrderUpdates(); // ✅ Ajouter
  }

  @override
void dispose() {
  _firebaseSubscription?.cancel();
  super.dispose();
}

Future<void> _listenForOrderUpdates() async {
  final prefs = await SharedPreferences.getInstance();
  final String? email = prefs.getString('user_email');
  if (email == null) return;

  final String safePath = email.replaceAll('@', '_').replaceAll('.', '_');
  final DatabaseReference ref =
      FirebaseDatabase.instance.ref("notifications/$safePath");

  _firebaseSubscription = ref.onValue.listen((event) {
    if (event.snapshot.value != null && mounted) {
      final Map<String, dynamic> data =
          Map<String, dynamic>.from(event.snapshot.value as Map);

      final String title = data['title'] ?? "Mise à jour commande";
      final String body = data['body'] ?? "";

      // ✅ Rafraîchit la liste
      _fetchOrders(page: _currentPage);

      // ✅ Snackbar coloré selon l'étape
      Color snackColor = _getSnackColor(body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "$title\n$body",
            style: GoogleFonts.montserrat(color: Colors.white),
          ),
          backgroundColor: snackColor,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  });
}



// ✅ Couleur selon le contenu du message
Color _getSnackColor(String body) {
  final b = body.toLowerCase();
  if (b.contains('refus') || b.contains('annul') || b.contains('rejet')) {
    return Colors.red;
  } else if (b.contains('livr') || b.contains('termin')) {
    return Colors.green;
  } else if (b.contains('cours') || b.contains('progress') || b.contains('accept')) {
    return Colors.orange;
  }
  return const Color(0xFF3473E4);
}

  // --- APPEL API AVEC PAGINATION ---
  Future<void> _fetchOrders({int page = 1}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _currentPage = page;
    });

    try {
   

      // Appel de la route avec le paramètre de page
      final header = await ApiHeaders.getHeaders();
      final response = await IgsHttpClient.get(
        Uri.parse("${ApiConfig.baseUrl}/fuel/me-commandes?page=$page"),
        forceRefresh: true,
        headers: header,
      );
      print ("Réponse commandes : ${response.body}");

      if (!mounted) return;

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        
        setState(() {
          _orders = responseData['data'] ?? [];
          
          // Calcul dynamique du nombre de pages
          int totalItems = responseData['count'] ?? 0;
          int limit = responseData['limit'] ?? 10;
          _totalPages = (totalItems / limit).ceil();
          if (_totalPages < 1) _totalPages = 1;

          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      print("Erreur récupération commandes : $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: const IgsAppBar(title: 'Mes Commandes Fuel'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const GoFuelOrderPage()),
          ).then((value) => _fetchOrders(page: 1));
        },
        backgroundColor: igsBlue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text("Commander",
            style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: igsBlue))
          : RefreshIndicator(
              onRefresh: () => _fetchOrders(page: 1),
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
                children: [
                  Text(
                    "Mes Commandes Fuel",
                    style: GoogleFonts.montserrat(
                      color: darkBrown,
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    "Historique de vos commandes de carburant.",
                    style: GoogleFonts.montserrat(color: Colors.grey[700], fontSize: 12.sp),
                  ),
                  SizedBox(height: 30.h),

                  if (_orders.isEmpty)
                    _buildEmptyState()
                  else ...[
                    // Liste des commandes
                    Column(
                      children: _orders.map((order) => _buildOrderCard(order)).toList(),
                    ),
                    
                    // Barre de pagination
                    if (_totalPages > 1) _buildPaginationControls(),
                  ],

                  SizedBox(height: 80.h),
                ],
              ),
            ),
    );
  }

  // --- WIDGET : CARTE DE COMMANDE ---
  Widget _buildOrderCard(Map<String, dynamic> order) {
    final String status = (order['status'] ?? 'pending').toString().toLowerCase();
    final String livraisonStatus = (order['livraison_status'] ?? '').toString().toLowerCase();
    final String type = order['type_carburant'] ?? 'essence';
    final double rawLitres = double.tryParse(order['nombre_litres'].toString()) ?? 0.0;
    // final String montant = order['montant_total']?.toString() ?? "0";
    
    String formattedDateTime = "Date inconnue";
    if (order['requested_at'] != null) {
      try {
        DateTime dt = DateTime.parse(order['requested_at'].toString());
        formattedDateTime = DateFormat('dd/MM/yyyy à HH:mm').format(dt);
      } catch (e) {
        formattedDateTime = order['requested_at'].toString();
      }
    }

    // Toute la carte est cliquable pour aller à la confirmation
    bool isActionable = livraisonStatus == "accepted" || status == "approved";

    return GestureDetector(
      onTap: () {
        if (isActionable) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ConfirmDeliveryPage(
                orderId: order['id'].toString(),
                orderData: order,
              ),
            ),
          ).then((_) => _fetchOrders(page: _currentPage));
        }
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 15.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15.r),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: ListTile(
          contentPadding: EdgeInsets.all(15.r),
          leading: Container(
            padding: EdgeInsets.all(10.r),
            decoration: BoxDecoration(
              color: igsBlue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              type == 'gasoil' ? Icons.oil_barrel_rounded : Icons.local_gas_station_rounded,
              color: igsBlue,
            ),
          ),
          title: Text(
            "${type.toUpperCase()} ${rawLitres.toStringAsFixed(0)} Litres",
            style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 14.sp),
          ),
          subtitle: Text(
            "Le $formattedDateTime",
            style: GoogleFonts.montserrat(fontSize: 11.sp, color: Colors.grey[600]),
          ),
          
          trailing: _buildStatusBadge(status, livraisonStatus),
        ),
        
      ),
    );
  }

  // --- WIDGET : BADGE DE STATUT ---
  Widget _buildStatusBadge(String status, String livraison) {
    Color color;
    String text;

// --- LOGIQUE COMBINÉE DES STATUS ---
    if (livraison == "done") {
      color = Colors.green;
      text = "Livrée";
    } else if (livraison == "in_progress" || livraison == "accepted") {
      color = Colors.orange;
      text = "En cours";
    } else if (status == "rejected" || livraison == "canceled") {
      color = Colors.red;
      text = status == "rejected" ? "Refusée" : "Annulée";
    } else if (status == "approved") {
      color = Colors.teal;
      text = "Approuvée";
    } else {
      color = Colors.blue;
      text = "En attente";
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(
        text,
        style: GoogleFonts.montserrat(color: color, fontWeight: FontWeight.bold, fontSize: 10.sp),
      ),
    );
  }

  // --- WIDGET : CONTRÔLES DE PAGINATION ---
  Widget _buildPaginationControls() {
    return Container(
      padding: EdgeInsets.only(top: 20.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Flèche précédent
          IconButton(
            icon: Icon(Icons.arrow_back_ios, size: 16.sp),
            color: _currentPage > 1 ? igsBlue : Colors.grey[300],
            onPressed: _currentPage > 1 ? () => _fetchOrders(page: _currentPage - 1) : null,
          ),

          // Liste des numéros
          Row(
            children: List.generate(_totalPages, (index) {
              int pageNum = index + 1;
              bool isSelected = pageNum == _currentPage;
              return GestureDetector(
                onTap: () => _fetchOrders(page: pageNum),
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 4.w),
                  height: 35.r,
                  width: 35.r,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? igsBlue : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: isSelected ? igsBlue : Colors.grey.shade300),
                  ),
                  child: Text(
                    pageNum.toString(),
                    style: GoogleFonts.montserrat(
                      color: isSelected ? Colors.white : darkBrown,
                      fontWeight: FontWeight.bold,
                      fontSize: 12.sp,
                    ),
                  ),
                ),
              );
            }),
          ),

          // Flèche suivant
          IconButton(
            icon: Icon(Icons.arrow_forward_ios, size: 16.sp),
            color: _currentPage < _totalPages ? igsBlue : Colors.grey[300],
            onPressed: _currentPage < _totalPages ? () => _fetchOrders(page: _currentPage + 1) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 60.r, color: Colors.grey[300]),
          SizedBox(height: 10.h),
          Text("Aucune commande pour le moment", style: GoogleFonts.montserrat(color: Colors.grey)),
        ],
      ),
    );
  }
}