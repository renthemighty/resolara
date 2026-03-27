enum UserRole { practitioner, patient }

extension UserRoleX on UserRole {
  String get toJson => name;
  static UserRole fromJson(String? v) =>
      v == 'patient' ? UserRole.patient : UserRole.practitioner;
}
