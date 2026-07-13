import 'explanation.dart';
import 'exercise.dart';
import 'medication.dart';

/// Current version of the patient-facing AI disclosure string. Bump this
/// (and add an entry to [kShareDisclosureText]) if the disclosure wording
/// changes, so bundles encrypted under an older version still render their
/// original disclosure rather than a silently-changed one.
const String kShareDisclosureVersion = 'v1';

const Map<String, String> kShareDisclosureText = {
  'v1': 'Parts of this summary were prepared with AI assistance and '
      'reviewed by your practitioner. This is educational information, '
      'not a diagnosis or treatment plan.',
};

String shareDisclosureText(String version) =>
    kShareDisclosureText[version] ?? kShareDisclosureText[kShareDisclosureVersion]!;

/// The full clinical bundle the practitioner curated and approved.
/// Encrypted client-side before it ever reaches the server (see
/// `ShareCrypto.encryptBundle`) — the server never sees any of this in
/// plaintext, and never generates it on the patient's behalf.
class ShareBundle {
  final String? patientName;
  final String? imageFilename;
  final String? imageAccessToken;
  final List<Map<String, dynamic>> findings;
  final List<FindingExplanation> explanations;
  final List<Exercise> exercises;
  final List<Medication> medications;
  final String disclosureVersion;

  const ShareBundle({
    this.patientName,
    this.imageFilename,
    this.imageAccessToken,
    this.findings = const [],
    this.explanations = const [],
    this.exercises = const [],
    this.medications = const [],
    this.disclosureVersion = kShareDisclosureVersion,
  });

  factory ShareBundle.fromJson(Map<String, dynamic> json) => ShareBundle(
        patientName: json['patient_name'] as String?,
        imageFilename: json['image_filename'] as String?,
        imageAccessToken: json['image_access_token'] as String?,
        findings: (json['findings'] as List<dynamic>? ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(),
        explanations: (json['explanations'] as List<dynamic>? ?? [])
            .whereType<Map>()
            .map((e) => FindingExplanation.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        exercises: (json['exercises'] as List<dynamic>? ?? [])
            .whereType<Map>()
            .map((e) => Exercise.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        medications: (json['medications'] as List<dynamic>? ?? [])
            .whereType<Map>()
            .map((e) => Medication.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        disclosureVersion:
            json['disclosure_version'] as String? ?? kShareDisclosureVersion,
      );

  Map<String, dynamic> toJson() => {
        if (patientName != null && patientName!.isNotEmpty) 'patient_name': patientName,
        if (imageFilename != null && imageFilename!.isNotEmpty) 'image_filename': imageFilename,
        if (imageAccessToken != null && imageAccessToken!.isNotEmpty) 'image_access_token': imageAccessToken,
        'findings':     findings,
        'explanations': explanations.map((e) => e.toJson()).toList(),
        'exercises':    exercises.map((e) => e.toJson()).toList(),
        'medications':  medications.map((e) => e.toJson()).toList(),
        'disclosure_version': disclosureVersion,
      };
}
