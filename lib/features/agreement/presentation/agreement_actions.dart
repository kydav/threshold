import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';

import 'package:threshold/core/services/delivery_service.dart';
import 'package:threshold/features/agreement/data/agreement_model.dart';
import 'package:threshold/features/agreement/data/agreement_repository.dart';

/// What tapping an agreement does, wherever it's listed: a draft resumes
/// signing, a signed one offers sending or sharing, a delivered one opens
/// the PDF to share.
Future<void> openAgreement(
  BuildContext context,
  WidgetRef ref,
  AgreementModel agreement, {
  ValueNotifier<bool>? loading,
}) async {
  switch (agreement.status) {
    case AgreementStatus.draft:
      await context.push('/agreements/${agreement.id}/sign');
    case AgreementStatus.delivered:
      await shareAgreementPdf(context, agreement, loading: loading);
    case AgreementStatus.signed:
    case AgreementStatus.pendingDelivery:
      await showDeliverySheet(context, ref, agreement, loading: loading);
  }
}

/// Opens the system share sheet with the agreement's PDF.
Future<void> shareAgreementPdf(
  BuildContext context,
  AgreementModel agreement, {
  ValueNotifier<bool>? loading,
}) async {
  final path = agreement.localPdfPath;
  if (path == null || !File(path).existsSync()) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PDF not found on this device.')),
    );
    return;
  }
  loading?.value = true;
  try {
    final bytes = await File(path).readAsBytes();
    await Printing.sharePdf(bytes: bytes, filename: path.split('/').last);
  } finally {
    loading?.value = false;
  }
}

/// Send by email or share a signed agreement.
Future<void> showDeliverySheet(
  BuildContext context,
  WidgetRef ref,
  AgreementModel agreement, {
  ValueNotifier<bool>? loading,
}) async {
  final hasPdf =
      agreement.localPdfPath != null &&
      File(agreement.localPdfPath!).existsSync();
  final theme = Theme.of(context);

  await showModalBottomSheet<void>(
    context: context,
    // Above the shell's bottom nav, not inside the tab under it.
    useRootNavigator: true,
    builder:
        (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        agreement.buyerName,
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        agreement.propertyScope,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: const Text('Send via email'),
                  subtitle: const Text('Delivers to buyer and agent'),
                  enabled: hasPdf,
                  onTap:
                      hasPdf
                          ? () async {
                            Navigator.pop(ctx);
                            final messenger = ScaffoldMessenger.of(context);
                            final ok = await ref
                                .read(deliveryServiceProvider)
                                .deliver(agreement);
                            await ref
                                .read(agreementListProvider.notifier)
                                .refresh();
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  ok
                                      ? 'Agreement sent successfully.'
                                      : "Couldn't send yet. It's saved and "
                                          'will retry automatically.',
                                ),
                              ),
                            );
                          }
                          : null,
                ),
                ListTile(
                  leading: const Icon(Icons.share_outlined),
                  title: const Text('Share / Download'),
                  subtitle: const Text('Opens the system share sheet'),
                  enabled: hasPdf,
                  onTap:
                      hasPdf
                          ? () {
                            Navigator.pop(ctx);
                            shareAgreementPdf(
                              context,
                              agreement,
                              loading: loading,
                            );
                          }
                          : null,
                ),
                if (!hasPdf)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Text(
                      'PDF not found on this device.',
                      style: TextStyle(
                        color: theme.colorScheme.error,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
  );
}

/// The agreement-list filters Home links to (`/agreements?status=`).
enum AgreementFilter {
  drafts('Drafts'),
  signed('Signed'),
  delivered('Delivered');

  const AgreementFilter(this.label);
  final String label;

  static AgreementFilter? parse(String? name) =>
      AgreementFilter.values.where((f) => f.name == name).firstOrNull;

  bool matches(AgreementModel a) => switch (this) {
    AgreementFilter.drafts => a.status == AgreementStatus.draft,
    AgreementFilter.signed =>
      a.status == AgreementStatus.signed ||
          a.status == AgreementStatus.pendingDelivery,
    AgreementFilter.delivered => a.status == AgreementStatus.delivered,
  };
}
