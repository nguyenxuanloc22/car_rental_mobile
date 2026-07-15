import 'package:flutter/material.dart';
import '../../models/booking.dart';
import '../../services/booking_api_service.dart';
import 'package:intl/intl.dart';

class AdminBookingsScreen extends StatefulWidget {
  const AdminBookingsScreen({super.key});

  @override
  State<AdminBookingsScreen> createState() => _AdminBookingsScreenState();
}

class _AdminBookingsScreenState extends State<AdminBookingsScreen> {
  final BookingApiService _apiService = BookingApiService();
  List<Booking> _bookings = [];
  bool _isLoading = true;
  String? _error;

  String _filterStatus = 'ALL'; // ALL, PENDING, CONFIRMED, IN_PROGRESS, COMPLETED, CANCELLED
  int _currentPage = 0;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 0;
      _bookings = [];
      _hasMore = true;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final statusParam = _filterStatus == 'ALL' ? null : _filterStatus;
      final list = await _apiService.fetchAllBookings(
        status: statusParam,
        page: _currentPage,
        size: 15,
      );

      setState(() {
        if (list.length < 15) {
          _hasMore = false;
        }
        _bookings.addAll(list);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _handleConfirm(Booking booking) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Duyệt đơn đặt xe?'),
        content: Text('Xác nhận duyệt booking #${booking.id} (${booking.bookingCode})? Hóa đơn cước phí sẽ được lập tự động.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Xác nhận', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _isLoading = true;
      });
      try {
        await _apiService.confirmBooking(booking.id);
        _showSnackBar('Đã phê duyệt đơn hàng thành công!', Colors.green);
        _loadBookings(refresh: true);
      } catch (e) {
        _showSnackBar(e.toString().replaceAll('Exception: ', ''), Colors.red);
        setState(() {
          _isLoading = false;
        });
      }
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
          _loadBookings(refresh: true);
        },
      ),
    );
  }

  Future<void> _handleCancel(Booking booking) async {
    final reasonController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hủy đơn đặt xe?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Bạn có chắc chắn muốn hủy đơn hàng #${booking.id}?'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(labelText: 'Lý do hủy đơn *', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xác nhận hủy', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final reason = reasonController.text.trim();
      if (reason.isEmpty) {
        _showSnackBar('Vui lòng điền lý do hủy đơn!', Colors.red);
        return;
      }
      setState(() {
        _isLoading = true;
      });
      try {
        await _apiService.cancelBooking(booking.id, reason);
        _showSnackBar('Đã hủy đơn hàng thành công.', Colors.green);
        _loadBookings(refresh: true);
      } catch (e) {
        _showSnackBar(e.toString().replaceAll('Exception: ', ''), Colors.red);
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showPaymentSheet(Booking booking, Invoice unpaidInvoice) {
    String selectedMethod = 'CASH';
    bool isProcessing = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              top: 24,
              left: 24,
              right: 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Thanh toán hóa đơn', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Số tiền cần thu: ${_formatMoney(unpaidInvoice.amount)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                const Divider(height: 24),

                const Text('Phương thức thanh toán:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                _buildPaymentMethodOption(setModalState, 'CASH', '💵 Tiền mặt', selectedMethod),
                const SizedBox(height: 8),
                _buildPaymentMethodOption(setModalState, 'E_WALLET', '📱 Ví điện tử', selectedMethod),
                const SizedBox(height: 8),
                _buildPaymentMethodOption(setModalState, 'BANK_TRANSFER', '🏦 Chuyển khoản ngân hàng', selectedMethod),
                const SizedBox(height: 16),

                ElevatedButton(
                  onPressed: isProcessing ? null : () async {
                    setModalState(() {
                      isProcessing = true;
                    });
                    try {
                      await _apiService.processPayment(unpaidInvoice.id, selectedMethod, unpaidInvoice.amount);
                      Navigator.pop(ctx);
                      _showSnackBar('Thanh toán hóa đơn thành công!', Colors.green);
                      _loadBookings(refresh: true);
                    } catch (e) {
                      setModalState(() {
                        isProcessing = false;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: isProcessing
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Xác nhận thanh toán', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPaymentMethodOption(StateSetter setModalState, String id, String label, String current) {
    final isSelected = id == current;
    return InkWell(
      onTap: () => setModalState(() => current = id),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green.shade50 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? Colors.green : Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_off, color: isSelected ? Colors.green : Colors.grey),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  void _showBookingDetailModal(Booking booking) {
    final hasUnpaid = booking.invoices.any((i) => i.status == 'UNPAID') && booking.status != 'CANCELLED';
    final unpaidInvoice = booking.invoices.firstWhere((i) => i.status == 'UNPAID', orElse: () => booking.invoices.first);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Chi tiết Booking #${booking.id}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(),
              _buildDetailRow('Mã Booking', booking.bookingCode),
              _buildDetailRow('Thời gian tạo', _formatDate(booking.createdAt)),
              _buildDetailRow('Tổng số tiền', _formatMoney(booking.totalAmount), valueColor: Colors.green),
              _buildDetailRow('Phương thức giao xe', booking.deliveryMode == 'DELIVERY' ? 'Giao tận nơi' : 'Tự nhận tại bãi'),
              if (booking.deliveryAddress != null) _buildDetailRow('Địa chỉ nhận xe', booking.deliveryAddress!),
              _buildDetailRow('Trạng thái đơn', _getStatusText(booking.status)),
              const SizedBox(height: 16),

              const Text('Thông tin xe thuê:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 6),
              ...booking.rentalUnits.map((unit) {
                final vehicle = unit.vehicle;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(vehicle != null ? '${vehicle.brand} ${vehicle.modelName}' : 'Xe tự lái', style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (vehicle?.plateNumber != null) Text(vehicle!.plateNumber, style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                      const SizedBox(height: 4),
                      Text('Thuê: ${_formatDate(unit.startTime)} → ${_formatDate(unit.endTime)}', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                      if (unit.isWithDriver && booking.status == 'CONFIRMED')
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _showAssignDriverDialog(booking, unit);
                            },
                            icon: const Icon(Icons.person_add, size: 14),
                            label: const Text('Phân công tài xế', style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF16A34A),
                              minimumSize: const Size(0, 32),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 16),
              const Text('Hóa đơn thanh toán:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 6),
              ...booking.invoices.map((inv) {
                final isPaid = inv.status == 'PAID';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${inv.type} — ${_formatMoney(inv.amount)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  subtitle: Text('ID: ${inv.id} — ${inv.paymentMethodType ?? "Chưa thanh toán"}', style: const TextStyle(fontSize: 11)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: isPaid ? Colors.green.shade50 : Colors.red.shade50, borderRadius: BorderRadius.circular(6)),
                    child: Text(isPaid ? 'Đã TT' : 'Chưa TT', style: TextStyle(color: isPaid ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 10)),
                  ),
                );
              }),

              const SizedBox(height: 24),
              Row(
                children: [
                  if (booking.status == 'PENDING') ...[
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _handleConfirm(booking);
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        child: const Text('Phê duyệt', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (booking.status == 'CONFIRMED' && hasUnpaid) ...[
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showPaymentSheet(booking, unpaidInvoice);
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                        child: const Text('Thu tiền cước', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (booking.status == 'PENDING' || booking.status == 'CONFIRMED') ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _handleCancel(booking);
                        },
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                        child: const Text('Hủy đơn', style: TextStyle(color: Colors.red)),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade800),
                      child: const Text('Đóng', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: valueColor ?? Colors.black87)),
        ],
      ),
    );
  }

  String _formatMoney(double amount) {
    return NumberFormat.currency(locale: 'vi_VN', symbol: 'đ').format(amount);
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

  String _getStatusText(String status) {
    switch (status) {
      case 'PENDING':
        return 'Chờ duyệt';
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

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF16A34A);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Đặt xe', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => _loadBookings(refresh: true)),
        ],
      ),
      body: Column(
        children: [
          // Filter section
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                const Text('Bộ lọc:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _filterStatus,
                    decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10)),
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('Tất cả trạng thái')),
                      DropdownMenuItem(value: 'PENDING', child: Text('Chờ duyệt (PENDING)')),
                      DropdownMenuItem(value: 'CONFIRMED', child: Text('Đã duyệt (CONFIRMED)')),
                      DropdownMenuItem(value: 'IN_PROGRESS', child: Text('Đang thuê (IN_PROGRESS)')),
                      DropdownMenuItem(value: 'COMPLETED', child: Text('Hoàn thành (COMPLETED)')),
                      DropdownMenuItem(value: 'CANCELLED', child: Text('Đã hủy (CANCELLED)')),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _filterStatus = val ?? 'ALL';
                      });
                      _loadBookings(refresh: true);
                    },
                  ),
                ),
              ],
            ),
          ),

          // Main list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _bookings.length + (_hasMore ? 1 : 0),
              itemBuilder: (ctx, index) {
                if (index == _bookings.length) {
                  // Loader at bottom
                  _loadBookings();
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(primaryGreen))),
                  );
                }

                final b = _bookings[index];
                final statusColor = _getStatusColor(b.status);
                final hasUnpaid = b.invoices.any((inv) => inv.status == 'UNPAID') && b.status != 'CANCELLED';

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
                        Text('Đơn hàng #${b.id}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                          child: Text(
                            _getStatusText(b.status),
                            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Mã Code: ${b.bookingCode}', style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Tổng tiền: ${_formatMoney(b.totalAmount)}', style: const TextStyle(fontWeight: FontWeight.bold, color: primaryGreen)),
                              Text(_formatDate(b.createdAt), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                          if (hasUnpaid) ...[
                            const SizedBox(height: 6),
                            const Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.red, size: 14),
                                SizedBox(width: 4),
                                Text('Có hóa đơn chưa thanh toán', style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    onTap: () => _showBookingDetailModal(b),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// ASSIGN DRIVER DIALOG (SHARED LOGIC)
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
  final BookingApiService _apiService = BookingApiService();
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
      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
      }
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
