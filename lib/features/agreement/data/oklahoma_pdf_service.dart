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

    final agentLicense = fd['agentLicenseNumber'] as String? ?? '';
    final brokerageLicense = fd['brokerageLicenseNumber'] as String? ?? '';
    final managingBrokerName = fd['managingBrokerName'] as String? ?? '';
    final managingBrokerPhone = fd['managingBrokerPhone'] as String? ?? '';
    final managingBrokerEmail = fd['managingBrokerEmail'] as String? ?? '';
    final additionalProvisions = fd['additionalProvisions'] as String? ?? '';

    // ── Section 5 – Duration ─────────────────────────────────────────────────
    // Start date: "entered into this _[day]_ day of _[month]_, 20_[year]_"
    // Field 35 = start day (best guess), 34 = start month (confirmed),
    // 33 = start year (best guess).
    _setText(form, 'Text Field 35', _dayFmt.format(start));
    _setText(form, 'Text Field 34', _monthFmt.format(start));
    _setText(form, 'Text Field 33', _yearFmt.format(start));
    // End date: "expire on the _[day]_ day of _[month]_, 20_[year]_"
    // Field 38 = end day (confirmed), 35 = end month (best guess),
    // 36 = end year (confirmed).
    // NOTE: TF35 is shared with start day above — last write wins (end month).
    // Both start-day and end-month cannot be filled simultaneously with this
    // PDF's field names; a future PDF revision could split them.
    _setText(form, 'Text Field 38', _dayFmt.format(end));
    _setText(form, 'Text Field 36', _yearFmt.format(end));
    // End month uses TF35, overwriting start day written above.
    _setText(form, 'Text Field 35', _monthFmt.format(end));

    // ── Section 6 – Termination tail ─────────────────────────────────────────
    _setText(form, 'Text Field 37', postTermDays.isEmpty ? '60' : postTermDays);

    // ── Section 7 – Compensation ─────────────────────────────────────────────
    final isTypeA = compType == 'percentage' || compType == 'dollar';
    final isTypeB = retainer.isNotEmpty;
    final isTypeC = compType == 'other';

    _setCheckbox(form, 'Check Box 19', isTypeA);
    if (compType == 'dollar') {
      _setText(form, 'Text Field 39', compValue);
    } else if (compType == 'percentage') {
      _setText(form, 'Text Field 40', compValue);
    }

    _setCheckbox(form, 'Check Box 20', isTypeB);
    if (isTypeB) _setText(form, 'Text Field 42', retainer);

    if (isTypeC) _setText(form, 'Text Field 43', otherComp);

    _setText(
      form,
      'Text Field 41',
      postExpDays.isEmpty ? '60' : postExpDays,
    );

    // ── Section 15 – Additional provisions ───────────────────────────────────
    final provLines = _lines(additionalProvisions, 3);
    _setText(form, 'Text Field 52', provLines[0]);
    _setText(form, 'Text Field 49', provLines[1]);
    _setText(form, 'Text Field 50', provLines[2]);

    // ── Buyer execution date (today) ──────────────────────────────────────────
    // Fields: 54 = day (best guess), 53 = month (best guess), 51 = year.
    _setText(form, 'Text Field 54', _dayFmt.format(now));
    _setText(form, 'Text Field 53', _monthFmt.format(now));
    _setText(form, 'Text Field 51', _yearFmt.format(now));

    // ── Buyer 1 ───────────────────────────────────────────────────────────────
    _setText(form, 'Text Field 57', buyer1Name);
    _setText(form, 'Text Field 61', buyer1Email);
    _setText(form, 'Text Field 63', buyer1Cell);
    _setText(form, 'Text Field 77', buyer1Work);

    // ── Buyer 2 (co-buyer) ────────────────────────────────────────────────────
    if (hasCoBuyer) {
      _setText(form, 'Text Field 56', buyer2Name);
      _setText(form, 'Text Field 60', buyer2Email);
      _setText(form, 'Text Field 62', buyer2Cell);
      _setText(form, 'Text Field 76', buyer2Work);
    }

    // ── Broker execution date (today) ─────────────────────────────────────────
    // Fields: 65 = month (confirmed), 64 = year (confirmed). Day unknown.
    _setText(form, 'Text Field 65', _monthFmt.format(now));
    _setText(form, 'Text Field 64', _yearFmt.format(now));

    // ── Broker / agent info ───────────────────────────────────────────────────
    final agentPhone = fd['agentPhone'] as String? ?? '';
    final brokerageAddress = fd['brokerageAddress'] as String? ?? '';

    _setText(form, 'Text Field 69', agreement.agentName);
    _setText(form, 'Text Field 68', agentLicense);
    _setText(form, 'Text Field 71', agentPhone);
    _setText(form, 'Text Field 70', agreement.agentEmail);
    _setText(form, 'Text Field 73', agreement.brokerageName);
    _setText(form, 'Text Field 72', managingBrokerName);
    _setText(form, 'Text Field 75', brokerageLicense);
    _setText(form, 'Text Field 74', managingBrokerPhone);
    _setText(form, 'Text Field 79', brokerageAddress);
    _setText(form, 'Text Field 78', managingBrokerEmail);

    // ── Signatures ────────────────────────────────────────────────────────────
    // Text Field 59 = buyer 1 signature line (drawn over the field bounds).
    // Text Field 58 = buyer 2 signature line.
    // Text Field 67 = broker/associate signature line.
    _drawSignature(doc, form, 'Text Field 59', buyerSignatureBytes);
    _drawSignature(doc, form, 'Text Field 67', agentSignatureBytes);
    if (hasCoBuyer && buyer2SignatureBytes != null) {
      _drawSignature(doc, form, 'Text Field 58', buyer2SignatureBytes);
    }

    // ── Disclosure page (page 4) ──────────────────────────────────────────────
    // Mark "Buyer Brokerage Agreement" checkbox.
    _setCheckbox(form, 'Check Box 22', true);
    // Disclosure receipt date.
    _setText(form, 'Text Field 87', _dayFmt.format(now));
    _setText(form, 'Text Field 88', _monthFmt.format(now));
    _setText(form, 'Text Field 89', _yearFmt.format(now));
    // Buyer printed names.
    _setText(form, 'Text Field 83', buyer1Name);
    if (hasCoBuyer) _setText(form, 'Text Field 84', buyer2Name);

    // ── Flatten all fields ────────────────────────────────────────────────────
    for (int i = 0; i < form.fields.count; i++) {
      form.fields[i].flatten();
    }

    final savedBytes = await doc.save();
    doc.dispose();

    final dir = await getApplicationDocumentsDirectory();
    final safeName = agreement.buyerName.replaceAll(RegExp('[^a-zA-Z0-9]'), '_');
    final filename =
        'OK_BBSA_${safeName}_${agreement.id.substring(0, 8)}.pdf';
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
      // Signatures are on page 3 (index 2).
      final page = doc.pages[2];
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
