import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'screens/license_gate_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const NovaApp());
}

class NovaApp extends StatelessWidget {
  const NovaApp({super.key});

  @override
  Widget build(BuildContext context) {
    const mint = Color(0xFF40D9C4);

    return MaterialApp(
      title: 'NOVA IPTV',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF080D17),
        colorScheme: ColorScheme.fromSeed(
          seedColor: mint,
          brightness: Brightness.dark,
          surface: const Color(0xFF111A2A),
        ),
        useMaterial3: true,
      ),
      home: const LicenseGateScreen(),
    );
  }
}
