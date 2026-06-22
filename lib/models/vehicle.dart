class Vehicle {
  final String id;
  final String status;
  final String plateNumber;
  final double? odometerKm;
  final String? color;
  final String? fleetHubName;
  final String modelName;
  final String brand;
  final String? imageUrl;
  final int? batteryLevel;

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
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    final model = json['model'] as Map<String, dynamic>?;
    final currentState = json['currentState'] as Map<String, dynamic>?;

    return Vehicle(
      id: (json['id'] ?? '').toString(),
      status: json['status'] ?? 'AVAILABLE',
      plateNumber: json['plateNumber'] ?? '',
      odometerKm: json['odometerKm'] != null ? (json['odometerKm'] as num).toDouble() : null,
      color: json['color'],
      fleetHubName: json['fleetHubName'],
      modelName: model != null ? (model['name'] ?? '') : 'Xe',
      brand: model != null ? (model['brand'] ?? '') : '',
      imageUrl: model != null ? model['imageUrl'] : null,
      batteryLevel: currentState != null ? currentState['batteryLevel'] as int? : null,
    );
  }
}
