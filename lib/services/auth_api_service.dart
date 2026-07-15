import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/auth_data.dart';
import '../models/user_profile.dart';
import 'base_api_service.dart';

class AuthApiService extends BaseApiService {
  static const String baseUrl = 'http://10.0.2.2:8888/api/v1';

  // Singleton instance
  static final AuthApiService _instance = AuthApiService._internal();
  factory AuthApiService() => _instance;
  AuthApiService._internal();

  // -------------------------------------------------------------
  // AUTHENTICATION & PROFILE APIs
  // -------------------------------------------------------------

  Future<LoginResponse> login(String email, String password) async {
    final url = Uri.parse('$baseUrl/auth/login');
    final response = await http.post(
      url,
      headers: await getHeaders(),
      body: jsonEncode({
        'email': email.trim(),
        'password': password.trim(),
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final loginResponse = LoginResponse.fromJson(data);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', loginResponse.accessToken);
      await prefs.setString('refreshToken', loginResponse.refreshToken);
      await prefs.setString('userId', loginResponse.userId);
      await prefs.setString('email', loginResponse.email);
      await prefs.setString('role', loginResponse.role);

      return loginResponse;
    } else {
      handleError(response, 'Đăng nhập thất bại. Vui lòng kiểm tra lại tài khoản.');
      throw Exception();
    }
  }

  Future<void> register(String fullName, String phoneNumber, String email, String password) async {
    final url = Uri.parse('$baseUrl/auth/register');
    final response = await http.post(
      url,
      headers: await getHeaders(),
      body: jsonEncode({
        'fullName': fullName.trim(),
        'phoneNumber': phoneNumber.trim(),
        'email': email.trim(),
        'password': password.trim(),
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      handleError(response, 'Đăng ký thất bại. Email có thể đã tồn tại.');
    }
  }

  Future<UserProfile> getProfile() async {
    final url = Uri.parse('$baseUrl/auth/profile');
    print('[AuthApiService] getProfile URL: $url');
    final response = await http.get(
      url,
      headers: await getHeaders(requireAuth: true),
    );
    print('[AuthApiService] getProfile Status: ${response.statusCode}');
    print('[AuthApiService] getProfile Body: ${response.body}');

    if (response.statusCode == 200 && response.body.isNotEmpty) {
      final data = jsonDecode(response.body);
      // Handle nested data structure (API might return {data: {...}})
      final profileData = data is Map && data.containsKey('data') ? data['data'] : data;
      return UserProfile.fromJson(profileData);
    } else {
      handleError(response, 'Không thể tải thông tin hồ sơ.');
      throw Exception();
    }
  }

  Future<void> changePassword(String oldPassword, String newPassword) async {
    final url = Uri.parse('$baseUrl/auth/change-password');
    final response = await http.post(
      url,
      headers: await getHeaders(requireAuth: true),
      body: jsonEncode({
        'oldPassword': oldPassword,
        'newPassword': newPassword,
      }),
    );

    if (response.statusCode != 200) {
      handleError(response, 'Đổi mật khẩu thất bại. Mật khẩu cũ không chính xác.');
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString('refreshToken');

    if (refreshToken != null) {
      final url = Uri.parse('$baseUrl/auth/logout');
      try {
        await http.post(
          url,
          headers: await getHeaders(),
          body: jsonEncode({
            'refreshToken': refreshToken,
          }),
        );
      } catch (e) {
        debugPrint('Error calling logout API: $e');
      }
    }

    await prefs.remove('token');
    await prefs.remove('refreshToken');
    await prefs.remove('userId');
    await prefs.remove('email');
    await prefs.remove('role');
  }

  // -------------------------------------------------------------
  // ADMIN USER MANAGEMENT
  // -------------------------------------------------------------
  Future<List<Map<String, dynamic>>> fetchAdminUsers({String? keyword, String? isActive}) async {
    String query = '';
    if (keyword != null && keyword.isNotEmpty) {
      query += '${query.isEmpty ? "?" : "&"}keyword=${Uri.encodeComponent(keyword)}';
    }
    if (isActive != null && isActive.isNotEmpty) {
      query += '${query.isEmpty ? "?" : "&"}isActive=$isActive';
    }
    
    final path = query.isEmpty ? '/admin/users' : '/admin/users/search$query';
    final url = Uri.parse('$baseUrl$path');
    final response = await http.get(url, headers: await getHeaders(requireAuth: true));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final list = data is Map && data.containsKey('data') 
          ? (data['data'] is Map && data['data'].containsKey('content') ? data['data']['content'] : data['data'])
          : (data is Map && data.containsKey('content') ? data['content'] : data);
      if (list is List) {
        return List<Map<String, dynamic>>.from(list);
      }
      return [];
    } else {
      throw Exception('Không thể tải danh sách người dùng.');
    }
  }

  Future<List<Map<String, dynamic>>> fetchRoles() async {
    final url = Uri.parse('$baseUrl/roles');
    try {
      final response = await http.get(url, headers: await getHeaders(requireAuth: true));
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = jsonDecode(response.body);
        final list = data is Map && data.containsKey('data') ? data['data'] : data;
        if (list is List) {
          return List<Map<String, dynamic>>.from(list);
        }
      }
    } catch (e) {
      debugPrint('Lỗi fetchRoles: $e');
    }
    return [
      {'id': 1, 'name': 'ADMIN'},
      {'id': 2, 'name': 'CUSTOMER'},
      {'id': 3, 'name': 'STAFF'},
      {'id': 4, 'name': 'DRIVER'},
    ];
  }

  Future<Map<String, dynamic>> createAdminUser(Map<String, dynamic> userData) async {
    final url = Uri.parse('$baseUrl/admin/users');
    final response = await http.post(
      url,
      headers: await getHeaders(requireAuth: true),
      body: jsonEncode(userData),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return data is Map && data.containsKey('data') ? data['data'] : data;
    } else {
      handleError(response, 'Tạo người dùng thất bại.');
      throw Exception();
    }
  }

  Future<void> updateAdminUser(String userId, Map<String, dynamic> userData) async {
    final url = Uri.parse('$baseUrl/admin/users/$userId');
    final response = await http.put(
      url,
      headers: await getHeaders(requireAuth: true),
      body: jsonEncode(userData),
    );
    if (response.statusCode != 200) {
      handleError(response, 'Cập nhật người dùng thất bại.');
    }
  }

  Future<void> deleteAdminUser(String userId) async {
    final url = Uri.parse('$baseUrl/admin/users/$userId');
    final response = await http.delete(url, headers: await getHeaders(requireAuth: true));
    if (response.statusCode != 200) {
      handleError(response, 'Xóa người dùng thất bại.');
    }
  }

  Future<void> toggleAdminUserActive(String userId, bool active) async {
    final act = active ? 'activate' : 'deactivate';
    final url = Uri.parse('$baseUrl/admin/users/$userId/$act');
    final response = await http.patch(url, headers: await getHeaders(requireAuth: true));
    if (response.statusCode != 200) {
      handleError(response, '${active ? "Kích hoạt" : "Khóa"} người dùng thất bại.');
    }
  }

  Future<void> resetAdminUserPassword(String userId, String newPassword) async {
    final url = Uri.parse('$baseUrl/admin/users/$userId/reset-password');
    final response = await http.post(
      url,
      headers: await getHeaders(requireAuth: true),
      body: jsonEncode({'newPassword': newPassword}),
    );
    if (response.statusCode != 200) {
      handleError(response, 'Đổi mật khẩu người dùng thất bại.');
    }
  }
}
