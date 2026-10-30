import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:threshold/features/templates/data/form_template.dart';
import 'package:threshold/features/templates/data/template_repository.dart';

/// A signer's consent and signature event, for the audit page.
class SignatureEvent {
  const SignatureEvent({
    required this.name,
    required this.role,
    required this.email,
    required this.consentedAt,
    required this.signedAt,
  });

  final String name;
  final String role;
  final String email;
  final DateTime consentedAt;
  final DateTime signedAt;
}

/// Field values: String for text, bool for checkboxes, PNG bytes for ink.
typedef FieldValues = Map<String, Object>;

/// Renders a signed agreement from a template: each cleaned page as the
/// background, values and signatures stamped into their boxes, then an audit
/// page recording consent and signing (ESIGN/UETA record of the process).
class TemplatePdfService {
  TemplatePdfService(this._repo);

  final TemplateRepository _repo;

  Future<({Uint8List bytes, String sha256})> render({
    required FormTemplate template,
    required FieldValues values,
    required String agreementId,
    required List<SignatureEvent> events,
  }) async {
    final doc = pw.Document(
      title: template.title,
      creator: 'Threshold',
      producer: 'Threshold',
    );

    // Pages first, so the fingerprint on the audit page covers exactly the
    // signed content.
    final pageDoc = pw.Document();
    for (var i = 0; i < template.pages.length; i++) {
      final page = template.pages[i];
      final bg = pw.MemoryImage(
        await (await _repo.pageFile(template, i)).readAsBytes(),
      );
      final fields = template.fields.where((f) => f.page == i + 1);
      for (final target in [doc, pageDoc]) {
        target.addPage(_page(page, bg, fields, values));
      }
    }
    final contentHash = sha256.convert(await pageDoc.save()).toString();

    doc.addPage(_auditPage(template, agreementId, events, contentHash));
    final bytes = await doc.save();
    return (bytes: bytes, sha256: contentHash);
  }

  pw.Page _page(
    TemplatePage page,
    pw.MemoryImage bg,
    Iterable<TemplateField> fields,
    FieldValues values,
  ) {
    // Letter-size page; the scanned page fills it edge to edge.
    const format = PdfPageFormat.letter;
    final sx = format.width / page.width;
    final sy = format.height / page.height;
    return pw.Page(
      pageFormat: format,
      margin: pw.EdgeInsets.zero,
      build:
          (_) => pw.Stack(
            children: [
              pw.Positioned.fill(child: pw.Image(bg, fit: pw.BoxFit.fill)),
              for (final f in fields)
                if (values[f.id] != null)
                  pw.Positioned(
                    left: f.box.left * sx,
                    top: f.box.top * sy,
                    child: pw.SizedBox(
                      width: f.box.width * sx,
                      height: f.box.height * sy,
                      child: _stamp(f, values[f.id]!, f.box.height * sy),
                    ),
                  ),
            ],
          ),
    );
  }

  pw.Widget _stamp(TemplateField f, Object value, double height) {
    if (value is Uint8List) {
      return pw.Image(
        pw.MemoryImage(value),
        alignment: pw.Alignment.bottomLeft,
      );
    }
    if (value is bool) {
      return value
          ? pw.Center(
            child: pw.Text(
              'X',
              style: pw.TextStyle(
                fontSize: height * 0.8,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          )
          : pw.SizedBox();
    }
    return pw.Align(
      alignment: pw.Alignment.bottomLeft,
      child: pw.FittedBox(
        fit: pw.BoxFit.scaleDown,
        alignment: pw.Alignment.bottomLeft,
        child: pw.Padding(
          padding: const pw.EdgeInsets.only(left: 2, bottom: 1),
          child: pw.Text(
            value.toString(),
            style: pw.TextStyle(fontSize: (height * 0.7).clamp(6, 12)),
          ),
        ),
      ),
    );
  }

  pw.Page _auditPage(
    FormTemplate template,
    String agreementId,
    List<SignatureEvent> events,
    String contentHash,
  ) {
    final fmt = DateFormat("MMM d, y 'at' h:mm:ss a");
    final device =
        '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
    return pw.Page(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.all(48),
      build:
          (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Signature certificate',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(template.title),
              pw.Text('Agreement ID: $agreementId'),
              pw.SizedBox(height: 16),
              for (final e in events) ...[
                pw.Text(
                  '${e.name} (${e.role})',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                if (e.email.isNotEmpty) pw.Text('Email: ${e.email}'),
                pw.Text(
                  'Agreed to sign electronically: ${fmt.format(e.consentedAt)}',
                ),
                pw.Text('Signed: ${fmt.format(e.signedAt)}'),
                pw.SizedBox(height: 10),
              ],
              pw.Text("Signed in person on the agent's device ($device)."),
              pw.SizedBox(height: 16),
              pw.Text(
                'Document fingerprint (SHA-256 of the signed pages):',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(contentHash, style: const pw.TextStyle(fontSize: 9)),
              pw.SizedBox(height: 8),
              pw.Text(
                'Any change to the signed pages changes this fingerprint.',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ],
          ),
    );
  }
}
