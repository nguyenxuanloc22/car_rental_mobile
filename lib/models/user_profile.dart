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
    // Debug: In toàn bộ JSON ra console để bạn có thể xem các key thực tế
    print("DEBUG: Raw Profile JSON: $json");
    
    return UserProfile(
      id: (json['id'] ?? json['userId'] ?? '').toString(),
      fullName: json['fullName'] ?? json['fullName'] ?? json['fullname'] ?? json['name'] ?? '',
      email: json['email'] ?? '',
      // Thử tất cả các kiểu đặt tên biến thông dụng
      phone: (json['phone'] ?? json['phoneNumber'] ?? json['phone_number'] ?? json['mobile'] ?? '').toString(), 
      dob: (json['dob'] ?? json['dateOfBirth'] ?? json['birthDate'] ?? json['birthday'] ?? '').toString(),
      gender: (json['gender'] ?? json['sex'] ?? json['genderType'] ?? '').toString(),
      createdAt: (json['createdAt'] ?? json['createdDate'] ?? json['createAt'] ?? '').toString(),
    );
  }
}
