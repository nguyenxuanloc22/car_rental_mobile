import 'package:flutter/material.dart';
import '../../models/booking.dart';
import '../../services/booking_api_service.dart';
import 'package:intl/intl.dart';

class DriverHistoryScreen extends StatefulWidget {
  const DriverHistoryScreen({super.key});

  @override
  State<DriverHistoryScreen> createState() => _DriverHistoryScreenState();
}

class _DriverHistoryScreenState extends State<DriverHistoryScreen> {
  final BookingApiService _apiService = BookingApiService();
  List<Booking> _trips = [];
  bool _isLoading = true;
  String? _error;

  int _totalTrips = 0;
  int _completedTrips = 0;
  int _cancelledTrips = 0;
  double _totalEarnings = 0.0;

  String _searchQuery = '';
  String _filterStatus = 'ALL'; // ALL, COMPLETED, CANCELLED
  String _filterMonth = 'ALL'; // ALL, THIS_MONTH, LAST_MONTH

  @override
  void initState() {
    super.initState();
    _loadHistoryData();
  }

  Future<void> _loadHistoryData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userId = await _apiService.getUserId();
      if (userId == null) {
        throw Exception('Vui lòng đăng nhập.');
      }

      final profile = await _apiService.getDriverByUserId(userId);
      if (profile.id == 0) {
        throw Exception('Tài khoản của bạn chưa được thiết lập hồ sơ tài xế.');
      }
      
      // Fetch both completed and cancelled
      final completed = await _apiService.getDriverBookings(profile.id);
      
      // Calculate stats
      int compCount = 0;
      int cancelCount = 0;
      double earnings = 0.0;

      for (var b in completed) {
        if (b.status == 'COMPLETED') {
          compCount++;
          earnings += b.totalAmount;
        } else if (b.status == 'CANCELLED') {
          cancelCount++;
        }
      }

      setState(() {
        _trips = completed;
        _totalTrips = completed.length;
        _completedTrips = compCount;
        _cancelledTrips = cancelCount;
        _totalEarnings = earnings;
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
      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF16A34A);

    // Apply filtering
    final now = DateTime.now();
    final filtered = _trips.where((t) {
      // Search query
      final query = _searchQuery.toLowerCase();
      if (query.isNotEmpty) {
        final matchCode = t.bookingCode.toLowerCase().contains(query);
        final matchAddress = (t.deliveryAddress ?? '').toLowerCase().contains(query);
        final matchId = t.id.toString().contains(query);
        if (!matchCode && !matchAddress && !matchId) return false;
      }

      // Status filter
      if (_filterStatus != 'ALL') {
        if (t.status != _filterStatus) return false;
      } else {
        // Only display COMPLETED or CANCELLED in history tab
        if (t.status != 'COMPLETED' && t.status != 'CANCELLED') return false;
      }

      // Month filter
      if (_filterMonth != 'ALL') {
        try {
          final dt = DateTime.parse(t.createdAt);
          if (_filterMonth == 'THIS_MONTH') {
            if (dt.month != now.month || dt.year != now.year) return false;
          } else if (_filterMonth == 'LAST_MONTH') {
            final prevMonth = now.month == 1 ? 12 : now.month - 1;
            final prevYear = now.month == 1 ? now.year - 1 : now.year;
            if (dt.month != prevMonth || dt.year != prevYear) return false;
          }
        } catch (_) {}
      }

      return true;
    }).toList();

    // Sort by createdAt descending
    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử chuyến đi', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadHistoryData),
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
                        const Icon(Icons.history_toggle_off, color: Colors.orange, size: 48),
                        const SizedBox(height: 12),
                        Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _loadHistoryData, child: const Text('Thử lại')),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    // STATS HIGHLIGHT CAROUSEL
                    Container(
                      height: 110,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      color: Colors.grey.shade50,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          _buildStatCard('Tổng chuyến đi', '$_totalTrips', '$_completedTrips hoàn thành', Colors.blue),
                          _buildStatCard('Tổng thu nhập', '${(_totalEarnings / 1000000).toStringAsFixed(1)}M', 'Trung bình: ${_totalTrips > 0 ? _formatMoney(_totalEarnings / _totalTrips) : 0}', Colors.green),
                          _buildStatCard('Tỉ lệ hoàn thành', '${_totalTrips > 0 ? ((_completedTrips / _totalTrips) * 100).toInt() : 100}%', 'Hủy: $_cancelledTrips chuyến', Colors.purple),
                        ],
                      ),
                    ),

                    // SEARCH & FILTERS
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        children: [
                          TextField(
                            onChanged: (val) => setState(() => _searchQuery = val),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.search, size: 20),
                              hintText: 'Tìm kiếm theo mã, địa chỉ...',
                              contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              filled: true,
                              fillColor: Colors.grey.shade100,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _filterStatus,
                                  decoration: InputDecoration(
                                    labelText: 'Trạng thái',
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 'ALL', child: Text('Tất cả')),
                                    DropdownMenuItem(value: 'COMPLETED', child: Text('Hoàn thành')),
                                    DropdownMenuItem(value: 'CANCELLED', child: Text('Đã hủy')),
                                  ],
                                  onChanged: (val) => setState(() => _filterStatus = val ?? 'ALL'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _filterMonth,
                                  decoration: InputDecoration(
                                    labelText: 'Tháng',
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 'ALL', child: Text('Tất cả')),
                                    DropdownMenuItem(value: 'THIS_MONTH', child: Text('Tháng này')),
                                    DropdownMenuItem(value: 'LAST_MONTH', child: Text('Tháng trước')),
                                  ],
                                  onChanged: (val) => setState(() => _filterMonth = val ?? 'ALL'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // LIST
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.directions_car_filled_outlined, size: 64, color: Colors.grey.shade300),
                                  const SizedBox(height: 8),
                                  const Text('Không có chuyến đi nào thỏa mãn điều kiện lọc.', style: TextStyle(color: Colors.grey)),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: filtered.length,
                              itemBuilder: (ctx, index) {
                                final trip = filtered[index];
                                final isComp = trip.status == 'COMPLETED';

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  color: Colors.white,
                                  elevation: 0.5,
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.all(16),
                                    title: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Chuyến đi #${trip.id}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: (isComp ? Colors.green.shade50 : Colors.red.shade50),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            isComp ? 'Hoàn thành' : 'Đã hủy',
                                            style: TextStyle(
                                              color: isComp ? Colors.green : Colors.red,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Mã: ${trip.bookingCode}', style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(Icons.location_on, size: 14, color: Colors.red),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  trip.deliveryAddress ?? 'Nhận xe tại bãi',
                                                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text('Ngày: ${_formatDate(trip.createdAt)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                              Text(isComp ? _formatMoney(trip.totalAmount) : '—', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    onTap: () => _showTripDetailModal(trip),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildStatCard(String label, String value, String sub, Color color) {
    return Container(
      width: 150,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color.withOpacity(0.9), fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(sub, style: const TextStyle(color: Colors.black54, fontSize: 10), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  void _showTripDetailModal(Booking trip) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Chi tiết chuyến đi #${trip.id}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            _buildDetailRow('Mã Code', trip.bookingCode),
            _buildDetailRow('Thời gian', _formatDate(trip.createdAt)),
            _buildDetailRow('Tổng tiền cước', _formatMoney(trip.totalAmount)),
            _buildDetailRow('Nhận hàng', 'CRS Hub'),
            _buildDetailRow('Giao hàng', trip.deliveryAddress ?? 'Nhận xe tại bãi'),
            _buildDetailRow('Loại giao dịch', trip.deliveryMode == 'DELIVERY' ? 'Giao xe tận nơi' : 'Tự nhận tại bãi'),
            _buildDetailRow('Trạng thái chuyến', trip.status == 'COMPLETED' ? 'Hoàn thành' : 'Đã hủy'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
                backgroundColor: Colors.grey.shade800,
              ),
              child: const Text('Đóng', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}
