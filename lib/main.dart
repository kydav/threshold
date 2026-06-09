import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/services/connectivity_watcher.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: ThresholdApp()));
}

class ThresholdApp extends ConsumerWidget {
  const ThresholdApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Start connectivity watcher so pending deliveries retry on reconnect.
    ref.watch(connectivityWatcherProvider);

    return MaterialApp(
      title: 'Threshold',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B4332),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const Scaffold(body: Center(child: Text('Threshold'))),
    );
  }
}
