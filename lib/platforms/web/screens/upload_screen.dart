import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/services/redaction/redaction.dart';
import '../../../features/redaction/redaction_approval.dart';
import '../services/clinic_api_client.dart';
import '../services/tesseract_ocr_service.dart';
import '../widgets/web_shell.dart';

/// File upload flow — file picker (drag-drop via HTML5 will land separately).
///
/// Accepts PNG / JPEG / TIFF up to 50 MB. No camera, no microphone — web
/// app is strictly file-based (primary source: Jane PDF exports, downloads
/// from other EMRs, or scanned files on the practitioner's computer).
///
/// PRIVACY: raw image bytes (PNG/JPEG/TIFF) are NEVER uploaded. They are
/// OCR'd entirely in-browser (tesseract.js, see [TesseractOcrService]).
/// The raw OCR text then goes through the SAME on-device redaction engine
/// the mobile app uses ([RedactionEngine.analyze]) and a mandatory
/// practitioner review gate ([RedactionReviewScreen]) — every detected
/// identifier span must be resolved (or, if nothing was found, explicitly
/// attested to) before anything is submitted. Only
/// [RedactionApproval.cleanedText] is ever POSTed, via
/// POST /v1/clinic/sessions/upload-text. This mirrors the mobile app's
/// on-device OCR + redaction + review flow for the web surface.
///
/// PDF upload is DISABLED on web for now. The project's non-negotiable
/// rule is that original PDFs must not leave the device — uploading raw
/// PDF bytes to the server (as this screen used to do) violates that even
/// though the server only extracts embedded text locally via Ghostscript.
/// In-browser PDF text extraction (so PDFs can take the same redact+review
/// path as images) is the preferred long-term fix but is out of scope for
/// this change; until then, practitioners are asked to export/screenshot
/// PDF pages as images (which take the safe path above) or use the mobile
/// app, which already has full on-device PDF handling.
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

  // PDF intentionally excluded — see class doc. Raw PDF upload is disabled
  // on web; the file picker must not even offer it as a choice.
  static const _allowedExtensions = ['png', 'jpg', 'jpeg', 'tif', 'tiff'];
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

    if (_isPdf) {
      // Defense in depth: _allowedExtensions no longer offers 'pdf' so the
      // file picker shouldn't be able to produce one, but this guard stays
      // so a PDF can never reach a network call from here regardless of
      // how it was selected. See class doc — raw PDF upload is disabled.
      setState(() {
        _error = 'PDF upload isn\'t available on the web app yet. Export '
            'the report page as an image (PNG/JPG) and upload that '
            'instead, or use the Resolara mobile app to upload PDFs '
            'directly.';
      });
      return;
    }

    setState(() {
      _uploading = true;
      _uploadProgress = 0;
      _ocrHint = null;
      _error = null;
    });

    try {
      await _uploadImageViaBrowserOcr();
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

  /// Images never leave the browser as raw bytes: OCR runs entirely
  /// client-side via tesseract.js. The raw OCR text then goes through the
  /// same de-identification engine and mandatory practitioner review gate
  /// the mobile app uses — see [RedactionEngine] / [RedactionReviewScreen]
  /// — before anything is submitted. Only the redacted text
  /// ([RedactionApproval.cleanedText]) is ever POSTed; the raw OCR string
  /// never reaches a network call.
  Future<void> _uploadImageViaBrowserOcr() async {
    setState(() => _ocrHint = 'Reading text from the image in your browser...');
    final rawText = await TesseractOcrService.recognizeBytes(
      _selectedFileBytes!,
      mime: _selectedFileMime ?? 'image/png',
    );
    if (!mounted) return;

    if (rawText.trim().length < 20) {
      setState(() {
        _uploading = false;
        _ocrHint = null;
        _error = 'Could not read text from this image. Try a clearer photo or scan.';
      });
      return;
    }

    setState(() => _ocrHint = null);
    final analysis = RedactionEngine.analyze(rawText);
    if (!mounted) return;

    // Practitioner review gate — the only place a RedactionApproval (the
    // sole type the POST below accepts as cleaned text) can be minted.
    // Cancelling returns null and nothing is sent.
    final approval = await Navigator.of(context).push<RedactionApproval>(
      MaterialPageRoute(
        builder: (_) => RedactionReviewScreen(analysis: analysis),
      ),
    );
    if (!mounted) return;
    if (approval == null) {
      setState(() {
        _uploading = false;
        _ocrHint = null;
      });
      return;
    }

    setState(() => _ocrHint = 'Submitting recognized text...');
    final dio = ClinicApiClient.instance.raw;
    final response = await dio.post('/v1/clinic/sessions/upload-text', data: {
      'patient_id': _selectedPatient!['id'] as String,
      'cleaned_report_text': approval.cleanedText,
      'source_mime': _selectedFileMime ?? 'image/png',
      'original_filename': _selectedFileName,
    });
    if (!mounted) return;
    await _handleUploadAccepted(response);
  }

  Future<void> _handleUploadAccepted(Response response) async {
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
                          'PNG, JPEG, or TIFF up to 50 MB',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 13,
                            color: AppTheme.sage,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'PDFs aren\'t supported on web yet — export a page '
                          'as an image, or use the mobile app.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 11,
                            color: AppTheme.sage.withValues(alpha: 0.7),
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
