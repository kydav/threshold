import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:threshold/core/services/delivery_service.dart';
import 'package:threshold/features/agreement/data/agreement_model.dart';
import 'package:threshold/features/agreement/data/agreement_repository.dart';

class OklahomaPdfService {
  OklahomaPdfService(this._repo, this._delivery);
  final AgreementRepository _repo;
  final DeliveryService _delivery;

  static final _dateFmt = DateFormat('MMMM d, yyyy');
  static final _shortFmt = DateFormat('MM/dd/yyyy');

  Future<String?> generate({
    required AgreementModel agreement,
    required Uint8List agentSignatureBytes,
    required Uint8List buyerSignatureBytes,
    Uint8List? buyer2SignatureBytes,
    bool autoEmail = true,
  }) async {
    final fd = agreement.formData;

    final buyer1Name = fd['buyer1Name'] as String? ?? agreement.buyerName;
    final buyerEmail = fd['buyerEmail'] as String? ?? agreement.buyerEmail;
    final buyerCell = fd['buyerCellPhone'] as String? ?? '';
    final buyerWork = fd['buyerWorkPhone'] as String? ?? '';
    final buyer2Name = fd['buyer2Name'] as String? ?? '';
    final buyer2Email = fd['buyer2Email'] as String? ?? '';
    final buyer2Cell = fd['buyer2CellPhone'] as String? ?? '';
    final buyer2Work = fd['buyer2WorkPhone'] as String? ?? '';
    final hasCoBuyer = buyer2Name.isNotEmpty;

    final postTermDays = fd['postTerminationDays'] as String? ?? '60';
    final compType = fd['compensationType'] as String? ?? 'percentage';
    final compValue = fd['compensationValue'] as String? ?? '';
    final retainerFee = fd['retainerFee'] as String? ?? '';
    final otherComp = fd['otherCompensation'] as String? ?? '';
    final postExpDays = fd['postExpirationDays'] as String? ?? '60';

    final agentLicense = fd['agentLicenseNumber'] as String? ?? '';
    final brokerageLicense = fd['brokerageLicenseNumber'] as String? ?? '';
    final mgBrokerName = fd['managingBrokerName'] as String? ?? '';
    final mgBrokerPhone = fd['managingBrokerPhone'] as String? ?? '';
    final mgBrokerEmail = fd['managingBrokerEmail'] as String? ?? '';
    final additionalProvisions = fd['additionalProvisions'] as String? ?? '';

    final baseFont = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();
    final italicFont = await PdfGoogleFonts.notoSansItalic();
    final theme = pw.ThemeData.withFont(
      base: baseFont,
      bold: boldFont,
      italic: italicFont,
    );

    final pdf = pw.Document();
    final agentSigImage = pw.MemoryImage(agentSignatureBytes);
    final buyerSigImage = pw.MemoryImage(buyerSignatureBytes);
    final buyer2SigImage =
        buyer2SignatureBytes != null ? pw.MemoryImage(buyer2SignatureBytes) : null;
    final now = DateTime.now();

    // ── Page 1 ────────────────────────────────────────────────────────────────
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.symmetric(horizontal: 54, vertical: 48),
        theme: theme,
        build: (ctx) => [
          _header(now),
          pw.SizedBox(height: 14),

          // §1 Parties
          _section('1. PARTIES'),
          _body(
            'This Agreement is entered into between ${agreement.brokerageName} '
            '("Buyer\'s Broker") and the following Buyer(s):',
          ),
          pw.SizedBox(height: 8),
          _filledRow('Buyer', buyer1Name),
          if (hasCoBuyer) _filledRow('Co-Buyer', buyer2Name),
          pw.SizedBox(height: 10),

          // §2 Definitions
          _section('2. DEFINITIONS'),
          _body(
            '"Property" means residential real property located in the state of Oklahoma. '
            '"Acquisition" means purchase, exchange, or other acquisition of Property. '
            '"Broker" means the brokerage firm and its associates acting as Buyer\'s agent.',
          ),
          pw.SizedBox(height: 10),

          // §3 Agreement
          _section('3. AGREEMENT'),
          _body(
            'Buyer agrees to exclusively use Broker to locate and acquire Property during the term '
            'of this Agreement. Buyer agrees to conduct all negotiations and make all offers to '
            'purchase or exchange Property through Broker.',
          ),
          pw.SizedBox(height: 10),

          // §4 Services
          _section('4. BROKER SERVICES'),
          _body(
            'Broker agrees to: (a) perform a diligent search for Property meeting Buyer\'s '
            'specifications; (b) present all properties suitable to Buyer\'s needs and financial '
            'ability; (c) assist Buyer in evaluating Property; (d) prepare and present all offers '
            'to purchase made by Buyer; (e) assist Buyer in completing the transaction.',
          ),
          pw.SizedBox(height: 10),

          // §5 Duration
          _section('5. DURATION OF AGREEMENT'),
          _body(
            'This Agreement commences on ${_dateFmt.format(agreement.startDate)} '
            'and expires on ${_dateFmt.format(agreement.endDate)}. '
            'If no expiration date is specified, this Agreement expires 60 days from execution.',
          ),
          pw.SizedBox(height: 10),

          // §6 Termination
          _section('6. TERMINATION'),
          _body(
            'Either party may terminate this Agreement upon written notice. However, if Buyer '
            'acquires Property within $postTermDays days (60 if blank) after the expiration or '
            'termination of this Agreement, and such Property was introduced to Buyer by Broker '
            'during the term of this Agreement, the compensation described herein shall be due '
            'and payable.',
          ),
          pw.SizedBox(height: 10),

          // §7 Compensation
          _section('7. COMPENSATION'),
          _compensationSection(
            compType: compType,
            compValue: compValue,
            otherComp: otherComp,
            retainerFee: retainerFee,
            postExpDays: postExpDays,
          ),
          pw.SizedBox(height: 10),

          // §8–10 Standard provisions
          _section('8. DUAL AGENCY / TRANSACTION BROKERAGE'),
          _body(
            'Buyer acknowledges that Broker may represent other buyers or sellers. Broker may '
            'act as a transaction broker or in a dual agency capacity only with the prior written '
            'consent of all parties involved.',
          ),
          pw.SizedBox(height: 10),

          _section('9. BUYER OBLIGATIONS'),
          _body(
            'Buyer agrees to: (a) work exclusively with Broker; (b) immediately refer to Broker '
            'all inquiries from any source regarding the acquisition of Property; (c) inform Broker '
            'of any communication received directly from sellers or their agents.',
          ),
          pw.SizedBox(height: 10),

          _section('10. PROPERTY DISCLOSURE'),
          _body(
            'Buyer acknowledges receipt of the Oklahoma Real Estate Commission Pamphlet on '
            'agency disclosure. Buyer understands Broker\'s fiduciary duties as Buyer\'s agent.',
          ),
        ],
      ),
    );

    // ── Page 2 ────────────────────────────────────────────────────────────────
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.symmetric(horizontal: 54, vertical: 48),
        theme: theme,
        build: (ctx) => [
          _pageHeader('BUYER BROKER SERVICE AGREEMENT — continued'),
          pw.SizedBox(height: 16),

          _section('11. INDEMNIFICATION'),
          _body(
            'Buyer agrees to indemnify and hold harmless Broker from any claims, damages, or '
            'expenses arising from Buyer\'s misrepresentation or breach of this Agreement.',
          ),
          pw.SizedBox(height: 10),

          _section('12. FINANCING'),
          _body(
            'This Agreement is not contingent upon Buyer obtaining financing unless otherwise '
            'agreed in writing. Broker is not responsible for the availability of financing.',
          ),
          pw.SizedBox(height: 10),

          _section('13. MEDIATION'),
          _body(
            'Any disputes arising from this Agreement shall first be submitted to mediation '
            'in accordance with the Oklahoma Real Estate Dispute Resolution System before '
            'arbitration or litigation.',
          ),
          pw.SizedBox(height: 10),

          _section('14. ENTIRE AGREEMENT'),
          _body(
            'This Agreement constitutes the entire agreement of the parties and supersedes '
            'any prior or contemporaneous written or oral agreements. This Agreement may not '
            'be amended except in writing signed by all parties.',
          ),
          pw.SizedBox(height: 10),

          _section('15. ADDITIONAL PROVISIONS'),
          if (additionalProvisions.isNotEmpty)
            _body(additionalProvisions)
          else
            _body('None.'),
          pw.SizedBox(height: 24),

          // NAR Compliance notice
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.blue900),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              color: PdfColors.blue50,
            ),
            child: pw.Text(
              'NAR SETTLEMENT COMPLIANCE: This Buyer Broker Service Agreement is entered into '
              'pursuant to the National Association of REALTORS® settlement requirements '
              'effective August 17, 2024. Buyer has agreed to the compensation arrangement '
              'stated herein prior to touring any property.',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.blue900),
            ),
          ),
          pw.SizedBox(height: 24),

          // ── Signature block ─────────────────────────────────────────────────
          _section('SIGNATURES'),
          pw.SizedBox(height: 8),

          // Buyer 1
          _buyerSigBlock(
            name: buyer1Name,
            email: buyerEmail,
            cell: buyerCell,
            work: buyerWork,
            sigImage: buyerSigImage,
            date: now,
          ),
          if (hasCoBuyer && buyer2SigImage != null) ...[
            pw.SizedBox(height: 16),
            _buyerSigBlock(
              name: buyer2Name,
              email: buyer2Email,
              cell: buyer2Cell,
              work: buyer2Work,
              sigImage: buyer2SigImage,
              date: now,
            ),
          ],
          pw.SizedBox(height: 20),

          // Broker / Agent
          _brokerSigBlock(
            agentName: agreement.agentName,
            agentEmail: agreement.agentEmail,
            agentPhone: '',
            agentLicense: agentLicense,
            brokerageName: agreement.brokerageName,
            brokerageLicense: brokerageLicense,
            brokerageAddress: '',
            mgBrokerName: mgBrokerName,
            mgBrokerPhone: mgBrokerPhone,
            mgBrokerEmail: mgBrokerEmail,
            sigImage: agentSigImage,
            date: now,
          ),
          pw.SizedBox(height: 24),
          pw.Text(
            'Generated by Threshold on ${_dateFmt.format(now)}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ],
      ),
    );

    // ── Page 3 — Disclosure ───────────────────────────────────────────────────
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.symmetric(horizontal: 54, vertical: 48),
        theme: theme,
        build: (ctx) => [
          ..._disclosurePage(
            buyer1Name: buyer1Name,
            buyer2Name: hasCoBuyer ? buyer2Name : null,
            agentName: agreement.agentName,
            brokerageName: agreement.brokerageName,
            buyerSigImage: buyerSigImage,
            buyer2SigImage: hasCoBuyer ? buyer2SigImage : null,
            now: now,
          ),
        ],
      ),
    );

    final bytes = await pdf.save();

    final dir = await getApplicationDocumentsDirectory();
    final safeName = agreement.buyerName.replaceAll(RegExp('[^a-zA-Z0-9]'), '_');
    final filename = 'OK_BBSA_${safeName}_${agreement.id.substring(0, 8)}.pdf';
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);
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
      await Printing.sharePdf(bytes: bytes, filename: filename);
    }

    return localPath;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  pw.Widget _header(DateTime now) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            'BUYER BROKER SERVICE AGREEMENT',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.center,
          ),
          pw.Text(
            'Oklahoma REALTORS® — Effective Date: ${_shortFmt.format(now)}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            textAlign: pw.TextAlign.center,
          ),
          pw.Divider(thickness: 1.5),
        ],
      );

  pw.Widget _pageHeader(String title) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          pw.Divider(),
        ],
      );

  pw.Widget _section(String title) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 2, bottom: 3),
        child: pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blueGrey800,
          ),
        ),
      );

  pw.Widget _body(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Text(
          text,
          style: const pw.TextStyle(fontSize: 9.5),
          textAlign: pw.TextAlign.justify,
        ),
      );

  pw.Widget _filledRow(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3),
        child: pw.Row(
          children: [
            pw.SizedBox(
              width: 80,
              child: pw.Text(
                '$label:',
                style: pw.TextStyle(
                  fontSize: 9.5,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Expanded(
              child: pw.Text(value, style: const pw.TextStyle(fontSize: 9.5)),
            ),
          ],
        ),
      );

  pw.Widget _compensationSection({
    required String compType,
    required String compValue,
    required String otherComp,
    required String retainerFee,
    required String postExpDays,
  }) {
    final compDesc = switch (compType) {
      'percentage' => '$compValue% of the gross selling price',
      'dollar' => '\$$compValue',
      _ => otherComp,
    };

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _body(
          '(a) Buyer agrees to pay Broker a fee of $compDesc upon Acquisition of '
          'any Property during the term of this Agreement or within $postExpDays days '
          '(60 if blank) after expiration.',
        ),
        if (retainerFee.isNotEmpty && retainerFee != '0')
          _body(
            '(b) Buyer agrees to pay a non-refundable retainer fee of \$$retainerFee, '
            'which shall be credited toward the compensation described in (a).',
          )
        else
          _body('(b) Retainer fee: \$0 (none).'),
        _body(
          '(c) If Buyer acquires Property through a source other than Broker '
          'during the term of this Agreement, the compensation described herein '
          'shall still be due and payable.',
        ),
      ],
    );
  }

  pw.Widget _buyerSigBlock({
    required String name,
    required String email,
    required String cell,
    required String work,
    required pw.ImageProvider sigImage,
    required DateTime date,
  }) =>
      pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Buyer (Print):',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(name, style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
                pw.SizedBox(width: 16),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Buyer Signature:',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Container(
                        height: 48,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey300),
                        ),
                        child: pw.Image(sigImage),
                      ),
                      pw.Text(
                        DateFormat('MM/dd/yyyy').format(date),
                        style: const pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Row(
              children: [
                if (email.isNotEmpty) ...[
                  pw.Text(
                    'Email: ',
                    style: pw.TextStyle(
                      fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(email, style: const pw.TextStyle(fontSize: 8.5)),
                  pw.SizedBox(width: 16),
                ],
                if (cell.isNotEmpty) ...[
                  pw.Text(
                    'Cell: ',
                    style: pw.TextStyle(
                      fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(cell, style: const pw.TextStyle(fontSize: 8.5)),
                ],
                if (work.isNotEmpty) ...[
                  pw.SizedBox(width: 16),
                  pw.Text(
                    'Work: ',
                    style: pw.TextStyle(
                      fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(work, style: const pw.TextStyle(fontSize: 8.5)),
                ],
              ],
            ),
          ],
        ),
      );

  pw.Widget _brokerSigBlock({
    required String agentName,
    required String agentEmail,
    required String agentPhone,
    required String agentLicense,
    required String brokerageName,
    required String brokerageLicense,
    required String brokerageAddress,
    required String mgBrokerName,
    required String mgBrokerPhone,
    required String mgBrokerEmail,
    required pw.ImageProvider sigImage,
    required DateTime date,
  }) =>
      pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          color: PdfColors.grey50,
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'BUYER\'S BROKER / ASSOCIATE',
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey800,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _sigRow('Name', agentName),
                      if (agentEmail.isNotEmpty) _sigRow('Email', agentEmail),
                      if (agentLicense.isNotEmpty)
                        _sigRow('Associate License #', agentLicense),
                      _sigRow('Brokerage', brokerageName),
                      if (brokerageLicense.isNotEmpty)
                        _sigRow('Brokerage License #', brokerageLicense),
                    ],
                  ),
                ),
                pw.SizedBox(width: 16),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Broker Signature:',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Container(
                        height: 48,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey300),
                          color: PdfColors.white,
                        ),
                        child: pw.Image(sigImage),
                      ),
                      pw.Text(
                        DateFormat('MM/dd/yyyy').format(date),
                        style: const pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (mgBrokerName.isNotEmpty) ...[
              pw.Divider(thickness: 0.5),
              pw.Text(
                'MANAGING BROKER',
                style: pw.TextStyle(
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey800,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                children: [
                  if (mgBrokerName.isNotEmpty) ...[
                    pw.Expanded(child: _sigRow('Name', mgBrokerName)),
                  ],
                  if (mgBrokerPhone.isNotEmpty) ...[
                    pw.Expanded(child: _sigRow('Phone', mgBrokerPhone)),
                  ],
                  if (mgBrokerEmail.isNotEmpty) ...[
                    pw.Expanded(child: _sigRow('Email', mgBrokerEmail)),
                  ],
                ],
              ),
            ],
          ],
        ),
      );

  pw.Widget _sigRow(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3),
        child: pw.RichText(
          text: pw.TextSpan(
            children: [
              pw.TextSpan(
                text: '$label: ',
                style: pw.TextStyle(
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.TextSpan(
                text: value,
                style: const pw.TextStyle(fontSize: 8.5),
              ),
            ],
          ),
        ),
      );

  List<pw.Widget> _disclosurePage({
    required String buyer1Name,
    required String? buyer2Name,
    required String agentName,
    required String brokerageName,
    required pw.ImageProvider buyerSigImage,
    required pw.ImageProvider? buyer2SigImage,
    required DateTime now,
  }) =>
      [
        pw.Text(
          'OKLAHOMA REAL ESTATE COMMISSION\nAGENCY DISCLOSURE',
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          textAlign: pw.TextAlign.center,
        ),
        pw.Divider(thickness: 1.5),
        pw.SizedBox(height: 10),
        pw.Text(
          'This disclosure is required by Oklahoma law. Please read it carefully.',
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blueGrey800,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          'BUYER\'S AGENT\n'
          'A buyer\'s agent is an agent who represents only the buyer. The buyer\'s agent has '
          'fiduciary duties to the buyer, including loyalty, confidentiality, disclosure, '
          'obedience, reasonable care and diligence, and accounting.',
          style: const pw.TextStyle(fontSize: 9.5),
          textAlign: pw.TextAlign.justify,
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'TRANSACTION BROKER\n'
          'A transaction broker facilitates a real estate transaction without representing '
          'either party as their agent. A transaction broker has no fiduciary duty of loyalty '
          'to either party but shall treat both parties honestly and fairly.',
          style: const pw.TextStyle(fontSize: 9.5),
          textAlign: pw.TextAlign.justify,
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'CONFIRMATION OF AGENCY RELATIONSHIP\n'
          '${agentName.isNotEmpty ? agentName : "The agent"} of ${brokerageName.isNotEmpty ? brokerageName : "the brokerage"} '
          'represents the BUYER in this transaction.',
          style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
          textAlign: pw.TextAlign.justify,
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'BUYER ACKNOWLEDGMENT\n'
          'I/We, the undersigned, acknowledge that I/we have read and understand the '
          'agency disclosure information presented above and confirm the agency relationship '
          'as stated.',
          style: const pw.TextStyle(fontSize: 9.5),
          textAlign: pw.TextAlign.justify,
        ),
        pw.SizedBox(height: 20),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Buyer (Print): $buyer1Name',
                    style: const pw.TextStyle(fontSize: 9.5),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'Buyer Signature:',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Container(
                    height: 48,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                    ),
                    child: pw.Image(buyerSigImage),
                  ),
                  pw.Text(
                    'Date: ${DateFormat('MM/dd/yyyy').format(now)}',
                    style: const pw.TextStyle(fontSize: 8.5),
                  ),
                ],
              ),
            ),
            if (buyer2Name != null && buyer2SigImage != null) ...[
              pw.SizedBox(width: 20),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Co-Buyer (Print): $buyer2Name',
                      style: const pw.TextStyle(fontSize: 9.5),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'Co-Buyer Signature:',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Container(
                      height: 48,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300),
                      ),
                      child: pw.Image(buyer2SigImage),
                    ),
                    pw.Text(
                      'Date: ${DateFormat('MM/dd/yyyy').format(now)}',
                      style: const pw.TextStyle(fontSize: 8.5),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ];
}

final oklahomaPdfServiceProvider = Provider<OklahomaPdfService>(
  (ref) => OklahomaPdfService(
    ref.read(agreementRepositoryProvider),
    ref.read(deliveryServiceProvider),
  ),
);
