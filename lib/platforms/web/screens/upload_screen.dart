import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../services/clinic_api_client.dart';
import '../services/tesseract_ocr_service.dart';
import '../widgets/web_shell.dart';

/// File upload flow — file picker (drag-drop via HTML5 will land separately).
///
/// Accepts PDF / PNG / JPEG / TIFF up to 50 MB. No camera, no microphone —
/// web app is strictly file-based (primary source: Jane PDF exports,
/// downloads from other EMRs, or scanned files on the practitioner's
/// computer).
///
/// PRIVACY: raw image bytes (PNG/JPEG/TIFF) are NEVER uploaded. They are
/// OCR'd entirely in-browser (tesseract.js, see [TesseractOcrService]) and
/// only the recognized TEXT is submitted, via
/// POST /v1/clinic/sessions/upload-text. This mirrors the mobile app's
/// on-device ML Kit OCR for the web surface.
///
/// PDFs are still uploaded to the server (POST /v1/clinic/sessions/upload)
/// because the server can extract embedded text locally via Ghostscript in
/// ~50ms with no OCR/vendor call at all — this is the dominant case
/// (practitioner-exported PDFs from an EMR). If a PDF turns out to be a
/// scanned image with no text layer, the server does NOT rasterize and OCR
/// it — it fails with `SCANNED_PDF_NO_TEXT_LAYER`, and this screen asks the
/// practitioner to export/screenshot the pages as images instead, which
/// then take the safe in-browser OCR path above.
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

  /// Status line shown during in-browser OCR / post-upload document checks
  /// (distinct from raw upload progress, which doesn't apply to those steps).
  String? _ocrHint;

  // Patient picker state
  Map<String, dynamic>? _selectedPatient;
  bool _showPatientPicker = false;

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

  bool get _isPdf => _selectedFileMime == 'application/pdf';

  Future<void> _upload() async {
    if (_selectedFileBytes == null || _selectedFileName == null) return;
    if (_selectedPatient == null) {
      setState(() => _error = 'Select a patient before uploading');
      return;
    }

    setState(() {
      _uploading = true;
      _uploadProgress = 0;
      _ocrHint = null;
      _error = null;
    });

    try {
      if (_isPdf) {
        await _uploadPdf();
      } else {
        await _uploadImageViaBrowserOcr();
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _uploading = false;
          _ocrHint = null;
          _error = 'Upload failed: ${e.message}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _uploading = false;
          _ocrHint = null;
          _error = 'OCR failed: $e';
        });
      }
    }
  }

  /// PDFs go to the server as a file — Ghostscript extracts embedded text
  /// locally in ~50ms, no OCR/vendor call. If the PDF turns out to have no
  /// text layer (a scanned document), the server rejects it rather than
  /// rasterizing and OCR'ing it server-side; this briefly polls for that
  /// specific failure so the practitioner can be redirected to the
  /// in-browser image OCR path instead of just seeing a silent stall.
  Future<void> _uploadPdf() async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        _selectedFileBytes!,
        filename: _selectedFileName,
        contentType: DioMediaType.parse(_selectedFileMime ?? 'application/pdf'),
      ),
      'patient_id': _selectedPatient!['id'] as String,
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
    await _handleUploadAccepted(response, pdfPath: true);
  }

  /// Images never leave the browser as raw bytes: OCR runs entirely
  /// client-side via tesseract.js, and only the recognized text is POSTed.
  Future<void> _uploadImageViaBrowserOcr() async {
    setState(() => _ocrHint = 'Reading text from the image in your browser...');
    final text = await TesseractOcrService.recognizeBytes(
      _selectedFileBytes!,
      mime: _selectedFileMime ?? 'image/png',
    );
    if (!mounted) return;

    if (text.trim().length < 20) {
      setState(() {
        _uploading = false;
        _ocrHint = null;
        _error = 'Could not read text from this image. Try a clearer photo or scan.';
      });
      return;
    }

    setState(() => _ocrHint = 'Submitting recognized text...');
    final dio = ClinicApiClient.instance.raw;
    final response = await dio.post('/v1/clinic/sessions/upload-text', data: {
      'patient_id': _selectedPatient!['id'] as String,
      'cleaned_report_text': text,
      'source_mime': _selectedFileMime ?? 'image/png',
      'original_filename': _selectedFileName,
    });
    if (!mounted) return;
    await _handleUploadAccepted(response, pdfPath: false);
  }

  Future<void> _handleUploadAccepted(Response response, {required bool pdfPath}) async {
    final status = response.statusCode ?? 0;
    if (status != 202) {
      final body = response.data as Map<String, dynamic>? ?? {};
      setState(() {
        _uploading = false;
        _ocrHint = null;
        _error = (body['error'] as String?) ?? 'Upload failed (HTTP $status)';
      });
      return;
    }

    final visitId = (response.data as Map<String, dynamic>?)?['visit_id'] as String?;

    if (pdfPath && visitId != null) {
      setState(() => _ocrHint = 'Checking document...');
      final isScannedPdf = await _pollForScannedPdfFailure(visitId);
      if (!mounted) return;
      if (isScannedPdf) {
        setState(() {
          _uploading = false;
          _ocrHint = null;
          _error = 'This PDF has no selectable text — it looks like a scanned '
              'document. Export or take screenshots of the pages as images '
              '(PNG/JPG) and upload those instead; they are OCR\'d securely '
              'in your browser and the images themselves are never uploaded.';
        });
        return;
      }
    }

    setState(() {
      _uploading = false;
      _ocrHint = null;
      _selectedFileBytes = null;
      _selectedFileName = null;
    });
    if (mounted && visitId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Uploaded. Processing... (visit $visitId)'),
          backgroundColor: AppTheme.emerald,
        ),
      );
    }
  }

  /// Briefly polls visit status right after a PDF upload to catch a
  /// SCANNED_PDF_NO_TEXT_LAYER failure quickly. Times out silently after a
  /// few seconds — the server keeps processing in the background regardless,
  /// this is purely to give fast feedback for the common "wrong file type"
  /// mistake without turning this screen into a full status poller.
  Future<bool> _pollForScannedPdfFailure(String visitId) async {
    final dio = ClinicApiClient.instance.raw;
    for (var i = 0; i < 6; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      try {
        final res = await dio.get('/v1/clinic/sessions/$visitId');
        if ((res.statusCode ?? 0) != 200) continue;
        final body = res.data as Map<String, dynamic>? ?? {};
        final visitStatus = body['status'] as String?;
        if (visitStatus == 'failed') {
          return (body['error'] as String?) == 'SCANNED_PDF_NO_TEXT_LAYER';
        }
        if (visitStatus != null && visitStatus != 'uploaded' && visitStatus != 'ocring') {
          // Moved past the Ghostscript stage without failing.
          return false;
        }
      } catch (_) {
        // Transient poll error — keep trying until the loop ends.
      }
    }
    return false;
  }

  void _clearSelection() {
    setState(() {
      _selectedFileBytes = null;
      _selectedFileName = null;
      _selectedFileMime = null;
      _selectedPatient = null;
      _showPatientPicker = false;
      _ocrHint = null;
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
                  // File selected — preview + patient picker + upload
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
                        // File info row
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
                        const SizedBox(height: 16),

                        // Patient picker
                        _PatientPickerField(
                          selectedPatient: _selectedPatient,
                          expanded: _showPatientPicker,
                          onToggle: _uploading ? null : () {
                            setState(() => _showPatientPicker = !_showPatientPicker);
                          },
                          onSelected: (patient) {
                            setState(() {
                              _selectedPatient = patient;
                              _showPatientPicker = false;
                            });
                          },
                          onClear: _uploading ? null : () {
                            setState(() => _selectedPatient = null);
                          },
                        ),
                        const SizedBox(height: 20),

                        if (_uploading) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _ocrHint != null ? null : _uploadProgress,
                              backgroundColor: const Color(0xFF1D3A31),
                              valueColor: const AlwaysStoppedAnimation(AppTheme.gold),
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _ocrHint ?? '${(_uploadProgress * 100).toInt()}% uploaded',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 12,
                              color: AppTheme.sage,
                            ),
                          ),
                        ] else
                          ElevatedButton(
                            onPressed: _selectedPatient != null ? _upload : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.gold,
                              foregroundColor: AppTheme.forestTeal,
                              disabledBackgroundColor: AppTheme.gold.withValues(alpha: 0.3),
                              disabledForegroundColor: AppTheme.forestTeal.withValues(alpha: 0.5),
                              minimumSize: const Size(double.infinity, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              _selectedPatient != null
                                  ? 'Upload and process'
                                  : 'Select a patient first',
                              style: const TextStyle(
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

/// Inline patient picker — shows a select field that expands into a search
/// dropdown. Supports searching existing patients and creating new ones.
class _PatientPickerField extends StatefulWidget {
  const _PatientPickerField({
    required this.selectedPatient,
    required this.expanded,
    required this.onToggle,
    required this.onSelected,
    required this.onClear,
  });

  final Map<String, dynamic>? selectedPatient;
  final bool expanded;
  final VoidCallback? onToggle;
  final ValueChanged<Map<String, dynamic>> onSelected;
  final VoidCallback? onClear;

  @override
  State<_PatientPickerField> createState() => _PatientPickerFieldState();
}

class _PatientPickerFieldState extends State<_PatientPickerField> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  bool _showNewForm = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _search(value.trim());
    });
  }

  Future<void> _search(String query) async {
    setState(() => _loading = true);
    try {
      final dio = ClinicApiClient.instance.raw;
      final params = <String, dynamic>{'limit': 10};
      if (query.length >= 2) params['q'] = query;
      final res = await dio.get('/v1/clinic/patients', queryParameters: params);
      if (!mounted) return;
      if ((res.statusCode ?? 0) == 200) {
        final body = res.data as Map<String, dynamic>;
        setState(() {
          _results = List<Map<String, dynamic>>.from(body['patients'] as List);
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void didUpdateWidget(covariant _PatientPickerField old) {
    super.didUpdateWidget(old);
    if (widget.expanded && !old.expanded) {
      _search('');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Selected patient display / toggle button
        InkWell(
          onTap: widget.onToggle,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0A1F1C),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: widget.selectedPatient != null
                    ? AppTheme.gold.withValues(alpha: 0.6)
                    : const Color(0xFF1D3A31),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  widget.selectedPatient != null ? Icons.person : Icons.person_search,
                  color: widget.selectedPatient != null ? AppTheme.gold : AppTheme.sage,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: widget.selectedPatient != null
                      ? Text(
                          '${widget.selectedPatient!['first_name']} ${widget.selectedPatient!['last_name']}',
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.warmStone,
                          ),
                        )
                      : Text(
                          'Select patient...',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 14,
                            color: AppTheme.sage.withValues(alpha: 0.7),
                          ),
                        ),
                ),
                if (widget.selectedPatient != null)
                  IconButton(
                    onPressed: widget.onClear,
                    icon: const Icon(Icons.close, size: 16),
                    color: AppTheme.sage,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    tooltip: 'Clear selection',
                  )
                else
                  Icon(
                    widget.expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppTheme.sage,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),

        // Expanded search dropdown
        if (widget.expanded) ...[
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 280),
            decoration: BoxDecoration(
              color: const Color(0xFF0A1F1C),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF1D3A31)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Search input
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: _onSearchChanged,
                    autofocus: true,
                    style: const TextStyle(color: AppTheme.warmStone, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search by name...',
                      hintStyle: TextStyle(color: AppTheme.sage.withValues(alpha: 0.5)),
                      prefixIcon: const Icon(Icons.search, color: AppTheme.sage, size: 18),
                      filled: true,
                      fillColor: const Color(0xFF122B21),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide.none,
                      ),
                      isDense: true,
                    ),
                  ),
                ),

                // Results
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.gold),
                    ),
                  )
                else if (_results.isEmpty && !_showNewForm)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Text(
                          _searchCtrl.text.length >= 2
                              ? 'No patients found'
                              : 'Type to search, or add a new patient',
                          style: const TextStyle(color: AppTheme.sage, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () => setState(() => _showNewForm = true),
                          icon: const Icon(Icons.person_add, size: 16),
                          label: const Text('New patient'),
                          style: TextButton.styleFrom(foregroundColor: AppTheme.gold),
                        ),
                      ],
                    ),
                  )
                else if (!_showNewForm)
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(bottom: 4),
                      children: [
                        for (final p in _results)
                          ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                            title: Text(
                              '${p['first_name']} ${p['last_name']}',
                              style: const TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.warmStone,
                              ),
                            ),
                            subtitle: Text(
                              [
                                if (p['dob'] != null && (p['dob'] as String).isNotEmpty) 'DOB ${p['dob']}',
                                if (p['email'] != null && (p['email'] as String).isNotEmpty) p['email'] as String,
                              ].join(' · '),
                              style: const TextStyle(fontSize: 11, color: AppTheme.sage),
                            ),
                            onTap: () => widget.onSelected(p),
                          ),
                        // "Add new" at bottom of results
                        ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          leading: const Icon(Icons.person_add, size: 16, color: AppTheme.gold),
                          title: const Text(
                            'Add new patient',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 13,
                              color: AppTheme.gold,
                            ),
                          ),
                          onTap: () => setState(() => _showNewForm = true),
                        ),
                      ],
                    ),
                  ),

                // Inline new patient form
                if (_showNewForm)
                  _InlineNewPatient(
                    onCreated: (patient) {
                      setState(() => _showNewForm = false);
                      widget.onSelected(patient);
                    },
                    onCancel: () => setState(() => _showNewForm = false),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Compact inline form for creating a new patient from the picker dropdown.
class _InlineNewPatient extends StatefulWidget {
  const _InlineNewPatient({required this.onCreated, required this.onCancel});

  final ValueChanged<Map<String, dynamic>> onCreated;
  final VoidCallback onCancel;

  @override
  State<_InlineNewPatient> createState() => _InlineNewPatientState();
}

class _InlineNewPatientState extends State<_InlineNewPatient> {
  final _firstCtrl = TextEditingController();
  final _lastCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _dobCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final first = _firstCtrl.text.trim();
    final last = _lastCtrl.text.trim();
    if (first.isEmpty || last.isEmpty) return;

    setState(() { _submitting = true; _error = null; });
    try {
      final dio = ClinicApiClient.instance.raw;
      final res = await dio.post('/v1/clinic/patients', data: {
        'first_name': first,
        'last_name': last,
        if (_dobCtrl.text.trim().isNotEmpty) 'dob': _dobCtrl.text.trim(),
      });
      if (!mounted) return;
      if ((res.statusCode ?? 0) == 201) {
        widget.onCreated(res.data as Map<String, dynamic>);
      } else {
        final body = res.data as Map<String, dynamic>? ?? {};
        setState(() {
          _submitting = false;
          _error = body['error'] as String? ?? 'Failed to create patient';
        });
      }
    } catch (e) {
      if (mounted) setState(() { _submitting = false; _error = '$e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _field(_firstCtrl, 'First name *')),
              const SizedBox(width: 8),
              Expanded(child: _field(_lastCtrl, 'Last name *')),
            ],
          ),
          const SizedBox(height: 8),
          _field(_dobCtrl, 'DOB (YYYY-MM-DD)'),
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text(_error!, style: const TextStyle(color: Color(0xFFCF6679), fontSize: 11)),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _submitting ? null : widget.onCancel,
                child: const Text('Cancel', style: TextStyle(color: AppTheme.sage, fontSize: 12)),
              ),
              const SizedBox(width: 6),
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.gold,
                  foregroundColor: AppTheme.forestTeal,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.forestTeal),
                      )
                    : const Text('Create and select', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label) {
    return TextField(
      controller: ctrl,
      enabled: !_submitting,
      style: const TextStyle(color: AppTheme.warmStone, fontSize: 12),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppTheme.sage, fontSize: 11),
        filled: true,
        fillColor: const Color(0xFF122B21),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide.none,
        ),
        isDense: true,
      ),
    );
  }
}
