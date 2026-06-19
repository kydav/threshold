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

class WisconsinPdfService {
  WisconsinPdfService(this._repo, this._delivery);
  final AgreementRepository _repo;
  final DeliveryService _delivery;

  static final _dateFmt = DateFormat('MM/dd/yyyy');

  Future<String?> generate({
    required AgreementModel agreement,
    required Uint8List agentSignatureBytes,
    required Uint8List buyerSignatureBytes,
    Uint8List? buyer2SignatureBytes,
    bool autoEmail = true,
  }) async {
    final assetData = await rootBundle.load('assets/forms/wisconsin_wb36.pdf');
    final pdfBytes = assetData.buffer.asUint8List();

    final doc = PdfDocument(inputBytes: pdfBytes);
    final form = doc.form;

    final fd = agreement.formData;
    final now = DateTime.now();

    // ── Buyer info ────────────────────────────────────────────────────────────
    _setText(form, 'buyer_address', fd['buyer_address'] as String? ?? '');
    _setText(form, 'buyer_email', fd['buyer_email'] as String? ?? agreement.buyerEmail);

    // Communication preferences
    final commEmail = (fd['comm_email'] as bool?) ?? true;
    final commMail = (fd['comm_mail'] as bool?) ?? false;
    _setCheckbox(form, 'email', commEmail);
    _setCheckbox(form, 'mail', commMail);

    // ── Co-buyer ──────────────────────────────────────────────────────────────
    final hasCoBuyer = (fd['has_co_buyer'] as bool?) ?? false;
    final buyer2Name = fd['buyer_name_2'] as String? ?? '';
    _setText(form, 'buyer_name_1', agreement.buyerName);
    if (hasCoBuyer && buyer2Name.isNotEmpty) {
      _setText(form, 'buyer_name_2', buyer2Name);
    }

    // ── Term dates ────────────────────────────────────────────────────────────
    final termStartRaw = fd['term_start'] as String?;
    final termEndRaw = fd['term_end'] as String?;

    if (termStartRaw != null) {
      final start = DateTime.tryParse(termStartRaw);
      if (start != null) {
        _setText(form, 'term_start_day', start.day.toString().padLeft(2, '0'));
        _setText(form, 'term_start_month', start.month.toString().padLeft(2, '0'));
        _setText(form, 'term_start_year', start.year.toString());
      }
    }

    if (termEndRaw != null) {
      final end = DateTime.tryParse(termEndRaw);
      if (end != null) {
        _setText(form, 'term_end_day', end.day.toString().padLeft(2, '0'));
        _setText(form, 'term_end_month', end.month.toString().padLeft(2, '0'));
        _setText(form, 'term_end_year', end.year.toString());
      }
    }

    // ── Compensation ──────────────────────────────────────────────────────────
    _setText(form, 'commission', fd['commission'] as String? ?? '');
    _setText(form, 'commission_line_2', fd['commission_2'] as String? ?? '');
    _setText(form, 'commissions_line_3', fd['commission_3'] as String? ?? '');
    _setText(form, 'other_compensation', fd['other_compensation'] as String? ?? '');
    _setText(form, 'other_compensation_line_2', fd['other_compensation_2'] as String? ?? '');
    _setText(form, 'purchase_price_range', fd['purchase_price_range'] as String? ?? '');

    // ── Excluded properties ───────────────────────────────────────────────────
    _setText(form, 'excluded_properties', fd['excluded_properties'] as String? ?? '');
    _setText(form, 'excluded_properties_line_2', fd['excluded_properties_2'] as String? ?? '');
    _setText(form, 'excluded_properties_prior', fd['excluded_properties_prior'] as String? ?? '');
    _setText(form, 'excluded_properties_prior_line_2', fd['excluded_properties_prior_2'] as String? ?? '');
    _setText(form, 'exclusion_date', fd['exclusion_date'] as String? ?? '');

    // ── Confidential / non-confidential ───────────────────────────────────────
    _setText(form, 'confidential_info', fd['confidential_info'] as String? ?? '');
    _setText(form, 'confidential_info_2', fd['confidential_info_2'] as String? ?? '');
    _setText(form, 'confidential_info_3', fd['confidential_info_3'] as String? ?? '');
    _setText(form, 'non_confidential', fd['non_confidential'] as String? ?? '');
    _setText(form, 'non_confidential_2', fd['non_confidential_2'] as String? ?? '');
    _setText(form, 'non_confidential_3', fd['non_confidential_3'] as String? ?? '');

    // ── Additional provisions ─────────────────────────────────────────────────
    _setText(form, 'additional_provisions', fd['additional_provisions'] as String? ?? '');
    _setText(form, 'additional_provisions_2', fd['additional_provisions_2'] as String? ?? '');

    // ── Firm info ─────────────────────────────────────────────────────────────
    _setText(form, 'agent_firm_name', agreement.brokerageName);
    _setText(form, 'agent_name', agreement.agentName);
    _setText(form, 'firm_address', '');

    // ── Signing date ──────────────────────────────────────────────────────────
    _setText(form, 'date', _dateFmt.format(now));

    // ── Signatures ────────────────────────────────────────────────────────────
    _drawSignature(doc, form, 'buyer_sig_1', buyerSignatureBytes);
    _drawSignature(doc, form, 'agent_sig', agentSignatureBytes);
    if (hasCoBuyer && buyer2SignatureBytes != null) {
      _drawSignature(doc, form, 'buyer_sig_2', buyer2SignatureBytes);
    }

    // ── Flatten all fields ────────────────────────────────────────────────────
    for (int i = 0; i < form.fields.count; i++) {
      form.fields[i].flatten();
    }

    final savedBytes = await doc.save();
    doc.dispose();

    // Save to device.
    final dir = await getApplicationDocumentsDirectory();
    final safeName = agreement.buyerName.replaceAll(RegExp('[^a-zA-Z0-9]'), '_');
    final filename = 'WI_WB36_${safeName}_${agreement.id.substring(0, 8)}.pdf';
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
      await Printing.sharePdf(bytes: Uint8List.fromList(savedBytes), filename: filename);
    }

    return localPath;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

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

  void _drawSignature(PdfDocument doc, PdfForm form, String name, Uint8List imageBytes) {
    try {
      final f = _find(form, name);
      if (f == null) return;

      final bounds = f.bounds;
      final image = PdfBitmap(imageBytes);

      // Signatures are on the last page of the Wisconsin WB-36 form.
      final page = doc.pages[doc.pages.count - 1];

      page.graphics.drawImage(
        image,
        Rect.fromLTWH(bounds.left, bounds.top, bounds.width, bounds.height),
      );
    } catch (_) {}
  }
}

final wisconsinPdfServiceProvider = Provider<WisconsinPdfService>(
  (ref) => WisconsinPdfService(
    ref.read(agreementRepositoryProvider),
    ref.read(deliveryServiceProvider),
  ),
);
