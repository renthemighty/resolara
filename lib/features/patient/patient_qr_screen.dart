import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../app/theme/app_theme.dart';
import '../../core/services/analytics_service.dart';
import 'patient_results_screen.dart';

class PatientQrScreen extends StatefulWidget {
  const PatientQrScreen({super.key});

  @override
  State<PatientQrScreen> createState() => _PatientQrScreenState();
}

class _PatientQrScreenState extends State<PatientQrScreen> {
  final _scanner  = MobileScannerController();
  final _codeCtrl = TextEditingController();

  // Synchronous lock — set BEFORE any await so rapid onDetect calls are dropped
  bool _busy = false;

  @override
  void dispose() {
    _scanner.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleCode(String raw) async {
    // Synchronous guard — must be first, before any await
    if (_busy) return;
    _busy = true;

    // Extract the code — handles: resolara://results/ABCDEF, https://.../ABCDEF, bare ABCDEF
    final uri = Uri.tryParse(raw);
    final code = (uri != null && uri.pathSegments.isNotEmpty
            ? uri.pathSegments.last
            : raw)
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .toUpperCase();

    if (code.isEmpty) {
      _busy = false;
      return;
    }

    await _scanner.stop();
    if (!mounted) { _busy = false; return; }

    final isManual = _codeCtrl.text.trim().toUpperCase()
            .replaceAll(RegExp(r'[^A-Z0-9]'), '') ==
        code;
    if (isManual) {
      Analytics.shareCodeSubmitted();
    } else {
      Analytics.qrScanned();
    }

    // Navigate immediately — PatientResultsScreen handles all loading
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => PatientResultsScreen(shareCode: code)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        leading: IconButton(
          icon:     const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // ── Scanner viewport ────────────────────────────────────────────
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                MobileScanner(
                  controller: _scanner,
                  onDetect: (capture) {
                    final code = capture.barcodes.firstOrNull?.rawValue;
                    if (code != null) _handleCode(code);
                  },
                ),
                Center(
                  child: Container(
                    width:  220,
                    height: 220,
                    decoration: BoxDecoration(
                      border:       Border.all(color: AppTheme.gold, width: 2.5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Manual code entry ───────────────────────────────────────────
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Or enter a share code manually',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller:         _codeCtrl,
                    decoration: const InputDecoration(
                      hintText:   'Share code',
                      suffixIcon: Icon(Icons.vpn_key_outlined),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    onSubmitted:        (_) => _handleCode(_codeCtrl.text.trim()),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: () => _handleCode(_codeCtrl.text.trim()),
                    child:     const Text('Load Results'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
