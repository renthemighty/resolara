import 'package:dio/dio.dart';
import '../api/api_client.dart';
import '../models/explanation.dart';
import '../models/exercise.dart';
import '../models/medication.dart';
import '../models/patient_result.dart';

class ShareServiceException implements Exception {
  final String message;
  const ShareServiceException(this.message);
  @override String toString() => message;
}

class ShareService {
  final _dio = ApiClient.instance.dio;

  /// Practitioner: create a share code for a completed session.
  /// Returns the short code (e.g. "ABCD-1234").
  Future<String> createShare({
    required String imageUrl,
    List<Map<String, dynamic>> findings = const [],
    String? patientName,
  }) async {
    try {
      final res = await _dio.post('/v1/share', data: {
        'image_url':   imageUrl,
        'findings':    findings,
        if (patientName != null && patientName.isNotEmpty)
          'patient_name': patientName,
      });
      final code = res.data['code'] as String?;
      if (code == null || code.isEmpty) {
        throw const ShareServiceException('Server returned no share code.');
      }
      return code;
    } on DioException catch (e) {
      final msg = e.response?.data?['error'] ?? e.message ?? 'Share failed.';
      throw ShareServiceException(msg.toString());
    }
  }

  /// Patient (no auth): fetch basic share data (fast file read).
  Future<PatientResult> fetchResults(String code) async {
    final clean = code.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    try {
      final res = await ApiClient.instance.dioNoAuth
          .get('/v1/patient/results/$clean');
      return PatientResult.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const ShareServiceException(
            'Code not found or expired. Check the code and try again.');
      }
      final msg = e.response?.data?['error'] ?? e.message ?? 'Could not load results.';
      throw ShareServiceException(msg.toString());
    }
  }

  /// Patient: load explanations (cached on server after first call).
  Future<List<FindingExplanation>> fetchExplanation(String code) async {
    final clean = code.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    try {
      final res = await ApiClient.instance.dioNoAuth
          .post('/v1/patient/results/$clean/explanation');
      final raw = (res.data['explanations'] as List<dynamic>? ?? []);
      return raw.map((e) => FindingExplanation.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      final msg = e.response?.data?['error'] ?? e.message ?? 'Could not load explanations.';
      throw ShareServiceException(msg.toString());
    }
  }

  /// Patient: load exercises for a phase (cached per phase on server).
  Future<List<Exercise>> fetchExercises(String code, String phase) async {
    final clean = code.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    try {
      final res = await ApiClient.instance.dioNoAuth
          .post('/v1/patient/results/$clean/exercises', data: {'phase': phase});
      final raw = (res.data['exercises'] as List<dynamic>? ?? []);
      return raw.map((e) => Exercise.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      final msg = e.response?.data?['error'] ?? e.message ?? 'Could not load exercises.';
      throw ShareServiceException(msg.toString());
    }
  }

  /// Patient: load medication suggestions (cached on server after first call).
  Future<List<Medication>> fetchMedications(String code) async {
    final clean = code.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    try {
      final res = await ApiClient.instance.dioNoAuth
          .post('/v1/patient/results/$clean/medications');
      final raw = (res.data['medications'] as List<dynamic>? ?? []);
      return raw.map((e) => Medication.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      final msg = e.response?.data?['error'] ?? e.message ?? 'Could not load medications.';
      throw ShareServiceException(msg.toString());
    }
  }
}
