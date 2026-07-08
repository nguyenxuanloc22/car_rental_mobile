import 'package:flutter/material.dart';
import '../../models/booking.dart';
import '../../services/auth_api_service.dart';
import '../../services/booking_api_service.dart';
import '../profile_screen.dart';
import '../home_screen.dart';
import 'driver_stats_tab.dart';
import 'driver_history_screen.dart';
import 'driver_report_screen.dart';
import 'package:intl/intl.dart';

class DriverDashboardScreen extends StatefulWidget {
  final VoidCallback? onLogout;
  const DriverDashboardScreen({super.key, this.onLogout});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  final AuthApiService _authApiService = AuthApiService();
  int _currentIndex = 0;
  late List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = [
      _DriverTripsTab(),
      const DriverStatsTab(),
      const DriverHistoryScreen(),
      const DriverReportScreen(),
      ProfileScreen(onLogout: _handleInternalLogout),
    ];
  }

  Future<void> _handleInternalLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Tài xế có chắc muốn nghỉ ca và đăng xuất?'),
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
          BottomNavigationBarItem(icon: Icon(Icons.navigation), label: 'Chuyến đi'),
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Lịch sử'),
          BottomNavigationBarItem(icon: Icon(Icons.report_problem), label: 'Báo cáo'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Cá nhân'),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// TAB 1: CHUYẾN ĐI CỦA TÀI XẾ
// -------------------------------------------------------------
class _DriverTripsTab extends StatefulWidget {
  @override
  State<_DriverTripsTab> createState() => _DriverTripsTabState();
}

class _DriverTripsTabState extends State<_DriverTripsTab> {
  final BookingApiService _apiService = BookingApiService();
  List<Booking> _bookings = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDriverData();
  }

  Future<void> _loadDriverData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userId = await _apiService.getUserId();
      if (userId == null) {
        throw Exception('Vui lòng đăng nhập.');
      }
      
      // Fetch driver profile to get the local driver ID
      final profile = await _apiService.getDriverByUserId(userId);

      // Fetch bookings assigned to this driver ID
      final list = await _apiService.getDriverBookings(profile.id);
      setState(() {
        _bookings = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _showPickupSheet(Booking booking, RentalUnit unit) {
    final odoController = TextEditingController(text: unit.vehicle?.odometerKm != null ? unit.vehicle!.odometerKm!.toInt().toString() : '0');
    final conditionController = TextEditingController(text: 'Bắt đầu đón khách. Xe hoạt động tốt.');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Xác nhận đón khách (PICKUP)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            TextField(
              controller: odoController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Chỉ số Odometer hiện tại (km) *', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: conditionController,
              decoration: const InputDecoration(labelText: 'Tình trạng xe *', border: OutlineInputBorder()),
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final odo = double.tryParse(odoController.text) ?? 0;
                final cond = conditionController.text.trim();
                Navigator.pop(ctx);
                setState(() {
                  _isLoading = true;
                });
                try {
                  await _apiService.driverPickupConfirmed(booking.id, unit.id, odo, cond);
                  _showSnackBar('Đã xác nhận đón khách thành công! Trạng thái: IN_PROGRESS', Colors.green);
                  _loadDriverData();
                } catch (e) {
                  _showSnackBar(e.toString().replaceAll('Exception: ', ''), Colors.red);
                  setState(() {
                    _isLoading = false;
                  });
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
              child: const Text('Đón khách hàng', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showCompleteSheet(Booking booking, RentalUnit unit) {
    final odoController = TextEditingController(text: unit.vehicle?.odometerKm != null ? unit.vehicle!.odometerKm!.toInt().toString() : '0');
    final conditionController = TextEditingController(text: 'Trả xe an toàn. Không có sự cố.');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Xác nhận hoàn thành chuyến đi (RETURN)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            TextField(
              controller: odoController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Chỉ số Odometer kết thúc (km) *', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: conditionController,
              decoration: const InputDecoration(labelText: 'Tình trạng xe khi trả khách *', border: OutlineInputBorder()),
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final odo = double.tryParse(odoController.text) ?? 0;
                final cond = conditionController.text.trim();
                Navigator.pop(ctx);
                setState(() {
                  _isLoading = true;
                });
                try {
                  await _apiService.driverCompleteTrip(booking.id, unit.id, odo, cond);
                  _showSnackBar('Chuyến đi hoàn thành thành công! Trạng thái: COMPLETED', Colors.green);
                  _loadDriverData();
                } catch (e) {
                  _showSnackBar(e.toString().replaceAll('Exception: ', ''), Colors.red);
                  setState(() {
                    _isLoading = false;
                  });
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF15803D)),
              child: const Text('Hoàn thành chuyến đi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF16A34A);

    // Active trips for driver
    final list = _bookings.where((b) => b.status == 'CONFIRMED' || b.status == 'IN_PROGRESS').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tài xế - Chuyến đi của tôi', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadDriverData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(primaryGreen)))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.navigation_outlined, color: Colors.orange, size: 48),
                        const SizedBox(height: 12),
                        Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _loadDriverData, child: const Text('Tải lại')),
                      ],
                    ),
                  ),
                )
              : list.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.directions_car_outlined, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text('Bạn không có chuyến đi nào chưa hoàn thành.', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadDriverData,
                      color: primaryGreen,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          final booking = list[index];
                          final isPickup = booking.status == 'CONFIRMED';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 1,
                            color: Colors.white,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Chuyến đi #${booking.id}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: (isPickup ? Colors.blue : Colors.teal).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          isPickup ? 'Chờ đón khách' : 'Đang di chuyển',
                                          style: TextStyle(
                                            color: isPickup ? Colors.blue : Colors.teal,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  if (booking.deliveryAddress != null) ...[
                                    Row(
                                      children: [
                                        const Icon(Icons.location_on, size: 14, color: Colors.red),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            booking.deliveryAddress!,
                                            style: const TextStyle(fontSize: 13, color: Colors.black54),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                  ],

                                  ...booking.rentalUnits.map((unit) {
                                    return Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(unit.vehicle != null ? '${unit.vehicle!.brand} ${unit.vehicle!.modelName}' : 'Xe được gán', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                                const SizedBox(height: 2),
                                                Text('Hạn trả: ${_formatDate(unit.endTime)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                              ],
                                            ),
                                          ),
                                          ElevatedButton(
                                            onPressed: () => isPickup ? _showPickupSheet(booking, unit) : _showCompleteSheet(booking, unit),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: isPickup ? Colors.blue : Colors.teal,
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                              minimumSize: Size.zero,
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            ),
                                            child: Text(
                                              isPickup ? 'Đón khách' : 'Kết thúc',
                                              style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
