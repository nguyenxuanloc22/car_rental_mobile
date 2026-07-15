import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/booking.dart';
import '../../services/booking_api_service.dart';
import 'booking_tracking_screen.dart';

class DriverWaitingScreen extends StatefulWidget {
  final Booking booking;

  const DriverWaitingScreen({super.key, required this.booking});

  @override
  State<DriverWaitingScreen> createState() => _DriverWaitingScreenState();
}

class _DriverWaitingScreenState extends State<DriverWaitingScreen> with SingleTickerProviderStateMixin {
  final BookingApiService _apiService = BookingApiService();
  Timer? _pollingTimer;
  late AnimationController _animationController;
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _startPolling();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await _checkBookingStatus();
    });
  }

  Future<void> _checkBookingStatus() async {
    try {
      final updatedBooking = await _apiService.fetchBookingById(widget.booking.id);
      
      if (!mounted) return;

      if (updatedBooking.status == 'IN_PROGRESS' || updatedBooking.status == 'CONFIRMED') {
        _pollingTimer?.cancel();
        
        // Chuyển sang màn hình Tracking
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => BookingTrackingScreen(booking: updatedBooking),
          ),
        );
      } else if (updatedBooking.status == 'CANCELLED') {
        _pollingTimer?.cancel();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chuyến đi đã bị huỷ.'), backgroundColor: Colors.red),
        );
        Navigator.pop(context); // Quay về trang chủ
      }
    } catch (e) {
      debugPrint('Error polling booking: $e');
    }
  }

  Future<void> _cancelBooking() async {
    setState(() {
      _isCancelling = true;
    });
    try {
      await _apiService.cancelBooking(widget.booking.id, 'Khách hàng huỷ trong lúc chờ tài xế');
      _pollingTimer?.cancel();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã huỷ tìm kiếm thành công.')),
        );
        Navigator.pop(context); // Quay về trang chủ
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCancelling = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF16A34A);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Đang tìm tài xế', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        titleTextStyle: const TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Cho phép user back về trang chủ nhưng hệ thống vẫn tiếp tục tìm
            Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _animationController,
                          builder: (context, child) {
                            return Container(
                              width: 150 + (_animationController.value * 50),
                              height: 150 + (_animationController.value * 50),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: primaryGreen.withOpacity(1.0 - _animationController.value),
                              ),
                            );
                          },
                        ),
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                spreadRadius: 2,
                              )
                            ]
                          ),
                          child: const Icon(
                            Icons.directions_car,
                            size: 50,
                            color: primaryGreen,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    const Text(
                      'Đang kết nối với tài xế gần bạn...',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        'Vui lòng giữ ứng dụng mở để nhận thông báo sớm nhất khi tài xế xác nhận chuyến đi.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Cancel button
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isCancelling ? null : _cancelBooking,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isCancelling 
                    ? const SizedBox(
                        height: 20, 
                        width: 20, 
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent)
                      )
                    : const Text(
                        'Huỷ yêu cầu',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
