import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../app/theme/app_theme.dart';
import '../../core/models/captured_report.dart';
import '../../core/utils/image_processor.dart';
import '../../shared/widgets/loading_overlay.dart';
import 'preview_screen.dart';

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

      if (!ImageProcessor.isAcceptedType(rawFile.path) &&
          !rawFile.path.toLowerCase().endsWith('.pdf')) {
        setState(() {
          _error = 'Unsupported file type. Please choose a JPEG, PNG, or PDF.';
          _processing = false;
        });
        return;
      }

      // Strip EXIF/metadata from image files (PDFs are passed through for now)
      final File processed;
      if (rawFile.path.toLowerCase().endsWith('.pdf')) {
        processed = rawFile;
      } else {
        processed = await ImageProcessor.stripMetadata(rawFile);
      }

      if (!mounted) return;

      setState(() => _processing = false);

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PreviewScreen(
            report: CapturedReport(
              file: processed,
              capturedAt: DateTime.now(),
              source: source,
            ),
          ),
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
          appBar: AppBar(title: const Text('New Report')),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                const Icon(Icons.document_scanner_outlined,
                    size: 72, color: AppTheme.primary),
                const SizedBox(height: 24),
                const Text(
                  'Capture or import a medical report',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Image metadata is removed before processing.\nAll identifying information is stripped before analysis.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary),
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
                      _processing ? null : () => _handleSource(CaptureSource.import),
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Import from Files'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.gold,
                    side: const BorderSide(color: AppTheme.gold),
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
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
