import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:threshold/features/agreement/data/agreement_model.dart';
import 'package:threshold/features/agreement/data/agreement_repository.dart';
import 'package:threshold/features/agreement/presentation/agreement_actions.dart';
import 'package:threshold/features/auth/data/user_profile.dart';
import 'package:threshold/features/templates/data/form_imports.dart';
import 'package:threshold/features/templates/data/form_template.dart';
import 'package:threshold/features/templates/data/template_repository.dart';
import 'package:threshold/features/templates/presentation/new_agreement_sheet.dart';

/// Home: start an agreement, finish what's waiting, jump to a status or a
/// form. Everything on it can be tapped.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final agreements = ref.watch(agreementListProvider);
    final templates = ref.watch(templatesProvider).valueOrNull ?? const [];
    final imports = ref.watch(formImportsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: agreements.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data:
              (list) => _DashboardContent(
                profile: profile,
                agreements: list,
                templates: templates,
                imports: imports,
              ),
        ),
      ),
    );
  }
}

class _DashboardContent extends ConsumerWidget {
  const _DashboardContent({
    required this.profile,
    required this.agreements,
    required this.templates,
    required this.imports,
  });

  final UserProfile? profile;
  final List<AgreementModel> agreements;
  final List<FormTemplate> templates;
  final List<PendingImport> imports;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final firstName = profile?.firstName ?? '';

    final drafts = [
      for (final a in agreements)
        if (a.status == AgreementStatus.draft) a,
    ];
    final unsent = [
      for (final a in agreements)
        if (a.status == AgreementStatus.pendingDelivery) a,
    ];
    final hasNeeds =
        drafts.isNotEmpty || unsent.isNotEmpty || imports.isNotEmpty;
    final recent = agreements.take(3).toList();

    return ListView(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.paddingOf(context).bottom + 24,
      ),
      children: [
        Text(
          firstName.isEmpty ? 'Hi there' : 'Hi $firstName',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),

        // 1. The main thing an agent does here.
        FilledButton.icon(
          onPressed: () => startNewAgreement(context, ref),
          onLongPress: () => chooseNewAgreement(context, ref),
          icon: const Icon(Icons.add),
          label: const Text('Start agreement'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            textStyle: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),

        // 2. What's waiting on the agent.
        if (hasNeeds) ...[
          const _SectionTitle('Needs you'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: _divided([
                for (final i in imports) _ImportRow(item: i),
                for (final a in drafts.take(3))
                  _NeedRow(
                    icon: Icons.draw_outlined,
                    color: Colors.orange,
                    title: a.buyerName,
                    subtitle: 'Finish signing · ${_date(a.createdAt)}',
                    onTap: () => openAgreement(context, ref, a),
                  ),
                if (drafts.length > 3)
                  _NeedRow(
                    icon: Icons.more_horiz,
                    color: theme.colorScheme.primary,
                    title: '${drafts.length - 3} more drafts',
                    subtitle: 'See all waiting on signatures',
                    onTap: () => context.go('/agreements?status=drafts'),
                  ),
                for (final a in unsent)
                  _NeedRow(
                    icon: Icons.upload_outlined,
                    color: Colors.purple,
                    title: a.buyerName,
                    subtitle: 'Signed, not sent yet · tap to send',
                    onTap: () => openAgreement(context, ref, a),
                  ),
              ]),
            ),
          ),
        ],

        // 3. Counts that open the list filtered.
        if (agreements.isNotEmpty) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              for (final f in AgreementFilter.values) ...[
                if (f != AgreementFilter.values.first) const SizedBox(width: 8),
                Expanded(
                  child: _CountChip(
                    filter: f,
                    count: agreements.where(f.matches).length,
                  ),
                ),
              ],
            ],
          ),
        ],

        // 5. The agent's own forms, one tap from a new deal.
        _SectionTitle(
          'My forms',
          action: templates.isEmpty ? null : 'All forms',
          onAction: () => context.push('/templates'),
        ),
        SizedBox(
          height: 112,
          child: ListView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            children: [
              for (final t in templates)
                _FormCard(
                  icon: Icons.description_outlined,
                  title: t.title,
                  subtitle: 'Start',
                  onTap: () => context.push('/templates/${t.id}/deal'),
                ),
              _FormCard(
                icon: Icons.document_scanner_outlined,
                title: templates.isEmpty ? 'Add your form' : 'Add a form',
                subtitle: 'Scan it once',
                onTap: () => context.push('/templates/new'),
              ),
            ],
          ),
        ),

        // 4. Recent agreements, each one tappable.
        if (recent.isNotEmpty) ...[
          _SectionTitle(
            'Recent',
            action: 'View all',
            onAction: () => context.go('/agreements'),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: _divided([
                for (final a in recent) _RecentAgreementTile(agreement: a),
              ]),
            ),
          ),
        ] else if (!hasNeeds) ...[
          const SizedBox(height: 24),
          Text(
            'Your signed agreements will show up here.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  static List<Widget> _divided(List<Widget> rows) => [
    for (var i = 0; i < rows.length; i++) ...[
      if (i > 0) const Divider(height: 1, indent: 64),
      rows[i],
    ],
  ];
}

String _date(DateTime d) => DateFormat('MMM d').format(d.toLocal());

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 0, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          if (action != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(action!),
            ),
        ],
      ),
    );
  }
}

class _NeedRow extends StatelessWidget {
  const _NeedRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.leading,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading:
          leading ??
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(icon, color: color, size: 20),
          ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

class _ImportRow extends StatelessWidget {
  const _ImportRow({required this.item});
  final PendingImport item;

  @override
  Widget build(BuildContext context) {
    final failed = item.status == ImportStatus.failed;
    final cs = Theme.of(context).colorScheme;
    final pages = '${item.pageCount} page${item.pageCount == 1 ? '' : 's'}';
    return _NeedRow(
      icon: Icons.error_outline,
      color: cs.error,
      leading:
          failed
              ? null
              : const SizedBox(
                width: 40,
                height: 40,
                child: Padding(
                  padding: EdgeInsets.all(10),
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
      title: failed ? 'Form import needs attention' : 'Reading your form…',
      subtitle:
          failed
              ? (item.error ?? 'Tap to try again')
              : '$pages · we’ll let you know when it’s ready',
      onTap: () => context.push('/templates'),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.filter, required this.count});

  final AgreementFilter filter;
  final int count;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = switch (filter) {
      AgreementFilter.drafts => Colors.orange,
      AgreementFilter.signed => Colors.blue,
      AgreementFilter.delivered => Colors.green,
    };
    return Material(
      color: color.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color.withValues(alpha: 0.25)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.go('/agreements?status=${filter.name}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$count',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                filter.label,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: SizedBox(
        width: 150,
        child: Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: cs.primary),
                  const Spacer(),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: cs.primary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentAgreementTile extends ConsumerWidget {
  const _RecentAgreementTile({required this.agreement});
  final AgreementModel agreement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final (label, color) = switch (agreement.status) {
      AgreementStatus.draft => ('Draft', Colors.orange),
      AgreementStatus.signed => ('Signed', Colors.blue),
      AgreementStatus.pendingDelivery => ('Sending', Colors.purple),
      AgreementStatus.delivered => ('Delivered', Colors.green),
    };

    return ListTile(
      onTap: () => openAgreement(context, ref, agreement),
      title: Text(
        agreement.buyerName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${agreement.scopeLabel} · ${_date(agreement.createdAt)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: cs.onSurfaceVariant),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }
}
