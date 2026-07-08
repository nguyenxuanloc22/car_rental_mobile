import 'package:flutter/material.dart';
import '../../models/booking.dart';
import '../../services/booking_api_service.dart';
import 'package:intl/intl.dart';

class DriverStatsTab extends StatefulWidget {
  const DriverStatsTab({super.key});

  @override
  State<DriverStatsTab> createState() => _DriverStatsTabState();
}

class _DriverStatsTabState extends State<DriverStatsTab> {
  final BookingApiService _apiService = BookingApiService();
  bool _isLoading = true;
  String? _error;

  String _driverName = 'Tài xế';
  double _rating = 5.0;
  int _totalRating = 0;
  int _totalTrips = 0;
  int _completedTrips = 0;
  int _cancelledTrips = 0;
  int _ongoingTrips = 0;
  double _totalEarnings = 0.0;
  double _thisMonthEarnings = 0.0;
  List<Booking> _recentCompletedTrips = [];

  @override
  void initState() {
    super.initState();
    _loadStatsData();
  }

  Future<void> _loadStatsData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userId = await _apiService.getUserId();
      if (userId == null) {
        throw Exception('Vui lòng đăng nhập.');
      }

      // 1. Fetch driver profile
      final profile = await _apiService.getDriverByUserId(userId);
      
      // 2. Fetch driver bookings
      final bookings = await _apiService.getDriverBookings(profile.id);

      final currentMonth = DateTime.now().month;
      final currentYear = DateTime.now().year;

      int ongoing = 0;
      int completed = 0;
      int cancelled = 0;
      double earnings = 0.0;
      double monthEarnings = 0.0;
      List<Booking> recent = [];

      for (var b in bookings) {
        if (b.status == 'COMPLETED') {
          completed++;
          earnings += b.totalAmount;
          
          try {
            final dt = DateTime.parse(b.createdAt);
            if (dt.month == currentMonth && dt.year == currentYear) {
              monthEarnings += b.totalAmount;
            }
          } catch (_) {}

          recent.add(b);
        } else if (b.status == 'IN_PROGRESS') {
          ongoing++;
        } else if (b.status == 'CANCELLED') {
          cancelled++;
        }
      }

      // Sort recent completed trips descending
      recent.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (recent.length > 5) {
        recent = recent.sublist(0, 5);
      }

      setState(() {
        _driverName = profile.licenseNumber; // fallback or name
        _rating = 4.9; // simulated average rating
        _totalRating = completed;
        _totalTrips = bookings.length;
        _completedTrips = completed;
        _ongoingTrips = ongoing;
        _cancelledTrips = cancelled;
        _totalEarnings = earnings;
        _thisMonthEarnings = monthEarnings;
        _recentCompletedTrips = recent;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  String _formatMoney(double amount) {
    return NumberFormat.currency(locale: 'vi_VN', symbol: 'đ').format(amount);
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF16A34A);

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(primaryGreen))),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.dashboard_customize_outlined, color: Colors.orange, size: 48),
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _loadStatsData, child: const Text('Tải lại')),
              ],
            ),
          ),
        ),
      );
    }

    final int acceptanceRate = _totalTrips > 0 ? (((_totalTrips - _cancelledTrips) / _totalTrips) * 100).round() : 100;
    final double estimatedExpenses = _totalEarnings * 0.2; // fuel/operational cost = 20%
    final double estimatedMonthExpenses = _thisMonthEarnings * 0.2;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Tài xế', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadStatsData,
        color: primaryGreen,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // GREETING
            Text(
              'Xin chào, $_driverName! 👋',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Dưới đây là thống kê hiệu suất hoạt động của bạn',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 20),

            // SUMMARY CARDS GRID
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.4,
              children: [
                _buildGridCard('Đánh giá của bạn', '$_rating / 5.0', '$_totalRating chuyến', Icons.star, Colors.amber),
                _buildGridCard('Tổng chuyến đi', '$_totalTrips', '$_completedTrips hoàn thành', Icons.map, Colors.blue),
                _buildGridCard('Doanh thu tháng này', '${(_thisMonthEarnings / 1000000).toStringAsFixed(1)}M', 'Tổng: ${(_totalEarnings / 1000000).toStringAsFixed(1)}M', Icons.trending_up, Colors.green),
                _buildGridCard('Tỉ lệ hoàn thành', '$acceptanceRate%', 'Đã hủy: $_cancelledTrips', Icons.check_circle, Colors.purple),
              ],
            ),
            const SizedBox(height: 20),

            // FINANCIAL PANEL
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              color: Colors.white,
              elevation: 0.5,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.account_balance_wallet, color: Colors.green),
                        SizedBox(width: 8),
                        Text('Tổng quan thu nhập', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(height: 24),
                    _buildFinancialRow('Thu nhập từ các chuyến xe', _formatMoney(_totalEarnings), Colors.green),
                    const SizedBox(height: 10),
                    _buildFinancialRow('Doanh thu tháng hiện tại', _formatMoney(_thisMonthEarnings), Colors.blue),
                    const SizedBox(height: 10),
                    _buildFinancialRow('Phí xăng xe ước lượng (Tạm tính 20%)', _formatMoney(estimatedExpenses), Colors.red),
                    const SizedBox(height: 10),
                    _buildFinancialRow('Chi phí vận hành tháng này', _formatMoney(estimatedMonthExpenses), Colors.orange),
                    const Divider(height: 24),
                    _buildFinancialRow('Thu nhập ròng thực nhận', _formatMoney(_totalEarnings - estimatedExpenses), primaryGreen, isBold: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // PERFORMANCE METER
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              color: Colors.white,
              elevation: 0.5,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Hiệu suất làm việc', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Tỉ lệ chấp nhận/hoàn thành', style: TextStyle(fontSize: 13, color: Colors.grey)),
                        Text('$acceptanceRate%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: acceptanceRate / 100,
                      backgroundColor: Colors.grey.shade200,
                      color: primaryGreen,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildStatusBullet('Đang chạy', '$_ongoingTrips', Colors.blue),
                        const Spacer(),
                        _buildStatusBullet('Hoàn thành', '$_completedTrips', Colors.green),
                        const Spacer(),
                        _buildStatusBullet('Đã hủy', '$_cancelledTrips', Colors.red),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // RECENT TRIPS
            const Text(
              'Chuyến đi hoàn thành gần đây',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (_recentCompletedTrips.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Center(child: Text('Chưa có chuyến xe nào hoàn thành.', style: TextStyle(color: Colors.grey))),
              )
            else
              ..._recentCompletedTrips.map((trip) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  color: Colors.white,
                  elevation: 0.5,
                  child: ListTile(
                    leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.check, color: Colors.white)),
                    title: Text('Đơn hàng #${trip.id}'),
                    subtitle: Text('Đến: ${trip.deliveryAddress ?? "CRS Hub"} - ${_formatDate(trip.createdAt)}'),
                    trailing: Text(_formatMoney(trip.totalAmount), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                  ),
                );
              }),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildGridCard(String label, String value, String sub, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
              Icon(icon, color: color, size: 18),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 2),
          Text(sub, style: const TextStyle(fontSize: 10, color: Colors.black54), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildFinancialRow(String label, String value, Color color, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: isBold ? Colors.black87 : Colors.grey, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        Text(value, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildStatusBullet(String label, String count, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text('$label: ', style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(count, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      ],
    );
  }
}
