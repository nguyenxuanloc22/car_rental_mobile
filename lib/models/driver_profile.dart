class DriverProfile {
  final int id;
  final String userId;
  final String licenseNumber;
  final String? licenseClass;
  final String currentLocation;
  final String status;

  DriverProfile({
    required this.id,
    required this.userId,
    required this.licenseNumber,
    this.licenseClass,
    required this.currentLocation,
    required this.status,
  });

  factory DriverProfile.fromJson(Map<String, dynamic> json) {
    return DriverProfile(
      id: json['id'] as int? ?? 0,
      userId: json['userId'] ?? '',
      licenseNumber: json['licenseNumber'] ?? '',
      licenseClass: json['licenseClass']?.toString(),
      currentLocation: json['currentLocation'] ?? '',
      status: json['status'] ?? 'INACTIVE',
    );
  }
}
