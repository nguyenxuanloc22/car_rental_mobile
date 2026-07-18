import 'package:flutter/material.dart';
import '../../models/booking.dart';
import '../../services/booking_api_service.dart';
import 'payment_screen.dart';
import 'booking_tracking_screen.dart';
import 'package:intl/intl.dart';

class BookingHistoryScreen extends StatefulWidget {
  const BookingHistoryScreen({super.key});

  @override
  BookingHistoryScreenState createState() => BookingHistoryScreenState();
}

class BookingHistoryScreenState extends State<BookingHistoryScreen> {
  final BookingApiService _apiService = BookingApiService();
  List<Booking> _bookings = [];
  bool _isLoading = true;
  String? _error;

  void reload() {
    _loadBookings();
  }

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
      final userId = await _apiService.getUserId();
      if (userId == null || userId.isEmpty) {
        throw Exception('Vui lòng đăng nhập để xem lịch sử.');
      }
      final list = await _apiService.fetchUserBookings(userId);
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

  Future<void> _handleCancelBooking(Booking booking) async {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hủy đặt xe', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bạn có chắc chắn muốn hủy đơn #${booking.id}?'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Lý do hủy đơn *',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Vui lòng nhập lý do hủy đơn!'), backgroundColor: Colors.red),
                );
                return;
              }
              Navigator.pop(ctx);
              setState(() {
                _isLoading = true;
              });
              try {
                await _apiService.cancelBooking(booking.id, reason);
                _showSnackBar('Đã hủy đơn đặt xe thành công.', Colors.green);
                _loadBookings();
              } catch (e) {
                _showSnackBar(e.toString().replaceAll('Exception: ', ''), Colors.red);
                setState(() {
                  _isLoading = false;
                });
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xác nhận hủy', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'PENDING':
        return Colors.orange;
      case 'CONFIRMED':
        return Colors.blue;
      case 'IN_PROGRESS':
        return Colors.teal;
      case 'COMPLETED':
        return Colors.green;
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'PENDING':
        return 'Chờ Staff duyệt';
      case 'CONFIRMED':
        return 'Đã xác nhận';
      case 'IN_PROGRESS':
        return 'Đang thuê xe';
      case 'COMPLETED':
        return 'Đã hoàn thành';
      case 'CANCELLED':
        return 'Đã hủy đơn';
      default:
        return status;
    }
  }

  String _formatMoney(double amount) {
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    return formatter.format(amount);
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  void _showBookingDetails(Booking booking) {
    final unpaidInvoice = booking.invoices.isEmpty ? null : booking.invoices.firstWhere((inv) => inv.status == 'UNPAID', orElse: () => booking.invoices.first);
    final isUnpaid = unpaidInvoice != null && unpaidInvoice.status == 'UNPAID' && booking.status != 'CANCELLED';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Đơn đặt xe #${booking.id}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text('Mã: ${booking.bookingCode}', style: const TextStyle(color: Colors.grey, fontSize: 13, fontFamily: 'monospace')),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getStatusColor(booking.status).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _getStatusText(booking.status),
                          style: TextStyle(color: _getStatusColor(booking.status), fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),

                  // Units Details
                  const Text('Thông tin xe thuê', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  if (booking.rentalUnits.isEmpty)
                    const Text('Không có thông tin xe', style: TextStyle(color: Colors.grey))
                  else
                    ...booking.rentalUnits.map((unit) {
                      final vehicle = unit.vehicle;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.white,
                                  radius: 20,
                                  child: Icon(Icons.directions_car, color: _getStatusColor(booking.status)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        vehicle != null ? '${vehicle.brand} ${vehicle.modelName}'.trim() : 'Xe tự lái',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        vehicle?.plateNumber ?? '',
                                        style: const TextStyle(fontSize: 12, color: Colors.grey, fontFamily: 'monospace'),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            _buildInfoRow('Loại dịch vụ', unit.isWithDriver ? 'Có tài xế' : 'Tự lái'),
                            if (unit.isWithDriver) ...[
                              _buildInfoRow('Điểm đón', booking.pickupAddress ?? 'N/A'),
                              _buildInfoRow('Điểm đến', booking.dropoffAddress ?? 'N/A'),
                            ] else ...[
                              _buildInfoRow('Nhận xe', _formatDate(unit.startTime)),
                              _buildInfoRow('Trả xe', _formatDate(unit.endTime)),
                            ],
                            _buildInfoRow('Đơn giá', '${_formatMoney(unit.unitPrice)}/ngày'),
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 16),

                  // Delivery Mode & Address (Only for self-drive or DELIVERY)
                  if (!booking.rentalUnits.any((u) => u.isWithDriver) || booking.deliveryMode == 'DELIVERY') ...[
                    const Text('Giao nhận xe', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(
                      booking.deliveryMode == 'DELIVERY' ? '🚚 Giao xe tận nơi' : '🏢 Tự nhận tại bãi xe',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    if (booking.deliveryAddress != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        booking.deliveryAddress!,
                        style: const TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                    const Divider(height: 32),
                  ],

                  // Pricing and invoices
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tổng tiền thanh toán', style: TextStyle(fontSize: 15, color: Colors.black54)),
                      Text(
                        _formatMoney(booking.totalAmount),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (booking.invoices.isNotEmpty) ...[
                    const Text('Hóa đơn liên quan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    ...booking.invoices.map((inv) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Hóa đơn #${inv.id} (${inv.paymentMethodType ?? "Chưa thanh toán"})', style: const TextStyle(fontSize: 13, color: Colors.black54)),
                              Text(
                                inv.status == 'PAID' ? 'Đã thanh toán' : 'Chưa thanh toán',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: inv.status == 'PAID' ? Colors.green : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                  const SizedBox(height: 28),

                  // Actions
                  Row(
                    children: [
                      // Tracking Button (if with driver and in progress/confirmed)
                      if (booking.rentalUnits.isNotEmpty && booking.rentalUnits.first.isWithDriver &&
                          (booking.status == 'CONFIRMED' || booking.status == 'IN_PROGRESS'))
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => BookingTrackingScreen(booking: booking),
                                ),
                              );
                            },
                            icon: const Icon(Icons.map, color: Colors.white, size: 18),
                            label: const Text('Theo dõi chuyến đi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      if (booking.rentalUnits.isNotEmpty && booking.rentalUnits.first.isWithDriver &&
                          (booking.status == 'CONFIRMED' || booking.status == 'IN_PROGRESS') &&
                          (booking.status == 'PENDING' || booking.status == 'CONFIRMED' || isUnpaid))
                        const SizedBox(width: 12),

                      // Cancel Button
                      if (booking.status == 'PENDING' || booking.status == 'CONFIRMED')
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _handleCancelBooking(booking);
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Hủy đơn đặt xe', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      
                      // Spacing
                      if ((booking.status == 'PENDING' || booking.status == 'CONFIRMED') && isUnpaid)
                        const SizedBox(width: 12),

                      // Pay Button
                      if (isUnpaid)
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              Navigator.pop(ctx);
                              final paid = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PaymentScreen(
                                    invoiceId: unpaidInvoice.id,
                                    amount: unpaidInvoice.amount,
                                    bookingId: booking.id,
                                    bookingCode: booking.bookingCode,
                                  ),
                                ),
                              );
                              if (paid == true) {
                                _loadBookings();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF16A34A),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Thanh toán ngay', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.black87)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF16A34A);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử đặt xe', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
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
                        ElevatedButton(onPressed: _loadBookings, child: const Text('Tải lại')),
                      ],
                    ),
                  ),
                )
              : _bookings.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text('Bạn chưa thực hiện đơn đặt xe nào.', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadBookings,
                      color: primaryGreen,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _bookings.length,
                        itemBuilder: (context, index) {
                          final booking = _bookings[index];
                          final statusColor = _getStatusColor(booking.status);
                          final hasUnpaid = booking.invoices.any((inv) => inv.status == 'UNPAID') && booking.status != 'CANCELLED';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 1,
                            color: Colors.white,
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => _showBookingDetails(booking),
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
                                            color: statusColor.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            _getStatusText(booking.status),
                                            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Mã: ${booking.bookingCode}',
                                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.grey),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('Tổng số tiền', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                            const SizedBox(height: 2),
                                            Text(
                                              _formatMoney(booking.totalAmount),
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryGreen),
                                            ),
                                          ],
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            const Text('Thời gian đặt', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                            const SizedBox(height: 2),
                                            Text(
                                              _formatDate(booking.createdAt),
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    if (hasUnpaid) ...[
                                      const Divider(height: 24),
                                      Row(
                                        children: [
                                          const Icon(Icons.info_outline, color: Colors.red, size: 16),
                                          const SizedBox(width: 6),
                                          const Text(
                                            'Có hóa đơn chưa thanh toán',
                                            style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w500),
                                          ),
                                          const Spacer(),
                                          const Text(
                                            'Xem chi tiết →',
                                            style: TextStyle(color: primaryGreen, fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
