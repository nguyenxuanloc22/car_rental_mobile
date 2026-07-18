import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:http/http.dart' as http;
import '../../models/booking.dart';
import '../../services/vehicle_api_service.dart';
import '../../services/booking_api_service.dart';
import 'booking_completed_screen.dart';

class BookingTrackingScreen extends StatefulWidget {
  final Booking booking;
  final String apiKey;
  final String maptilesKey;

  const BookingTrackingScreen({
    super.key,
    required this.booking,
    this.apiKey = 'E8tXU5PV0Sm19d0dX1mJqwb40t6MjLNrRCiiF8LC',
    this.maptilesKey = '0SLpDGBBZ5birHNRZIk13fLQWdS4lEXIOk2M9ZSY',
  });

  @override
  State<BookingTrackingScreen> createState() => _BookingTrackingScreenState();
}

class _BookingTrackingScreenState extends State<BookingTrackingScreen> {
  final VehicleApiService _vehicleService = VehicleApiService();
  final BookingApiService _bookingService = BookingApiService();
  Timer? _timer;
  
  late Booking _currentBooking;

  MapLibreMapController? _mapController;

  List<LatLng> _routePoints = [];
  LatLng? _currentVehicleLocation;
  bool _isLoadingRoute = true;

  Line? _routeLine;
  Circle? _pickupCircle;
  Circle? _dropoffCircle;
  Circle? _carShadowCircle;
  Circle? _carCircle;

  @override
  void initState() {
    super.initState();
    _currentBooking = widget.booking;
    
    _fetchRoute();
    _fetchVehicleLocation();
    
    // Tự động làm mới vị trí xe mỗi 5 giây
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      _fetchVehicleLocation();
      _checkBookingStatus();
    });
  }

  Future<void> _checkBookingStatus() async {
    try {
      final updatedBooking = await _bookingService.fetchBookingById(_currentBooking.id);
      
      if (mounted) {
        setState(() {
          _currentBooking = updatedBooking;
        });
      }
      
      debugPrint('Polled Booking Status: ${updatedBooking.status}');
      
      if (updatedBooking.status == 'COMPLETED') {
        if (mounted) {
          _timer?.cancel();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => BookingCompletedScreen(booking: updatedBooking),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error checking booking status: $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchRoute() async {
    final lat1 = widget.booking.pickupLatitude;
    final lng1 = widget.booking.pickupLongitude;
    final lat2 = widget.booking.dropoffLatitude;
    final lng2 = widget.booking.dropoffLongitude;

    if (lat1 == null || lng1 == null || lat2 == null || lng2 == null) {
      setState(() {
        _isLoadingRoute = false;
      });
      return;
    }

    try {
      final url = Uri.parse(
        'https://rsapi.goong.io/Direction?origin=$lat1,$lng1&destination=$lat2,$lng2&vehicle=car&api_key=${widget.apiKey}',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final encodedPolyline =
              data['routes'][0]['overview_polyline']['points'];
          
          _routePoints = _decodePolyline(encodedPolyline);
          
          if (mounted) {
            setState(() {
              _isLoadingRoute = false;
            });
          }
          
          _drawRouteAndFitBounds();
        }
      }
    } catch (e) {
      debugPrint('Error fetching route: $e');
      if (mounted) {
        setState(() {
          _isLoadingRoute = false;
        });
      }
    }
  }

  Future<void> _fetchVehicleLocation() async {
    if (widget.booking.rentalUnits.isEmpty) return;
    final vehicleId = widget.booking.rentalUnits.first.vehicleId;
    if (vehicleId == null) return;

    try {
      final vehicle = await _vehicleService.getVehicleById(vehicleId);
      if (vehicle != null &&
          vehicle.latitude != null &&
          vehicle.longitude != null) {
        
        final newLoc = LatLng(vehicle.latitude!, vehicle.longitude!);
        _currentVehicleLocation = newLoc;
        
        if (mounted) {
          setState(() {});
        }
        
        _updateVehicleMarker();
      }
    } catch (e) {
      debugPrint('Error fetching vehicle location: $e');
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      poly.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return poly;
  }

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
  }
  
  Future<void> _drawInitialMarkers() async {
    if (_mapController == null) return;
    
    final lat1 = widget.booking.pickupLatitude;
    final lng1 = widget.booking.pickupLongitude;
    final lat2 = widget.booking.dropoffLatitude;
    final lng2 = widget.booking.dropoffLongitude;
    
    if (lat1 != null && lng1 != null && _pickupCircle == null) {
       _pickupCircle = await _mapController!.addCircle(CircleOptions(
         geometry: LatLng(lat1, lng1),
         circleColor: "#22c55e",
         circleRadius: 8,
         circleStrokeColor: "#ffffff",
         circleStrokeWidth: 3,
       ));
    }
    
    if (lat2 != null && lng2 != null && _dropoffCircle == null) {
       _dropoffCircle = await _mapController!.addCircle(CircleOptions(
         geometry: LatLng(lat2, lng2),
         circleColor: "#ef4444",
         circleRadius: 8,
         circleStrokeColor: "#ffffff",
         circleStrokeWidth: 3,
       ));
    }
  }

  Future<void> _drawRouteAndFitBounds() async {
    if (_mapController == null || _routePoints.isEmpty) return;
    
    // Draw route
    if (_routeLine == null) {
      _routeLine = await _mapController!.addLine(LineOptions(
        geometry: _routePoints,
        lineColor: "#3b82f6",
        lineWidth: 5.0,
        lineOpacity: 0.8,
      ));
    }
    
    // Fit Bounds
    double minLat = _routePoints.first.latitude;
    double maxLat = _routePoints.first.latitude;
    double minLng = _routePoints.first.longitude;
    double maxLng = _routePoints.first.longitude;
    
    for (var p in _routePoints) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    
    await _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        left: 50, right: 50, top: 50, bottom: 250,
      )
    );
  }
  
  Future<void> _updateVehicleMarker() async {
    if (_mapController == null || _currentVehicleLocation == null) return;
    
    if (_carCircle == null) {
      _carShadowCircle = await _mapController!.addCircle(CircleOptions(
        geometry: _currentVehicleLocation!,
        circleColor: "#000000",
        circleRadius: 14,
        circleOpacity: 0.2,
      ));
      _carCircle = await _mapController!.addCircle(CircleOptions(
        geometry: _currentVehicleLocation!,
        circleColor: "#000000", // Đen tượng trưng cho xe
        circleRadius: 10,
        circleStrokeColor: "#ffffff",
        circleStrokeWidth: 3,
      ));
    } else {
      await _mapController!.updateCircle(_carShadowCircle!, CircleOptions(geometry: _currentVehicleLocation!));
      await _mapController!.updateCircle(_carCircle!, CircleOptions(geometry: _currentVehicleLocation!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lat1 = widget.booking.pickupLatitude;
    final lng1 = widget.booking.pickupLongitude;
    
    final initialTarget = (lat1 != null && lng1 != null) 
      ? LatLng(lat1, lng1) 
      : const LatLng(10.762622, 106.660172);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Theo dõi chuyến đi',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black87),
        titleTextStyle: const TextStyle(
          color: Colors.black87,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: Stack(
        children: [
          MapLibreMap(
            initialCameraPosition: CameraPosition(
              target: initialTarget,
              zoom: 14.0,
            ),
            styleString: 'https://tiles.goong.io/assets/goong_map_web.json?api_key=${widget.maptilesKey}',
            onMapCreated: _onMapCreated,
            onStyleLoadedCallback: () {
              _drawInitialMarkers();
              _drawRouteAndFitBounds();
              _updateVehicleMarker();
            },
            myLocationEnabled: true,
            myLocationRenderMode: MyLocationRenderMode.normal,
            compassEnabled: true,
            logoViewMargins: const math.Point(-100, -100), // Hide logo if necessary
          ),
          
          if (_isLoadingRoute)
            const Center(
              child: CircularProgressIndicator(),
            ),

          // Thông tin chuyến đi Card
          Positioned(
            left: 20,
            right: 20,
            bottom: 30,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Thông tin chuyến đi',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildAddressRow(
                    Icons.my_location,
                    Colors.green,
                    _currentBooking.pickupAddress ?? 'Điểm đón',
                  ),
                  const SizedBox(height: 8),
                  _buildAddressRow(
                    Icons.location_on,
                    Colors.red,
                    _currentBooking.dropoffAddress ?? 'Điểm đến',
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Trạng thái:',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        _currentBooking.status,
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressRow(IconData icon, Color color, String address) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            address,
            style: const TextStyle(fontSize: 13, height: 1.4),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
