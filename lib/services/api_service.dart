import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/auth_data.dart';
import '../models/vehicle.dart';

class ApiService {
  // Base URL for the API Gateway / Backend.
  // Using 10.0.2.2 for Android emulator to access computer's localhost.
  // Change to 'localhost' if running on a real device/iOS simulator and proxying,
  // or use your specific local network IP (e.g. 192.168.1.X).
  static const String baseUrl = 'http://10.0.2.2:8888/api/v1';

  // Singleton instance
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Helper to get authorization headers
  Future<Map<String, String>> _getHeaders({bool requireAuth = false}) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (requireAuth) {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  // Login implementation
  Future<LoginResponse> login(String email, String password) async {
    final url = Uri.parse('$baseUrl/auth/login');
    final response = await http.post(
      url,
      headers: await _getHeaders(),
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final loginResponse = LoginResponse.fromJson(data);

      // Save credentials locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', loginResponse.accessToken);
      await prefs.setString('refreshToken', loginResponse.refreshToken);
      await prefs.setString('userId', loginResponse.userId);
      await prefs.setString('email', loginResponse.email);
      await prefs.setString('role', loginResponse.role);

      return loginResponse;
    } else {
      // Decode error if possible
      try {
        final errData = jsonDecode(response.body);
        throw Exception(errData['message'] ?? 'Đăng nhập thất bại. Vui lòng kiểm tra lại thông tin.');
      } catch (_) {
        throw Exception('Đăng nhập thất bại. Sai email hoặc mật khẩu.');
      }
    }
  }

  // Logout implementation
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString('refreshToken');

    // Call API if refresh token exists
    if (refreshToken != null) {
      final url = Uri.parse('$baseUrl/auth/logout');
      try {
        await http.post(
          url,
          headers: await _getHeaders(),
          body: jsonEncode({
            'refreshToken': refreshToken,
          }),
        );
      } catch (e) {
        // Log error but continue local logout
        debugPrint('Error calling logout API: $e');
      }
    }

    // Always clear local session even if API call fails
    await prefs.remove('token');
    await prefs.remove('refreshToken');
    await prefs.remove('userId');
    await prefs.remove('email');
    await prefs.remove('role');
  }

  // Fetch all vehicles
  Future<List<Vehicle>> fetchVehicles() async {
    final url = Uri.parse('$baseUrl/vehicles?size=50');
    final response = await http.get(
      url,
      headers: await _getHeaders(requireAuth: false),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // Handle potential pagination wrappers from Spring Boot (e.g. data: { content: [...] })
      List<dynamic> content = [];
      if (data is Map && data.containsKey('data')) {
        final nestedData = data['data'];
        if (nestedData is Map && nestedData.containsKey('content')) {
          content = nestedData['content'] as List;
        } else if (nestedData is List) {
          content = nestedData;
        }
      } else if (data is List) {
        content = data;
      } else if (data is Map && data.containsKey('content')) {
        content = data['content'] as List;
      }

      return content.map((json) => Vehicle.fromJson(json)).toList();
    } else {
      throw Exception('Không thể tải danh sách xe. Vui lòng thử lại.');
    }
  }

  // Getters for current session
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') != null;
  }

  Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('email');
  }

  Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('role');
  }

  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userId');
  }
}
