import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:sky_p/config/api_config.dart';
import 'package:sky_p/core/theme/ui_helpers.dart';
import 'package:sky_p/services/api_service.dart';
import 'package:sky_p/services/download.dart';
import 'package:sky_p/services/header.dart';

class TicketUsagePage extends StatefulWidget {
  final List<Map<String, dynamic>> selectedTickets;
  final bool isExistingGroup;

  const TicketUsagePage({
    super.key,
    required this.selectedTickets,
    this.isExistingGroup = false,
  });

  @override
  State<TicketUsagePage> createState() => _TicketUsagePageState();
}

class _TicketUsagePageState extends State<TicketUsagePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _groupId;
  String? _qrToken;
  String? _errorMessage;

  static const Color igsBlue = Color(0xFF3473E4);
  static const Color igsYellow = Color(0xffFE8C00);
  static const Color lightGreyBg = Color(0xFFF5F5F5);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (widget.isExistingGroup) {
      _loadExistingTicket();
    } else {
      _generateGroupToken();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadExistingTicket() {
    if (widget.selectedTickets.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }
    final ticket = widget.selectedTickets.first;
    final rawPath = ticket['qr_code']?.toString();
    _groupId = ticket['id']?.toString();
    setState(() {
      _qrToken = rawPath != null && rawPath.isNotEmpty && rawPath != 'null'
          ? _formatQrUrl(rawPath)
          : null;
      _errorMessage = _qrToken == null ? 'QR Code non disponible pour ce ticket' : null;
      _isLoading = false;
    });
  }

  Future<void> _generateGroupToken() async {
    try {
      final ticketIds = widget.selectedTickets
          .map<int>((ticket) => int.parse(ticket['id'].toString()))
          .toList();
      final response = await IgsHttpClient.post(
        Uri.parse('${ApiConfig.baseUrl}/tickets/group'),
        headers: await ApiHeaders.getHeaders(),
        body: json.encode({'ticket_ids': ticketIds}),
      );
      if (!mounted) return;
      if (response.statusCode == 200 || response.statusCode == 201) {
        final groupTicket = json.decode(response.body)['group_ticket'];
        final rawPath = groupTicket?['qr_code']?.toString();
        setState(() {
          _groupId = groupTicket?['id']?.toString();
          _qrToken = rawPath == null ? null : _formatQrUrl(rawPath);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = IgsAlerts.friendlyError(statusCode: response.statusCode);
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = IgsAlerts.friendlyError(error: error);
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _cancelGrouping() async {
    if (_groupId == null) return;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _buildConfirmationSheet(
        context: sheetContext,
        icon: Icons.link_off_rounded,
        title: 'Dégrouper les tickets ?',
        message: 'Les tickets redeviendront disponibles séparément avec leurs propres codes QR.',
        confirmLabel: 'Oui, dégrouper',
        confirmColor: Colors.redAccent,
        onConfirm: () => Navigator.pop(sheetContext, true),
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/tickets/group/$_groupId/cancel'),
        headers: await ApiHeaders.getHeaders(),
      );
      if (!mounted) return;
      if (response.statusCode == 200 || response.statusCode == 204) {
        Navigator.pop(context, true);
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = IgsAlerts.friendlyError(
            statusCode: response.statusCode,
            fallback: 'Le groupage n’a pas pu être annulé. Veuillez réessayer.',
          );
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = IgsAlerts.friendlyError(error: error);
        });
      }
    }
  }

  Widget _buildConfirmationSheet({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
    required VoidCallback onConfirm,
  }) {
    return Container(
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
                color: confirmColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: confirmColor, size: 34),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                color: const Color(0xFF26211E),
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
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
                onPressed: onConfirm,
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: Text(confirmLabel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: confirmColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  textStyle: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
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
    );
  }

  double get totalAmount => widget.selectedTickets.fold(
    0.0,
    (sum, item) => sum + double.parse(item['valeur'].toString()),
  );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.pop(context, true);
      },
      child: Scaffold(
        backgroundColor: lightGreyBg,
        appBar: AppBar(
          backgroundColor: igsBlue,
          title: Text('Paiement par Ticket', style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold)),
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: TabBar(
            controller: _tabController,
            labelColor: igsYellow,
            unselectedLabelColor: Colors.white70,
            indicatorColor: igsYellow,
            tabs: const [
              Tab(icon: Icon(Icons.qr_code_scanner_rounded), text: 'Code QR'),
              Tab(icon: Icon(Icons.receipt_long_rounded), text: 'Détails'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: igsBlue))
            : _errorMessage != null
            ? _buildErrorView()
            : TabBarView(controller: _tabController, children: [_buildQrView(), _buildDetailsView()]),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 50),
          const SizedBox(height: 10),
          Text(_errorMessage!, textAlign: TextAlign.center),
          TextButton(
            onPressed: () {
              setState(() => _isLoading = true);
              _generateGroupToken();
            },
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _buildQrView() {
    final idToExport = _groupId ?? widget.selectedTickets.first['id'].toString();
    final canCancel = _groupId != null &&
        (!widget.isExistingGroup || widget.selectedTickets.first['nature'] == 'GROUPE');
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 30,
            backgroundColor: Color(0xFFE3EDFF),
            child: Icon(Icons.sensors_rounded, color: igsBlue, size: 30),
          ),
          const SizedBox(height: 15),
          Text("Présentez ce code à l'agent SKY-P", style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 30),
          _buildTicketCard(),
          const SizedBox(height: 30),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => ExportService().downloadExport(context, '${ApiConfig.baseUrl}/tickets/$idToExport/export', 'Ticket_$idToExport'),
                        icon: const Icon(Icons.download_rounded, size: 20),
                        label: const Text('Télécharger'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          minimumSize: const Size(0, 52),
                          side: const BorderSide(color: Colors.redAccent),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => ExportService().shareExport(context, '${ApiConfig.baseUrl}/tickets/$idToExport/export?action=share', 'Ticket_$idToExport'),
                        icon: const Icon(Icons.share_outlined, size: 20),
                        label: const Text('Envoyer'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: igsBlue,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 52),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ),
                if (canCancel) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: _cancelGrouping,
                      icon: const Icon(Icons.link_off_rounded, size: 18),
                      label: const Text('Annuler le groupage'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent.shade200,
                        side: BorderSide(color: Colors.redAccent.shade100),
                        backgroundColor: Colors.redAccent.withOpacity(0.04),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 25),
          Text('${widget.selectedTickets.length} ticket(s) sécurisé(s)', style: GoogleFonts.montserrat(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildTicketCard() {
    return SizedBox(
      width: 300,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 30),
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            child: Center(
              child: _qrToken == null
                  ? const Icon(Icons.qr_code_2_rounded, size: 200, color: Colors.grey)
                  : Image.network(_qrToken!, width: 250, height: 250, fit: BoxFit.contain),
            ),
          ),
          Container(
            color: Colors.white,
            child: Row(
              children: [
                _buildNotch(isLeft: true),
                Expanded(child: CustomPaint(painter: DashedLinePainter(color: Colors.grey.shade300))),
                _buildNotch(isLeft: false),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 25),
            decoration: const BoxDecoration(color: igsBlue, borderRadius: BorderRadius.vertical(bottom: Radius.circular(20))),
            child: Column(
              children: [
                Text('MONTANT TOTAL', style: GoogleFonts.montserrat(color: igsYellow, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('${totalAmount.toStringAsFixed(0)} FCFA', style: GoogleFonts.montserrat(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotch({required bool isLeft}) {
    return Container(
      height: 20,
      width: 10,
      decoration: BoxDecoration(
        color: lightGreyBg,
        borderRadius: BorderRadius.only(
          topRight: isLeft ? const Radius.circular(10) : Radius.zero,
          bottomRight: isLeft ? const Radius.circular(10) : Radius.zero,
          topLeft: !isLeft ? const Radius.circular(10) : Radius.zero,
          bottomLeft: !isLeft ? const Radius.circular(10) : Radius.zero,
        ),
      ),
    );
  }

  Widget _buildDetailsView() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: widget.selectedTickets.length,
      itemBuilder: (context, index) {
        final ticket = widget.selectedTickets[index];
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            title: Text('Ticket ${ticket['nature']} #${ticket['id']}', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text('Expire le: ${ticket['expiry']}', style: GoogleFonts.montserrat(fontSize: 10, color: Colors.redAccent)),
            trailing: Text('${double.parse(ticket['valeur'].toString()).toStringAsFixed(0)} F', style: GoogleFonts.montserrat(color: igsBlue, fontWeight: FontWeight.bold)),
          ),
        );
      },
    );
  }
}

String _formatQrUrl(String rawPath) {
  if (rawPath.startsWith('http')) return rawPath;
  return '${ApiConfig.baseUrl1}/$rawPath';
}

class DashedLinePainter extends CustomPainter {
  final Color color;
  DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const dashWidth = 5.0;
    const dashSpace = 3.0;
    var startX = 0.0;
    final paint = Paint()..color = color;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant DashedLinePainter oldDelegate) => oldDelegate.color != color;
}
