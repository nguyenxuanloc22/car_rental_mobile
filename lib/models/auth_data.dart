class LoginResponse {
  final String accessToken;
  final String refreshToken;
  final String userId;
  final String email;
  final String role;

  LoginResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.email,
    required this.role,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      accessToken: json['accessToken'] ?? '',
      refreshToken: json['refreshToken'] ?? '',
      userId: json['userId'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'userId': userId,
      'email': email,
      'role': role,
    };
  }
}
