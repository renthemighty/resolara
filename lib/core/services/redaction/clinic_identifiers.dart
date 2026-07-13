/// The reporting practitioner's own identifiers, supplied by the app so the
/// engine can strip letterhead/signature-block PHI that has no other
/// reliable signal (a clinic's own name/address/phone repeats verbatim on
/// every report it issues).
class ClinicIdentifiers {
  final List<String> names;
  final List<String> clinicNames;
  final List<String> addresses;
  final List<String> phones;

  const ClinicIdentifiers({
    this.names = const [],
    this.clinicNames = const [],
    this.addresses = const [],
    this.phones = const [],
  });

  bool get isEmpty =>
      names.isEmpty &&
      clinicNames.isEmpty &&
      addresses.isEmpty &&
      phones.isEmpty;
}
