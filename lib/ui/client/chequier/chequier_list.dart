import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:sky_p/config/api_config.dart';
import 'package:sky_p/services/header.dart';
import 'package:sky_p/services/auth_service.dart';
import 'package:sky_p/services/notification_service.dart';
import 'package:sky_p/ui/client/chequier/chequier_detail.dart';
import 'package:sky_p/ui/client/chequier/requestChequierform.dart';
import 'package:sky_p/ui/widgets/state_handler.dart';

import '../../../services/api_service.dart';

class GroupListPage extends StatefulWidget {
  const GroupListPage({super.key});

  @override
  State<GroupListPage> createState() => _GroupListPageState();
}

class _GroupListPageState extends State<GroupListPage> {
  static const Color igsBlue = Color(0xFF3473E4);
  static const Color igsYellow = Color(0xffFE8C00);
  static const Color darkBrown = Color(0xFF26211E);
  static const Color bgColor = Color(0xFFF8F9FA);

  String _selectedFilter = 'approved';
  String userName = "";

  StreamSubscription?
  _notifSubscription; // Clé pour forcer le rebuild du FutureBuilder
  Key _futureKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _notifSubscription = NotificationService().stream.listen((data) {
      if (mounted) {
        final String body = data['body'] ?? "";
        setState(() => _futureKey = UniqueKey());

        // ✅ Snackbar coloré
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "${data['title'] ?? ''}\n$body",
              style: GoogleFonts.montserrat(color: Colors.white),
            ),
            backgroundColor:
                body.toLowerCase().contains('refus') ||
                    body.toLowerCase().contains('annul')
                ? Colors.red
                : igsBlue,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });

    // ✅ Garder pour tap depuis arrière-plan
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (mounted) setState(() => _futureKey = UniqueKey());
    });
  }

  @override
  void dispose() {
    _notifSubscription?.cancel();
    super.dispose();
  }

  Future<void> _logoutWithConfirmation() async {
    // Note: Tu peux importer 'package:quickalert/quickalert.dart'
    // Ou utiliser un showDialog classique si tu n'as pas QuickAlert ici
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "Déconnexion",
          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
        ),
        content: const Text("Voulez-vous vraiment vous déconnecter ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Annuler",
              style: GoogleFonts.montserrat(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              await AuthService.clearAll();
              if (!mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (route) => false,
              );
            },
            child: Text(
              "Oui",
              style: GoogleFonts.montserrat(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userName = prefs.getString('user_name') ?? "Utilisateur";
    });
  }

  String _formatFrenchDate(String? dateStr) {
    if (dateStr == null) return "Récemment";
    try {
      DateTime dt = DateTime.parse(dateStr);
      return DateFormat('dd MMMM yyyy', 'fr_FR').format(dt);
    } catch (e) {
      return dateStr.split('T')[0];
    }
  }

  Future<List<dynamic>> fetchChequiers() async {
   
    String path = _selectedFilter == 'approved' ? "/chequiers/me" : "/me/demandes";

  Uri url;
  if (_selectedFilter == 'approved') {
    url = Uri.parse("${ApiConfig.baseUrl}$path");
  } else {
    url = Uri.parse("${ApiConfig.baseUrl}$path").replace(
      queryParameters: {'provider': 'SKY-P'},
    );
  }
    


    try {
      final header = await ApiHeaders.getHeaders();
      final response = await IgsHttpClient.get(
        url,
        forceRefresh: true,
        headers:header ,
      );
      print("Réponse chequiers liste : ${response.body}");

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        print("Données reçues pour les chéquiers : $decoded");
        List<dynamic> data = [];
        if (decoded is List)
          data = decoded;
        else if (decoded is Map) {
          data =
              decoded['chequiers'] ??
              decoded['requests'] ??
              decoded['data'] ??
              decoded['demandes'] ??
              [decoded];
        }
        if (_selectedFilter != 'approved') {
          return data
              .where(
                (d) =>
                    d['status'].toString().toLowerCase() ==
                    _selectedFilter.toLowerCase(),
              )
              .toList();
        }
        List<dynamic> enriched = await Future.wait(
          data.map((item) async {
            try {
              final header = await ApiHeaders.getHeaders();
              final detailResponse = await IgsHttpClient.get(
                Uri.parse("${ApiConfig.baseUrl}/chequiers/${item['id']}"),
                forceRefresh: true,
                headers: header,
              );
              if (detailResponse.statusCode == 200) {
                final detail = json.decode(detailResponse.body);
                final List tickets = detail['tickets'] ?? [];
                final int utilises = tickets
                    .where((t) => t['used'] == true)
                    .length;
                final int restants = tickets.length - utilises;
                return {
                  ...item,
                  'tickets_remaining': restants,
                  'tickets_used': utilises,
                };
              }
            } catch (_) {}
            return item;
          }),
        );

        return enriched;
      } else {
        throw Exception('Erreur serveur');
      }
    } catch (e) {
      throw Exception('Erreur de connexion');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        toolbarHeight: 160, // Augmenté pour donner de l'espace
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        flexibleSpace: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              10,
              20,
              20,
            ), // Plus d'espace en bas (20)
            child: Column(
              mainAxisAlignment: MainAxisAlignment
                  .end, // Aligne vers le bas pour plus d'air en haut
              children: [
                // LIGNE 1 : Utilisateur
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        // Cercle contenant le logo
                        Container(
                          width: 80,
                          height: 80,

                          child: ClipRRect(
                            child: Image.asset(
                              'assets/logoremovebg.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "",
                          style: GoogleFonts.montserrat(
                            color: igsBlue,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.logout_rounded,
                        color: igsBlue,
                      ),
                      onPressed: _logoutWithConfirmation,
                    ),
                  ],
                ),
                const SizedBox(
                  height: 5,
                ), // Plus d'espace entre utilisateur et titre
                // LIGNE 2 : Titre + Bouton Ajouter
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "MES CHÉQUIERS",
                      style: GoogleFonts.montserrat(
                        color: igsBlue,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    GestureDetector(
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RequestChequierPage(),
                          ),
                        );
                        if (result == true) setState(() {});
                      },
                      child: Container(
                        width: 45,
                        height: 45,
                        decoration: const BoxDecoration(
                          color: Colors.grey,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.black12, blurRadius: 4),
                          ],
                        ),
                        child: const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // FOND BLEU qui continue juste après l'AppBar pour les filtres
          Container(
            height: 80, // S'arrête juste après les filtres
            width: double.infinity,
            color: Colors.white,
          ),
          Column(
            children: [
              const SizedBox(height: 15), // Petit espace sous le titre
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 2,
                ),
                child: _buildSegmentedFilter(),
              ),
              const SizedBox(height: 15),
              Expanded(
                child: FutureBuilder<List<dynamic>>(
                  key: _futureKey,
                  future: fetchChequiers(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: igsBlue),
                      );
                    } else if (snapshot.hasError) {
                      return _buildErrorWidget(snapshot.error.toString());
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return _buildEmptyState(
                        _selectedFilter == 'approved'
                            ? "Aucun chéquier actif."
                            : "Aucune demande.",
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) =>
                          _buildOldStyleCard(snapshot.data![index], index),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedFilter() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: igsBlue.withOpacity(0.2),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          _buildFilterTab("approved", "APPROUVÉS"),
          _buildFilterTab("pending", "EN ATTENTE"),
          _buildFilterTab("rejected", "REFUSÉS"),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String status, String label) {
    bool isSelected = _selectedFilter == status;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilter = status),
        child: Container(
          margin: const EdgeInsets.all(5),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? igsBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : igsBlue,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOldStyleCard(dynamic item, int index) {
    double total =
        double.parse((item['ticket_price'] ?? 0).toString()) *
        (item['tickets_count'] ?? 0);
    // bool isValable = (item['tickets_count'] ?? 0) > 0;
    final int restants =
        item['tickets_remaining'] ?? (item['tickets_count'] ?? 0);
    bool isValable = restants > 0;
    return GestureDetector(
      onTap: _selectedFilter == 'approved'
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      GroupDetailPage(groupId: item['id'].toString()),
                ),
              );
            }
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 6,
                decoration: BoxDecoration(
                  color: _selectedFilter == 'approved'
                      ? (isValable ? Colors.grey : Colors.red)
                      : (_selectedFilter == 'pending'
                            ? Colors.orange
                            : Colors.red),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: igsBlue.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.inventory_2_rounded,
                          color: igsBlue,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: igsBlue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    '${index + 1}',
                                    style: GoogleFonts.montserrat(
                                      color: igsBlue,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    (item['partner'] ??
                                            item['agence'] ??
                                            'Chéquier')
                                        .toString(),
                                    style: GoogleFonts.montserrat(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: darkBrown,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _infoRow(
                              Icons.calendar_today_rounded,
                              "Le ${_formatFrenchDate(item['created_at'] ?? item['requested_at'])}",
                              Colors.orange,
                            ),
                            const SizedBox(height: 4),
                            _infoRow(
                              Icons.confirmation_num_rounded,
                              "$restants / ${item['tickets_count']} Tickets restants",
                              igsBlue,
                            ),
                            const SizedBox(height: 4),
                            _infoRow(
                              Icons.payments_rounded,
                              "${total.toStringAsFixed(0)} FCFA",
                              igsYellow,
                              isBold: true,
                            ),
                          ],
                        ),
                      ),
                      Align(
                        alignment: Alignment.topRight,
                        child: _buildOldStatusBadge(isValable),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(
    IconData icon,
    String label,
    Color iconColor, {
    bool isBold = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 12, color: iconColor),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.montserrat(
            fontSize: 11,
            color: isBold ? igsBlue : Colors.blueGrey[700],
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildOldStatusBadge(bool isValable) {
    Color color;
    String label;
    if (_selectedFilter == 'approved') {
      color = isValable ? Colors.green : Colors.red;
      label = isValable ? "Valable" : "Non valable";
    } else if (_selectedFilter == 'pending') {
      color = Colors.orange;
      label = "En attente";
    } else {
      color = Colors.red;
      label = "Refusé";
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.montserrat(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) => Padding(
    padding: const EdgeInsets.only(top: 50),
    child: IGSStateDisplay(
      animation: 'empty_box',
      title: "C'est vide",
      message: message,
    ),
  );
  Widget _buildErrorWidget(String error) => Padding(
    padding: const EdgeInsets.only(top: 50),
    child: IGSStateDisplay(
      animation: 'no_internet',
      title: "Erreur",
      message: "Vérifiez votre connexion.",
    ),
  );
}
