import 'package:flutter/material.dart';
import '../models/vehicle.dart';
import '../services/auth_api_service.dart';
import '../services/vehicle_api_service.dart';
import '../services/booking_api_service.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import 'register_screen.dart';
import 'profile_screen.dart';
import 'user/booking_history_screen.dart';
import 'staff/staff_dashboard_screen.dart';
import 'driver/driver_dashboard_screen.dart';
import 'admin/admin_dashboard_screen.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthApiService _authApiService = AuthApiService();
  final VehicleApiService _vehicleApiService = VehicleApiService();

  List<Vehicle> _vehicles = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';

  bool _isLoggedIn = false;
  String? _userEmail;
  String? _userRole;

  int _customerIndex = 0; // Bottom navbar index for USER/Guest
  final GlobalKey<BookingHistoryScreenState> _bookingHistoryKey = GlobalKey<BookingHistoryScreenState>();

  // Gradient background cycle for vehicles without images
  final List<List<Color>> _cardGradients = [
    [const Color(0xFFECFDF5), const Color(0xFFD1FAE5)], // emerald
    [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)], // blue
    [const Color(0xFFF5F3FF), const Color(0xFFEDE9FE)], // purple
    [const Color(0xFFFFF7ED), const Color(0xFFFFEDD5)], // orange
    [const Color(0xFFFDF2F8), const Color(0xFFFCE7F3)], // pink
    [const Color(0xFFF0FDFA), const Color(0xFFCCFBF1)], // teal
  ];

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
    _loadVehicles();
  }

  Future<void> _checkLoginStatus() async {
    final loggedIn = await _authApiService.isLoggedIn();
    if (loggedIn) {
      final email = await _authApiService.getUserEmail();
      final role = await _authApiService.getRole();
      setState(() {
        _isLoggedIn = true;
        _userEmail = email;
        _userRole = role;
      });
    } else {
      setState(() {
        _isLoggedIn = false;
        _userEmail = null;
        _userRole = null;
        _customerIndex = 0; // reset tab for safety
      });
    }
  }

  Future<void> _loadVehicles() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final list = await _vehicleApiService.fetchVehicles();
      setState(() {
        _vehicles = list.where((v) => v.status == 'AVAILABLE').toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _handleLogout() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi tài khoản này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() {
                _isLoading = true;
              });
              await _authApiService.logout();
              await _checkLoginStatus();
              setState(() {
                _isLoading = false;
              });
              
              if (mounted) {
                // FORCE RESTART TO HOME: This is the most reliable way to clear all role-based UI
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const HomeScreen()),
                  (route) => false,
                );

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đăng xuất thành công')),
                );
              }
            },
            child: const Text('Đăng xuất', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToLogin() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );

    if (result == true) {
      await _checkLoginStatus();
      _loadVehicles(); // Reload
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Xin chào $_userEmail! Đăng nhập thành công.'),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
      }
    }
  }

  void _showBookingBottomSheet(Vehicle vehicle) {
    if (!_isLoggedIn) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('Yêu cầu đăng nhập'),
            ],
          ),
          content: const Text('Bạn cần đăng nhập trước khi thực hiện đặt xe.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Đóng', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _navigateToLogin();
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
              child: const Text('Đăng nhập ngay', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (ctx) => _BookingFormBottomSheet(
          vehicle: vehicle,
          onSuccess: () {
            _showBookingSuccessBanner(vehicle);
          },
        ),
      );
    }
  }

  void _showBookingSuccessBanner(Vehicle vehicle) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.white,
        duration: const Duration(seconds: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFD1FAE5), width: 1.5),
        ),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFD1FAE5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Đặt xe thành công! 🎉',
                    style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Đơn đang chờ Staff xác nhận.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      setState(() {
                        _customerIndex = 1; // redirect to booking history tab
                      });
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _bookingHistoryKey.currentState?.reload();
                      });
                    },
                    child: const Text(
                      'Xem lịch sử đặt xe →',
                      style: TextStyle(color: Color(0xFF16A34A), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.grey, size: 16),
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ],
        ),
      ),
    );
  }

  // Parse color string from backend (e.g. 'Red', 'Blue', '#FFFFFF')
  Color _parseColor(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'red': return Colors.red;
      case 'blue': return Colors.blue;
      case 'green': return Colors.green;
      case 'yellow': return Colors.yellow;
      case 'black': return Colors.black;
      case 'white': return Colors.white;
      case 'grey':
      case 'gray': return Colors.grey;
      case 'orange': return Colors.orange;
      case 'purple': return Colors.purple;
      default:
        try {
          if (colorName.startsWith('#')) {
            final hex = colorName.replaceAll('#', '');
            if (hex.length == 6) {
              return Color(int.parse('FF$hex', radix: 16));
            } else if (hex.length == 8) {
              return Color(int.parse(hex, radix: 16));
            }
          }
        } catch (_) {}
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    // REMOVED: Immediate role-based dashboard routing that was overriding the Home Screen

    // Default Customer / Guest Shell
    const primaryGreen = Color(0xFF16A34A);
    
    return Scaffold(
      body: IndexedStack(
        index: _customerIndex,
        children: [
          _buildCarCatalogTab(),
          _isLoggedIn ? BookingHistoryScreen(key: _bookingHistoryKey) : _buildGuestPrompt('Xem lịch sử đặt xe & hóa đơn'),
          _isLoggedIn ? ProfileScreen(onLogout: _handleLogout) : _buildGuestPrompt('Quản lý thông tin tài khoản & mật khẩu'),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _customerIndex,
        selectedItemColor: primaryGreen,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() {
            _customerIndex = index;
          });
          if (index == 1 && _isLoggedIn) {
            _bookingHistoryKey.currentState?.reload();
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.directions_car), label: 'Đặt xe'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Chuyến đi'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Cá nhân'),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // CUSTOMER TAB 1: VEHICLE CATALOG
  // -------------------------------------------------------------
  Widget _buildCarCatalogTab() {
    const primaryGreen = Color(0xFF16A34A);
    const bgGray = Color(0xFFF9FAFB);

    final filteredVehicles = _vehicles.where((v) {
      final term = _searchQuery.toLowerCase();
      if (term.isEmpty) return true;
      return v.modelName.toLowerCase().contains(term) ||
          v.brand.toLowerCase().contains(term) ||
          v.plateNumber.toLowerCase().contains(term) ||
          (v.fleetHubName?.toLowerCase().contains(term) ?? false);
    }).toList();

    return Scaffold(
      backgroundColor: bgGray,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Text(
          'Car Rental',
          style: TextStyle(
            color: primaryGreen,
            fontWeight: FontWeight.bold,
            fontSize: 22,
            shadows: [
              Shadow(offset: const Offset(0, 1), blurRadius: 1, color: Colors.black.withValues(alpha: 0.05))
            ]
          ),
        ),
        actions: [
          if (_isLoggedIn && _userRole != 'CUSTOMER')
            IconButton(
              icon: const Icon(Icons.admin_panel_settings, color: primaryGreen),
              tooltip: 'Vào trang quản trị',
              onPressed: () {
                if (_userRole == 'ADMIN') Navigator.push(context, MaterialPageRoute(builder: (_) => AdminDashboardScreen(onLogout: _handleLogout)));
                if (_userRole == 'STAFF') Navigator.push(context, MaterialPageRoute(builder: (_) => StaffDashboardScreen(onLogout: _handleLogout)));
                if (_userRole == 'DRIVER') Navigator.push(context, MaterialPageRoute(builder: (_) => DriverDashboardScreen(onLogout: _handleLogout)));
              },
            ),
          _isLoggedIn
              ? IconButton(
                  icon: const Icon(Icons.logout, color: Colors.redAccent),
                  onPressed: _handleLogout,
                )
              : Row(
                  children: [
                    TextButton(
                      onPressed: _navigateToLogin,
                      child: const Text('Đăng nhập', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                    ),
                    const Text('|', style: TextStyle(color: Colors.grey)),
                    TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                      child: const Text('Đăng ký', style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
        ],
      ),
      body: Column(
        children: [
          // Search & refresh bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                    },
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      hintText: 'Tìm theo tên, biển số...',
                      fillColor: bgGray,
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                InkWell(
                  onTap: _loadVehicles,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.refresh, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
          
          // Vehicles count
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Xe có sẵn', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 2),
                    Text(
                      _isLoading ? 'Đang tải...' : '${filteredVehicles.length} xe đang sẵn sàng để đặt',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Main catalog body
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(primaryGreen)))
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                              const SizedBox(height: 12),
                              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 16),
                              ElevatedButton(onPressed: _loadVehicles, child: const Text('Thử lại')),
                            ],
                          ),
                        ),
                      )
                    : filteredVehicles.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.directions_car_outlined, size: 64, color: Colors.grey),
                                const SizedBox(height: 12),
                                Text(_searchQuery.isNotEmpty ? 'Không tìm thấy xe phù hợp với "$_searchQuery"' : 'Hiện không có xe nào khả dụng', style: const TextStyle(color: Colors.grey)),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadVehicles,
                            color: primaryGreen,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: filteredVehicles.length,
                              itemBuilder: (context, index) {
                                final vehicle = filteredVehicles[index];
                                final gradient = _cardGradients[index % _cardGradients.length];
                                
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
                                    border: Border.all(color: Colors.grey.shade100),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Stack(
                                        children: [
                                          Container(
                                            height: 160,
                                            width: double.infinity,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                                            ),
                                            child: vehicle.imageUrl != null && vehicle.imageUrl!.isNotEmpty
                                                ? Image.network(
                                                    vehicle.imageUrl!,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.directions_car, size: 64, color: Colors.black26),
                                                  )
                                                : const Icon(Icons.directions_car, size: 64, color: Colors.black26),
                                          ),
                                          Positioned(
                                            top: 12,
                                            right: 12,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(12)),
                                              child: const Text('Có sẵn', style: TextStyle(color: Color(0xFF15803D), fontSize: 11, fontWeight: FontWeight.bold)),
                                            ),
                                          ),
                                          if (vehicle.color != null)
                                            Positioned(
                                              bottom: 12,
                                              right: 12,
                                              child: Container(
                                                width: 16,
                                                height: 16,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: _parseColor(vehicle.color!),
                                                  border: Border.all(color: Colors.white, width: 2),
                                                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)],
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('${vehicle.brand} ${vehicle.modelName}'.trim(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                            const SizedBox(height: 2),
                                            Text(vehicle.plateNumber, style: TextStyle(fontFamily: 'monospace', color: Colors.grey.shade500, fontSize: 13)),
                                            const SizedBox(height: 10),
                                            Row(
                                              children: [
                                                if (vehicle.batteryLevel != null) ...[
                                                  Icon(Icons.battery_charging_full, size: 14, color: vehicle.batteryLevel! >= 50 ? primaryGreen : Colors.orange),
                                                  const SizedBox(width: 3),
                                                  Text('${vehicle.batteryLevel}%', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                                                  const SizedBox(width: 12),
                                                ],
                                                if (vehicle.fleetHubName != null) ...[
                                                  const Icon(Icons.location_on, size: 14, color: Colors.grey),
                                                  const SizedBox(width: 3),
                                                  Expanded(child: Text(vehicle.fleetHubName!, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.black54))),
                                                  const SizedBox(width: 12),
                                                ],
                                                if (vehicle.odometerKm != null) ...[
                                                  const Icon(Icons.speed, size: 14, color: Colors.grey),
                                                  const SizedBox(width: 3),
                                                  Text('${vehicle.odometerKm!.toInt()} km', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                                                ],
                                              ],
                                            ),
                                            const Divider(height: 24, thickness: 0.5),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                const Text('Giá thuê thỏa thuận', style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic)),
                                                ElevatedButton(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: primaryGreen,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                                  ),
                                                  onPressed: () => _showBookingBottomSheet(vehicle),
                                                  child: const Row(
                                                    children: [
                                                      Text('Đặt ngay', style: TextStyle(fontWeight: FontWeight.bold)),
                                                      SizedBox(width: 4),
                                                      Icon(Icons.chevron_right, size: 16),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  // Guest State prompt widget
  Widget _buildGuestPrompt(String description) {
    const primaryGreen = Color(0xFF16A34A);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_person_outlined, size: 80, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              const Text('Yêu cầu đăng nhập', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(color: Colors.grey, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _navigateToLogin,
                style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, minimumSize: const Size(200, 48)),
                child: const Text('Đăng nhập ngay', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// CUSTOM CONFIGURATION BOOKING BOTTOM SHEET
// -------------------------------------------------------------
class _BookingFormBottomSheet extends StatefulWidget {
  final Vehicle vehicle;
  final VoidCallback onSuccess;

  const _BookingFormBottomSheet({
    required this.vehicle,
    required this.onSuccess,
  });

  @override
  State<_BookingFormBottomSheet> createState() => _BookingFormBottomSheetState();
}

class _BookingFormBottomSheetState extends State<_BookingFormBottomSheet> {
  final BookingApiService _apiService = BookingApiService();

  bool _isWithDriver = false;
  String _deliveryMode = 'SELF_PICKUP'; // SELF_PICKUP, DELIVERY
  final _addressController = TextEditingController();
  final _priceController = TextEditingController(text: '500000');

  DateTime? _startDate;
  DateTime? _endDate;
  bool _submitting = false;

  @override
  void dispose() {
    _addressController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime(bool isStart) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(hours: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null || !mounted) return;

    setState(() {
      if (isStart) {
        _startDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      } else {
        _endDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      }
    });
  }

  Future<void> _submitBooking() async {
    if (_startDate == null || _endDate == null) {
      _showError('Vui lòng chọn thời gian bắt đầu và kết thúc!');
      return;
    }
    if (_startDate!.isAfter(_endDate!) || _startDate!.isAtSameMomentAs(_endDate!)) {
      _showError('Thời gian kết thúc phải sau thời gian bắt đầu!');
      return;
    }
    final priceStr = _priceController.text;
    final price = double.tryParse(priceStr) ?? 0;
    if (price <= 0) {
      _showError('Vui lòng nhập giá thuê hợp lệ!');
      return;
    }
    if (_isWithDriver && _deliveryMode == 'DELIVERY' && _addressController.text.trim().isEmpty) {
      _showError('Vui lòng nhập địa chỉ tài xế đến đón!');
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      final userId = await _apiService.getUserId();
      
      // format format: 2026-06-28T12:00:00
      final formatter = DateFormat("yyyy-MM-dd'T'HH:mm:ss");
      final startFormatted = formatter.format(_startDate!);
      final endFormatted = formatter.format(_endDate!);

      final payload = {
        'userId': userId,
        'deliveryMode': _deliveryMode,
        'deliveryAddress': (_isWithDriver && _deliveryMode == 'DELIVERY') ? _addressController.text.trim() : null,
        'rentalUnits': [
          {
            'vehicleId': widget.vehicle.id,
            'isWithDriver': _isWithDriver,
            'startTime': startFormatted,
            'endTime': endFormatted,
            'unitPrice': price,
          }
        ]
      };

      await _apiService.createBooking(payload);
      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
      }
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() {
        _submitting = false;
      });
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
    );
  }

  String _formatDateTimeDisplay(DateTime? dt) {
    if (dt == null) return 'Chọn ngày giờ';
    return DateFormat('dd/MM/yyyy HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF16A34A);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 20),
            
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Đặt xe của bạn', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text('${widget.vehicle.brand} ${widget.vehicle.modelName} — ${widget.vehicle.plateNumber}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const Divider(height: 24),

            // Service Mode
            const Text('Loại hình dịch vụ *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _isWithDriver = false;
                        _deliveryMode = 'SELF_PICKUP';
                      });
                    },
                    icon: Icon(Icons.directions_car, color: !_isWithDriver ? primaryGreen : Colors.grey),
                    label: Text('Tự lái', style: TextStyle(color: !_isWithDriver ? primaryGreen : Colors.grey, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: !_isWithDriver ? primaryGreen : Colors.grey.shade300, width: 1.5),
                      backgroundColor: !_isWithDriver ? primaryGreen.withOpacity(0.05) : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _isWithDriver = true;
                      });
                    },
                    icon: Icon(Icons.person, color: _isWithDriver ? primaryGreen : Colors.grey),
                    label: Text('Có tài xế', style: TextStyle(color: _isWithDriver ? primaryGreen : Colors.grey, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: _isWithDriver ? primaryGreen : Colors.grey.shade300, width: 1.5),
                      backgroundColor: _isWithDriver ? primaryGreen.withOpacity(0.05) : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // If with driver, select delivery mode
            if (_isWithDriver) ...[
              const Text('Phương thức đón khách *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _deliveryMode = 'SELF_PICKUP';
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _deliveryMode == 'SELF_PICKUP' ? primaryGreen : Colors.grey.shade300),
                        backgroundColor: _deliveryMode == 'SELF_PICKUP' ? primaryGreen.withOpacity(0.05) : Colors.white,
                      ),
                      child: Text('Đón tại bãi xe', style: TextStyle(color: _deliveryMode == 'SELF_PICKUP' ? primaryGreen : Colors.grey, fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _deliveryMode = 'DELIVERY';
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _deliveryMode == 'DELIVERY' ? primaryGreen : Colors.grey.shade300),
                        backgroundColor: _deliveryMode == 'DELIVERY' ? primaryGreen.withOpacity(0.05) : Colors.white,
                      ),
                      child: Text('Giao tận nơi', style: TextStyle(color: _deliveryMode == 'DELIVERY' ? primaryGreen : Colors.grey, fontSize: 13)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // If delivery address is required
            if (_isWithDriver && _deliveryMode == 'DELIVERY') ...[
              const Text('Địa chỉ đón khách *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 6),
              TextField(
                controller: _addressController,
                decoration: InputDecoration(
                  hintText: 'VD: 123 Nguyễn Văn Linh, Quận 7, TP.HCM',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Date time picks
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Nhận xe *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      OutlinedButton.icon(
                        onPressed: () => _pickDateTime(true),
                        icon: const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                        label: Text(
                          _formatDateTimeDisplay(_startDate),
                          style: TextStyle(fontSize: 12, color: _startDate != null ? Colors.black87 : Colors.grey),
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 44),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Trả xe *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      OutlinedButton.icon(
                        onPressed: () => _pickDateTime(false),
                        icon: const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                        label: Text(
                          _formatDateTimeDisplay(_endDate),
                          style: TextStyle(fontSize: 12, color: _endDate != null ? Colors.black87 : Colors.grey),
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 44),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Rental Price
            const Text('Giá thỏa thuận (VNĐ/ngày) *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 6),
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 24),

            // Confirm Button
            ElevatedButton(
              onPressed: _submitting ? null : _submitBooking,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                    )
                  : const Text('Xác nhận đặt xe', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
