import '../models/extraction_result.dart';
import '../models/medication.dart';
import 'api_client.dart';

class MedicationsServiceException implements Exception {
  final String message;
  MedicationsServiceException(this.message);
}

class MedicationsService {
  final _client = ApiClient.instance;

  /// Fetches AI-suggested medications based on confirmed findings.
  Future<List<Medication>> fetchSuggestions(List<Finding> findings) async {
    try {
      final response = await _client.dio.post(
        '/v1/medications',
        data: {
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
      if (data is! Map || data['medications'] == null) {
        throw MedicationsServiceException('Unexpected response format.');
      }

      final raw = data['medications'] as List<dynamic>;
      return raw
          .map((m) => Medication.fromJson(m as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (e is MedicationsServiceException) rethrow;
      throw MedicationsServiceException('Could not fetch medication suggestions: $e');
    }
  }
}
