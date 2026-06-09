import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:threshold/features/agreement/presentation/colorado_form_screen.dart';
import 'package:threshold/features/agreement/presentation/form_screen.dart';
import 'package:threshold/features/agreement/presentation/history_screen.dart';
import 'package:threshold/features/agreement/presentation/signature_screen.dart';
import 'package:threshold/features/auth/data/agent_profile_store.dart';
import 'package:threshold/features/auth/presentation/login_screen.dart';
import 'package:threshold/features/auth/presentation/signup_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthNotifier();
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: notifier,
    redirect: (context, state) {
      final loggedIn = FirebaseAuth.instance.currentUser != null;
      final onAuthPage = state.matchedLocation == '/login' ||
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
          GoRoute(
            path: 'new',
            builder: (_, _) => const _FormRouter(),
          ),
          GoRoute(
            path: ':id/sign',
            builder: (_, state) => SignatureScreen(
              agreementId: state.pathParameters['id']!,
            ),
          ),
        ],
      ),
    ],
  );
});

/// Reads the agent's state and routes to the correct state-specific form.
class _FormRouter extends ConsumerWidget {
  const _FormRouter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(agentProfileProvider);
    return profileAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => const FormScreen(),
      data: (profile) {
        final state = profile?.state ?? 'Colorado';
        return switch (state) {
          'Colorado' => const ColoradoFormScreen(),
          _ => const FormScreen(),
        };
      },
    );
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
