import 'package:flutter/material.dart';

import '../services/licensing_service.dart';
import 'home_screen.dart';

class LicenseGateScreen extends StatefulWidget {
  const LicenseGateScreen({super.key});

  @override
  State<LicenseGateScreen> createState() => _LicenseGateScreenState();
}

class _LicenseGateScreenState extends State<LicenseGateScreen> {
  final _keyController = TextEditingController();
  bool _busy = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkExistingLicense();
  }

  Future<void> _checkExistingLicense() async {
    try {
      final valid = await LicensingService.validate();
      if (!mounted) return;
      if (valid) {
        _openHome();
        return;
      }
    } catch (_) {
      // Keep the activation screen visible when the server cannot be reached.
    }
    if (mounted) setState(() => _busy = false);
  }

  void _openHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  Future<void> _activate() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      setState(() => _error = 'اكتب مفتاح الترخيص أولاً');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await LicensingService.activate(key);
      final valid = await LicensingService.validate();
      if (!valid) {
        throw Exception('لم يتم اعتماد الترخيص من الخادم');
      }
      if (mounted) _openHome();
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const mint = Color(0xFF40D9C4);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.live_tv_rounded, size: 66, color: mint),
                const SizedBox(height: 18),
                const Text(
                  'NOVA IPTV',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  'أدخل مفتاح الترخيص لتفعيل البرنامج',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 15),
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: _keyController,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                    labelText: 'مفتاح الترخيص',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.key),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busy ? null : _activate,
                  style: FilledButton.styleFrom(
                    backgroundColor: mint,
                    foregroundColor: const Color(0xFF07131A),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 21,
                          height: 21,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('تفعيل البرنامج'),
                ),
                const SizedBox(height: 16),
                const Text(
                  'لشراء الترخيص، تواصل مع جهة البيع.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
