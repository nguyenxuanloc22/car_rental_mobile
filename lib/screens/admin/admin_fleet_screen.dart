import 'package:flutter/material.dart';
import '../../services/vehicle_api_service.dart';
import '../../services/booking_api_service.dart';
import '../../models/vehicle.dart';

class AdminFleetScreen extends StatefulWidget {
  const AdminFleetScreen({super.key});

  @override
  State<AdminFleetScreen> createState() => _AdminFleetScreenState();
}

class _AdminFleetScreenState extends State<AdminFleetScreen> {
  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF16A34A);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Quản lý Đội xe & Tài xế', style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          bottom: const TabBar(
            indicatorColor: primaryGreen,
            labelColor: primaryGreen,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(icon: Icon(Icons.directions_car), text: 'Đội xe'),
              Tab(icon: Icon(Icons.people), text: 'Tài xế'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _AdminVehiclesListTab(),
            _AdminDriversListTab(),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// SUB-TAB 1: VEHICLES CATALOG (WITH CRUD FOR ADMIN)
// -------------------------------------------------------------
class _AdminVehiclesListTab extends StatefulWidget {
  const _AdminVehiclesListTab();

  @override
  State<_AdminVehiclesListTab> createState() => _AdminVehiclesListTabState();
}

class _AdminVehiclesListTabState extends State<_AdminVehiclesListTab> {
  final VehicleApiService _apiService = VehicleApiService();
  List<Vehicle> _vehicles = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final list = await _apiService.fetchVehicles();
      setState(() {
        _vehicles = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _handleDeleteVehicle(Vehicle v) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa phương tiện?'),
        content: Text('Bạn có chắc chắn muốn xóa xe biển số ${v.plateNumber}? Hành động này không thể phục hồi.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xác nhận xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _isLoading = true;
      });
      try {
        await _apiService.deleteVehicle(v.id);
        _showSnackBar('Đã xóa xe thành công!', Colors.green);
        _loadVehicles();
      } catch (e) {
        _showSnackBar(e.toString().replaceAll('Exception: ', ''), Colors.red);
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showVehicleForm({Vehicle? vehicle}) {
    final isEdit = vehicle != null;
    final brandController = TextEditingController(text: isEdit ? vehicle!.brand : '');
    final modelController = TextEditingController(text: isEdit ? vehicle!.modelName : '');
    final plateController = TextEditingController(text: isEdit ? vehicle!.plateNumber : '');
    final vinController = TextEditingController(text: isEdit ? vehicle!.vin : '');
    final yearController = TextEditingController(text: isEdit ? vehicle!.manufactureYear?.toString() : '2026');
    final odoController = TextEditingController(text: isEdit ? vehicle!.odometerKm?.toInt().toString() : '0');
    final colorController = TextEditingController(text: isEdit ? vehicle!.color : '');
    final hubIdController = TextEditingController(text: isEdit ? vehicle!.fleetHubId?.toString() : '1');

    String selectedStatus = isEdit ? vehicle!.status : 'AVAILABLE';
    bool isVirtual = isEdit ? (vehicle!.isVirtual ?? false) : false;

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
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(isEdit ? 'Chỉnh sửa thông tin xe' : 'Đăng ký xe mới', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: brandController,
                          enabled: !isEdit,
                          decoration: const InputDecoration(labelText: 'Hãng xe *', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: modelController,
                          enabled: !isEdit,
                          decoration: const InputDecoration(labelText: 'Dòng xe *', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: plateController,
                          decoration: const InputDecoration(labelText: 'Biển số *', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: vinController,
                          enabled: !isEdit,
                          decoration: const InputDecoration(labelText: 'Số VIN *', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: yearController,
                          enabled: !isEdit,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Năm sản xuất', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: odoController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Odometer (km)', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: colorController,
                          decoration: const InputDecoration(labelText: 'Màu xe', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: hubIdController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Fleet Hub ID', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    value: selectedStatus,
                    decoration: const InputDecoration(labelText: 'Trạng thái hoạt động', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'AVAILABLE', child: Text('Sẵn sàng (AVAILABLE)')),
                      DropdownMenuItem(value: 'IN_USE', child: Text('Đang sử dụng (IN_USE)')),
                      DropdownMenuItem(value: 'MAINTENANCE', child: Text('Bảo trì (MAINTENANCE)')),
                      DropdownMenuItem(value: 'CHARGING', child: Text('Đang sạc (CHARGING)')),
                    ],
                    onChanged: (val) => setModalState(() => selectedStatus = val ?? 'AVAILABLE'),
                  ),
                  const SizedBox(height: 12),

                  CheckboxListTile(
                    value: isVirtual,
                    title: const Text('Xe ảo (Virtual Device Sim)'),
                    onChanged: isEdit ? null : (val) => setModalState(() => isVirtual = val ?? false),
                  ),
                  const SizedBox(height: 16),

                  ElevatedButton(
                    onPressed: () async {
                      final brand = brandController.text.trim();
                      final model = modelController.text.trim();
                      final plate = plateController.text.trim();
                      final vin = vinController.text.trim();

                      if (brand.isEmpty || model.isEmpty || plate.isEmpty || vin.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Vui lòng điền đầy đủ hãng, dòng xe, biển số, số VIN!'), backgroundColor: Colors.red),
                        );
                        return;
                      }

                      final Map<String, dynamic> data = {
                        'plateNumber': plate,
                        'color': colorController.text.trim(),
                        'status': selectedStatus,
                        'odometerKm': double.tryParse(odoController.text) ?? 0,
                        'fleetHubId': int.tryParse(hubIdController.text) ?? 1,
                      };

                      if (!isEdit) {
                        data['brand'] = brand;
                        data['modelName'] = model;
                        data['vin'] = vin;
                        data['manufactureYear'] = int.tryParse(yearController.text) ?? 2026;
                        data['modelId'] = 1; // default model link
                        data['isVirtual'] = isVirtual;
                      }

                      Navigator.pop(ctx);
                      setState(() {
                        _isLoading = true;
                      });

                      try {
                        if (isEdit) {
                          await _apiService.updateVehicle(vehicle!.id, data);
                          _showSnackBar('Cập nhật xe thành công!', Colors.green);
                        } else {
                          await _apiService.createVehicle(data);
                          _showSnackBar('Đăng ký xe mới thành công!', Colors.green);
                        }
                        _loadVehicles();
                      } catch (e) {
                        _showSnackBar(e.toString().replaceAll('Exception: ', ''), Colors.red);
                        setState(() {
                          _isLoading = false;
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(isEdit ? 'Lưu thay đổi' : 'Đăng ký xe', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
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
      case 'AVAILABLE':
        return Colors.blue;
      case 'IN_USE':
        return Colors.green;
      case 'MAINTENANCE':
        return Colors.red;
      case 'CHARGING':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'AVAILABLE':
        return 'Sẵn sàng';
      case 'IN_USE':
        return 'Đang sử dụng';
      case 'MAINTENANCE':
        return 'Bảo trì';
      case 'CHARGING':
        return 'Đang sạc';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF16A34A);
    final filtered = _vehicles.where((v) {
      final query = _searchQuery.toLowerCase();
      if (query.isEmpty) return true;
      return v.plateNumber.toLowerCase().contains(query) ||
          v.modelName.toLowerCase().contains(query) ||
          v.brand.toLowerCase().contains(query) ||
          (v.color?.toLowerCase().contains(query) ?? false);
    }).toList();

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      hintText: 'Tìm xe theo biển số, hãng...',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(icon: const Icon(Icons.refresh), onPressed: _loadVehicles),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(primaryGreen)))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 44),
                            const SizedBox(height: 8),
                            Text(_error!, style: const TextStyle(color: Colors.red)),
                            const SizedBox(height: 12),
                            ElevatedButton(onPressed: _loadVehicles, child: const Text('Thử lại')),
                          ],
                        ),
                      )
                    : filtered.isEmpty
                        ? const Center(child: Text('Không tìm thấy xe nào.', style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: filtered.length,
                            itemBuilder: (ctx, index) {
                              final v = filtered[index];
                              final statusColor = _getStatusColor(v.status);

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                color: Colors.white,
                                elevation: 0.5,
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('${v.brand} ${v.modelName}'.trim(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                              const SizedBox(height: 2),
                                              Text(v.plateNumber, style: const TextStyle(fontSize: 13, color: Colors.grey, fontFamily: 'monospace')),
                                            ],
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: statusColor.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              _getStatusText(v.status),
                                              style: TextStyle(
                                                color: statusColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 24),
                                      Row(
                                        children: [
                                          Expanded(child: _buildValueColumn('Màu sắc', v.color ?? '—')),
                                          Expanded(child: _buildValueColumn('Odometer', '${v.odometerKm?.toInt() ?? 0} km')),
                                          Expanded(child: _buildValueColumn('Trạm (Hub)', v.fleetHubName ?? '—')),
                                        ],
                                      ),
                                      const Divider(height: 24),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                            onPressed: () => _showVehicleForm(vehicle: v),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                            onPressed: () => _handleDeleteVehicle(v),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primaryGreen,
        icon: const Icon(Icons.add_a_photo_outlined, color: Colors.white),
        label: const Text('Thêm xe mới', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => _showVehicleForm(),
      ),
    );
  }

  Widget _buildValueColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87), overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

// -------------------------------------------------------------
// SUB-TAB 2: DRIVERS LIST FOR ADMIN (READ-ONLY/TOGGLE)
// -------------------------------------------------------------
class _AdminDriversListTab extends StatefulWidget {
  const _AdminDriversListTab();

  @override
  State<_AdminDriversListTab> createState() => _AdminDriversListTabState();
}

class _AdminDriversListTabState extends State<_AdminDriversListTab> {
  final BookingApiService _apiService = BookingApiService();
  List<Map<String, dynamic>> _drivers = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadDrivers();
  }

  Future<void> _loadDrivers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final list = await _apiService.fetchAllDrivers();
      setState(() {
        _drivers = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF16A34A);
    final filtered = _drivers.where((d) {
      final query = _searchQuery.toLowerCase();
      if (query.isEmpty) return true;
      final name = (d['fullName'] ?? d['name'] ?? '').toString().toLowerCase();
      final license = (d['licenseNumber'] ?? '').toString().toLowerCase();
      return name.contains(query) || license.contains(query);
    }).toList();

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      hintText: 'Tìm tài xế theo tên, GPLX...',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(icon: const Icon(Icons.refresh), onPressed: _loadDrivers),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(primaryGreen)))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 44),
                            const SizedBox(height: 8),
                            Text(_error!, style: const TextStyle(color: Colors.red)),
                            const SizedBox(height: 12),
                            ElevatedButton(onPressed: _loadDrivers, child: const Text('Thử lại')),
                          ],
                        ),
                      )
                    : filtered.isEmpty
                        ? const Center(child: Text('Không tìm thấy tài xế.', style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: filtered.length,
                            itemBuilder: (ctx, index) {
                              final d = filtered[index];
                              final status = (d['status'] ?? 'INACTIVE').toString();
                              final license = (d['licenseNumber'] ?? '—').toString();
                              final shift = (d['currentShift'] ?? d['shift'] ?? '—').toString();
                              final name = (d['fullName'] ?? d['name'] ?? 'Tài xế').toString();
                              final phone = (d['phoneNumber'] ?? d['phone'] ?? '—').toString();

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                color: Colors.white,
                                elevation: 0.5,
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: (status == 'ACTIVE' ? Colors.blue.shade50 : Colors.grey.shade100),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              status,
                                              style: TextStyle(
                                                color: (status == 'ACTIVE' ? Colors.blue : Colors.grey),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 24),
                                      _buildInfoRow(Icons.phone_android, 'Số điện thoại', phone),
                                      const SizedBox(height: 6),
                                      _buildInfoRow(Icons.badge, 'Bằng lái xe (GPLX)', license),
                                      const SizedBox(height: 6),
                                      _buildInfoRow(Icons.access_time, 'Ca làm việc', shift),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }
}
