import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/vehicle.dart';
import 'base_api_service.dart';

class VehicleApiService extends BaseApiService {
  static const String baseUrl = 'http://10.0.2.2:8888/api/v1';

  // Singleton instance
  static final VehicleApiService _instance = VehicleApiService._internal();
  factory VehicleApiService() => _instance;
  VehicleApiService._internal();

  // -------------------------------------------------------------
  // VEHICLE APIs
  // -------------------------------------------------------------

  Future<List<Vehicle>> fetchVehicles() async {
    final url = Uri.parse('$baseUrl/vehicles?size=100');
    final response = await http.get(
      url,
      headers: await getHeaders(requireAuth: false),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
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
      handleError(response, 'Không thể tải danh sách xe.');
      throw Exception();
    }
  }

  Future<void> createVehicle(Map<String, dynamic> data) async {
    final url = Uri.parse('$baseUrl/vehicles');
    final response = await http.post(
      url,
      headers: await getHeaders(requireAuth: true),
      body: jsonEncode(data),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      handleError(response, 'Tạo xe mới thất bại.');
    }
  }

  Future<void> updateVehicle(int vehicleId, Map<String, dynamic> data) async {
    final url = Uri.parse('$baseUrl/vehicles/$vehicleId');
    final response = await http.put(
      url,
      headers: await getHeaders(requireAuth: true),
      body: jsonEncode(data),
    );
    if (response.statusCode != 200) {
      handleError(response, 'Cập nhật xe thất bại.');
    }
  }

  Future<void> deleteVehicle(int vehicleId) async {
    final url = Uri.parse('$baseUrl/vehicles/$vehicleId');
    final response = await http.delete(url, headers: await getHeaders(requireAuth: true));
    if (response.statusCode != 200) {
      handleError(response, 'Xóa xe thất bại.');
    }
  }
}
