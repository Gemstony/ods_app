/// Payload for `POST /owner/users`.
///
/// Fields that don't apply to the selected [role] are `null` and
/// omitted from the JSON. Backend FormRequest validates role-specific
/// requirements.
class CreateUserInput {
  final String role;          // 'manager' | 'receiver' | 'rider'
  final String name;
  final String email;
  final String phone;
  final String password;
  final String passwordConfirmation;
  final int branchId;

  // Receiver-only
  final bool? dispatcherEnabled;

  // Rider-only
  final String? nida;
  final String? sex;              // 'male' | 'female' | 'other'
  final String? dateOfBirth;      // 'YYYY-MM-DD'
  final String? vehicleType;
  final String? vehicleColor;
  final String? vehicleOwnership; // 'owned' | 'rented' | 'company'
  final String? plateNumber;

  const CreateUserInput({
    required this.role,
    required this.name,
    required this.email,
    required this.phone,
    required this.password,
    required this.passwordConfirmation,
    required this.branchId,
    this.dispatcherEnabled,
    this.nida,
    this.sex,
    this.dateOfBirth,
    this.vehicleType,
    this.vehicleColor,
    this.vehicleOwnership,
    this.plateNumber,
  });

  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'name': name,
      'email': email,
      'phone': phone,
      'password': password,
      'password_confirmation': passwordConfirmation,
      'branch_id': branchId,
      if (role == 'receiver' && dispatcherEnabled != null)
        'dispatcher_enabled': dispatcherEnabled,
      if (role == 'rider') ...{
        if (nida != null) 'nida': nida,
        if (sex != null) 'sex': sex,
        if (dateOfBirth != null) 'date_of_birth': dateOfBirth,
        if (vehicleType != null) 'vehicle_type': vehicleType,
        if (vehicleColor != null) 'vehicle_color': vehicleColor,
        if (vehicleOwnership != null) 'vehicle_ownership': vehicleOwnership,
        if (plateNumber != null) 'plate_number': plateNumber,
      },
    };
  }
}