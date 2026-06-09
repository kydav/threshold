import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/agreement/presentation/history_screen.dart';
import '../features/agreement/presentation/form_screen.dart';
import '../features/agreement/presentation/signature_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/signup_screen.dart';

final _authStream = FirebaseAuth.instance.authStateChanges();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final user = FirebaseAuth.instance.currentUser;
      final onAuthPage = state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup';

      if (user == null && !onAuthPage) return '/login';
      if (user != null && onAuthPage) return '/agreements';
      return null;
    },
    refreshListenable: _GoRouterRefreshStream(_authStream),
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, __) => const SignupScreen()),
      GoRoute(path: '/agreements', builder: (_, __) => const HistoryScreen()),
      GoRoute(
        path: '/agreements/new',
        builder: (_, __) => const FormScreen(),
      ),
      GoRoute(
        path: '/agreements/:id/sign',
        builder: (_, state) =>
            SignatureScreen(agreementId: state.pathParameters['id']!),
      ),
    ],
  );
});

class _GoRouterRefreshStream extends ChangeNotifier {
  _GoRouterRefreshStream(Stream<dynamic> stream) {
    stream.listen((_) => notifyListeners());
  }
}
