import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/vehicle.dart';

class StaffFleetScreen extends StatefulWidget {
  const StaffFleetScreen({super.key});

  @override
  State<StaffFleetScreen> createState() => _StaffFleetScreenState();
}

class _StaffFleetScreenState extends State<StaffFleetScreen> {
  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF16A34A);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Quản lý Đội ngũ & Xe', style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          bottom: const TabBar(
            indicatorColor: primaryGreen,
            labelColor: primaryGreen,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(icon: Icon(Icons.people), text: 'Tài xế'),
              Tab(icon: Icon(Icons.directions_car), text: 'Đội xe'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _StaffDriversList(),
            _StaffVehiclesList(),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// SUB-WIDGET 1: DRIVERS LIST
// -------------------------------------------------------------
class _StaffDriversList extends StatefulWidget {
  const _StaffDriversList();

  @override
  State<_StaffDriversList> createState() => _StaffDriversListState();
}

class _StaffDriversListState extends State<_StaffDriversList> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _drivers = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadDrivers();
  }

  Future<void> _loadDrivers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final list = await _apiService.fetchAllDrivers();
      setState(() {
        _drivers = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF16A34A);
    final filtered = _drivers.where((d) {
      final query = _searchQuery.toLowerCase();
      if (query.isEmpty) return true;
      final name = (d['fullName'] ?? d['name'] ?? '').toString().toLowerCase();
      final license = (d['licenseNumber'] ?? '').toString().toLowerCase();
      final shift = (d['currentShift'] ?? d['shift'] ?? '').toString().toLowerCase();
      return name.contains(query) || license.contains(query) || shift.contains(query);
    }).toList();

    return Scaffold(
      body: Column(
        children: [
          // Search box
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      hintText: 'Tìm tài xế theo tên, GPLX, ca làm...',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(icon: const Icon(Icons.refresh), onPressed: _loadDrivers),
              ],
            ),
          ),

          // Main list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(primaryGreen)))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 44),
                            const SizedBox(height: 8),
                            Text(_error!, style: const TextStyle(color: Colors.red)),
                            const SizedBox(height: 12),
                            ElevatedButton(onPressed: _loadDrivers, child: const Text('Thử lại')),
                          ],
                        ),
                      )
                    : filtered.isEmpty
                        ? const Center(child: Text('Không tìm thấy tài xế nào phù hợp.', style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: filtered.length,
                            itemBuilder: (ctx, index) {
                              final d = filtered[index];
                              final status = d['status'] ?? 'INACTIVE';
                              final license = d['licenseNumber'] ?? '—';
                              final shift = d['currentShift'] ?? d['shift'] ?? '—';
                              final name = d['fullName'] ?? d['name'] ?? 'Tài xế';
                              final phone = d['phoneNumber'] ?? d['phone'] ?? '—';

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                color: Colors.white,
                                elevation: 0.5,
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: (status == 'ACTIVE' ? Colors.blue.shade50 : Colors.grey.shade100),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              status,
                                              style: TextStyle(
                                                color: (status == 'ACTIVE' ? Colors.blue : Colors.grey),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 24),
                                      _buildInfoRow(Icons.phone_android, 'Số điện thoại', phone),
                                      const SizedBox(height: 6),
                                      _buildInfoRow(Icons.badge, 'Bằng lái xe (GPLX)', license),
                                      const SizedBox(height: 6),
                                      _buildInfoRow(Icons.access_time, 'Ca làm việc', shift),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }
}

// -------------------------------------------------------------
// SUB-WIDGET 2: VEHICLES LIST
// -------------------------------------------------------------
class _StaffVehiclesList extends StatefulWidget {
  const _StaffVehiclesList();

  @override
  State<_StaffVehiclesList> createState() => _StaffVehiclesListState();
}

class _StaffVehiclesListState extends State<_StaffVehiclesList> {
  final ApiService _apiService = ApiService();
  List<Vehicle> _vehicles = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final list = await _apiService.fetchVehicles();
      setState(() {
        _vehicles = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'AVAILABLE':
        return Colors.blue;
      case 'IN_USE':
        return Colors.green;
      case 'MAINTENANCE':
        return Colors.red;
      case 'CHARGING':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'AVAILABLE':
        return 'Sẵn sàng';
      case 'IN_USE':
        return 'Đang sử dụng';
      case 'MAINTENANCE':
        return 'Bảo trì';
      case 'CHARGING':
        return 'Đang sạc';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF16A34A);
    final filtered = _vehicles.where((v) {
      final query = _searchQuery.toLowerCase();
      if (query.isEmpty) return true;
      return v.plateNumber.toLowerCase().contains(query) ||
          v.modelName.toLowerCase().contains(query) ||
          v.brand.toLowerCase().contains(query) ||
          (v.color?.toLowerCase().contains(query) ?? false);
    }).toList();

    return Scaffold(
      body: Column(
        children: [
          // Search box
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      hintText: 'Tìm xe theo biển số, hãng, màu sắc...',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(icon: const Icon(Icons.refresh), onPressed: _loadVehicles),
              ],
            ),
          ),

          // Main list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(primaryGreen)))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 44),
                            const SizedBox(height: 8),
                            Text(_error!, style: const TextStyle(color: Colors.red)),
                            const SizedBox(height: 12),
                            ElevatedButton(onPressed: _loadVehicles, child: const Text('Thử lại')),
                          ],
                        ),
                      )
                    : filtered.isEmpty
                        ? const Center(child: Text('Không tìm thấy xe nào.', style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: filtered.length,
                            itemBuilder: (ctx, index) {
                              final v = filtered[index];
                              final statusColor = _getStatusColor(v.status);

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                color: Colors.white,
                                elevation: 0.5,
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('${v.brand} ${v.modelName}'.trim(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                              const SizedBox(height: 2),
                                              Text(v.plateNumber, style: const TextStyle(fontSize: 13, color: Colors.grey, fontFamily: 'monospace')),
                                            ],
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: statusColor.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              _getStatusText(v.status),
                                              style: TextStyle(
                                                color: statusColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 24),
                                      Row(
                                        children: [
                                          Expanded(child: _buildValueColumn('Màu sắc', v.color ?? '—')),
                                          Expanded(child: _buildValueColumn('Odometer', '${v.odometerKm?.toInt() ?? 0} km')),
                                          Expanded(child: _buildValueColumn('Trạm (Hub)', v.fleetHubName ?? '—')),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildValueColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87), overflow: TextOverflow.ellipsis),
      ],
    );
  }
}
