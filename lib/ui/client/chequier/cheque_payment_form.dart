import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sky_p/core/theme/ui_helpers.dart';

class ChequePaymentForm extends StatefulWidget {
  final int totalAmount;
  final ValueChanged<ChequePaymentData> onValidated;

  const ChequePaymentForm({
    super.key,
    required this.totalAmount,
    required this.onValidated,
  });

  @override
  State<ChequePaymentForm> createState() => _ChequePaymentFormState();
}

class ChequePaymentData {
  final String paymentMethod; // "cheque" or "bank_transfer"
  final String? chequeNumber; // numero du cheque
  final String? transferReference; // reference du virement
  final String bankName; // la banque / banque emettrice
  final String amount; // montant
  final File? proofImage; // la photo du cheque ou virement

  const ChequePaymentData({
    required this.paymentMethod,
    this.chequeNumber,
    this.transferReference,
    required this.bankName,
    required this.amount,
    this.proofImage,
  });
}

class _ChequePaymentFormState extends State<ChequePaymentForm> {
  static const Color igsBlue = Color(0xFF3473E4);

  // Method Selection
  bool _isCheque = true;

  // Cheque Form Controllers
  final _chequeNumberController = TextEditingController();
  final _chequeAmountController = TextEditingController();
  final _chequeBankController = TextEditingController();
  File? _chequeImage;

  // Virement Form Controllers
  final _virementRefController = TextEditingController();
  final _virementAmountController = TextEditingController();
  final _virementBankController = TextEditingController();
  File? _virementImage;

  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _chequeAmountController.text = widget.totalAmount.toString();
    _virementAmountController.text = widget.totalAmount.toString();
  }

  @override
  void dispose() {
    _chequeNumberController.dispose();
    _chequeAmountController.dispose();
    _chequeBankController.dispose();
    _virementRefController.dispose();
    _virementAmountController.dispose();
    _virementBankController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(bool isCheque) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        setState(() {
          if (isCheque) {
            _chequeImage = File(pickedFile.path);
          } else {
            _virementImage = File(pickedFile.path);
          }
        });
      }
    } catch (_) {
      if (mounted) {
        IgsAlerts.showError('Impossible d’ouvrir l’appareil photo.');
      }
    }
  }

  void _submit() {
    if (_isCheque) {
      final chequeNumber = _chequeNumberController.text.trim();
      final amount = _chequeAmountController.text.trim();
      final bank = _chequeBankController.text.trim();

      if (chequeNumber.isEmpty || amount.isEmpty || bank.isEmpty || _chequeImage == null) {
        IgsAlerts.showError('Tous les champs du formulaire Chèque sont obligatoires (y compris la photo).');
        return;
      }

      widget.onValidated(
        ChequePaymentData(
          paymentMethod: 'cheque',
          chequeNumber: chequeNumber,
          bankName: bank,
          amount: amount,
          proofImage: _chequeImage,
        ),
      );
    } else {
      final reference = _virementRefController.text.trim();
      final amount = _virementAmountController.text.trim();
      final bank = _virementBankController.text.trim();

      if (reference.isEmpty || amount.isEmpty || bank.isEmpty || _virementImage == null) {
        IgsAlerts.showError('Tous les champs du formulaire Virement sont obligatoires (y compris le reçu).');
        return;
      }

      widget.onValidated(
        ChequePaymentData(
          paymentMethod: 'bank_transfer',
          transferReference: reference,
          bankName: bank,
          amount: amount,
          proofImage: _virementImage,
        ),
      );
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    IgsAlerts.showSuccess('$label copié dans le presse-papiers.');
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMethodSwitch(),
          const SizedBox(height: 20),

          _buildAmountHeader(),
          const SizedBox(height: 20),

          AnimatedCrossFade(
            firstChild: _buildChequeForm(),
            secondChild: _buildVirementForm(),
            crossFadeState: _isCheque ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 300),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: igsBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 3,
                shadowColor: igsBlue.withValues(alpha: 0.3),
              ),
              child: Text(
                'VALIDER LE PAIEMENT',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  letterSpacing: 1.1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodSwitch() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isCheque = true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _isCheque ? igsBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: _isCheque
                      ? [
                          BoxShadow(
                            color: igsBlue.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ]
                      : [],
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.description_outlined,
                      color: _isCheque ? Colors.white : Colors.grey.shade600,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'CHÈQUE',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w700,
                        color: _isCheque ? Colors.white : Colors.grey.shade600,
                        fontSize: 13,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isCheque = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !_isCheque ? igsBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: !_isCheque
                      ? [
                          BoxShadow(
                            color: igsBlue.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ]
                      : [],
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.account_balance_outlined,
                      color: !_isCheque ? Colors.white : Colors.grey.shade600,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'VIREMENT',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w700,
                        color: !_isCheque ? Colors.white : Colors.grey.shade600,
                        fontSize: 13,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF26211E), Color(0xFF3D3531)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MONTANT À RÉGLER',
            style: GoogleFonts.montserrat(
              color: igsBlue,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${widget.totalAmount.toString()} FCFA',
            style: GoogleFonts.montserrat(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Divider(color: Colors.white.withValues(alpha: 0.15)),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                _isCheque ? Icons.info_outline : Icons.shield_outlined,
                color: Colors.white70,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _isCheque
                      ? 'Remplissez les détails du chèque physique reçu.'
                      : 'Effectuez le virement bancaire puis renseignez les informations.',
                  style: GoogleFonts.montserrat(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChequeForm() {
    return Column(
      key: const ValueKey('chequeForm'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildField(
          controller: _chequeNumberController,
          label: 'Numéro du chèque',
          hint: 'Ex: 123456789',
          icon: Icons.confirmation_num_outlined,
        ),
        const SizedBox(height: 16),
        _buildField(
          controller: _chequeAmountController,
          label: 'Montant du chèque (FCFA)',
          hint: 'Ex: 1100000',
          icon: Icons.attach_money_rounded,
          keyboardType: TextInputType.number,
          readOnly: true,
        ),
        const SizedBox(height: 16),
        _buildField(
          controller: _chequeBankController,
          label: 'Banque émettrice',
          hint: 'Ex: Ecobank, BOA, SG...',
          icon: Icons.account_balance_rounded,
        ),
        const SizedBox(height: 20),
        Text(
          'Photo du chèque',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF26211E),
          ),
        ),
        const SizedBox(height: 8),
        _buildPhotoSelector(isCheque: true, imageFile: _chequeImage),
      ],
    );
  }

  Widget _buildVirementForm() {
    return Column(
      key: const ValueKey('virementForm'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAtmBankDetails(),
        const SizedBox(height: 20),

        _buildField(
          controller: _virementRefController,
          label: 'Référence du virement',
          hint: 'Ex: TXN987654321',
          icon: Icons.tag_rounded,
        ),
        const SizedBox(height: 16),
        _buildField(
          controller: _virementAmountController,
          label: 'Montant transféré (FCFA)',
          hint: 'Ex: 1100000',
          icon: Icons.attach_money_rounded,
          keyboardType: TextInputType.number,
          readOnly: true,
        ),
        const SizedBox(height: 16),
        _buildField(
          controller: _virementBankController,
          label: 'Votre banque émettrice',
          hint: 'Ex: UBA, Ecobank, Coris...',
          icon: Icons.account_balance_outlined,
        ),
        const SizedBox(height: 20),
        Text(
          'Reçu ou Preuve de virement',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF26211E),
          ),
        ),
        const SizedBox(height: 8),
        _buildPhotoSelector(isCheque: false, imageFile: _virementImage),
      ],
    );
  }

  Widget _buildAtmBankDetails() {
    const String ribText = 'BJ062 01001 123456789012 34';
    const String codeBank = 'BJ062';
    const String accNum = '123456789012';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_rounded, color: igsBlue, size: 20),
              const SizedBox(width: 8),
              Text(
                'RIB / Comptes SKY-P',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: const Color(0xFF26211E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildCopyRow(label: 'Titulaire', value: 'SKY-P SARL'),
          _buildCopyRow(label: 'Banque', value: 'ECOBANK BÉNIN'),
          _buildCopyRow(label: 'N° de Compte', value: accNum, copyValue: accNum),
          _buildCopyRow(label: 'Code Banque', value: codeBank, copyValue: codeBank),
          _buildCopyRow(label: 'Clé RIB', value: '34', copyValue: '34'),
          Divider(color: Colors.grey.shade200, height: 20),
          _buildCopyRow(
            label: 'RIB Complet',
            value: ribText,
            copyValue: ribText,
            isLongValue: true,
          ),
        ],
      ),
    );
  }

  Widget _buildCopyRow({
    required String label,
    required String value,
    String? copyValue,
    bool isLongValue = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: isLongValue ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: GoogleFonts.montserrat(
                color: Colors.grey.shade500,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.montserrat(
                color: const Color(0xFF26211E),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (copyValue != null)
            GestureDetector(
              onTap: () => _copyToClipboard(copyValue, label),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: igsBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.copy_rounded,
                  color: igsBlue,
                  size: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPhotoSelector({required bool isCheque, File? imageFile}) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _pickPhoto(isCheque),
            icon: const Icon(Icons.camera_alt_outlined, color: igsBlue),
            label: Text(
              isCheque ? 'Prendre une photo du chèque' : 'Prendre une photo de la preuve',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF26211E),
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: igsBlue, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        if (imageFile != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    imageFile,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isCheque ? 'Photo du chèque ajoutée' : 'Photo de la preuve ajoutée',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF26211E),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF26211E),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          readOnly: readOnly,
          style: GoogleFonts.montserrat(color: const Color(0xFF26211E)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.montserrat(color: Colors.grey[500]),
            prefixIcon: Icon(icon, color: igsBlue),
            filled: true,
            fillColor: readOnly ? Colors.grey.shade100 : Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: igsBlue, width: 1.8),
            ),
          ),
        ),
      ],
    );
  }
}
