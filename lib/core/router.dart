import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:threshold/core/presentation/main_shell.dart';
import 'package:threshold/features/agreement/presentation/agreement_actions.dart';
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
import 'package:threshold/features/auth/presentation/setup_screen.dart';
import 'package:threshold/features/auth/presentation/signup_screen.dart';
import 'package:threshold/features/auth/presentation/walkthrough_screen.dart';
import 'package:threshold/features/dashboard/presentation/dashboard_screen.dart';
import 'package:threshold/features/templates/data/template_deal.dart';
import 'package:threshold/features/templates/presentation/template_capture_screen.dart';
import 'package:threshold/features/templates/presentation/template_deal_screen.dart';
import 'package:threshold/features/templates/presentation/template_review_screen.dart';
import 'package:threshold/features/templates/presentation/template_sign_screen.dart';
import 'package:threshold/features/templates/presentation/templates_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthNotifier();
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: notifier,
    redirect: (context, state) {
      final loggedIn = FirebaseAuth.instance.currentUser != null;
      final loc = state.matchedLocation;
      final onAuthPage = loc == '/login' || loc == '/signup';
      final onSetupPage = loc == '/setup';

      if (!loggedIn && !onAuthPage) return '/login';
      if (loggedIn && onAuthPage) return '/home';
      if (loggedIn && onSetupPage) return null;
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, _) => const SignupScreen()),
      GoRoute(
        path: '/setup',
        builder: (_, state) {
          final extra = state.extra as Map<String, String>? ?? {};
          return SetupScreen(
            displayName: extra['displayName'] ?? '',
            email: extra['email'] ?? '',
          );
        },
      ),
      // How Threshold works: once after setup (?first=1), and from Profile.
      GoRoute(
        path: '/welcome',
        builder:
            (_, state) => WalkthroughScreen(
              firstRun: state.uri.queryParameters['first'] == '1',
            ),
      ),
      // Non-shell routes — no bottom nav shown
      GoRoute(
        path: '/agreements/new',
        pageBuilder:
            (_, state) => CustomTransitionPage<void>(
              key: state.pageKey,
              child: const _FormRouter(),
              transitionDuration: const Duration(milliseconds: 260),
              reverseTransitionDuration: const Duration(milliseconds: 260),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) {
                final curved = CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                  reverseCurve: Curves.easeInCubic,
                );
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(1, 0),
                    end: Offset.zero,
                  ).animate(curved),
                  child: child,
                );
              },
            ),
      ),
      // Bring-your-own-form templates.
      GoRoute(path: '/templates', builder: (_, _) => const TemplatesScreen()),
      GoRoute(
        path: '/templates/new',
        builder: (_, _) => const TemplateCaptureScreen(),
      ),
      GoRoute(
        path: '/templates/:id/review',
        builder:
            (_, state) => TemplateReviewScreen(
              templateId: state.pathParameters['id']!,
              // From a deal on an unchecked form: back to that deal.
              thenDeal: state.uri.queryParameters['then'] == 'deal',
            ),
      ),
      GoRoute(
        path: '/templates/:id/deal',
        builder:
            (_, state) =>
                TemplateDealScreen(templateId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/templates/:id/sign',
        // The deal only lives in memory; without it (e.g. a restored route)
        // start the deal over.
        redirect:
            (_, state) =>
                state.extra is TemplateDeal
                    ? null
                    : '/templates/${state.pathParameters['id']}/deal',
        builder:
            (_, state) =>
                TemplateSignScreen(deal: state.extra! as TemplateDeal),
      ),
      GoRoute(
        path: '/agreements/:id/sign',
        builder:
            (_, state) =>
                SignatureScreen(agreementId: state.pathParameters['id']!),
      ),
      // Shell routes — wrapped with floating bottom nav
      ShellRoute(
        builder:
            (context, state, child) =>
                MainShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder:
                (_, _) => const NoTransitionPage(child: DashboardScreen()),
          ),
          GoRoute(
            path: '/agreements',
            pageBuilder:
                (_, state) => NoTransitionPage(
                  child: HistoryScreen(
                    initialFilter: AgreementFilter.parse(
                      state.uri.queryParameters['status'],
                    ),
                  ),
                ),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder:
                (_, _) => const NoTransitionPage(child: ProfileScreen()),
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
  bool _redirected = false;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider);

    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final state = profile.state;
    final approved = kSupportedStates.contains(state);

    if (!approved) {
      // No built-in form for this state: the agent scans their own.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_redirected || !mounted) return;
        _redirected = true;
        context.pushReplacement('/templates/new');
      });

      // Hold a blank shell until the redirect.
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
