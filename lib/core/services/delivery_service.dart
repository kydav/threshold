import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:threshold/features/agreement/data/agreement_model.dart';
import 'package:threshold/features/agreement/data/agreement_repository.dart';

// Pass via --dart-define=SENDGRID_API_KEY=SG.xxx
const _sendgridApiKey = String.fromEnvironment('SENDGRID_API_KEY');
const _fromEmail = String.fromEnvironment(
  'FROM_EMAIL',
  defaultValue: 'agreements@threshold.app',
);

class DeliveryService {
  DeliveryService(this._repo);
  final AgreementRepository _repo;

  /// Attempt to deliver a signed agreement. Returns true on success.
  /// On failure the agreement stays in pending_delivery so the
  /// connectivity watcher retries when signal returns.
  Future<bool> deliver(AgreementModel agreement) async {
    if (!agreement.hasLocalPdf) return false;

    if (_sendgridApiKey.isEmpty) {
      // Dev mode — skip send and mark delivered so UI works for testing.
      final delivered = agreement.copyWith(
        status: AgreementStatus.delivered,
        deliveredAt: DateTime.now(),
      );
      await _repo.save(delivered);
      return true;
    }

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

    try {
      for (final recipient in recipients) {
        final res = await http.post(
          Uri.parse('https://api.sendgrid.com/v3/mail/send'),
          headers: {
            'Authorization': 'Bearer $_sendgridApiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'personalizations': [
              {
                'to': [recipient],
              }
            ],
            'from': {'email': _fromEmail, 'name': 'Threshold'},
            'subject':
                'Signed buyer representation agreement — ${agreement.propertyScope}',
            'content': [
              {
                'type': 'text/plain',
                'value':
                    'Hi ${recipient['name']},\n\nPlease find your signed buyer representation agreement attached.\n\nThis agreement covers: ${agreement.propertyScope}\nCompensation: ${agreement.compensation}\nTerm: ${_fmt(agreement.startDate)} – ${_fmt(agreement.endDate)}\n\nThreshold',
              }
            ],
            'attachments': [
              {
                'content': pdfBase64,
                'filename': filename,
                'type': 'application/pdf',
                'disposition': 'attachment',
              }
            ],
          }),
        );

        if (res.statusCode != 202) return false;
      }

      final delivered = agreement.copyWith(
        status: AgreementStatus.delivered,
        deliveredAt: DateTime.now(),
      );
      await _repo.save(delivered);
      return true;
    } on SocketException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Retry all pending agreements for the given agent.
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
