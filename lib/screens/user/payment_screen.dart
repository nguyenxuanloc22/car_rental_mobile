import 'package:flutter/material.dart';
import 'dart:convert';
import '../../services/booking_api_service.dart';
import '../../models/booking.dart';
import 'package:intl/intl.dart';

class PaymentScreen extends StatefulWidget {
  final int invoiceId;
  final double amount;
  final int bookingId;
  final String bookingCode;

  const PaymentScreen({
    super.key,
    required this.invoiceId,
    required this.amount,
    required this.bookingId,
    required this.bookingCode,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final BookingApiService _apiService = BookingApiService();
  String _paymentMethod = 'CASH'; // CASH, E_WALLET, BANK_TRANSFER, CREDIT_CARD
  bool _isLoading = false;
  String? _error;
  Invoice? _result;

  Future<void> _handlePayment() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _result = null;
    });

    try {
      final res = await _apiService.processPayment(
        widget.invoiceId,
        _paymentMethod,
        widget.amount,
      );
      setState(() {
        _result = res;
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
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    return formatter.format(amount);
  }

  Widget? _buildQRCodeImage(String? qrData) {
    if (qrData == null || qrData.isEmpty) return null;
    try {
      if (qrData.startsWith('data:image')) {
        final base64Str = qrData.substring(qrData.indexOf(',') + 1);
        final bytes = base64Decode(base64Str);
        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade200, width: 2),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(12),
          child: Image.memory(
            bytes,
            width: 200,
            height: 200,
            fit: BoxFit.contain,
          ),
        );
      } else if (qrData.startsWith('http')) {
        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade200, width: 2),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(12),
          child: Image.network(
            qrData,
            width: 200,
            height: 200,
            fit: BoxFit.contain,
            errorBuilder: (c, e, s) => const Icon(Icons.qr_code, size: 100, color: Colors.grey),
          ),
        );
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF16A34A);
    const bgGray = Color(0xFFF9FAFB);

    return Scaffold(
      backgroundColor: bgGray,
      appBar: AppBar(
        title: const Text('Thanh toán hóa đơn', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Invoice details card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 1,
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: primaryGreen.withOpacity(0.1),
                      child: const Icon(Icons.receipt_long, color: primaryGreen, size: 28),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Thanh toán cho Booking #${widget.bookingId}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Mã đơn: ${widget.bookingCode}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'monospace'),
                    ),
                    const Divider(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Số tiền thanh toán', style: TextStyle(color: Colors.grey, fontSize: 14)),
                        Text(
                          _formatMoney(widget.amount),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (_result == null) ...[
              // Select Payment Method
              const Text(
                'Chọn phương thức thanh toán',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
              ),
              const SizedBox(height: 12),
              
              // Cash Option
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: _paymentMethod == 'CASH' ? primaryGreen : Colors.transparent,
                    width: 2,
                  ),
                ),
                color: Colors.white,
                child: ListTile(
                  leading: const Icon(Icons.money, color: Colors.amber, size: 30),
                  title: const Text('Tiền mặt (CASH)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('Thanh toán trực tiếp cho nhân viên khi giao nhận xe', style: TextStyle(fontSize: 12)),
                  trailing: Radio<String>(
                    value: 'CASH',
                    groupValue: _paymentMethod,
                    activeColor: primaryGreen,
                    onChanged: (val) {
                      setState(() {
                        _paymentMethod = val!;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // E-Wallet Option
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: _paymentMethod == 'E_WALLET' ? primaryGreen : Colors.transparent,
                    width: 2,
                  ),
                ),
                color: Colors.white,
                child: ListTile(
                  leading: const Icon(Icons.qr_code_scanner, color: primaryGreen, size: 30),
                  title: const Text('Ví điện tử (E_WALLET)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('Quét mã QR Code thanh toán online tức thì', style: TextStyle(fontSize: 12)),
                  trailing: Radio<String>(
                    value: 'E_WALLET',
                    groupValue: _paymentMethod,
                    activeColor: primaryGreen,
                    onChanged: (val) {
                      setState(() {
                        _paymentMethod = val!;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Error banner
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade200),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Pay button
              ElevatedButton(
                onPressed: _isLoading ? null : _handlePayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Xác nhận thanh toán',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ] else ...[
              // Payment Successful Display
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                color: Colors.white,
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      const CircleAvatar(
                        radius: 28,
                        backgroundColor: Color(0xFFDCFCE7),
                        child: Icon(Icons.check_circle, color: primaryGreen, size: 36),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Yêu cầu xử lý thành công!',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: primaryGreen),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Hóa đơn #${_result!.id} — Trạng thái: ${_result!.status == 'PAID' ? 'ĐÃ THANH TOÁN' : 'ĐANG CHỜ QUÉT MÃ'}',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                      const Divider(height: 32),

                      // If QR code is present for E-wallet
                      if (_paymentMethod == 'E_WALLET' && _result!.qrCodeData != null) ...[
                        const Text(
                          'Quét mã QR dưới đây để hoàn tất:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                        ),
                        const SizedBox(height: 12),
                        _buildQRCodeImage(_result!.qrCodeData) ?? const SizedBox.shrink(),
                        const SizedBox(height: 16),
                      ],

                      // Back Button
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          minimumSize: const Size(double.infinity, 44),
                        ),
                        child: const Text('Hoàn tất & Quay lại', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
