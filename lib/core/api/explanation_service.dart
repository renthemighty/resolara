import '../models/explanation.dart';
import '../models/extraction_result.dart';
import 'api_client.dart';

class ExplanationServiceException implements Exception {
  final String message;
  ExplanationServiceException(this.message);
}

class ExplanationService {
  final _client = ApiClient.instance;

  Future<List<FindingExplanation>> fetchExplanations(
      List<Finding> findings) async {
    try {
      final response = await _client.dio.post(
        '/v1/explanation',
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
      if (data is! Map) throw ExplanationServiceException('Unexpected response.');

      final raw = data['explanations'] as List<dynamic>? ?? [];
      return raw
          .map((e) => FindingExplanation.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (e is ExplanationServiceException) rethrow;
      throw ExplanationServiceException('Could not load explanations: $e');
    }
  }
}
