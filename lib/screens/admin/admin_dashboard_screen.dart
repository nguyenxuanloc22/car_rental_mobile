import 'package:flutter/material.dart';
import '../../services/auth_api_service.dart';
import '../../services/booking_api_service.dart';
import '../profile_screen.dart';
import '../home_screen.dart';
import 'admin_users_screen.dart';
import 'admin_fleet_screen.dart';
import 'admin_bookings_screen.dart';
import 'admin_incidents_screen.dart';
import 'package:intl/intl.dart';

class AdminDashboardScreen extends StatefulWidget {
  final VoidCallback? onLogout; // Optional now
  const AdminDashboardScreen({super.key, this.onLogout});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final AuthApiService _authApiService = AuthApiService();
  int _currentIndex = 0;
  late List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = [
      const _AdminStatsTab(),
      const AdminBookingsScreen(),
      const AdminUsersScreen(),
      const AdminFleetScreen(),
      const AdminIncidentsScreen(),
      ProfileScreen(onLogout: _handleInternalLogout),
    ];
  }

  Future<void> _handleInternalLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn chắc chắn muốn thoát quyền Admin?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đăng xuất', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authApiService.logout();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF16A34A);

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: primaryGreen,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Stats'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Đơn hàng'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Thành viên'),
          BottomNavigationBarItem(icon: Icon(Icons.directions_car), label: 'Đội xe'),
          BottomNavigationBarItem(icon: Icon(Icons.warning), label: 'Sự cố AI'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Cá nhân'),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// TAB 1: ADMIN STATISTICS
// -------------------------------------------------------------
class _AdminStatsTab extends StatefulWidget {
  const _AdminStatsTab();

  @override
  State<_AdminStatsTab> createState() => _AdminStatsTabState();
}

class _AdminStatsTabState extends State<_AdminStatsTab> {
  final BookingApiService _apiService = BookingApiService();
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await _apiService.fetchAdminDashboardStats();
      setState(() {
        _stats = res;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatMoney(double amount) {
    return NumberFormat.currency(locale: 'vi_VN', symbol: 'đ').format(amount);
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF16A34A);
    final statusCounts = _stats['statusCounts'] as Map<String, dynamic>? ?? {};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadStats),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(primaryGreen)))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 48),
                      const SizedBox(height: 12),
                      Text('Lỗi tải dữ liệu: $_error', style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _loadStats, child: const Text('Thử lại')),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Total Revenue Card
                      Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 1,
                        color: primaryGreen,
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('TỔNG DOANH THU', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.2)),
                              const SizedBox(height: 8),
                              Text(
                                _formatMoney((_stats['totalRevenue'] as num? ?? 0).toDouble()),
                                style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              const Text('Doanh thu từ các chuyến đi đã hoàn tất.', style: TextStyle(color: Colors.white60, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Fleet & Bookings Counts
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricCard(
                              'ĐƠN ĐẶT XE',
                              '${_stats['totalBookings'] ?? 0}',
                              Icons.receipt_long,
                              Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMetricCard(
                              'ĐỘI XE',
                              '${_stats['totalVehicles'] ?? 0} xe',
                              Icons.directions_car,
                              Colors.purple,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricCard(
                              'XE TRỐNG (AVAILABLE)',
                              '${_stats['availableVehicles'] ?? 0} xe',
                              Icons.check_circle,
                              Colors.teal,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Bookings breakdown
                      const Text('Trạng thái đơn hàng', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                      const SizedBox(height: 12),
                      _buildBreakdownRow('Đơn hàng chờ duyệt (PENDING)', statusCounts['PENDING'] ?? 0, Colors.orange),
                      _buildBreakdownRow('Đơn hàng đang hoạt động (ACTIVE)', statusCounts['ACTIVE'] ?? 0, Colors.blue),
                      _buildBreakdownRow('Đơn hàng đã hoàn thành (COMPLETED)', statusCounts['COMPLETED'] ?? 0, Colors.green),
                      _buildBreakdownRow('Đơn hàng đã hủy (CANCELLED)', statusCounts['CANCELLED'] ?? 0, Colors.red),
                    ],
                  ),
                ),
    );
  }

  Widget _buildMetricCard(String title, String val, IconData icon, Color color) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.1),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  const SizedBox(height: 4),
                  Text(val, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownRow(String label, int val, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: Colors.white,
        elevation: 0.5,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                  ),
                  const SizedBox(width: 12),
                  Text(label, style: const TextStyle(fontSize: 13, color: Colors.black54)),
                ],
              ),
              Text('$val đơn', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
            ],
          ),
        ),
      ),
    );
  }
}
