import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:threshold/core/services/subscription_service.dart';

/// Shows a modal bottom sheet paywall and returns true if the user
/// successfully subscribes.
Future<bool> showPaywall(BuildContext context) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _PaywallSheet(),
  );
  return result ?? false;
}

class _PaywallSheet extends ConsumerStatefulWidget {
  const _PaywallSheet();

  @override
  ConsumerState<_PaywallSheet> createState() => _PaywallSheetState();
}

class _PaywallSheetState extends ConsumerState<_PaywallSheet> {
  bool _loading = false;
  String? _error;

  Future<void> _purchase() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ok = await ref.read(subscriptionProvider.notifier).purchase();
      if (mounted) Navigator.of(context).pop(ok);
    } catch (e) {
      if (mounted) {
        setState(() {
          if (e is PlatformException &&
              e.message != null &&
              e.message!.contains('cancelled')) {
            _error = 'Purchase cancelled.';
            return;
          }
          if (e is Exception) {
            _error = 'Purchase failed: ${e.toString()}';
          } else {
            _error = 'Purchase failed: $e';
          }
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _restore() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(subscriptionProvider.notifier).restore();
      final isPro = ref.read(subscriptionProvider.notifier).isProActive;
      if (mounted) Navigator.of(context).pop(isPro);
    } catch (e) {
      if (mounted) setState(() => _error = 'Restore failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: cs.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Icon(Icons.workspace_premium_rounded, size: 56, color: cs.primary),
          const SizedBox(height: 16),
          Text(
            'Unlock Threshold Pro',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            "You've used your 2 free agreements.",
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          ..._features(cs),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _loading ? null : _purchase,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child:
                _loading
                    ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Text(
                      'Subscribe — \$4.99 / month',
                      style: TextStyle(fontSize: 16),
                    ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _loading ? null : _restore,
            child: const Text('Restore previous purchase'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: cs.error, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Subscription renews monthly. Cancel anytime.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  List<Widget> _features(ColorScheme cs) {
    const features = [
      (Icons.all_inclusive, 'Unlimited buyer agreements'),
      (Icons.picture_as_pdf_outlined, 'PDF generation for every agreement'),
      (Icons.email_outlined, 'Auto email delivery to you and your clients'),
      (Icons.history_outlined, 'Full agreement history on this device'),
    ];
    return features
        .map(
          (f) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(f.$1, size: 20, color: cs.primary),
                const SizedBox(width: 12),
                Text(f.$2, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        )
        .toList();
  }
}
