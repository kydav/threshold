import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'agreement_model.dart';
import 'agreement_repository.dart';
import 'colorado_form_data.dart';
import '../../../core/services/delivery_service.dart';

class ColoradoPdfService {
  ColoradoPdfService(this._repo, this._delivery);
  final AgreementRepository _repo;
  final DeliveryService _delivery;

  static final _dateFmt = DateFormat('MM/dd/yyyy');

  Future<String?> generate({
    required AgreementModel agreement,
    required Uint8List agentSignatureBytes,
    required Uint8List buyerSignatureBytes,
  }) async {
    final assetData =
        await rootBundle.load('assets/forms/colorado_bc60.pdf');
    final pdfBytes = assetData.buffer.asUint8List();

    final doc = PdfDocument(inputBytes: pdfBytes);
    final form = doc.form;

    final co = ColoradoFormData.fromJson(agreement.formData);
    final now = DateTime.now();

    // ── Parties ──────────────────────────────────────────────────────────────
    _setText(form, 'Document Date', _dateFmt.format(now));
    _setText(form, 'Buyer/Buyers Name', agreement.buyerName);
    _setText(form, 'Buyers Email Address', agreement.buyerEmail);
    _setText(form, 'Buyers Email Address_2', agreement.buyerEmail);
    _setText(form, 'Buyers Phone No', co.buyerPhone);
    _setText(form, 'Buyers Phone No_2', co.buyerPhone);
    _setText(form, 'Buyers Street Address', co.buyerStreetAddress);
    _setText(form, 'Buyers Street Address_2', co.buyerStreetAddress);
    _setText(form, 'Buyers City State Zip', co.buyerCityStateZip);
    _setText(form, 'Buyers City State Zip_2', co.buyerCityStateZip);

    _setText(form, 'Brokerage Firm Name', agreement.brokerageName);
    _setText(form, 'Broker Name', agreement.agentName);
    _setText(form, 'Broker Email Address', agreement.agentEmail);
    _setText(form, 'Electronic Notice Email address', agreement.agentEmail);

    // ── Section 2 — Firm type ─────────────────────────────────────────────
    _setCheckbox(form, 'Section 2.1 Checkbox', true);
    _setCheckbox(form, 'Section 2.2 Checkbox', false);

    // ── Section 3 — Listing period ────────────────────────────────────────
    _setText(form, 'Listing Period Beginning Date',
        _dateFmt.format(agreement.startDate));
    _setText(form, 'Alternative Listing Period End Date',
        _dateFmt.format(agreement.endDate));
    _setText(form, 'Holdover Number of Days', co.holdoverDays);
    _setCheckbox(form, 'Computation of Date Will', co.computationWillExtend);
    _setCheckbox(form, 'Computation of Date Will Not', !co.computationWillExtend);
    _setCheckbox(form, 'Section 3.5.2 Checkbox', false);

    // ── Section 4 — Brokerage relationship ───────────────────────────────
    _setCheckbox(form, 'Buyer Agency Checkbox', co.isBuyerAgency);
    _setCheckbox(form, 'Transaction-Brokerage Checkbox', !co.isBuyerAgency);
    _setCheckbox(form, 'Section 4.3.1.2 Checkbox', false);

    // ── Section 7 — Compensation ──────────────────────────────────────────
    if (co.compensationType == 'percentage') {
      _setText(form, 'Success Fee Percentage', co.compensationValue);
    } else {
      _setText(form, 'Success Fee Dollars', co.compensationValue);
    }
    _setCheckbox(form, 'Section 7.1.1 Checkbox', true);
    _setCheckbox(form, 'Section 7.1.2 Will Checkbox', false);
    _setCheckbox(form, 'Section 7.1.3 Will Checkbox', false);
    _setCheckbox(form, 'Section 7.1.3 Will Not Check', true);
    _setCheckbox(form, 'Section 7.1.4 Will Checkbox', false);
    _setCheckbox(form, 'Section 7.2.4 Will Checkbox', false);
    _setCheckbox(form, 'Section 7.2.4 Will Not Checkbox', true);
    _setCheckbox(form, 'Section 7.3.1 Checkbox', false);
    _setCheckbox(form, 'Section 7.3.2 Checkbox', false);
    _setCheckbox(form, 'Section 7.4 Will Checkbox', false);
    _setCheckbox(form, 'Section 7.4 Will Not Checkbox', true);

    // ── Section 9 — Buyer obligations ────────────────────────────────────
    _setCheckbox(form, 'Section 9 Is Checkbox', co.buyerIsPartyToOtherAgreement);
    _setCheckbox(form, 'Section 9 Is Not Checkbox', !co.buyerIsPartyToOtherAgreement);
    _setCheckbox(form, 'Section 9 Has Checkbox', co.buyerHasReceivedSubmittedList);
    _setCheckbox(form, 'Section 9 Has Not Checkbox', !co.buyerHasReceivedSubmittedList);

    // ── Section 13 ────────────────────────────────────────────────────────
    _setCheckbox(form, 'Section 13 Does Checkbox', false);
    _setCheckbox(form, 'Section 13 Does Not Checkbox', true);

    // ── Signature date fields ─────────────────────────────────────────────
    final dateStr = _dateFmt.format(now);
    _setText(form, 'Date_2', dateStr);
    _setText(form, 'Date_3', dateStr);
    _setText(form, 'Date_4', dateStr);

    // ── Draw signatures at field bounds ───────────────────────────────────
    _drawSignature(doc, form, 'Buyers Signature', buyerSignatureBytes);
    _drawSignature(doc, form, 'Brokers Signature', agentSignatureBytes);

    // ── Flatten all fields so values are baked in and uneditable ─────────
    for (int i = 0; i < form.fields.count; i++) {
      form.fields[i].flatten();
    }

    final savedBytes = await doc.save();
    doc.dispose();

    // Save to device.
    final dir = await getApplicationDocumentsDirectory();
    final safeName =
        agreement.buyerName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final filename =
        'CO_BC60_${safeName}_${agreement.id.substring(0, 8)}.pdf';
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(savedBytes);
    final localPath = file.path;

    final signed = agreement.copyWith(
      status: AgreementStatus.pendingDelivery,
      localPdfPath: localPath,
      signedAt: now,
    );
    await _repo.save(signed);
    await _delivery.deliver(signed);

    return localPath;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Find a field by name, since PdfFormFieldCollection only supports int index.
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

      // Signatures are on page 6 (last page) of the Colorado BC60 form.
      final page = doc.pages[doc.pages.count - 1];

      page.graphics.drawImage(
        image,
        Rect.fromLTWH(bounds.left, bounds.top, bounds.width, bounds.height),
      );
    } catch (_) {}
  }
}

final coloradoPdfServiceProvider = Provider<ColoradoPdfService>((ref) =>
    ColoradoPdfService(
      ref.read(agreementRepositoryProvider),
      ref.read(deliveryServiceProvider),
    ));
