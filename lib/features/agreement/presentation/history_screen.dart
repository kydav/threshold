import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import 'package:threshold/core/services/delivery_service.dart';
import 'package:threshold/features/agreement/data/agreement_model.dart';
import 'package:threshold/features/agreement/data/agreement_repository.dart';

class HistoryScreen extends HookConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agreements = ref.watch(agreementListProvider);
    final cs = Theme.of(context).colorScheme;
    final loading = useState(false);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left, color: cs.onSurface),
          onPressed: () => context.go('/home'),
        ),
        title: Text(
          'Agreements',
          style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold),
        ),
      ),
      body: agreements.when(
        loading:
            () => Center(child: CircularProgressIndicator(color: cs.primary)),
        error:
            (e, _) => Center(
              child: Text('Error: $e', style: TextStyle(color: cs.onSurface)),
            ),
        data: (list) {
          if (list.isEmpty) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 200),
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: 48,
                          color: cs.outlineVariant,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No agreements yet',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap + to start one at a showing',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Card(
              child: RefreshIndicator(
                onRefresh:
                    () => ref.read(agreementListProvider.notifier).refresh(),
                child: Stack(
                  children: [
                    if (loading.value)
                      const Positioned.fill(
                        child: Card(
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ),
                    ListView.separated(
                      shrinkWrap: true,
                      primary: false,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder:
                          (context, i) => _AgreementTile(
                            agreement: list[i],
                            loading: loading,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AgreementTile extends ConsumerWidget {
  const _AgreementTile({required this.agreement, required this.loading});
  final AgreementModel agreement;
  final ValueNotifier<bool> loading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final dateStr = DateFormat(
      'MMM d, yyyy',
    ).format(agreement.createdAt.toLocal());

    return ListTile(
      leading: _StatusIcon(status: agreement.status),
      title: Text(agreement.buyerName),
      subtitle: Text('${agreement.propertyScope} · $dateStr'),
      trailing: _statusChip(agreement.status, cs),
      onTap: () => _handleTap(context, ref),
    );
  }

  Future<void> _handleTap(BuildContext context, WidgetRef ref) async {
    switch (agreement.status) {
      case AgreementStatus.draft:
        context.go('/agreements/${agreement.id}/sign');

      case AgreementStatus.delivered:
        await _sharePdf(context, loading);

      case AgreementStatus.signed:
      case AgreementStatus.pendingDelivery:
        if (context.mounted) await _showDeliverySheet(context, ref);
    }
  }

  Future<void> _sharePdf(
    BuildContext context,
    ValueNotifier<bool> loading,
  ) async {
    loading.value = true;
    await Future.delayed(
      const Duration(milliseconds: 1000),
    ); // allow loading indicator to show
    final path = agreement.localPdfPath;
    if (path == null || !File(path).existsSync()) {
      loading.value = false;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF not found on this device.')),
        );
      }
      return;
    }
    final bytes = await File(path).readAsBytes();
    final filename = path.split('/').last;
    await Printing.sharePdf(bytes: bytes, filename: filename);
    loading.value = false;
  }

  Future<void> _showDeliverySheet(BuildContext context, WidgetRef ref) async {
    final hasPdf =
        agreement.localPdfPath != null &&
        File(agreement.localPdfPath!).existsSync();

    await showModalBottomSheet(
      context: context,
      builder:
          (ctx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                agreement.buyerName,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                agreement.propertyScope,
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.email_outlined),
                    title: const Text('Send via email'),
                    subtitle: const Text(
                      'Delivers to buyer and agent via SendGrid',
                    ),
                    enabled: hasPdf,
                    onTap:
                        hasPdf
                            ? () async {
                              Navigator.pop(ctx);
                              final messenger = ScaffoldMessenger.of(context);
                              final ok = await ref
                                  .read(deliveryServiceProvider)
                                  .deliver(agreement);
                              if (context.mounted) {
                                await ref
                                    .read(agreementListProvider.notifier)
                                    .refresh();
                              }
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    ok
                                        ? 'Agreement sent successfully.'
                                        : 'Failed to send. Check your connection.',
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
                              _sharePdf(context, loading);
                            }
                            : null,
                  ),
                  if (!hasPdf)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      child: Text(
                        'PDF not found on this device.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
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

  Widget _statusChip(AgreementStatus status, ColorScheme cs) {
    final (label, color) = switch (status) {
      AgreementStatus.draft => ('Draft', cs.errorContainer),
      AgreementStatus.signed => ('Signed', cs.secondaryContainer),
      AgreementStatus.pendingDelivery => ('Sending', cs.tertiaryContainer),
      AgreementStatus.delivered => ('Delivered', cs.primaryContainer),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});
  final AgreementStatus status;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (status) {
      AgreementStatus.draft => (Icons.edit_outlined, Colors.orange),
      AgreementStatus.signed => (Icons.check_circle_outline, Colors.blue),
      AgreementStatus.pendingDelivery => (Icons.upload_outlined, Colors.purple),
      AgreementStatus.delivered => (
        Icons.mark_email_read_outlined,
        Colors.green,
      ),
    };
    return CircleAvatar(
      backgroundColor: color.withValues(alpha: 0.15),
      child: Icon(icon, color: color, size: 20),
    );
  }
}
