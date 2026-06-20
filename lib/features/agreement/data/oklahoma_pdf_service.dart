import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:threshold/core/services/delivery_service.dart';
import 'package:threshold/features/agreement/data/agreement_model.dart';
import 'package:threshold/features/agreement/data/agreement_repository.dart';

class OklahomaPdfService {
  OklahomaPdfService(this._repo, this._delivery);
  final AgreementRepository _repo;
  final DeliveryService _delivery;

  static final _monthFmt = DateFormat('MMMM');
  static final _dayFmt = DateFormat('d');
  static final _yearFmt = DateFormat('yy');

  Future<String?> generate({
    required AgreementModel agreement,
    required Uint8List agentSignatureBytes,
    required Uint8List buyerSignatureBytes,
    Uint8List? buyer2SignatureBytes,
    bool autoEmail = true,
  }) async {
    final assetData = await rootBundle.load(
      'assets/forms/oklahoma_buyer_broker.pdf',
    );
    final pdfBytes = assetData.buffer.asUint8List();

    final doc = PdfDocument(inputBytes: pdfBytes);
    final form = doc.form;

    final fd = agreement.formData;
    final now = DateTime.now();
    final start = agreement.startDate;
    final end = agreement.endDate;

    final buyer1Name = fd['buyer1Name'] as String? ?? agreement.buyerName;
    final buyer1Email = fd['buyerEmail'] as String? ?? agreement.buyerEmail;
    final buyer1Cell = fd['buyerCellPhone'] as String? ?? '';
    final buyer1Work = fd['buyerWorkPhone'] as String? ?? '';
    final hasCoBuyer = (fd['buyer2Name'] as String? ?? '').isNotEmpty;
    final buyer2Name = fd['buyer2Name'] as String? ?? '';
    final buyer2Email = fd['buyer2Email'] as String? ?? '';
    final buyer2Cell = fd['buyer2CellPhone'] as String? ?? '';
    final buyer2Work = fd['buyer2WorkPhone'] as String? ?? '';

    final compType = fd['compensationType'] as String? ?? 'percentage';
    final compValue = fd['compensationValue'] as String? ?? '';
    final retainer = fd['retainerFee'] as String? ?? '';
    final otherComp = fd['otherCompensation'] as String? ?? '';
    final postTermDays = fd['postTerminationDays'] as String? ?? '60';
    final postExpDays = fd['postExpirationDays'] as String? ?? '60';

    final agentLicenseNumber = fd['agentLicenseNumber'] as String? ?? '';
    final brokerageLicenseNumber = fd['brokerageLicenseNumber'] as String? ?? '';
    final managingBrokerName = fd['managingBrokerName'] as String? ?? '';
    final managingBrokerPhone = fd['managingBrokerPhone'] as String? ?? '';
    final managingBrokerEmail = fd['managingBrokerEmail'] as String? ?? '';
    final additionalProvisions = fd['additionalProvisions'] as String? ?? '';
    final agentPhone = fd['agentPhone'] as String? ?? '';
    final brokerageAddress = fd['brokerageAddress'] as String? ?? '';

    // ── Section 5 – Duration (page 1) ────────────────────────────────────────
    // Date(day/month/year) is a shared field reused on pages 1, 3, and 4 for
    // the agreement entry date, buyer/broker execution dates, and disclosure
    // receipt date. All show the same value — use the agreement start date.
    _setText(form, 'Date(day)', _dayFmt.format(start));
    _setText(form, 'Date(month)', _monthFmt.format(start));
    _setText(form, 'Date(Last two digits year)', _yearFmt.format(start));
    _setText(form, 'Expiration Day', _dayFmt.format(end));
    _setText(form, 'Expiration Month', _monthFmt.format(end));
    _setText(form, 'Expiration last two digits of year', _yearFmt.format(end));

    // ── Section 6 – Termination tail ─────────────────────────────────────────
    _setText(
      form,
      'days after expiration termination',
      postTermDays.isEmpty ? '60' : postTermDays,
    );

    // ── Section 7 – Compensation ─────────────────────────────────────────────
    final isTypeA = compType == 'percentage' || compType == 'dollar';
    final isTypeB = retainer.isNotEmpty;
    final isTypeC = compType == 'other';

    _setCheckbox(form, 'Compensation checkbox', isTypeA);
    if (compType == 'dollar') _setText(form, 'compensation amount', compValue);
    if (compType == 'percentage') {
      _setText(form, 'compensation percentage', compValue);
    }

    _setCheckbox(form, 'checkbox_28kprp', isTypeB);
    if (isTypeB) _setText(form, 'retainer fee amount', retainer);

    _setCheckbox(form, 'compensation other checkbox', isTypeC);
    if (isTypeC) _setText(form, 'other compensation', otherComp);

    _setText(
      form,
      'compensation execution days',
      postExpDays.isEmpty ? '60' : postExpDays,
    );

    // ── Section 15 – Additional provisions (page 3) ───────────────────────────
    final provLines = _lines(additionalProvisions, 4);
    _setText(form, 'additional provisions line 1', provLines[0]);
    _setText(form, 'additional provisions line 2', provLines[1]);
    _setText(form, 'additional provisions line 3', provLines[2]);
    _setText(form, 'additional provisions line 4', provLines[3]);

    // ── Buyer 1 (page 3) ─────────────────────────────────────────────────────
    _setText(form, 'buyer 1 name', buyer1Name);
    _setText(form, 'buyer 1 email', buyer1Email);
    _setText(form, 'buyer 1 cell phone', buyer1Cell);
    _setText(form, 'buyer 1 work phone', buyer1Work);
    _setText(form, 'buyer 1 initials', _initials(buyer1Name));

    // ── Buyer 2 (page 3) ─────────────────────────────────────────────────────
    if (hasCoBuyer) {
      _setText(form, 'buyer 2 name', buyer2Name);
      _setText(form, 'buyer 2 email', buyer2Email);
      _setText(form, 'buyer 2 cell phone', buyer2Cell);
      _setText(form, 'buyer 2 work phone', buyer2Work);
      _setText(form, 'buyer 2 initials', _initials(buyer2Name));
    }

    // ── Agent / broker info (page 3) ─────────────────────────────────────────
    _setText(form, 'agent name', agreement.agentName);
    _setText(form, 'agent cell phone', agentPhone);
    _setText(form, 'agent email address', agreement.agentEmail);
    _setText(form, 'agent license number', agentLicenseNumber);
    _setText(form, 'brokerage name', agreement.brokerageName);
    _setText(form, 'brokerage license number', brokerageLicenseNumber);
    _setText(form, 'brokerage office address', brokerageAddress);
    _setText(form, 'name of managing broker', managingBrokerName);
    _setText(form, 'managing broker office number', managingBrokerPhone);
    _setText(form, 'managing broker email', managingBrokerEmail);

    // ── Disclosure page (page 4) ──────────────────────────────────────────────
    _setCheckbox(form, 'buyer broker attach check', true);

    // ── Signatures (drawn on page 3, index 2) ────────────────────────────────
    // buyer 1 / 2 signature fields also have a widget on page 4, but drawing
    // on page 3 covers the primary execution block.
    _drawSignature(doc, form, 'buyer 1 signature', buyerSignatureBytes);
    _drawSignature(doc, form, 'agent signature', agentSignatureBytes);
    if (hasCoBuyer && buyer2SignatureBytes != null) {
      _drawSignature(doc, form, 'buyer 2 signature', buyer2SignatureBytes);
    }

    // ── Flatten all fields ────────────────────────────────────────────────────
    for (int i = 0; i < form.fields.count; i++) {
      form.fields[i].flatten();
    }

    final savedBytes = await doc.save();
    doc.dispose();

    final dir = await getApplicationDocumentsDirectory();
    final safeName = agreement.buyerName.replaceAll(RegExp('[^a-zA-Z0-9]'), '_');
    final filename = 'OK_BBSA_${safeName}_${agreement.id.substring(0, 8)}.pdf';
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(savedBytes);
    final localPath = file.path;

    if (autoEmail) {
      final signed = agreement.copyWith(
        status: AgreementStatus.pendingDelivery,
        localPdfPath: localPath,
        signedAt: now,
      );
      await _repo.save(signed);
      await _delivery.deliver(signed);
    } else {
      final signed = agreement.copyWith(
        status: AgreementStatus.delivered,
        localPdfPath: localPath,
        signedAt: now,
        deliveredAt: now,
      );
      await _repo.save(signed);
      await Printing.sharePdf(
        bytes: Uint8List.fromList(savedBytes),
        filename: filename,
      );
    }

    return localPath;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  List<String> _lines(String text, int count) {
    final parts = text.split('\n');
    return List.generate(
      count,
      (i) => i < parts.length ? parts[i].trim() : '',
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  PdfField? _find(PdfForm form, String name) {
    for (int i = 0; i < form.fields.count; i++) {
      if (form.fields[i].name == name) return form.fields[i];
    }
    return null;
  }

  void _setText(PdfForm form, String name, String value) {
    try {
      final f = _find(form, name);
      if (f is PdfTextBoxField) f.text = value;
    } catch (_) {}
  }

  void _setCheckbox(PdfForm form, String name, bool checked) {
    try {
      final f = _find(form, name);
      if (f is PdfCheckBoxField) f.isChecked = checked;
    } catch (_) {}
  }

  void _drawSignature(
    PdfDocument doc,
    PdfForm form,
    String name,
    Uint8List imageBytes,
  ) {
    try {
      final f = _find(form, name);
      if (f == null) return;
      final bounds = f.bounds;
      final image = PdfBitmap(imageBytes);
      final page = doc.pages[2]; // signatures are on page 3 (0-indexed)
      page.graphics.drawImage(
        image,
        Rect.fromLTWH(bounds.left, bounds.top, bounds.width, bounds.height),
      );
    } catch (_) {}
  }
}

final oklahomaPdfServiceProvider = Provider<OklahomaPdfService>(
  (ref) => OklahomaPdfService(
    ref.read(agreementRepositoryProvider),
    ref.read(deliveryServiceProvider),
  ),
);
