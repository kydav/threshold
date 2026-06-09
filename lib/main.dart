import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(const ProviderScope(child: ThresholdApp()));
}

class ThresholdApp extends StatelessWidget {
  const ThresholdApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Threshold',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B4332), // deep forest green
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(child: Text('Threshold')),
      ),
    );
  }
}
