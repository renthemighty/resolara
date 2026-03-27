import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../app/theme/app_theme.dart';
import '../generate/generate_screen.dart';

class DescribeScreen extends StatefulWidget {
  const DescribeScreen({super.key});

  @override
  State<DescribeScreen> createState() => _DescribeScreenState();
}

class _DescribeScreenState extends State<DescribeScreen> {
  final _labelController = TextEditingController();
  final _promptController = TextEditingController();
  final _stt = SpeechToText();

  bool _sttAvailable = false;
  bool _listening = false;
  String _sttError = '';

  @override
  void initState() {
    super.initState();
    _initStt();
  }

  @override
  void dispose() {
    _labelController.dispose();
    _promptController.dispose();
    _stt.stop();
    super.dispose();
  }

  Future<void> _initStt() async {
    final available = await _stt.initialize(
      onError: (e) {
        if (mounted) setState(() { _listening = false; _sttError = e.errorMsg; });
      },
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted) setState(() => _listening = false);
        }
      },
    );
    if (mounted) setState(() => _sttAvailable = available);
  }

  Future<void> _toggleListening() async {
    if (_listening) {
      await _stt.stop();
      setState(() => _listening = false);
      return;
    }

    setState(() { _listening = true; _sttError = ''; });

    await _stt.listen(
      onResult: (result) {
        if (mounted) {
          setState(() => _promptController.text = result.recognizedWords);
          _promptController.selection = TextSelection.fromPosition(
            TextPosition(offset: _promptController.text.length),
          );
        }
      },
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 4),
      localeId: 'en_US',
    );
  }

  void _generate() {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a description first.')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GenerateScreen(
          directPrompt: prompt,
          patientName: _labelController.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Describe Instead'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Patient label
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.sage, width: 0.5)),
            ),
            child: TextField(
              controller: _labelController,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.warmStone
                    : AppTheme.emerald,
              ),
              decoration: InputDecoration(
                hintText: 'Patient label (optional)',
                hintStyle: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                prefixIcon: const Icon(Icons.person_outline, size: 18, color: AppTheme.textSecondary),
                isDense: true,
                filled: false,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.sage),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppTheme.sage.withAlpha(120)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),

          // Description input
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Describe what you want to show',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppTheme.warmStone
                          : AppTheme.emerald,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: TextField(
                      controller: _promptController,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppTheme.warmStone
                            : AppTheme.emerald,
                        height: 1.5,
                      ),
                      decoration: InputDecoration(
                        hintText: 'e.g. healthy knee anatomy, or lumbar spine with L4-L5 disc herniation',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary.withAlpha(160),
                          height: 1.5,
                        ),
                        contentPadding: const EdgeInsets.all(14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.sage),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.sage.withAlpha(120)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  if (_sttError.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Mic error: $_sttError',
                      style: const TextStyle(fontSize: 12, color: AppTheme.error),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Bottom bar
          Container(
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              border: Border(top: BorderSide(color: AppTheme.sage, width: 0.5)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Row(
              children: [
                if (_sttAvailable)
                  _MicButton(listening: _listening, onTap: _toggleListening),
                if (_sttAvailable) const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _generate,
                    icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                    label: const Text('Generate Visualization'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  final bool listening;
  final VoidCallback onTap;
  const _MicButton({required this.listening, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: listening ? AppTheme.error.withAlpha(30) : AppTheme.sage.withAlpha(30),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: listening ? AppTheme.error : AppTheme.sage.withAlpha(120),
            width: 1.5,
          ),
        ),
        child: Icon(
          listening ? Icons.stop_rounded : Icons.mic_outlined,
          color: listening ? AppTheme.error : AppTheme.textSecondary,
          size: 24,
        ),
      ),
    );
  }
}
