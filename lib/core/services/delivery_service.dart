import 'dart:convert';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:threshold/features/agreement/data/agreement_model.dart';
import 'package:threshold/features/agreement/data/agreement_repository.dart';

class DeliveryService {
  DeliveryService(this._repo);
  final AgreementRepository _repo;

  Future<bool> deliver(AgreementModel agreement) async {
    if (!agreement.hasLocalPdf) return false;

    final file = File(agreement.localPdfPath!);
    if (!file.existsSync()) return false;

    final pdfBytes = await file.readAsBytes();
    final pdfBase64 = base64Encode(pdfBytes);
    final filename =
        'agreement_${agreement.buyerName.replaceAll(' ', '_')}.pdf';

    final recipients = [
      {'email': agreement.buyerEmail, 'name': agreement.buyerName},
      {'email': agreement.agentEmail, 'name': agreement.agentName},
    ];

    final buyer2Email = agreement.formData['buyer2Email'] as String?;
    final buyer2Name = agreement.formData['buyer2Name'] as String?;
    if (buyer2Email != null && buyer2Email.isNotEmpty) {
      recipients.add({'email': buyer2Email, 'name': buyer2Name ?? 'Co-buyer'});
    }

    final bodyText =
        'Please find your signed buyer representation agreement attached.\n\n'
        'This agreement covers: ${agreement.propertyScope}\n'
        'Compensation: ${agreement.compensation}\n'
        'Term: ${_fmt(agreement.startDate)} – ${_fmt(agreement.endDate)}\n\n'
        'Threshold';

    try {
      final callable = FirebaseFunctions.instance
          .httpsCallable('sendAgreementEmail');
      await callable.call({
        'recipients': recipients,
        'agentName': agreement.agentName,
        'agentEmail': agreement.agentEmail,
        'subject':
            'Signed buyer representation agreement — ${agreement.propertyScope}',
        'bodyText': bodyText,
        'pdfBase64': pdfBase64,
        'filename': filename,
      });

      final delivered = agreement.copyWith(
        status: AgreementStatus.delivered,
        deliveredAt: DateTime.now(),
      );
      await _repo.save(delivered);
      return true;
    } on FirebaseFunctionsException catch (_) {
      return false;
    } on SocketException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> retryPending(String agentId) async {
    final pending = await _repo.listPending(agentId);
    for (final agreement in pending) {
      await deliver(agreement);
    }
  }

  String _fmt(DateTime d) => '${d.month}/${d.day}/${d.year}';
}

final deliveryServiceProvider = Provider<DeliveryService>(
  (ref) => DeliveryService(ref.read(agreementRepositoryProvider)),
);
