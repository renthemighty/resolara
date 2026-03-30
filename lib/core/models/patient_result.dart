import 'explanation.dart';
import 'exercise.dart';
import 'medication.dart';

class PatientResult {
  final String code;
  final String imageUrl;
  final String? patientName;
  final String? createdAt;
  final String? expiresAt;
  final List<FindingExplanation> explanations;
  final List<Exercise> exercises;
  final List<Medication> medications;

  const PatientResult({
    required this.code,
    required this.imageUrl,
    this.patientName,
    this.createdAt,
    this.expiresAt,
    this.explanations = const [],
    this.exercises    = const [],
    this.medications  = const [],
  });

  factory PatientResult.fromJson(Map<String, dynamic> json) => PatientResult(
        code:         json['code']         as String? ?? '',
        imageUrl:     json['image_url']    as String? ?? '',
        patientName:  json['patient_name'] as String?,
        createdAt:    json['created_at']   as String?,
        expiresAt:    json['expires_at']   as String?,
        explanations: (json['explanations'] as List<dynamic>? ?? [])
            .map((e) => FindingExplanation.fromJson(e as Map<String, dynamic>))
            .toList(),
        exercises: (json['exercises'] as List<dynamic>? ?? [])
            .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
            .toList(),
        medications: (json['medications'] as List<dynamic>? ?? [])
            .map((e) => Medication.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
