import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
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
  List<Vehicle> _mockVehicles = [];
  bool _isLoading = true;
  bool _isGpsLoading = true;
  String? _error;
  String _searchQuery = '';
  String _statusFilter = 'ALL'; 
  bool _isAutoRefresh = true;
  Timer? _refreshTimer;
  Timer? _mockMovementTimer;
  Vehicle? _selectedVehicle;
  LatLng? _currentAdminPosition;

  @override
  void initState() {
    super.initState();
    _initGpsAndLoadVehicles();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _mockMovementTimer?.cancel();
    super.dispose();
  }

  Future<Position?> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return null;
    } 

    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  Future<void> _initGpsAndLoadVehicles() async {
    setState(() {
      _isGpsLoading = true;
    });
    
    LatLng centerPosition = const LatLng(10.7769, 106.7009); // District 1, HCMC default
    
    try {
      final position = await _determinePosition();
      if (position != null) {
        centerPosition = LatLng(position.latitude, position.longitude);
        _currentAdminPosition = centerPosition;
        _mapController.move(centerPosition, 15.0);
      } else {
        _currentAdminPosition = centerPosition;
        _mapController.move(centerPosition, 15.0);
      }
    } catch (e) {
      debugPrint('Error loading GPS: $e');
      _currentAdminPosition = centerPosition;
    } finally {
      setState(() {
        _isGpsLoading = false;
      });
    }

    _generateMockVehicles(centerPosition);
    await _loadVehicles();
    _startAutoRefresh();
    _startMockMovement();
  }

  void _generateMockVehicles(LatLng center) {
    final math.Random rand = math.Random();
    final mockList = <Vehicle>[];
    final statuses = ['AVAILABLE', 'IN_USE', 'MAINTENANCE'];
    final brands = ['VinFast', 'Toyota', 'Hyundai', 'Honda', 'Kia'];
    final models = {
      'VinFast': ['VF8', 'VF9', 'VFe34', 'VF5'],
      'Toyota': ['Vios', 'Camry', 'Fortuner', 'Innova'],
      'Hyundai': ['Accent', 'Elantra', 'SantaFe', 'Tucson'],
      'Honda': ['City', 'Civic', 'CR-V'],
      'Kia': ['Cerato', 'Seltos', 'Morning'],
    };
    
    for (int i = 1; i <= 5; i++) {
      // Offset latitude and longitude randomly between +- 0.0015 to 0.004 degrees
      final double latOffset = (rand.nextDouble() * 0.005 - 0.0025); 
      final double finalLatOffset = latOffset + (latOffset >= 0 ? 0.0015 : -0.0015);
      
      final double lngOffset = (rand.nextDouble() * 0.005 - 0.0025);
      final double finalLngOffset = lngOffset + (lngOffset >= 0 ? 0.0015 : -0.0015);

      final brand = brands[rand.nextInt(brands.length)];
      final modelList = models[brand]!;
      final model = modelList[rand.nextInt(modelList.length)];
      final status = statuses[rand.nextInt(statuses.length)];
      final plateNum = '51K-${rand.nextInt(90000) + 10000}';
      
      mockList.add(
        Vehicle(
          id: 99000 + i,
          status: status,
          plateNumber: plateNum,
          brand: brand,
          modelName: model,
          latitude: center.latitude + finalLatOffset,
          longitude: center.longitude + finalLngOffset,
          batteryLevel: rand.nextInt(41) + 60, 
          odometerKm: (rand.nextDouble() * 50000 + 10000),
          fleetHubId: i,
          isVirtual: true,
        )
      );
    }
    
    setState(() {
      _mockVehicles = mockList;
    });
  }

  void _startMockMovement() {
    _mockMovementTimer?.cancel();
    _mockMovementTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted) return;
      final math.Random rand = math.Random();
      setState(() {
        _mockVehicles = _mockVehicles.map((v) {
          // Move small amount: delta of -0.00015 to +0.00015
          final double latDelta = (rand.nextDouble() * 0.0003 - 0.00015);
          final double lngDelta = (rand.nextDouble() * 0.0003 - 0.00015);
          
          return Vehicle(
            id: v.id,
            status: v.status,
            plateNumber: v.plateNumber,
            brand: v.brand,
            modelName: v.modelName,
            latitude: v.latitude! + latDelta,
            longitude: v.longitude! + lngDelta,
            batteryLevel: (v.batteryLevel ?? 100) - (rand.nextDouble() < 0.1 ? 1 : 0),
            odometerKm: (v.odometerKm ?? 0.0) + (rand.nextDouble() * 0.05),
            fleetHubId: v.fleetHubId,
            isVirtual: v.isVirtual,
          );
        }).toList();
        
        if (_selectedVehicle != null && _selectedVehicle!.isVirtual == true) {
          final updated = _mockVehicles.firstWhere(
            (v) => v.id == _selectedVehicle!.id,
            orElse: () => _selectedVehicle!,
          );
          _selectedVehicle = updated;
        }
      });
    });
  }

  Future<void> _loadVehicles() async {
    try {
      final list = await _vehicleApiService.fetchVehicles();
      if (mounted) {
        setState(() {
          _vehicles = list;
          _isLoading = false;
          _error = null;

          if (_selectedVehicle != null && _selectedVehicle!.isVirtual != true) {
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
          debugPrint('Error loading real vehicles: $e');
          _isLoading = false;
          // Set error only if we don't have simulated/mock vehicles to show
          if (_vehicles.isEmpty && _mockVehicles.isEmpty) {
            _error = e.toString();
          }
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

  List<Vehicle> get _allVehicles {
    final list = <Vehicle>[];
    list.addAll(_vehicles);
    list.addAll(_mockVehicles);
    return list;
  }

  List<Vehicle> get _filteredVehicles {
    return _allVehicles.where((v) {
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
              initialCenter: _currentAdminPosition ?? (filtered.isNotEmpty 
                  ? LatLng(filtered.first.latitude!, filtered.first.longitude!)
                  : const LatLng(10.7769, 106.7009)),
              initialZoom: 15.0,
              onTap: (tapPosition, point) => setState(() => _selectedVehicle = null),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.loccarrental.car_rental_mobile',
              ),
              MarkerLayer(
                markers: [
                  // Chấm định vị vị trí hiện tại của Admin (Blue dot giống Grab)
                  if (_currentAdminPosition != null)
                    Marker(
                      point: _currentAdminPosition!,
                      width: 40,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Các Marker xe
                  ...filtered.map((v) {
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
                                child: Icon(
                                  v.isVirtual == true ? Icons.directions_car : Icons.airport_shuttle, 
                                  color: Colors.white, 
                                  size: 20
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ],
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
                          child: Icon(
                            _selectedVehicle!.isVirtual == true ? Icons.directions_car : Icons.airport_shuttle, 
                            color: grabGreen, 
                            size: 30
                          ),
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
                    Icon(Icons.location_off, size: 50, color: (_error != null && _vehicles.isEmpty && _mockVehicles.isEmpty) ? Colors.red : Colors.grey),
                    const SizedBox(height: 10),
                    Text((_error != null && _vehicles.isEmpty && _mockVehicles.isEmpty) ? 'Lỗi kết nối' : 'Không tìm thấy xe', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      (_error != null && _vehicles.isEmpty && _mockVehicles.isEmpty) ? _error! : 'Vui lòng kiểm tra lại bộ lọc hoặc GPS xe.',
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
          if (_currentAdminPosition != null) {
            _mapController.move(_currentAdminPosition!, 15);
          } else if (filtered.isNotEmpty) {
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
