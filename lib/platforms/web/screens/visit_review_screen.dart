import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../services/clinic_api_client.dart';
import '../widgets/web_shell.dart';

/// Visit review screen — shows OCR status, findings, and visualization.
///
/// Flow:
///   1. Polls GET /v1/clinic/sessions/<visitId> until status is "ready"
///   2. Shows extracted findings for practitioner review
///   3. Practitioner clicks "Generate visualization"
///   4. Calls existing POST /v1/visualizations with findings
///   5. Polls GET /v1/visualizations/<jobId> until image is ready
///   6. Shows the generated anatomical visualization
///   7. Practitioner can share to patient via /v1/share
class VisitReviewScreen extends ConsumerStatefulWidget {
  const VisitReviewScreen({required this.visitId, super.key});

  final String visitId;

  @override
  ConsumerState<VisitReviewScreen> createState() => _VisitReviewScreenState();
}

class _VisitReviewScreenState extends ConsumerState<VisitReviewScreen> {
  String _status = 'loading';
  String? _error;
  List<Map<String, dynamic>> _findings = [];
  String? _vizImageUrl;
  Timer? _pollTimer;
  String? _shareCode;
  String? _shareUrl;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _pollVisitStatus();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _pollVisitStatus() async {
    try {
      final dio = ClinicApiClient.instance.raw;
      final res = await dio.get('/v1/clinic/sessions/${widget.visitId}');
      if (!mounted) return;

      if ((res.statusCode ?? 0) != 200) {
        setState(() {
          _status = 'error';
          _error = (res.data as Map<String, dynamic>?)?['error'] as String? ?? 'Failed to load';
        });
        return;
      }

      final body = res.data as Map<String, dynamic>;
      final status = body['status'] as String? ?? 'unknown';

      setState(() {
        _status = status;
        _error = body['error'] as String?;
        if (body.containsKey('findings') && body['findings'] != null) {
          _findings = List<Map<String, dynamic>>.from(body['findings'] as List);
        }
      });

      // Keep polling if still processing
      if (status == 'uploaded' || status == 'ocring' || status == 'extracting') {
        _pollTimer?.cancel();
        _pollTimer = Timer(const Duration(seconds: 3), _pollVisitStatus);
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _status = 'error';
          _error = 'Network error: ${e.message}';
        });
      }
    }
  }

  Future<void> _generateVisualization() async {
    if (_findings.isEmpty) return;
    setState(() => _status = 'generating');

    try {
      final dio = ClinicApiClient.instance.raw;

      // Build findings list for the existing visualization endpoint
      final bodyRegions = _findings
          .map((f) => f['body_region'] as String? ?? '')
          .where((r) => r.isNotEmpty)
          .toSet()
          .toList();

      final res = await dio.post('/v1/visualizations', data: {
        'findings': _findings,
        'body_regions': bodyRegions,
        'device_meta': {
          'platform': 'web',
          'device_type': 'desktop',
          'screen_width': MediaQuery.of(context).size.width.toInt(),
          'screen_height': MediaQuery.of(context).size.height.toInt(),
          'orientation': 'landscape',
        },
      });

      if (!mounted) return;

      if ((res.statusCode ?? 0) == 200 || (res.statusCode ?? 0) == 201) {
        final jobId = (res.data as Map<String, dynamic>?)?['job_id'] as String?;
        if (jobId != null) {
          _pollVizStatus(jobId);
          return;
        }
      }

      setState(() {
        _status = 'ready';
        _error = 'Failed to start visualization';
      });
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _status = 'ready';
          _error = 'Generation failed: ${e.message}';
        });
      }
    }
  }

  Future<void> _pollVizStatus(String jobId) async {
    try {
      final dio = ClinicApiClient.instance.raw;
      final res = await dio.get('/v1/visualizations/$jobId');
      if (!mounted) return;

      final body = res.data as Map<String, dynamic>? ?? {};
      final vizStatus = body['status'] as String? ?? 'pending';

      if (vizStatus == 'completed') {
        final imageUrl = body['image_url'] as String?;
        setState(() {
          _status = 'complete';
          _vizImageUrl = imageUrl;
        });
        return;
      }

      if (vizStatus == 'failed') {
        setState(() {
          _status = 'ready';
          _error = 'Visualization generation failed';
        });
        return;
      }

      // Keep polling
      _pollTimer?.cancel();
      _pollTimer = Timer(const Duration(seconds: 4), () => _pollVizStatus(jobId));
    } on DioException {
      // Retry
      _pollTimer?.cancel();
      _pollTimer = Timer(const Duration(seconds: 5), () => _pollVizStatus(jobId));
    }
  }

  Future<void> _shareWithPatient() async {
    if (_vizImageUrl == null || _findings.isEmpty || _sharing) return;
    setState(() { _sharing = true; _shareCode = null; _shareUrl = null; });

    try {
      final dio = ClinicApiClient.instance.raw;
      final res = await dio.post('/v1/clinic/share', data: {
        'image_url': _vizImageUrl!.startsWith('http')
            ? _vizImageUrl!
            : 'https://resolara.ai/api/v1/images/$_vizImageUrl',
        'findings': _findings,
      });
      if (!mounted) return;
      if ((res.statusCode ?? 0) == 200) {
        final body = res.data as Map<String, dynamic>;
        setState(() {
          _sharing = false;
          _shareCode = body['code'] as String?;
          _shareUrl = body['url'] as String?;
        });
      } else {
        setState(() => _sharing = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to create share link')),
          );
        }
      }
    } on DioException {
      if (mounted) {
        setState(() => _sharing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Network error creating share')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WebShell(
      title: 'Visit review',
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Status bar
                _statusBar(),
                const SizedBox(height: 24),

                // Error
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3A1E1E),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_error!, style: const TextStyle(color: Color(0xFFCF6679), fontSize: 13)),
                  ),
                  const SizedBox(height: 16),
                ],

                // Findings
                if (_findings.isNotEmpty) ...[
                  Text(
                    'Extracted findings (${_findings.length})',
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.warmStone,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._findings.map(_findingCard),
                  const SizedBox(height: 24),
                ],

                // Generate button
                if (_status == 'ready')
                  ElevatedButton(
                    onPressed: _generateVisualization,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.gold,
                      foregroundColor: AppTheme.forestTeal,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Generate visualization',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                // Visualization image
                if (_vizImageUrl != null) ...[
                  const SizedBox(height: 24),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      _vizImageUrl!.startsWith('http')
                          ? _vizImageUrl!
                          : 'https://resolara.ai/api/v1/images/$_vizImageUrl',
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(color: AppTheme.gold),
                        );
                      },
                      errorBuilder: (_, __, ___) => Container(
                        height: 200,
                        color: const Color(0xFF122B21),
                        child: const Center(
                          child: Text('Image failed to load', style: TextStyle(color: AppTheme.sage)),
                        ),
                      ),
                    ),
                  ),
                ],

                // Share button + result (after viz is complete)
                if (_status == 'complete' && _vizImageUrl != null) ...[
                  const SizedBox(height: 24),
                  if (_shareCode != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF122B21),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.check_circle, color: AppTheme.gold, size: 32),
                          const SizedBox(height: 8),
                          const Text(
                            'Share link created',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.warmStone,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SelectableText(
                            _shareUrl ?? 'https://resolara.ai/results/$_shareCode',
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 14,
                              color: AppTheme.gold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Code: $_shareCode',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.warmStone,
                              letterSpacing: 4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Patient can visit the link above or enter this code in the Resolara app.',
                            style: TextStyle(color: AppTheme.sage, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ] else
                    ElevatedButton.icon(
                      onPressed: _sharing ? null : _shareWithPatient,
                      icon: _sharing
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.forestTeal),
                            )
                          : const Icon(Icons.share_outlined, size: 18),
                      label: Text(_sharing ? 'Creating link...' : 'Share with patient'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.emerald,
                        foregroundColor: AppTheme.warmStone,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                ],

                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => context.go('/'),
                  child: const Text(
                    'Back to dashboard',
                    style: TextStyle(color: AppTheme.sage, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusBar() {
    final (icon, label, color) = switch (_status) {
      'loading' || 'uploaded' || 'ocring' => (Icons.hourglass_top, 'Processing OCR...', AppTheme.gold),
      'extracting' => (Icons.auto_awesome, 'Extracting findings...', AppTheme.gold),
      'ready' => (Icons.check_circle_outline, 'Ready for review', AppTheme.gold),
      'generating' => (Icons.brush, 'Generating visualization...', AppTheme.gold),
      'complete' => (Icons.check_circle, 'Complete', const Color(0xFF4CAF50)),
      'failed' => (Icons.error_outline, 'Processing failed', const Color(0xFFCF6679)),
      _ => (Icons.help_outline, _status, AppTheme.sage),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF122B21),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          if (_status == 'loading' || _status == 'uploaded' || _status == 'ocring' || _status == 'extracting' || _status == 'generating')
            SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          else
            Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _findingCard(Map<String, dynamic> finding) {
    final region = finding['body_region'] as String? ?? 'Unknown region';
    final description = finding['description'] as String? ?? '';
    final severity = finding['severity'] as String? ?? 'normal';

    final severityColor = switch (severity) {
      'mild' => const Color(0xFFFFA726),
      'moderate' => const Color(0xFFFF7043),
      'severe' => const Color(0xFFEF5350),
      _ => AppTheme.sage,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF122B21),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1D3A31)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  region,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.warmStone,
                  ),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12,
                      color: AppTheme.sage,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: severityColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              severity,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: severityColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
