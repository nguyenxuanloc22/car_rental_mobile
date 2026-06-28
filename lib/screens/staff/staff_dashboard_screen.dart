import 'package:flutter/material.dart';
import '../../models/booking.dart';
import '../../services/api_service.dart';
import '../profile_screen.dart';
import 'staff_fleet_screen.dart';
import 'package:intl/intl.dart';

class StaffDashboardScreen extends StatefulWidget {
  final VoidCallback onLogout;
  const StaffDashboardScreen({super.key, required this.onLogout});

  @override
  State<StaffDashboardScreen> createState() => _StaffDashboardScreenState();
}

class _StaffDashboardScreenState extends State<StaffDashboardScreen> {
  int _currentIndex = 0;
  late List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = [
      _StaffBookingsTab(),
      _StaffHandoverReturnTab(),
      const StaffFleetScreen(),
      ProfileScreen(onLogout: widget.onLogout),
    ];
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
          BottomNavigationBarItem(icon: Icon(Icons.approval), label: 'Duyệt đơn'),
          BottomNavigationBarItem(icon: Icon(Icons.swap_horiz), label: 'Giao/Nhận xe'),
          BottomNavigationBarItem(icon: Icon(Icons.airport_shuttle), label: 'Đội ngũ & Xe'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Cá nhân'),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// TAB 1: DUYỆT ĐƠN & PHÂN CÔNG TÀI XẾ
// -------------------------------------------------------------
class _StaffBookingsTab extends StatefulWidget {
  @override
  State<_StaffBookingsTab> createState() => _StaffBookingsTabState();
}

class _StaffBookingsTabState extends State<_StaffBookingsTab> {
  final ApiService _apiService = ApiService();
  List<Booking> _bookings = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // Load all bookings. Staff needs to see all pending/confirmed
      final list = await _apiService.fetchAllBookings();
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

  Future<void> _confirmBooking(Booking booking) async {
    setState(() {
      _isLoading = true;
    });
    try {
      await _apiService.confirmBooking(booking.id);
      _showSnackBar('Đã phê duyệt đơn đặt xe thành công! CONFIRMED', Colors.green);
      _loadBookings();
    } catch (e) {
      _showSnackBar(e.toString().replaceAll('Exception: ', ''), Colors.red);
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _showAssignDriverDialog(Booking booking, RentalUnit unit) async {
    showDialog(
      context: context,
      builder: (ctx) => _AssignDriverDialog(
        bookingId: booking.id,
        rentalUnitId: unit.id,
        onSuccess: () {
          _showSnackBar('Đã phân công tài xế thành công!', Colors.green);
          _loadBookings();
        },
      ),
    );
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  String _formatMoney(double amount) {
    return NumberFormat.currency(locale: 'vi_VN', symbol: 'đ').format(amount);
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
    
    // Staff displays pending or confirmed bookings requiring attention
    final list = _bookings.where((b) => b.status == 'PENDING' || b.status == 'CONFIRMED').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff - Phê duyệt đơn', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadBookings),
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
                        const Icon(Icons.error_outline, color: Colors.red, size: 48),
                        const SizedBox(height: 12),
                        Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _loadBookings, child: const Text('Thử lại')),
                      ],
                    ),
                  ),
                )
              : list.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text('Không có đơn đặt xe cần duyệt.', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadBookings,
                      color: primaryGreen,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          final booking = list[index];
                          final hasDriverUnit = booking.rentalUnits.any((u) => u.isWithDriver);

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
                                        'Đơn hàng #${booking.id}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: (booking.status == 'PENDING' ? Colors.orange : Colors.blue).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          booking.status == 'PENDING' ? 'Chờ duyệt' : 'Đã duyệt',
                                          style: TextStyle(
                                            color: booking.status == 'PENDING' ? Colors.orange : Colors.blue,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Khách hàng: ${booking.bookingCode}',
                                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                                  ),
                                  Text(
                                    'Dịch vụ: ${hasDriverUnit ? "Có tài xế" : "Tự lái"} — ${_formatMoney(booking.totalAmount)}',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 12),
                                  
                                  // Detailed unit view with driver assignment if applicable
                                  ...booking.rentalUnits.map((unit) {
                                    return Container(
                                      margin: const EdgeInsets.only(top: 8),
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(unit.vehicle != null ? '${unit.vehicle!.brand} ${unit.vehicle!.modelName}' : 'Xe tự lái', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                                const SizedBox(height: 2),
                                                Text('Thuê: ${_formatDate(unit.startTime)} - ${_formatDate(unit.endTime)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                              ],
                                            ),
                                          ),
                                          if (unit.isWithDriver && booking.status == 'CONFIRMED')
                                            ElevatedButton(
                                              onPressed: () => _showAssignDriverDialog(booking, unit),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: primaryGreen,
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                minimumSize: Size.zero,
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              ),
                                              child: const Text('Gán tài xế', style: TextStyle(fontSize: 11, color: Colors.white)),
                                            ),
                                        ],
                                      ),
                                    );
                                  }),

                                  const Divider(height: 24),
                                  // Bottom actions
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      if (booking.status == 'PENDING')
                                        ElevatedButton(
                                          onPressed: () => _confirmBooking(booking),
                                          style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
                                          child: const Text('Xác nhận duyệt', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        ),
                                      if (booking.status == 'CONFIRMED')
                                        const Text('Đã xác nhận & đang chờ bàn giao xe', style: TextStyle(color: Colors.blue, fontSize: 12, fontStyle: FontStyle.italic)),
                                    ],
                                  ),
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

// -------------------------------------------------------------
// ASSIGN DRIVER DIALOG
// -------------------------------------------------------------
class _AssignDriverDialog extends StatefulWidget {
  final int bookingId;
  final int rentalUnitId;
  final VoidCallback onSuccess;

  const _AssignDriverDialog({
    required this.bookingId,
    required this.rentalUnitId,
    required this.onSuccess,
  });

  @override
  State<_AssignDriverDialog> createState() => _AssignDriverDialogState();
}

class _AssignDriverDialogState extends State<_AssignDriverDialog> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _drivers = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDrivers();
  }

  Future<void> _loadDrivers() async {
    try {
      final list = await _apiService.fetchAvailableDrivers();
      setState(() {
        _drivers = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDriver(int driverId) async {
    setState(() {
      _isLoading = true;
    });
    try {
      await _apiService.assignDriver(widget.bookingId, widget.rentalUnitId, driverId);
      Navigator.pop(context);
      widget.onSuccess();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Chọn tài xế rảnh', style: TextStyle(fontWeight: FontWeight.bold)),
      content: _isLoading
          ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))
          : _error != null
              ? Text(_error!, style: const TextStyle(color: Colors.red))
              : _drivers.isEmpty
                  ? const Text('Hiện không có tài xế nào rảnh.')
                  : SizedBox(
                      width: double.maxFinite,
                      height: 250,
                      child: ListView.builder(
                        itemCount: _drivers.length,
                        itemBuilder: (context, index) {
                          final driver = _drivers[index];
                          final id = driver['id'] as int;
                          final license = driver['licenseNumber'] ?? '';
                          final location = driver['currentLocation'] ?? '';
                          return ListTile(
                            leading: const CircleAvatar(child: Icon(Icons.person)),
                            title: Text('Tài xế #$id'),
                            subtitle: Text('GPLX: $license - Vị trí: $location'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _selectDriver(id),
                          );
                        },
                      ),
                    ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------
// TAB 2: BÀN GIAO & NHẬN XE (HANDOVER & RETURN)
// -------------------------------------------------------------
class _StaffHandoverReturnTab extends StatefulWidget {
  @override
  State<_StaffHandoverReturnTab> createState() => _StaffHandoverReturnTabState();
}

class _StaffHandoverReturnTabState extends State<_StaffHandoverReturnTab> {
  final ApiService _apiService = ApiService();
  List<Booking> _bookings = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final list = await _apiService.fetchAllBookings();
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

  void _showHandoverSheet(Booking booking, RentalUnit unit) {
    final odoController = TextEditingController(text: unit.vehicle?.odometerKm != null ? unit.vehicle!.odometerKm!.toInt().toString() : '0');
    final conditionController = TextEditingController(text: 'Bàn giao xe sạch sẽ, đầy đủ giấy tờ.');

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
            const Text('Biên bản Bàn giao xe (PICKUP)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                  await _apiService.staffHandoverStart(booking.id, unit.id, odo, cond);
                  _showSnackBar('Đã bàn giao xe cho khách hàng! Trạng thái: IN_PROGRESS', Colors.green);
                  _loadBookings();
                } catch (e) {
                  _showSnackBar(e.toString().replaceAll('Exception: ', ''), Colors.red);
                  setState(() {
                    _isLoading = false;
                  });
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
              child: const Text('Xác nhận Bàn giao xe', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showReturnSheet(Booking booking, RentalUnit unit) {
    final odoController = TextEditingController(text: unit.vehicle?.odometerKm != null ? unit.vehicle!.odometerKm!.toInt().toString() : '0');
    final conditionController = TextEditingController(text: 'Nhận lại xe an toàn, không hư hại.');
    final feeController = TextEditingController(text: '0');

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
            const Text('Biên bản Nhận lại xe (RETURN)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            TextField(
              controller: odoController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Chỉ số Odometer khi nhận lại (km) *', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: conditionController,
              decoration: const InputDecoration(labelText: 'Tình trạng xe khi nhận lại *', border: OutlineInputBorder()),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: feeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Phí phát sinh (nếu có) - VNĐ', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final odo = double.tryParse(odoController.text) ?? 0;
                final cond = conditionController.text.trim();
                final fee = double.tryParse(feeController.text) ?? 0;
                Navigator.pop(ctx);
                setState(() {
                  _isLoading = true;
                });
                try {
                  await _apiService.staffHandoverReturn(booking.id, unit.id, odo, cond, fee);
                  _showSnackBar('Đã nhận lại xe thành công! Trạng thái: COMPLETED', Colors.green);
                  _loadBookings();
                } catch (e) {
                  _showSnackBar(e.toString().replaceAll('Exception: ', ''), Colors.red);
                  setState(() {
                    _isLoading = false;
                  });
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF15803D)),
              child: const Text('Xác nhận Nhận lại xe', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF16A34A);
    
    // Handover & Return requires confirmed or in_progress bookings
    final list = _bookings.where((b) => b.status == 'CONFIRMED' || b.status == 'IN_PROGRESS').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff - Bàn giao & Nhận xe', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadBookings),
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
                        const Icon(Icons.error_outline, color: Colors.red, size: 48),
                        const SizedBox(height: 12),
                        Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _loadBookings, child: const Text('Thử lại')),
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
                          const Text('Không có đơn hàng cần giao nhận xe.', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadBookings,
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
                                        'Đơn hàng #${booking.id}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: (isPickup ? Colors.blue : Colors.teal).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          isPickup ? 'Chờ Bàn giao' : 'Đang thuê xe',
                                          style: TextStyle(
                                            color: isPickup ? Colors.blue : Colors.teal,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Biển số đơn: ${booking.bookingCode}',
                                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                                  ),
                                  const SizedBox(height: 12),
                                  
                                  ...booking.rentalUnits.map((unit) {
                                    return Container(
                                      margin: const EdgeInsets.only(top: 8),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.directions_car, color: primaryGreen),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(unit.vehicle != null ? '${unit.vehicle!.brand} ${unit.vehicle!.modelName}' : 'Xe tự lái', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                                Text(unit.vehicle?.plateNumber ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey, fontFamily: 'monospace')),
                                              ],
                                            ),
                                          ),
                                          ElevatedButton(
                                            onPressed: () => isPickup ? _showHandoverSheet(booking, unit) : _showReturnSheet(booking, unit),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: isPickup ? Colors.blue : Colors.teal,
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              minimumSize: Size.zero,
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            ),
                                            child: Text(
                                              isPickup ? 'Giao xe' : 'Nhận lại xe',
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
