class Vehicle {
  final int id;
  final String status;
  final String plateNumber;
  final double? odometerKm;
  final String? color;
  final String? fleetHubName;
  final String modelName;
  final String brand;
  final String? imageUrl;
  final int? batteryLevel;
  final String? vin;
  final int? manufactureYear;
  final int? fleetHubId;
  final bool? isVirtual;
  final double? latitude;
  final double? longitude;

  Vehicle({
    required this.id,
    required this.status,
    required this.plateNumber,
    this.odometerKm,
    this.color,
    this.fleetHubName,
    required this.modelName,
    required this.brand,
    this.imageUrl,
    this.batteryLevel,
    this.vin,
    this.manufactureYear,
    this.fleetHubId,
    this.isVirtual,
    this.latitude,
    this.longitude,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    final model = json['model'] as Map<String, dynamic>?;
    final currentState = json['currentState'] as Map<String, dynamic>?;

    return Vehicle(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      status: json['status'] ?? 'AVAILABLE',
      plateNumber: json['plateNumber'] ?? '',
      odometerKm: json['odometerKm'] != null ? (json['odometerKm'] as num).toDouble() : null,
      color: json['color'],
      fleetHubName: json['fleetHubName'],
      modelName: model != null ? (model['name'] ?? '') : 'Xe',
      brand: model != null ? (model['brand'] ?? '') : '',
      imageUrl: model != null ? model['imageUrl'] : null,
      batteryLevel: currentState != null ? currentState['batteryLevel'] as int? : null,
      vin: json['vin'],
      manufactureYear: json['manufactureYear'] as int?,
      fleetHubId: json['fleetHubId'] as int?,
      isVirtual: json['isVirtual'] as bool?,
      latitude: currentState != null ? (currentState['latitude'] as num?)?.toDouble() : null,
      longitude: currentState != null ? (currentState['longitude'] as num?)?.toDouble() : null,
    );
  }
}
