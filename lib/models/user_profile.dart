class UserProfile {
  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final String? dob;
  final String? gender;
  final String? createdAt;

  UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    this.dob,
    this.gender,
    this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] ?? '',
      fullName: json['fullName'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      dob: json['dob'],
      gender: json['gender'],
      createdAt: json['createdAt'],
    );
  }
}
