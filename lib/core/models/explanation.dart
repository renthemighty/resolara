class FindingExplanation {
  final String id;
  final String heading;
  final String whatItIs;
  final String whyItMatters;
  final String outlook;

  const FindingExplanation({
    required this.id,
    required this.heading,
    required this.whatItIs,
    required this.whyItMatters,
    required this.outlook,
  });

  factory FindingExplanation.fromJson(Map<String, dynamic> json) =>
      FindingExplanation(
        id:            json['id']              as String? ?? '',
        heading:       json['heading']         as String? ?? '',
        whatItIs:      json['what_it_is']      as String? ?? '',
        whyItMatters:  json['why_it_matters']  as String? ?? '',
        outlook:       json['outlook']         as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id':            id,
        'heading':       heading,
        'what_it_is':    whatItIs,
        'why_it_matters': whyItMatters,
        'outlook':       outlook,
      };
}
