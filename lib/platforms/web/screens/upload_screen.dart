import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../services/clinic_api_client.dart';
import '../widgets/web_shell.dart';

/// File upload flow — file picker (drag-drop via HTML5 will land separately).
///
/// Accepts PDF / PNG / JPEG / TIFF up to 50 MB. No camera, no microphone —
/// web app is strictly file-based (primary source: Jane PDF exports,
/// downloads from other EMRs, or scanned files on the practitioner's
/// computer).
class UploadScreen extends ConsumerStatefulWidget {
  const UploadScreen({super.key});

  @override
  ConsumerState<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends ConsumerState<UploadScreen> {
  bool _uploading = false;
  double _uploadProgress = 0;
  String? _error;
  String? _selectedFileName;
  Uint8List? _selectedFileBytes;
  String? _selectedFileMime;

  static const _allowedExtensions = ['pdf', 'png', 'jpg', 'jpeg', 'tif', 'tiff'];
  static const _maxSize = 52428800; // 50 MB

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _allowedExtensions,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes == null) return;

      if (file.size > _maxSize) {
        setState(() => _error = 'File exceeds 50 MB limit');
        return;
      }

      final ext = file.extension?.toLowerCase() ?? '';
      setState(() {
        _selectedFileName = file.name;
        _selectedFileBytes = file.bytes;
        _selectedFileMime = _mimeFromExtension(ext);
        _error = null;
      });
    } catch (e) {
      setState(() => _error = 'Failed to pick file: $e');
    }
  }

  Future<void> _upload() async {
    if (_selectedFileBytes == null || _selectedFileName == null) return;
    setState(() {
      _uploading = true;
      _uploadProgress = 0;
      _error = null;
    });

    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          _selectedFileBytes!,
          filename: _selectedFileName,
          contentType: DioMediaType.parse(_selectedFileMime ?? 'application/octet-stream'),
        ),
        // TODO(patient-picker): show a patient search/create dialog before
        // upload so we can pass a real patient_id. For now the backend will
        // reject this — the patient picker must be wired first.
        'patient_id': 'placeholder',
      });

      final dio = ClinicApiClient.instance.raw;
      final response = await dio.post(
        '/v1/clinic/sessions/upload',
        data: formData,
        onSendProgress: (sent, total) {
          if (total > 0 && mounted) {
            setState(() => _uploadProgress = sent / total);
          }
        },
      );

      if (!mounted) return;

      final status = response.statusCode ?? 0;
      if (status == 202) {
        final visitId = (response.data as Map<String, dynamic>?)?['visit_id'];
        setState(() {
          _uploading = false;
          _selectedFileBytes = null;
          _selectedFileName = null;
        });
        if (mounted && visitId != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Uploaded. Processing OCR... (visit $visitId)'),
              backgroundColor: AppTheme.emerald,
            ),
          );
        }
        return;
      }

      final body = response.data as Map<String, dynamic>? ?? {};
      setState(() {
        _uploading = false;
        _error = (body['error'] as String?) ?? 'Upload failed (HTTP $status)';
      });
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _uploading = false;
          _error = 'Upload failed: ${e.message}';
        });
      }
    }
  }

  void _clearSelection() {
    setState(() {
      _selectedFileBytes = null;
      _selectedFileName = null;
      _selectedFileMime = null;
      _error = null;
    });
  }

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
                if (_selectedFileBytes == null) ...[
                  // Drop zone / picker
                  Container(
                    height: 280,
                    decoration: BoxDecoration(
                      color: const Color(0xFF122B21),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF1D3A31)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.cloud_upload_outlined,
                          size: 56,
                          color: AppTheme.sage,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Upload a clinical report',
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
                ] else ...[
                  // File selected — preview + upload
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF122B21),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF1D3A31)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _selectedFileMime == 'application/pdf'
                                  ? Icons.picture_as_pdf
                                  : Icons.image,
                              color: AppTheme.gold,
                              size: 32,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedFileName ?? 'File',
                                    style: const TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.warmStone,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatSize(_selectedFileBytes!.length),
                                    style: const TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize: 12,
                                      color: AppTheme.sage,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!_uploading)
                              IconButton(
                                onPressed: _clearSelection,
                                icon: const Icon(Icons.close, size: 18),
                                color: AppTheme.sage,
                                tooltip: 'Remove',
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        if (_uploading) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _uploadProgress,
                              backgroundColor: const Color(0xFF1D3A31),
                              valueColor: const AlwaysStoppedAnimation(AppTheme.gold),
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${(_uploadProgress * 100).toInt()}% uploaded',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 12,
                              color: AppTheme.sage,
                            ),
                          ),
                        ] else
                          ElevatedButton(
                            onPressed: _upload,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.gold,
                              foregroundColor: AppTheme.forestTeal,
                              minimumSize: const Size(double.infinity, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Upload and process',
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3A1E1E),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCF6679)),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Color(0xFFCF6679), fontSize: 13),
                    ),
                  ),
                const SizedBox(height: 16),
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

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }

  static String _mimeFromExtension(String ext) {
    return switch (ext) {
      'pdf' => 'application/pdf',
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'tif' || 'tiff' => 'image/tiff',
      _ => 'application/octet-stream',
    };
  }
}
