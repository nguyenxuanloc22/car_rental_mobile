import 'package:flutter/material.dart';
import '../models/vehicle.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  
  List<Vehicle> _vehicles = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  
  bool _isLoggedIn = false;
  String? _userEmail;
  String? _userRole;

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
    final loggedIn = await _apiService.isLoggedIn();
    if (loggedIn) {
      final email = await _apiService.getUserEmail();
      final role = await _apiService.getRole();
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
      });
    }
  }

  Future<void> _loadVehicles() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final list = await _apiService.fetchVehicles();
      setState(() {
        // Filter by AVAILABLE like the web app
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
              await _apiService.logout();
              await _checkLoginStatus();
              setState(() {
                _isLoading = false;
              });
              if (mounted) {
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
      _loadVehicles(); // Reload in case tokens affect visibility
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

  void _showBookingDialog(Vehicle vehicle) {
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
      // Mock Booking confirmation
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Đặt xe ${vehicle.brand} ${vehicle.modelName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Biển số: ${vehicle.plateNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (vehicle.fleetHubName != null) Text('Nhận tại: ${vehicle.fleetHubName}'),
              const SizedBox(height: 8),
              const Text('Phương thức: Tự lái (Nhận tại bãi xe)'),
              const SizedBox(height: 8),
              const Text('Giá thuê: Thỏa thuận theo thời gian thực tế'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _showBookingSuccessBanner(vehicle);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
              child: const Text('Xác nhận đặt xe', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }
  }

  void _showBookingSuccessBanner(Vehicle vehicle) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.white,
        duration: const Duration(seconds: 5),
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

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF16A34A);
    const bgGray = Color(0xFFF9FAFB);

    // Search and filter cars
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
        title: Row(
          children: [
            Text(
              'Car Rental',
              style: TextStyle(
                color: primaryGreen,
                fontWeight: FontWeight.bold,
                fontSize: 22,
                shadows: [
                  Shadow(
                    offset: const Offset(0, 1),
                    blurRadius: 1,
                    color: Colors.black.withOpacity(0.05),
                  )
                ]
              ),
            ),
          ],
        ),
        actions: [
          // Hotline number matching web app
          const Row(
            children: [
              Icon(Icons.phone, color: primaryGreen, size: 18),
              SizedBox(width: 4),
              Text(
                '1900 9999',
                style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(width: 12),
          
          // User session display (Greeting vs login button)
          _isLoggedIn
              ? PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'logout') {
                      _handleLogout();
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      enabled: false,
                      child: Text(
                        _userEmail ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
                      ),
                    ),
                    PopupMenuItem(
                      enabled: false,
                      child: Text(
                        'Vai trò: ${_userRole ?? "USER"}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(Icons.logout, color: Colors.red, size: 18),
                          SizedBox(width: 8),
                          Text('Đăng xuất', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: primaryGreen),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person, color: primaryGreen, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Xin chào!',
                          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                )
              : TextButton.icon(
                  onPressed: _navigateToLogin,
                  icon: const Icon(Icons.person_outline, color: Colors.black87, size: 20),
                  label: const Text('Đăng nhập', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                ),
          const SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          // Subheader search section matching web page
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
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Reload/Refresh button
                InkWell(
                  onTap: _loadVehicles,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.refresh, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
          
          // Car title counts section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Xe có sẵn',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
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

          // Main body content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(primaryGreen)),
                        SizedBox(height: 12),
                        Text('Đang tải danh sách xe...', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                              const SizedBox(height: 12),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadVehicles,
                                style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
                                child: const Text('Thử lại', style: TextStyle(color: Colors.white)),
                              ),
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
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'Không tìm thấy xe phù hợp với "$_searchQuery"'
                                      : 'Hiện không có xe nào khả dụng',
                                  style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
                                ),
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
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.04),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                    border: Border.all(color: Colors.grey.shade100),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Image section or gradient placeholder
                                      Stack(
                                        children: [
                                          Container(
                                            height: 160,
                                            width: double.infinity,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: gradient,
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                            ),
                                            child: vehicle.imageUrl != null && vehicle.imageUrl!.isNotEmpty
                                                ? Image.network(
                                                    vehicle.imageUrl!,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context, error, stackTrace) => const Icon(
                                                      Icons.directions_car,
                                                      size: 64,
                                                      color: Colors.black26,
                                                    ),
                                                  )
                                                : const Icon(
                                                    Icons.directions_car,
                                                    size: 64,
                                                    color: Colors.black26,
                                                  ),
                                          ),
                                          // Status Badge (AVAILABLE / "Có sẵn")
                                          Positioned(
                                            top: 12,
                                            right: 12,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFDCFCE7),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: const Text(
                                                'Có sẵn',
                                                style: TextStyle(
                                                  color: Color(0xFF15803D),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                          // Color dot
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
                                                  boxShadow: const [
                                                    BoxShadow(color: Colors.black12, blurRadius: 2)
                                                  ],
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      
                                      // Detail section
                                      Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${vehicle.brand} ${vehicle.modelName}'.trim(),
                                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              vehicle.plateNumber,
                                              style: TextStyle(
                                                fontFamily: 'monospace',
                                                color: Colors.grey.shade500,
                                                fontSize: 13,
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            
                                            // Stats Row
                                            Row(
                                              children: [
                                                // Battery level if present
                                                if (vehicle.batteryLevel != null) ...[
                                                  Icon(
                                                    Icons.battery_charging_full,
                                                    size: 14,
                                                    color: vehicle.batteryLevel! >= 50 ? primaryGreen : Colors.orange,
                                                  ),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    '${vehicle.batteryLevel}%',
                                                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                                                  ),
                                                  const SizedBox(width: 12),
                                                ],
                                                // Fleet Hub Name if present
                                                if (vehicle.fleetHubName != null) ...[
                                                  const Icon(Icons.location_on, size: 14, color: Colors.grey),
                                                  const SizedBox(width: 3),
                                                  Expanded(
                                                    child: Text(
                                                      vehicle.fleetHubName!,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                ],
                                                // Odometer Km
                                                if (vehicle.odometerKm != null) ...[
                                                  const Icon(Icons.speed, size: 14, color: Colors.grey),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    '${vehicle.odometerKm!.toInt()} km',
                                                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            
                                            const Divider(height: 24, thickness: 0.5),
                                            
                                            // Pricing and CTA button
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                const Text(
                                                  'Giá thuê thỏa thuận',
                                                  style: TextStyle(
                                                    color: Colors.grey,
                                                    fontSize: 12,
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                                ),
                                                ElevatedButton(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: primaryGreen,
                                                    foregroundColor: Colors.white,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(8.0),
                                                    ),
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 10,
                                                    ),
                                                  ),
                                                  onPressed: () => _showBookingDialog(vehicle),
                                                  child: const Row(
                                                    children: [
                                                      Text(
                                                        'Đặt ngay',
                                                        style: TextStyle(fontWeight: FontWeight.bold),
                                                      ),
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
        // Try hex code parsing
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
}
