import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

abstract class BaseApiService {
  // Helper to get authorization headers
  Future<Map<String, String>> getHeaders({bool requireAuth = false}) async {
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

  // Helper to handle API response and throw descriptive exceptions
  void handleError(http.Response response, String defaultErrorMsg) {
    if (response.body.isEmpty) {
      throw Exception('$defaultErrorMsg (Mã lỗi: ${response.statusCode})');
    }
    try {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? defaultErrorMsg);
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('$defaultErrorMsg (HTTP ${response.statusCode})');
    }
  }

  // -------------------------------------------------------------
  // USER SESSION ACCESSORS
  // -------------------------------------------------------------
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
