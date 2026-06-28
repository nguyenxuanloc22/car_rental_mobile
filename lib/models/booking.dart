import 'vehicle.dart';

class Booking {
  final int id;
  final String bookingCode;
  final String status;
  final String deliveryMode;
  final String? deliveryAddress;
  final double totalAmount;
  final String createdAt;
  final List<RentalUnit> rentalUnits;
  final List<Invoice> invoices;

  Booking({
    required this.id,
    required this.bookingCode,
    required this.status,
    required this.deliveryMode,
    this.deliveryAddress,
    required this.totalAmount,
    required this.createdAt,
    required this.rentalUnits,
    required this.invoices,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    var unitsList = json['rentalUnits'] as List? ?? [];
    List<RentalUnit> units = unitsList.map((u) => RentalUnit.fromJson(u)).toList();

    var invoicesList = json['invoices'] as List? ?? [];
    List<Invoice> invs = invoicesList.map((i) => Invoice.fromJson(i)).toList();

    return Booking(
      id: json['id'] as int? ?? 0,
      bookingCode: json['bookingCode'] ?? '',
      status: json['status'] ?? 'PENDING',
      deliveryMode: json['deliveryMode'] ?? 'SELF_PICKUP',
      deliveryAddress: json['deliveryAddress'],
      totalAmount: (json['totalAmount'] as num? ?? 0).toDouble(),
      createdAt: json['createdAt'] ?? '',
      rentalUnits: units,
      invoices: invs,
    );
  }
}

class RentalUnit {
  final int id;
  final String vehicleId;
  final bool isWithDriver;
  final String startTime;
  final String endTime;
  final double unitPrice;
  final Vehicle? vehicle;

  RentalUnit({
    required this.id,
    required this.vehicleId,
    required this.isWithDriver,
    required this.startTime,
    required this.endTime,
    required this.unitPrice,
    this.vehicle,
  });

  factory RentalUnit.fromJson(Map<String, dynamic> json) {
    return RentalUnit(
      id: json['id'] as int? ?? 0,
      vehicleId: (json['vehicleId'] ?? '').toString(),
      isWithDriver: json['isWithDriver'] as bool? ?? false,
      startTime: json['startTime'] ?? '',
      endTime: json['endTime'] ?? '',
      unitPrice: (json['unitPrice'] as num? ?? 0).toDouble(),
      vehicle: json['vehicle'] != null ? Vehicle.fromJson(json['vehicle']) : null,
    );
  }
}

class Invoice {
  final int id;
  final String status;
  final double amount;
  final String? paymentMethodType;
  final String? qrCodeData;

  Invoice({
    required this.id,
    required this.status,
    required this.amount,
    this.paymentMethodType,
    this.qrCodeData,
  });

  factory Invoice.fromJson(Map<String, dynamic> json) {
    return Invoice(
      id: json['id'] as int? ?? 0,
      status: json['status'] ?? 'UNPAID',
      amount: (json['amount'] as num? ?? 0).toDouble(),
      paymentMethodType: json['paymentMethodType'],
      qrCodeData: json['qrCodeData'],
    );
  }
}
