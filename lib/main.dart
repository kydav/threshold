import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:threshold/core/router.dart';
import 'package:threshold/core/services/connectivity_watcher.dart';
import 'package:threshold/core/services/remote_config_service.dart';
import 'package:threshold/core/services/subscription_service.dart';
import 'package:threshold/features/auth/data/user_profile.dart';
import 'package:threshold/features/templates/data/form_imports.dart';
import 'package:threshold/firebase_options.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      if (!kDebugMode) {
        FlutterError.onError =
            FirebaseCrashlytics.instance.recordFlutterFatalError;
        PlatformDispatcher.instance.onError = (error, stack) {
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
          return true;
        };
      }

      try {
        await configureRevenueCat();
      } catch (e, s) {
        debugPrint('RevenueCat init failed: $e');
        if (!kDebugMode) {
          await FirebaseCrashlytics.instance.recordError(e, s);
        }
      }

      final remoteConfig = await RemoteConfigService.initSafe();
      runApp(
        ProviderScope(
          overrides: [remoteConfigProvider.overrideWithValue(remoteConfig)],
          child: const ThresholdApp(),
        ),
      );
    },
    (error, stack) {
      if (!kDebugMode) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      }
    },
  );
}

/// App-wide messages, e.g. a form that finished setting up in the background.
final _messengerKey = GlobalKey<ScaffoldMessengerState>();

class ThresholdApp extends ConsumerWidget {
  const ThresholdApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(connectivityWatcherProvider);
    ref.watch(profileLoaderProvider);
    // Keeps background form imports polling app-wide.
    ref.watch(formImportsProvider);
    final router = ref.watch(routerProvider);
    ref.listen(formReadyProvider, (_, template) {
      if (template == null) return;
      ref.read(formReadyProvider.notifier).state = null;
      _messengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Your form "${template.title}" is ready to review.'),
          duration: const Duration(seconds: 10),
          action: SnackBarAction(
            label: 'Review',
            onPressed: () => router.push('/templates/${template.id}/review'),
          ),
        ),
      );
    });

    return MaterialApp.router(
      title: 'Threshold',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messengerKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E56B2)),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D3B66),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
