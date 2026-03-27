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

  // Video generation — reserved for future implementation.
  // Endpoint /v1/videos does not exist yet.
}
