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

class LouisianaPdfService {
  LouisianaPdfService(this._repo, this._delivery);
  final AgreementRepository _repo;
  final DeliveryService _delivery;

  static final _monthFmt = DateFormat('MMMM');
  static final _dayFmt = DateFormat('d');
  static final _yearFmt = DateFormat('yyyy');
  static final _dateFmt = DateFormat('MM/dd/yyyy');

  Future<String?> generate({
    required AgreementModel agreement,
    required Uint8List agentSignatureBytes,
    required Uint8List buyerSignatureBytes,
    Uint8List? buyer2SignatureBytes,
    bool autoEmail = true,
  }) async {
    final assetData = await rootBundle.load(
      'assets/forms/louisiana_buyer_rep.pdf',
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
    final buyer1Phone = fd['buyerPhone'] as String? ?? '';
    final hasCoBuyer = (fd['buyer2Name'] as String? ?? '').isNotEmpty;
    final buyer2Name = fd['buyer2Name'] as String? ?? '';
    final buyer2Email = fd['buyer2Email'] as String? ?? '';
    final buyer2Phone = fd['buyer2Phone'] as String? ?? '';

    final compType = fd['compensationType'] as String? ?? 'percentage';
    final compValue = fd['compensationValue'] as String? ?? '';
    final otherComp = fd['otherCompensation'] as String? ?? '';
    final postTermDays = fd['postTerminationDays'] as String? ?? '';

    final agentPhone = fd['agentPhone'] as String? ?? '';

    // ── Page 1 — Parties ──────────────────────────────────────────────────────
    // Buyer Name and Broker Name are shared fields (appear on both pages).
    _setText(form, 'Buyer Name', buyer1Name);
    _setText(form, 'Broker Name', agreement.brokerageName);
    _setText(form, 'Designated Agent', agreement.agentName);

    // ── Page 1 — Compensation ─────────────────────────────────────────────────
    if (compType == 'percentage') {
      _setText(form, 'Percentage of Gross Purchase Price', compValue);
    } else if (compType == 'flat') {
      _setText(form, 'Flat Fee 1', compValue);
    } else {
      // Split other across the two continuation lines.
      final lines = _lines(otherComp, 2);
      _setText(form, 'Other', lines[0]);
      _setText(form, 'Other Cont', lines[1]);
    }

    // ── Page 1 — Post-termination protection ─────────────────────────────────
    _setText(
      form,
      'Number of Calendar Days',
      postTermDays.isEmpty ? '180' : postTermDays,
    );

    // ── Page 1 — Term ─────────────────────────────────────────────────────────
    _setText(form, 'Begin Month', _monthFmt.format(start));
    _setText(form, 'Begin Date', _dayFmt.format(start));
    _setText(form, 'Begin Year', _yearFmt.format(start));
    _setText(form, 'End Month', _monthFmt.format(end));
    _setText(form, 'End Date', _dayFmt.format(end));
    _setText(form, 'End Year', _yearFmt.format(end));

    // ── Page 2 — Buyer 1 ─────────────────────────────────────────────────────
    // Buyer Name is shared; already set above.
    _setText(form, 'Buyer Telephone', buyer1Phone);
    _setText(form, 'Buyer Email Address', buyer1Email);
    _setText(form, 'Date', _dateFmt.format(now));

    // ── Page 2 — Buyer 2 ─────────────────────────────────────────────────────
    if (hasCoBuyer) {
      _setText(form, 'Buyer Name_2', buyer2Name);
      _setText(form, 'Buyer Telephone_2', buyer2Phone);
      _setText(form, 'Buyer Email Address_2', buyer2Email);
      _setText(form, 'Date_2', _dateFmt.format(now));
    }

    // ── Page 2 — Broker / agent ───────────────────────────────────────────────
    // Broker Name is shared; already set above.
    _setText(form, 'Broker Telephone_3', agentPhone);
    _setText(form, 'Broker Email Address_3', agreement.agentEmail);
    _setText(form, 'Date_3', _dateFmt.format(now));

    // ── Signatures (drawn on page 2, index 1) ─────────────────────────────────
    _drawSignature(doc, form, 'Buyer Signature', buyerSignatureBytes);
    _drawSignature(doc, form, 'Broker Signature', agentSignatureBytes);
    if (hasCoBuyer && buyer2SignatureBytes != null) {
      _drawSignature(doc, form, 'Buyer Signature_2', buyer2SignatureBytes);
    }

    // ── Flatten all fields ────────────────────────────────────────────────────
    for (int i = 0; i < form.fields.count; i++) {
      form.fields[i].flatten();
    }

    final savedBytes = await doc.save();
    doc.dispose();

    final dir = await getApplicationDocumentsDirectory();
    final safeName = agreement.buyerName.replaceAll(RegExp('[^a-zA-Z0-9]'), '_');
    final filename = 'LA_BRA_${safeName}_${agreement.id.substring(0, 8)}.pdf';
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
      final page = doc.pages[1]; // signatures are on page 2 (0-indexed)
      page.graphics.drawImage(
        image,
        Rect.fromLTWH(bounds.left, bounds.top, bounds.width, bounds.height),
      );
    } catch (_) {}
  }
}

final louisianaPdfServiceProvider = Provider<LouisianaPdfService>(
  (ref) => LouisianaPdfService(
    ref.read(agreementRepositoryProvider),
    ref.read(deliveryServiceProvider),
  ),
);
