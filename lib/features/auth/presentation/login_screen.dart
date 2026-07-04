import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:threshold/core/services/analytics_service.dart';
import 'package:threshold/features/auth/data/auth_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _socialLoading = false;
  String? _error;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final authService = ref.read(authServiceProvider);
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    try {
      await authService.signIn(email: email, password: password);
      AnalyticsService.login();
    } on Exception catch (e) {
      if (mounted) setState(() => _error = _friendlyError(e.toString()));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_emailCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Enter your email above first.');
      return;
    }
    await ref
        .read(authServiceProvider)
        .sendPasswordResetEmail(email: _emailCtrl.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent.')),
      );
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _socialLoading = true;
      _error = null;
    });
    try {
      final result = await ref.read(authServiceProvider).signInWithGoogle();
      if (!mounted) return;
      if (result.isNewUser) {
        context.go(
          '/setup',
          extra: {'displayName': result.displayName, 'email': result.email},
        );
      }
      // Returning users: router redirect handles navigation to /agreements.
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _friendlySocialError(e.code));
    } on Exception catch (e) {
      final msg = e.toString();
      if (mounted && !msg.contains('cancelled')) {
        setState(() => _error = 'Google sign-in failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _socialLoading = false);
    }
  }

  Future<void> _signInWithApple() async {
    setState(() {
      _socialLoading = true;
      _error = null;
    });
    try {
      final result = await ref.read(authServiceProvider).signInWithApple();
      if (!mounted) return;
      if (result.isNewUser) {
        context.go(
          '/setup',
          extra: {'displayName': result.displayName, 'email': result.email},
        );
      }
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code != AuthorizationErrorCode.canceled && mounted) {
        setState(
          () => _error = 'Apple sign-in was interrupted. Please try again.',
        );
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('Apple FirebaseAuthException: ${e.code} — ${e.message}');
      if (mounted) setState(() => _error = _friendlySocialError(e.code));
    } on Exception catch (e) {
      debugPrint('Apple sign-in Exception: $e');
      final msg = e.toString();
      if (mounted && !msg.contains('cancelled') && !msg.contains('cancel')) {
        setState(() => _error = 'Apple sign-in failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _socialLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              Theme.of(context).brightness == Brightness.light
                  ? 'assets/images/background.png'
                  : 'assets/images/background_dark.png',
              fit: BoxFit.cover,
              alignment: Alignment.bottomCenter,
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Image.asset(
                        'assets/icon/icon_transparent.png',
                        height: 120,
                      ),
                      Text(
                        'Threshold',
                        style: Theme.of(
                          context,
                        ).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.primary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Buyer agreements, done at the door.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 48),
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                        ),
                        validator:
                            (v) =>
                                (v == null || !v.contains('@'))
                                    ? 'Enter a valid email'
                                    : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        autofillHints: const [AutofillHints.password],
                        decoration: InputDecoration(
                          labelText: 'Password',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed:
                                () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator:
                            (v) =>
                                (v == null || v.length < 6)
                                    ? 'Min 6 characters'
                                    : null,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: TextStyle(color: cs.error),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed:
                            (_loading || _socialLoading) ? null : _submit,
                        child:
                            _loading
                                ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Text('Log in'),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _resetPassword,
                        child: const Text('Forgot password?'),
                      ),

                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'or',
                              style: TextStyle(color: cs.onSurfaceVariant),
                            ),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 8),

                      OutlinedButton.icon(
                        onPressed:
                            (_loading || _socialLoading)
                                ? null
                                : _signInWithGoogle,
                        icon: Image.asset(
                          'assets/icon/google.png',
                          height: 18,
                          width: 18,
                          errorBuilder:
                              (ctx, err, stack) =>
                                  const Icon(Icons.login, size: 18),
                        ),
                        label: const Text('Continue with Google'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed:
                            (_loading || _socialLoading)
                                ? null
                                : _signInWithApple,
                        icon: const Icon(
                          Icons.apple,
                          size: 25,
                          color: Colors.black,
                        ),
                        label: const Text('Continue with Apple'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),

                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () => context.go('/signup'),
                        child: const Text("Don't have an account? Sign up"),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _friendlyError(String raw) {
    if (raw.contains('user-not-found') ||
        raw.contains('wrong-password') ||
        raw.contains('invalid-credential')) {
      return 'Incorrect email or password.';
    }
    if (raw.contains('too-many-requests')) {
      return 'Too many attempts. Try again later.';
    }
    return 'Sign-in failed. Please try again.';
  }

  String _friendlySocialError(String code) {
    switch (code) {
      case 'account-exists-with-different-credential':
        return 'An account already exists with this email. Sign in with your email and password instead — use "Forgot password?" if needed.';
      case 'invalid-credential':
      case 'invalid-verification-code':
      case 'invalid-verification-id':
        return 'Apple sign-in failed. Sign out of your Apple ID in Settings, sign back in, then try again.';
      case 'credential-already-in-use':
        return 'This Apple ID is already linked to a different account.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'operation-not-allowed':
        return "This sign-in method isn't enabled. Please contact support.";
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      default:
        return 'Sign-in failed. Please try again.';
    }
  }
}
