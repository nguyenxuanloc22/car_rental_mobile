import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import '../../services/vehicle_api_service.dart';
import '../../models/vehicle.dart';

class AdminGpsScreen extends StatefulWidget {
  const AdminGpsScreen({super.key});

  @override
  State<AdminGpsScreen> createState() => _AdminGpsScreenState();
}

class _AdminGpsScreenState extends State<AdminGpsScreen> {
  final VehicleApiService _vehicleApiService = VehicleApiService();
  final MapController _mapController = MapController();

  List<Vehicle> _vehicles = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  String _statusFilter = 'ALL'; 
  bool _isAutoRefresh = true;
  Timer? _refreshTimer;
  Vehicle? _selectedVehicle;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadVehicles() async {
    try {
      final list = await _vehicleApiService.fetchVehicles();
      if (mounted) {
        setState(() {
          _vehicles = list;
          _isLoading = false;
          _error = null;

          if (_selectedVehicle != null) {
            final updated = list.firstWhere(
              (v) => v.id == _selectedVehicle!.id,
              orElse: () => _selectedVehicle!,
            );
            _selectedVehicle = updated;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    if (_isAutoRefresh) {
      _refreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
        _loadVehicles();
      });
    }
  }

  void _toggleAutoRefresh(bool? value) {
    setState(() {
      _isAutoRefresh = value ?? false;
      _startAutoRefresh();
    });
  }

  Future<void> _openGoogleMaps(double lat, double lng) async {
    final googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    final uri = Uri.parse(googleMapsUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'AVAILABLE': return const Color(0xFF22C55E); // Grab Green
      case 'IN_USE': return const Color(0xFF3B82F6); // Blue
      case 'MAINTENANCE': return const Color(0xFFEF4444); // Red
      default: return Colors.grey;
    }
  }

  List<Vehicle> get _filteredVehicles {
    // Only show vehicles with GPS coordinates
    return _vehicles.where((v) {
      if (v.latitude == null || v.longitude == null) return false;
      if (_statusFilter != 'ALL' && v.status != _statusFilter) return false;
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        return v.plateNumber.toLowerCase().contains(query) || 
               v.modelName.toLowerCase().contains(query);
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    const grabGreen = Color(0xFF00B14F);
    final filtered = _filteredVehicles;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. MAP LAYER (FULL SCREEN)
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: filtered.isNotEmpty 
                  ? LatLng(filtered.first.latitude!, filtered.first.longitude!)
                  : const LatLng(10.7769, 106.7009),
              initialZoom: 14.0,
              onTap: (tapPosition, point) => setState(() => _selectedVehicle = null),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.crs.car_rental_mobile',
              ),
              MarkerLayer(
                markers: filtered.map((v) {
                  final isSelected = _selectedVehicle?.id == v.id;
                  final color = _getStatusColor(v.status);
                  
                  return Marker(
                    point: LatLng(v.latitude!, v.longitude!),
                    width: isSelected ? 120 : 60,
                    height: isSelected ? 120 : 60,
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedVehicle = v),
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 300),
                        scale: isSelected ? 1.2 : 1.0,
                        child: Column(
                          children: [
                            if (isSelected)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  v.plateNumber,
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            const SizedBox(height: 4),
                            Container(
                              padding: EdgeInsets.all(isSelected ? 8 : 6),
                              decoration: BoxDecoration(
                                color: isSelected ? grabGreen : color,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2.5),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))
                                ],
                              ),
                              child: const Icon(Icons.directions_car, color: Colors.white, size: 20),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          // 2. TOP FLOATING SEARCH BAR (GRAB STYLE)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 5))
                    ],
                  ),
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm phương tiện...',
                      prefixIcon: const Icon(Icons.search, color: grabGreen),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Auto', style: TextStyle(fontSize: 10, color: Colors.grey)),
                          Transform.scale(
                            scale: 0.7,
                            child: Switch(
                              value: _isAutoRefresh,
                              onChanged: _toggleAutoRefresh,
                              activeColor: grabGreen,
                            ),
                          ),
                        ],
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Quick Filters
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['ALL', 'AVAILABLE', 'IN_USE', 'MAINTENANCE'].map((s) {
                      final isSel = _statusFilter == s;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(s == 'ALL' ? 'Tất cả' : s),
                          selected: isSel,
                          onSelected: (v) => setState(() => _statusFilter = s),
                          selectedColor: grabGreen,
                          labelStyle: TextStyle(color: isSel ? Colors.white : Colors.black, fontSize: 12),
                          backgroundColor: Colors.white,
                          elevation: 2,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // 3. BACK BUTTON
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 10,
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // 4. BOTTOM FLOATING PANEL (WHEN SELECTED)
          if (_selectedVehicle != null)
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, -5))
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: grabGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Icon(Icons.directions_car, color: grabGreen, size: 30),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_selectedVehicle!.brand} ${_selectedVehicle!.modelName}',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Biển số: ${_selectedVehicle!.plateNumber}',
                                style: const TextStyle(color: Colors.grey, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _getStatusColor(_selectedVehicle!.status).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _selectedVehicle!.status,
                            style: TextStyle(color: _getStatusColor(_selectedVehicle!.status), fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildQuickInfo(Icons.battery_3_bar, '${_selectedVehicle!.batteryLevel ?? 100}%', 'Pin'),
                        _buildQuickInfo(Icons.speed, '${_selectedVehicle!.odometerKm?.toInt() ?? 0}km', 'Odo'),
                        _buildQuickInfo(Icons.hub, 'Hub ${_selectedVehicle!.fleetHubId ?? 1}', 'Vị trí'),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _openGoogleMaps(_selectedVehicle!.latitude!, _selectedVehicle!.longitude!),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: grabGreen,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              elevation: 0,
                            ),
                            child: const Text('Dẫn đường (Maps)', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.refresh, color: Colors.black54),
                            onPressed: _loadVehicles,
                          ),
                        )
                      ],
                    )
                  ],
                ),
              ),
            ),
          
          // 5. NO DATA OVERLAY
          if (!_isLoading && filtered.isEmpty)
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_off, size: 50, color: _error != null ? Colors.red : Colors.grey),
                    const SizedBox(height: 10),
                    Text(_error != null ? 'Lỗi kết nối' : 'Không tìm thấy xe', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      _error ?? 'Vui lòng kiểm tra lại bộ lọc hoặc GPS xe.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _selectedVehicle == null ? FloatingActionButton(
        onPressed: () {
          if (filtered.isNotEmpty) {
             _mapController.move(LatLng(filtered.first.latitude!, filtered.first.longitude!), 15);
          }
        },
        backgroundColor: Colors.white,
        child: const Icon(Icons.my_location, color: grabGreen),
      ) : null,
    );
  }

  Widget _buildQuickInfo(IconData icon, String val, String label) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(height: 4),
        Text(val, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
      ],
    );
  }
}
