import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:threshold/features/agreement/data/agreement_model.dart';
import 'package:threshold/features/agreement/data/agreement_repository.dart';
import 'package:threshold/features/agreement/presentation/agreement_actions.dart';

class HistoryScreen extends HookConsumerWidget {
  const HistoryScreen({super.key, this.initialFilter});

  /// Set when opened from one of Home's counts.
  final AgreementFilter? initialFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agreements = ref.watch(agreementListProvider);
    final cs = Theme.of(context).colorScheme;
    final loading = useState(false);
    final filter = useState(initialFilter);
    useEffect(() {
      filter.value = initialFilter;
      return null;
    }, [initialFilter]);
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
        data: (all) {
          if (all.isEmpty) {
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
          final list = [
            for (final a in all)
              if (filter.value?.matches(a) ?? true) a,
          ];
          // The shell's floating nav overlaps the body (extendBody); its
          // height arrives as bottom padding, so stop the list above it.
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              MediaQuery.paddingOf(context).bottom + 12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final f in [null, ...AgreementFilter.values])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(
                              f == null
                                  ? 'All ${all.length}'
                                  : '${f.label} ${all.where(f.matches).length}',
                            ),
                            selected: filter.value == f,
                            onSelected: (_) => filter.value = f,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (list.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 32),
                    child: Text(
                      'No ${filter.value!.label.toLowerCase()} agreements.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  )
                else
                  Flexible(child: _list(context, ref, list, loading)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _list(
    BuildContext context,
    WidgetRef ref,
    List<AgreementModel> list,
    ValueNotifier<bool> loading,
  ) {
    return Card(
      child: RefreshIndicator(
        onRefresh: () => ref.read(agreementListProvider.notifier).refresh(),
        child: Stack(
          children: [
            if (loading.value)
              const Positioned.fill(
                child: Card(child: Center(child: CircularProgressIndicator())),
              ),
            ListView.separated(
              shrinkWrap: true,
              primary: false,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: list.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder:
                  (context, i) =>
                      _AgreementTile(agreement: list[i], loading: loading),
            ),
          ],
        ),
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
      subtitle: Text('${agreement.scopeLabel} · $dateStr'),
      trailing: _statusChip(agreement.status, cs),
      onTap: () => openAgreement(context, ref, agreement, loading: loading),
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
