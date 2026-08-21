import 'package:flutter/material.dart';

import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sky_p/config/api_config.dart';
import 'package:sky_p/core/theme/ui_helpers.dart';
import 'package:sky_p/services/api_service.dart';
import 'package:sky_p/services/download.dart';
import 'package:sky_p/services/header.dart';
import 'package:sky_p/ui/client/chequier/ticket_usage_page.dart';
import 'package:sky_p/ui/client/transfertTicket/transfer_ticket_modal.dart';

class GroupDetailPage extends StatefulWidget {
  final String groupId;
  const GroupDetailPage({super.key, required this.groupId});

  @override
  State<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends State<GroupDetailPage> {
  // Charte graphique IGS
  static const Color igsBlue = Color(0xFF3473E4);
  static const Color igsYellow = Color(0xffFE8C00);
  static const Color darkBrown = Color(0xFF26211E);

  List<Map<String, dynamic>> tickets = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchTickets();
  }

  void _showTransferModal() async {
    final selection = tickets.where((t) => t['selected']).toList();

    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) => TransferTicketModal(selectedTickets: selection),
    );

    if (result == true) {
      setState(() {
        isLoading = true; // On affiche le loader pendant le rafraîchissement
      });
      _fetchTickets();

      // Optionnel : Désélectionner tout après un succès pour nettoyer l'interface
      _toggleSelectAll(false);
    }
  }

  Future<void> _fetchTickets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('token');

      if (token == null) throw Exception("Token non trouvé");

      final url = Uri.parse(
        "${ApiConfig.baseUrl}/chequiers/${widget.groupId}/tickets",
      );
      final header = await ApiHeaders.getHeaders();

      final response = await IgsHttpClient.get(
        url,
        forceRefresh: true,
        headers: header,
      );
      print ("Réponse chequier detail : ${response.body}");

      if (response.statusCode == 200) {
        final dynamic decodedData = json.decode(response.body);
        print("Données brutes reçues: $decodedData"); // Log pour debug
        final rawList = _extractTickets(decodedData);

        setState(() {
          tickets = rawList.map((t) {
            String expiry = "N/A";
            if (t['expires_at'] != null && t['expires_at'] is Map) {
              expiry = t['expires_at']['date']?.toString().split(' ')[0] ?? expiry;
            } else if (t['expires_at'] != null) {
              expiry = t['expires_at'].toString().split('T')[0];
            }

            String natureDetectee =
                t['nature']?.toString() ??
                t['type']?.toString() ??
                t['category']?.toString() ??
                "SIMPLE";
            return {
              "id": t['id'],
              "code": t['code'] ?? "",
              "valeur": _readTicketAmount(t),
              "nature": natureDetectee.toUpperCase(),
              "expiry": expiry,
              "qr_code": t['qr_code'],
              "valid": _readValid(t) && !_readUsed(t) &&
                  (t['status'] == null ||
                    t['status'].toString().toLowerCase() == 'available'),
              "selected": false,
            };
          }).toList();
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = IgsAlerts.friendlyError(statusCode: response.statusCode);
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = IgsAlerts.friendlyError(error: e);
        isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _extractTickets(dynamic value) {
    if (value is List) {
      return value.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
    }
    if (value is Map) {
      for (final key in ['tickets', 'data', 'items', 'results']) {
        final extracted = _extractTickets(value[key]);
        if (extracted.isNotEmpty) return extracted;
      }

      final indexedTickets = value.values
          .whereType<Map>()
          .where((item) => item.containsKey('id'))
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      if (indexedTickets.isNotEmpty) return indexedTickets;
    }
    return [];
  }

  bool _readUsed(Map<String, dynamic> ticket) {
    final value = ticket['used'] ?? ticket['is_used'];
    if (value is bool) return value;
    return value?.toString().toLowerCase() == 'true' || value?.toString() == '1';
  }

  bool _readValid(Map<String, dynamic> ticket) {
    final value = ticket['valid'];
    if (value == null) return true;
    if (value is bool) return value;
    return value.toString().toLowerCase() == 'true' || value.toString() == '1';
  }

  double _readTicketAmount(Map<String, dynamic> ticket) {
    final value = ticket['price'] ?? ticket['ticket_price'] ?? ticket['amount'] ?? 0;
    return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0;
  }

  double get totalSelected => tickets
      .where((t) => t['selected'] == true)
      .fold(0.0, (sum, item) => sum + (item['valeur'] as double));

  void _toggleSelectAll(bool? value) {
    setState(() {
      for (var t in tickets) {
        if (t['valid']) t['selected'] = value ?? false;
      }
    });
  }

  Future<bool> _confirmGrouping(int selectedCount, double amount) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              const SizedBox(height: 22),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: igsBlue.withOpacity(0.11),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.merge_rounded,
                  color: igsBlue,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Prêt à grouper vos tickets ?',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  color: darkBrown,
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Ils seront réunis sous un seul code QR pour faciliter le paiement.',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F8FF),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: igsBlue.withOpacity(0.12)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildGroupingSummary(
                        Icons.confirmation_num_outlined,
                        '$selectedCount',
                        'Tickets',
                      ),
                    ),
                    Container(width: 1, height: 36, color: Colors.grey.shade300),
                    Expanded(
                      child: _buildGroupingSummary(
                        Icons.account_balance_wallet_outlined,
                        '${amount.toStringAsFixed(0)} F',
                        'Montant total',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(sheetContext, true),
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('Confirmer le groupage'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: igsBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    textStyle: GoogleFonts.montserrat(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(sheetContext, false),
                child: Text(
                  'Pas maintenant',
                  style: GoogleFonts.montserrat(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return result == true;
  }

  Widget _buildGroupingSummary(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: igsBlue, size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.montserrat(
            color: darkBrown,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.montserrat(
            color: Colors.grey.shade600,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Future<void> _showExportMenu() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Actions du chéquier',
                style: GoogleFonts.montserrat(
                  color: darkBrown,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Gérez le PDF complet de ce chéquier',
                style: GoogleFonts.montserrat(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 18),
              _buildExportAction(
                context: sheetContext,
                value: 'download',
                icon: Icons.download_rounded,
                color: igsBlue,
                title: 'Télécharger le PDF',
                subtitle: 'Enregistrer le chéquier sur votre appareil',
              ),
              const SizedBox(height: 12),
              _buildExportAction(
                context: sheetContext,
                value: 'share',
                icon: Icons.ios_share_rounded,
                color: igsYellow,
                title: 'Envoyer le PDF',
                subtitle: 'Partager le chéquier avec une autre personne',
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || action == null) return;
    final exportUrl = "${ApiConfig.baseUrl}/chequiers/${widget.groupId}/export";
    if (action == 'download') {
      await ExportService().downloadExport(
        context,
        exportUrl,
        "Chequier_${widget.groupId}",
      );
    } else {
      final confirmed = await _confirmChequierShare();
      if (!confirmed || !mounted) return;
      await ExportService().shareExport(
        context,
        '$exportUrl?action=share',
        "Chequier_${widget.groupId}",
        subject: 'PDF du chéquier',
        text: 'Voici le PDF complet de votre chéquier.',
      );
    }
  }

  Future<bool> _confirmChequierShare() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              const SizedBox(height: 22),
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: igsBlue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.share_outlined, color: igsBlue, size: 34),
              ),
              const SizedBox(height: 16),
              Text(
                'Envoyer ce chéquier ?',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  color: darkBrown,
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Après l’envoi, ce chéquier ne sera plus visible dans votre liste actuelle. Il restera toutefois associé à votre compte d’origine.',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(sheetContext, true),
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Oui, envoyer le chéquier'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: igsBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    textStyle: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(sheetContext, false),
                child: Text(
                  'Pas maintenant',
                  style: GoogleFonts.montserrat(color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return result == true;
  }

  Widget _buildExportAction({
    required BuildContext context,
    required String value,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Material(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.pop(context, value),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 25),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.montserrat(
                        color: darkBrown,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.montserrat(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade500),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final availableTickets = tickets.where((t) => t['valid']).toList();
    final usedTickets = tickets.where((t) => !t['valid']).toList();
    bool isAllSelected =
        availableTickets.isNotEmpty &&
        availableTickets.every((t) => t['selected']);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: Text(
            "Détails du Chéquier",
            style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: igsBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Tooltip(
                message: 'Télécharger ou envoyer le chéquier',
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    onPressed: _showExportMenu,
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Icons.share_outlined,
                      color: Colors.white,
                      size: 23,
                    ),
                  ),
                ),
              ),
            ),
          ],
          bottom: TabBar(
            indicatorColor: igsYellow,
            indicatorWeight: 4,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: GoogleFonts.montserrat(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            unselectedLabelStyle: GoogleFonts.montserrat(
              fontWeight: FontWeight.normal,
              fontSize: 14,
            ),
            tabs: const [
              Tab(
                icon: Icon(Icons.confirmation_num_outlined),
                text: "Disponibles",
              ),
              Tab(
                icon: Icon(Icons.history_toggle_off_rounded),
                text: "Utilisés",
              ),
            ],
          ),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator(color: igsBlue))
            : RefreshIndicator(
                onRefresh: _fetchTickets, // Permet le "Pull to refresh"
                color: igsBlue,
                child: TabBarView(
                  children: [
                    _buildTicketList(
                      availableTickets,
                      canSelect: true,
                      isAllSelected: isAllSelected,
                    ),
                    _buildTicketList(usedTickets, canSelect: false),
                  ],
                ),
              ),
        bottomNavigationBar: totalSelected > 0
            ? _buildSelectionSummaryBar()
            : null,

        floatingActionButton: _buildFloatingMenu(),
      ),
    );
  }

  Widget _buildSelectionSummaryBar() {
    final selectedCount = tickets.where((t) => t['selected']).length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$selectedCount ticket(s) sélectionné(s)",
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  "${totalSelected.toStringAsFixed(0)} FCFA",
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: igsBlue,
                  ),
                ),
              ],
            ),
            // Optionnel : Un petit bouton pour vider la sélection
            TextButton(
              onPressed: () => _toggleSelectAll(false),
              child: Text(
                "Effacer",
                style: GoogleFonts.montserrat(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingMenu() {
    return SpeedDial(
      icon: Icons.add,
      activeIcon: Icons.close,
      backgroundColor: igsYellow,
      foregroundColor: darkBrown,
      overlayColor: Colors.black,
      overlayOpacity: 0.5,
      spacing: 12,
      spaceBetweenChildren: 12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      children: [
        // Action UTILISER
        SpeedDialChild(
          child: const Icon(Icons.confirmation_num_outlined),
          backgroundColor: igsYellow,
          foregroundColor: darkBrown,
          label: 'UTILISER (${totalSelected.toStringAsFixed(0)} FCFA)',
          labelStyle: GoogleFonts.montserrat(
            fontWeight: FontWeight.bold,
            color: darkBrown,
          ),
          labelBackgroundColor: igsYellow,
          onTap: totalSelected > 0
              ? () async {
                  final selection = tickets
                      .where((t) => t['selected'])
                      .toList();
                final isGrouping = selection.length > 1;
                if (isGrouping &&
                  !await _confirmGrouping(selection.length, totalSelected)) {
                return;
                }
                  bool isAlreadyGrouped =
                      selection.length == 1 &&
                      selection.first['nature'] == "GROUPE";

                  // Un seul ticket SIMPLE → utiliser son QR directement
                  bool isSingleSimple =
                      selection.length == 1 &&
                      selection.first['nature'] == "SIMPLE";

                  // 1. On attend le retour de la page
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (c) => TicketUsagePage(
                        selectedTickets: selection,
                        isExistingGroup: isAlreadyGrouped || isSingleSimple,
                      ),
                    ),
                  );

                  // 2. Si result est true, on rafraîchit la liste
                  if (result == true) {
                    setState(() {
                      isLoading = true; // On affiche le loader
                    });
                    _fetchTickets(); // On recharge les tickets depuis l'API
                  }
                }
              : null,
        ),
        // Action TRANSFÉRER
        SpeedDialChild(
          child: const Icon(Icons.send_rounded),
          backgroundColor: igsBlue,
          foregroundColor: Colors.white,
          label: 'TRANSFÉRER',
          labelStyle: GoogleFonts.montserrat(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          labelBackgroundColor: igsBlue,
          onTap: totalSelected > 0
              ? () => _showTransferModal()
              : () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Veuillez sélectionner au moins un ticket"),
                    ),
                  );
                },
        ),
      ],
    );
  }

  Widget _buildTicketList(
    List<Map<String, dynamic>> filteredTickets, {
    required bool canSelect,
    bool isAllSelected = false,
  }) {
    if (filteredTickets.isEmpty) {
      return Center(
        child: Text(
          "Aucun ticket trouvé",
          style: GoogleFonts.montserrat(color: Colors.grey),
        ),
      );
    }

    return Column(
      children: [
        if (canSelect)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 15, 30, 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(
                10,
              ), // Pour un effet de clic propre
              onTap: () => _toggleSelectAll(!isAllSelected),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    // Cet espace correspond exactement au retrait de l'icône dans la carte
                    const SizedBox(width: 59),
                    Expanded(
                      child: Text(
                        "Tout sélectionner",
                        style: GoogleFonts.montserrat(
                          fontSize: 17,
                          fontWeight: FontWeight
                              .w700, // Un peu plus gras pour l'en-tête
                          color: darkBrown.withOpacity(0.8),
                        ),
                      ),
                    ),
                    _buildCustomCheckbox(isAllSelected),
                  ],
                ),
              ),
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: filteredTickets.length,
            itemBuilder: (context, index) {
              final ticket = filteredTickets[index];
              bool isSelected = ticket['selected'];

              return GestureDetector(
                onTap: canSelect
                    ? () => setState(() => ticket['selected'] = !isSelected)
                    : null,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? igsYellow : Colors.transparent,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: canSelect
                              ? igsBlue.withOpacity(0.1)
                              : Colors.grey[100],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.business_center,
                          color: canSelect ? igsBlue : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ticket ${ticket['id']}',
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              "${ticket['valeur'].toStringAsFixed(0)} FCFA",
                              style: GoogleFonts.montserrat(
                                color: igsYellow,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (canSelect)
                        _buildCustomCheckbox(isSelected)
                      else
                        const Icon(
                          Icons.lock_reset_rounded,
                          color: Colors.grey,
                          size: 22,
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCustomCheckbox(bool isSelected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: isSelected ? igsBlue : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? igsBlue : Colors.grey.shade400,
          width: 2,
        ),
      ),
      child: isSelected
          ? const Icon(Icons.check, size: 16, color: Colors.white)
          : null,
    );
  }
}
