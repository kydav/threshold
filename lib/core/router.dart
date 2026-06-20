import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:threshold/features/agreement/presentation/colorado_form_screen.dart';
import 'package:threshold/features/agreement/presentation/form_screen.dart';
import 'package:threshold/features/agreement/presentation/history_screen.dart';
import 'package:threshold/features/agreement/presentation/louisiana_form_screen.dart';
import 'package:threshold/features/agreement/presentation/oklahoma_form_screen.dart';
import 'package:threshold/features/agreement/presentation/signature_screen.dart';
import 'package:threshold/features/agreement/presentation/wisconsin_form_screen.dart';
import 'package:threshold/features/auth/data/user_profile.dart';
import 'package:threshold/features/auth/presentation/login_screen.dart';
import 'package:threshold/features/auth/presentation/profile_screen.dart';
import 'package:threshold/features/auth/presentation/signup_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthNotifier();
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: notifier,
    redirect: (context, state) {
      final loggedIn = FirebaseAuth.instance.currentUser != null;
      final onAuthPage =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup';

      if (!loggedIn && !onAuthPage) return '/login';
      if (loggedIn && onAuthPage) return '/agreements';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, _) => const SignupScreen()),
      GoRoute(
        path: '/agreements',
        builder: (_, _) => const HistoryScreen(),
        routes: [
          GoRoute(path: 'new', builder: (_, _) => const _FormRouter()),
          GoRoute(path: 'profile', builder: (_, _) => const ProfileScreen()),
          GoRoute(
            path: ':id/sign',
            builder:
                (_, state) =>
                    SignatureScreen(agreementId: state.pathParameters['id']!),
          ),
        ],
      ),
    ],
  );
});

/// Watches the agent profile and routes to the correct state-specific form.
/// Shows a loader while the profile is still being fetched from Firestore.
class _FormRouter extends ConsumerStatefulWidget {
  const _FormRouter();

  @override
  ConsumerState<_FormRouter> createState() => _FormRouterState();
}

class _FormRouterState extends ConsumerState<_FormRouter> {
  bool _shownUnsupportedSheet = false;
  Future<void> _showUnsupportedStateSheet(String state) async {
    if (_shownUnsupportedSheet || !mounted) return;
    _shownUnsupportedSheet = true;

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (_) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'State not supported yet',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text('$state forms are not available yet.'),
                const Text(
                  'Please contact your local board, state association or broker and have them reach out to hello@auaha.app to get your state added to the platform.',
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'),
                  ),
                ),
              ],
            ),
          ),
    );

    if (mounted) context.go('/agreements');
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider);

    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final state = profile.state;
    final approved = kSupportedStates.contains(state);

    if (!approved) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showUnsupportedStateSheet(state);
      });

      // Hold a blank shell while the sheet is shown.
      return const Scaffold(body: SizedBox.shrink());
    }
    return switch (profile.state) {
      'Colorado' => const ColoradoFormScreen(),
      'Louisiana' => const LouisianaFormScreen(),
      'Oklahoma' => const OklahomaFormScreen(),
      //'Utah' => const UtahFormScreen(),
      'Wisconsin' => const WisconsinFormScreen(),
      _ => const FormScreen(),
    };
  }
}

class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier() {
    _sub = FirebaseAuth.instance.authStateChanges().listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<User?> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
