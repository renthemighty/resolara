import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../widgets/web_shell.dart';

/// File upload flow — drag-drop / file picker / OS "open with" handler.
///
/// Accepts PDF / PNG / JPEG / TIFF up to 50 MB. No camera, no microphone —
/// web app is strictly file-based (primary source: Jane PDF exports,
/// downloads from other EMRs, or scanned files on the practitioner's
/// computer). Browser camera/microphone permissions are blocked by the
/// Permissions-Policy header on app.resolara.ai.
class UploadScreen extends ConsumerStatefulWidget {
  const UploadScreen({super.key});

  @override
  ConsumerState<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends ConsumerState<UploadScreen> {
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    return WebShell(
      title: 'Upload report',
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 280,
                  decoration: BoxDecoration(
                    color: _dragging
                        ? const Color(0xFF163A2E)
                        : const Color(0xFF122B21),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _dragging
                          ? AppTheme.gold
                          : const Color(0xFF1D3A31),
                      width: _dragging ? 2 : 1,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.cloud_upload_outlined,
                        size: 56,
                        color: _dragging ? AppTheme.gold : AppTheme.sage,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Drop a clinical report here',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.warmStone,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'PDF, PNG, JPEG, or TIFF up to 50 MB',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 13,
                          color: AppTheme.sage,
                        ),
                      ),
                      const SizedBox(height: 20),
                      OutlinedButton(
                        onPressed: _pickFile,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.warmStone,
                          side: const BorderSide(color: AppTheme.sage),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Choose file'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Files are uploaded directly to Resolara and processed on '
                  'Canadian servers. Original files are retained for 90 days '
                  'then deleted.',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12,
                    color: AppTheme.sage,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    // TODO(web-upload): wire file_picker + drag-drop (dart:html FileReader)
    // and POST to /api/sessions/upload as multipart/form-data with CSRF
    // token. Show progress, thumbnail preview via pdfx, patient picker,
    // then navigate to findings review once OCR + extraction complete.
  }
}
