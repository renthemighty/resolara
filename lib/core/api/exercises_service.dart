import '../models/exercise.dart';
import '../models/extraction_result.dart';
import 'api_client.dart';

class ExercisesServiceException implements Exception {
  final String message;
  ExercisesServiceException(this.message);
}

class ExercisesService {
  final _client = ApiClient.instance;

  /// Fetch AI-generated exercises for the given findings and recovery phase.
  Future<List<Exercise>> fetchExercises(
      List<Finding> findings, RecoveryPhase phase) async {
    try {
      final response = await _client.dio.post(
        '/v1/exercises',
        data: {
          'phase': phase.toJson,
          'findings': findings
              .map((f) => {
                    'id':          f.id,
                    'body_region': f.bodyRegion,
                    'finding':     f.text,
                    'layman_term': f.laymanTerm,
                  })
              .toList(),
        },
      );

      final data = response.data;
      if (data is! Map) throw ExercisesServiceException('Unexpected response.');

      final raw = data['exercises'] as List<dynamic>? ?? [];
      return raw
          .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (e is ExercisesServiceException) rethrow;
      throw ExercisesServiceException('Could not load exercises: $e');
    }
  }

  /// Request video generation for an exercise.
  /// Returns the video job ID for polling.
  Future<String> requestVideo(Exercise exercise) async {
    try {
      final response = await _client.dio.post(
        '/v1/videos',
        data: exercise.toJson(),
      );
      final jobId = response.data['job_id'] as String?;
      if (jobId == null) throw ExercisesServiceException('No job ID returned.');
      return jobId;
    } catch (e) {
      if (e is ExercisesServiceException) rethrow;
      throw ExercisesServiceException('Could not start video generation: $e');
    }
  }

  /// Poll for video job completion.
  /// Yields status updates until done or failed.
  Stream<Map<String, dynamic>> pollVideo(String jobId) async* {
    const maxAttempts = 60; // 5 minutes at 5s intervals
    var attempts = 0;
    while (attempts < maxAttempts) {
      await Future.delayed(const Duration(seconds: 5));
      attempts++;
      try {
        final response =
            await _client.dio.get('/v1/videos/$jobId');
        final data = response.data as Map<String, dynamic>;
        yield data;
        final status = data['status'] as String? ?? '';
        if (status == 'completed' || status == 'failed') return;
      } catch (_) {
        // transient error — keep polling
      }
    }
    yield {'status': 'failed', 'error': 'Timed out waiting for video.'};
  }
}
