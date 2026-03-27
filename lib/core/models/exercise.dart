enum ExerciseCategory { stretch, mobility, strengthening, rest }
enum RecoveryPhase    { acute, subacute, rehabilitation }
enum VideoStatus      { none, generating, ready, failed }

extension ExerciseCategoryX on ExerciseCategory {
  String get label {
    switch (this) {
      case ExerciseCategory.stretch:       return 'Stretch';
      case ExerciseCategory.mobility:      return 'Mobility';
      case ExerciseCategory.strengthening: return 'Strengthening';
      case ExerciseCategory.rest:          return 'Rest';
    }
  }
  String get toJson => name;
  static ExerciseCategory fromJson(String v) =>
      ExerciseCategory.values.firstWhere((e) => e.name == v,
          orElse: () => ExerciseCategory.stretch);
}

extension RecoveryPhaseX on RecoveryPhase {
  String get label {
    switch (this) {
      case RecoveryPhase.acute:          return 'Acute';
      case RecoveryPhase.subacute:       return 'Subacute';
      case RecoveryPhase.rehabilitation: return 'Rehabilitation';
    }
  }
  String get subtitle {
    switch (this) {
      case RecoveryPhase.acute:          return 'First 1–2 weeks';
      case RecoveryPhase.subacute:       return 'Weeks 2 through 6';
      case RecoveryPhase.rehabilitation: return '6+ weeks or cleared for activity';
    }
  }
  String get toJson => name;
  static RecoveryPhase fromJson(String v) =>
      RecoveryPhase.values.firstWhere((e) => e.name == v,
          orElse: () => RecoveryPhase.acute);
}

class Exercise {
  final String id;
  final String name;
  final String description;
  final String repsOrDuration;
  final String frequency;
  final ExerciseCategory category;
  final bool restOnly;

  final String youtubeQuery;

  const Exercise({
    required this.id,
    required this.name,
    required this.description,
    required this.repsOrDuration,
    required this.frequency,
    required this.category,
    this.restOnly = false,
    this.youtubeQuery = '',
  });

  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
        id:             json['id']               as String? ?? '',
        name:           json['name']             as String? ?? '',
        description:    json['description']      as String? ?? '',
        repsOrDuration: json['reps_or_duration'] as String? ?? '',
        frequency:      json['frequency']        as String? ?? '',
        category: ExerciseCategoryX.fromJson(
            json['category'] as String? ?? 'stretch'),
        restOnly:      json['rest_only']      as bool?   ?? false,
        youtubeQuery:  json['youtube_query']  as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id':              id,
        'name':            name,
        'description':     description,
        'reps_or_duration': repsOrDuration,
        'frequency':       frequency,
        'category':        category.toJson,
        'rest_only':       restOnly,
        'youtube_query':   youtubeQuery,
      };
}

/// Mutable wrapper used in the review screen.
class ExerciseEntry {
  final Exercise exercise;
  bool active;
  VideoStatus videoStatus;
  String? videoJobId;
  String? videoUrl;

  ExerciseEntry({
    required this.exercise,
    this.active      = true,
    this.videoStatus = VideoStatus.none,
    this.videoJobId,
    this.videoUrl,
  });
}
