import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../features/agreement/data/agreement_model.dart';

// Pass via --dart-define=SENDGRID_API_KEY=SG.xxx
const _sendgridApiKey = String.fromEnvironment('SENDGRID_API_KEY');
const _fromEmail = String.fromEnvironment(
  'FROM_EMAIL',
  defaultValue: 'agreements@threshold.app',
);

class DeliveryService {
  DeliveryService(this._firestore);
  final FirebaseFirestore _firestore;

  /// Attempt to deliver a signed agreement. Returns true on success.
  /// On failure the agreement stays in `pending_delivery` state so the
  /// caller can retry when connectivity is restored.
  Future<bool> deliver(AgreementModel agreement) async {
    if (!agreement.hasLocalPdf) return false;
    if (_sendgridApiKey.isEmpty) {
      // Dev mode — log and mark delivered without actually sending.
      await _markDelivered(agreement.id);
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

        if (res.statusCode != 202) {
          // SendGrid returns 202 Accepted on success.
          return false;
        }
      }

      await _markDelivered(agreement.id);
      return true;
    } on SocketException {
      // No network — leave as pending_delivery
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Retry all agreements in pending_delivery state for the given agent.
  Future<void> retryPending(String agentId) async {
    final snap = await _firestore
        .collection('agreements')
        .where('agentId', isEqualTo: agentId)
        .where('status', isEqualTo: 'pending_delivery')
        .get();

    for (final doc in snap.docs) {
      final agreement = AgreementModel.fromFirestore(doc);
      await deliver(agreement);
    }
  }

  Future<void> _markDelivered(String id) async {
    await _firestore.collection('agreements').doc(id).update({
      'status': 'delivered',
      'deliveredAt': FieldValue.serverTimestamp(),
    });
  }

  String _fmt(DateTime d) => '${d.month}/${d.day}/${d.year}';
}

final deliveryServiceProvider = Provider<DeliveryService>(
  (ref) => DeliveryService(FirebaseFirestore.instance),
);
