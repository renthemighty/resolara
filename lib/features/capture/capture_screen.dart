import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../app/theme/app_theme.dart';
import '../../core/models/captured_report.dart';
import '../../shared/widgets/loading_overlay.dart';
import 'preview_screen.dart';
import '../reader/reader_screen.dart';
import '../describe/describe_screen.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  bool _processing = false;
  String? _error;

  Future<void> _handleSource(CaptureSource source) async {
    setState(() {
      _processing = true;
      _error = null;
    });

    try {
      File? rawFile;

      if (source == CaptureSource.camera) {
        final picked = await ImagePicker().pickImage(
          source: ImageSource.camera,
          imageQuality: 100,
          requestFullMetadata: false,
        );
        if (picked == null) {
          setState(() => _processing = false);
          return;
        }
        rawFile = File(picked.path);
      } else if (source == CaptureSource.photos) {
        final picked = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          imageQuality: 100,
          requestFullMetadata: false,
        );
        if (picked == null) {
          setState(() => _processing = false);
          return;
        }
        rawFile = File(picked.path);
      } else {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['jpg', 'jpeg', 'png', 'heic', 'heif', 'webp', 'pdf'],
          allowMultiple: false,
        );
        if (result == null || result.files.single.path == null) {
          setState(() => _processing = false);
          return;
        }
        rawFile = File(result.files.single.path!);
      }

      final ext = rawFile.path.toLowerCase();
      final isPdf = ext.endsWith('.pdf');
      final isImage = ext.endsWith('.jpg') || ext.endsWith('.jpeg') ||
          ext.endsWith('.png') || ext.endsWith('.heic') ||
          ext.endsWith('.heif') || ext.endsWith('.webp');

      if (!isPdf && !isImage) {
        setState(() {
          _error = 'Unsupported file type. Please choose a JPEG, PNG, or PDF.';
          _processing = false;
        });
        return;
      }

      if (!mounted) return;

      setState(() => _processing = false);

      final report = CapturedReport(
        file: rawFile,
        capturedAt: DateTime.now(),
        source: source,
      );

      // PDFs can't be previewed as an image — go straight to ReaderScreen
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => report.isPdf
              ? ReaderScreen(report: report)
              : PreviewScreen(report: report),
        ),
      );
    } catch (e) {
      setState(() {
        _error = 'Could not load image. Please try again.';
        _processing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(title: const Text('Resolara')),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Image.asset(
                  'assets/images/SMALL-Resolara_V5.png',
                  height: 200,
                  width: 200,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.document_scanner_outlined, size: 72, color: AppTheme.primary),
                ),
                const SizedBox(height: 24),
                Text(
                  'Capture or Upload Report',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppTheme.warmStone
                          : AppTheme.emerald),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppTheme.error, fontSize: 13),
                    ),
                  ),
                ],
                const Spacer(),
                ElevatedButton.icon(
                  onPressed:
                      _processing ? null : () => _handleSource(CaptureSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Take Photo'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed:
                      _processing ? null : () => _handleSource(CaptureSource.photos),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Choose from Photos'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed:
                      _processing ? null : () => _handleSource(CaptureSource.import),
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Import from Files'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _processing
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const DescribeScreen()),
                          ),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Describe Instead'),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
        if (_processing)
          const LoadingOverlay(message: 'Processing image…'),
      ],
    );
  }
}
