enum DoseTime { morning, noon, evening, bedtime }

extension DoseTimeX on DoseTime {
  String get label {
    switch (this) {
      case DoseTime.morning:  return 'Morning';
      case DoseTime.noon:     return 'Noon';
      case DoseTime.evening:  return 'Evening';
      case DoseTime.bedtime:  return 'Bedtime';
    }
  }

  String get timeString {
    switch (this) {
      case DoseTime.morning:  return '8:00 AM';
      case DoseTime.noon:     return '12:00 PM';
      case DoseTime.evening:  return '6:00 PM';
      case DoseTime.bedtime:  return '9:00 PM';
    }
  }

  String get toJson => name;
  static DoseTime fromJson(String v) =>
      DoseTime.values.firstWhere((d) => d.name == v, orElse: () => DoseTime.morning);
}

/// Default dose times for a given daily frequency.
List<DoseTime> defaultTimesForFrequency(int timesPerDay) {
  switch (timesPerDay) {
    case 1:  return [DoseTime.morning];
    case 2:  return [DoseTime.morning, DoseTime.evening];
    case 3:  return [DoseTime.morning, DoseTime.noon, DoseTime.evening];
    case 4:  return [DoseTime.morning, DoseTime.noon, DoseTime.evening, DoseTime.bedtime];
    default: return [DoseTime.morning, DoseTime.evening];
  }
}

class Medication {
  final String id;
  final String name;
  final String purpose;
  final String typicalDosing;
  final bool aiSuggested;

  const Medication({
    required this.id,
    required this.name,
    required this.purpose,
    required this.typicalDosing,
    this.aiSuggested = true,
  });

  factory Medication.fromJson(Map<String, dynamic> json) => Medication(
        id:           json['id']             as String? ?? '',
        name:         json['name']           as String? ?? '',
        purpose:      json['purpose']        as String? ?? '',
        typicalDosing: json['typical_dosing'] as String? ?? '',
        aiSuggested:  json['ai_suggested']   as bool?   ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id':            id,
        'name':          name,
        'purpose':       purpose,
        'typical_dosing': typicalDosing,
        'ai_suggested':  aiSuggested,
      };
}

/// Mutable wrapper used in the review screen.
class MedicationEntry {
  final Medication medication;
  bool active;
  Set<DoseTime> times;

  MedicationEntry({
    required this.medication,
    this.active = true,
    Set<DoseTime>? times,
  }) : times = times ?? {DoseTime.morning, DoseTime.evening};

  Map<String, dynamic> toJson() => {
        ...medication.toJson(),
        'active': active,
        'times':  times.map((t) => t.toJson).toList(),
      };
}
