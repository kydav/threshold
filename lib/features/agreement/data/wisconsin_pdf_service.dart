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
    _setText(
      form,
      'buyer_email',
      fd['buyer_email'] as String? ?? agreement.buyerEmail,
    );

    // ── Firm representation ───────────────────────────────────────────────────
    // PDF now has three independent checkboxes instead of a radio group.
    // Values: not_same_agent = with designated agency (multiple_designated),
    //         neutral_firm   = without designated agency (multiple_no_designated),
    //         no_same_firm   = reject multiple representation (no_multiple)
    final firmRep = fd['firm_representation'] as String? ?? '';
    _setCheckbox(form, 'multiple_designated', firmRep == 'not_same_agent');
    _setCheckbox(form, 'multiple_no_designated', firmRep == 'neutral_firm');
    _setCheckbox(form, 'no_multiple', firmRep == 'no_same_firm');

    // Communication preferences
    final commEmail = (fd['comm_email'] as bool?) ?? true;
    final commMail = (fd['comm_mail'] as bool?) ?? false;
    _setCheckbox(form, 'email', commEmail);
    _setCheckbox(form, 'mail', commMail);

    // ── Co-buyer ──────────────────────────────────────────────────────────────
    final hasCoBuyer = (fd['has_co_buyer'] as bool?) ?? false;
    final buyer2Name = fd['buyer_name_2'] as String? ?? '';
    final buyerName1 = fd['buyer_name'] as String? ?? agreement.buyerName;
    _setText(form, 'buyer_name_1', buyerName1);
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
        _setText(
          form,
          'term_start_month',
          start.month.toString().padLeft(2, '0'),
        );
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
    final commLines = _lines(fd['commission'] as String? ?? '', 3);
    _setText(form, 'commission', commLines[0]);
    _setText(form, 'commission_line_2', commLines[1]);
    _setText(form, 'commissions_line_3', commLines[2]);
    final otherCompLines = _lines(fd['other_compensation'] as String? ?? '', 2);
    _setText(form, 'other_compensation', otherCompLines[0]);
    _setText(form, 'other_compensation_line_2', otherCompLines[1]);
    _setText(
      form,
      'purchase_price_range',
      fd['purchase_price_range'] as String? ?? '',
    );

    // ── Excluded properties ───────────────────────────────────────────────────
    final exclLines = _lines(fd['excluded_properties'] as String? ?? '', 2);
    _setText(form, 'excluded_properties', exclLines[0]);
    _setText(form, 'excluded_properties_line_2', exclLines[1]);
    final exclPriorLines = _lines(
      fd['excluded_properties_prior'] as String? ?? '',
      2,
    );
    _setText(form, 'excluded_properties_prior', exclPriorLines[0]);
    _setText(form, 'excluded_properties_prior_line_2', exclPriorLines[1]);
    _setText(form, 'exclusion_date', fd['exclusion_date'] as String? ?? '');

    // ── Confidential / non-confidential ───────────────────────────────────────
    final confLines = _lines(fd['confidential_info'] as String? ?? '', 3);
    _setText(form, 'confidential_info', confLines[0]);
    _setText(form, 'confidential_info_2', confLines[1]);
    _setText(form, 'confidential_info_3', confLines[2]);
    final nonConfLines = _lines(fd['non_confidential'] as String? ?? '', 3);
    _setText(form, 'non_confidential', nonConfLines[0]);
    _setText(form, 'non_confidential_2', nonConfLines[1]);
    _setText(form, 'non_confidential_3', nonConfLines[2]);

    // ── Additional provisions ─────────────────────────────────────────────────
    final provLines = _lines(fd['additional_provisions'] as String? ?? '', 2);
    _setText(form, 'additional_provisions', provLines[0]);
    _setText(form, 'additional_provisions_2', provLines[1]);

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
    final safeName = agreement.buyerName.replaceAll(
      RegExp('[^a-zA-Z0-9]'),
      '_',
    );
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
      await Printing.sharePdf(
        bytes: Uint8List.fromList(savedBytes),
        filename: filename,
      );
    }

    return localPath;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Splits [text] by newlines and returns exactly [count] strings,
  /// padding with empty strings if there are fewer lines than [count].
  List<String> _lines(String text, int count) {
    final parts = text.split('\n');
    return List.generate(count, (i) => i < parts.length ? parts[i].trim() : '');
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

  void _setRadio(PdfForm form, String name, String value) {
    try {
      final f = _find(form, name);
      if (f is PdfRadioButtonListField) {
        for (int i = 0; i < f.items.count; i++) {
          // Syncfusion doesn't decode #XX hex sequences beyond whitespace,
          // so item.value may be e.g. "not#5Fsame#5Fagent". Decode it fully.
          if (_decodePdfName(f.items[i].value) == value) {
            f.items[i].style = PdfCheckBoxStyle.cross;
            // Must use selectedValue with the raw (undecoded) item value.
            // selectedIndex internally never updates _helper.selectedIndex,
            // so the flatten renders nothing. selectedValue does update it.
            f.selectedValue = f.items[i].value;
            break;
          }
        }
      }
    } catch (_) {}
  }

  String _decodePdfName(String name) {
    return name.replaceAllMapped(RegExp('#([0-9A-Fa-f]{2})'), (m) {
      return String.fromCharCode(int.parse(m.group(1)!, radix: 16));
    });
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
