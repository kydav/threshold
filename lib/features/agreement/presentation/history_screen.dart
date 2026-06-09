import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../data/agreement_model.dart';
import '../data/agreement_repository.dart';
import '../../auth/data/auth_service.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agreements = ref.watch(agentAgreementsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agreements'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => ref.read(authServiceProvider).signOut(),
          ),
        ],
      ),
      body: agreements.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.description_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.outlineVariant),
                  const SizedBox(height: 16),
                  const Text('No agreements yet'),
                  const SizedBox(height: 8),
                  const Text('Tap + to start one at a showing'),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) => _AgreementTile(agreement: list[i]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/agreements/new'),
        icon: const Icon(Icons.add),
        label: const Text('New agreement'),
      ),
    );
  }
}

class _AgreementTile extends StatelessWidget {
  const _AgreementTile({required this.agreement});
  final AgreementModel agreement;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dateStr =
        DateFormat('MMM d, yyyy').format(agreement.createdAt.toLocal());

    return ListTile(
      leading: _StatusIcon(status: agreement.status),
      title: Text(agreement.buyerName),
      subtitle: Text('${agreement.propertyScope} · $dateStr'),
      trailing: _statusChip(agreement.status, cs),
      onTap: () {
        if (agreement.status == AgreementStatus.draft) {
          context.go('/agreements/${agreement.id}/sign');
        }
      },
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
      AgreementStatus.delivered =>
        (Icons.mark_email_read_outlined, Colors.green),
    };
    return CircleAvatar(
      backgroundColor: color.withOpacity(0.15),
      child: Icon(icon, color: color, size: 20),
    );
  }
}
