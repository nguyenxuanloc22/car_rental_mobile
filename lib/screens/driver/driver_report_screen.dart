import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class DriverReportScreen extends StatefulWidget {
  const DriverReportScreen({super.key});

  @override
  State<DriverReportScreen> createState() => _DriverReportScreenState();
}

class _DriverReportScreenState extends State<DriverReportScreen> {
  List<Map<String, dynamic>> _reports = [];
  bool _isLoading = true;
  String _filterStatus = 'all';

  // Stats
  int _totalCount = 0;
  int _pendingCount = 0;
  int _resolvedCount = 0;
  int _highSeverityCount = 0;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('driver_reports');

    List<Map<String, dynamic>> list = [];
    if (jsonStr != null) {
      final decoded = jsonDecode(jsonStr);
      if (decoded is List) {
        list = List<Map<String, dynamic>>.from(decoded);
      }
    } else {
      // Default mock reports from web
      list = [
        {
          'id': 'RPT001',
          'type': 'damage',
          'title': 'Xước cản trước bên phải',
          'description': 'Phát hiện vết xước sâu khi kiểm tra xe buổi sáng',
          'severity': 'medium',
          'location': 'Quận 1',
          'date': '02/02/2026',
          'status': 'Đang xử lý',
          'createdAt': '02/02/2026 08:30',
        },
        {
          'id': 'RPT002',
          'type': 'accident',
          'title': 'Va chạm nhẹ tại giao lộ',
          'description': 'Va chạm với xe khác tại ngã tư Lê Lợi - Nguyễn Huệ',
          'severity': 'high',
          'location': 'Quận 1',
          'date': '01/02/2026',
          'status': 'Đã giải quyết',
          'createdAt': '01/02/2026 15:45',
        },
        {
          'id': 'RPT003',
          'type': 'complaint',
          'title': 'Khiếu nại từ khách hàng',
          'description': 'Khách hàng cho rằng tài xế lái quá nhanh',
          'severity': 'low',
          'location': 'Quận 3',
          'date': '31/01/2026',
          'status': 'Đã giải quyết',
          'createdAt': '31/01/2026 20:15',
        },
        {
          'id': 'RPT004',
          'type': 'vehicle',
          'title': 'Lốp xe bị xẹp',
          'description': 'Lốp sau bên trái bị xẹp khi lái, phải thay lốp dự phòng',
          'severity': 'high',
          'location': 'Quốc lộ 1',
          'date': '30/01/2026',
          'status': 'Đang xử lý',
          'createdAt': '30/01/2026 10:20',
        },
      ];
      await prefs.setString('driver_reports', jsonEncode(list));
    }

    setState(() {
      _reports = list;
      _isLoading = false;
      _calculateStats();
    });
  }

  void _calculateStats() {
    _totalCount = _reports.length;
    _pendingCount = _reports.where((r) => r['status'] == 'Chờ duyệt' || r['status'] == 'Đang xử lý').length;
    _resolvedCount = _reports.where((r) => r['status'] == 'Đã giải quyết').length;
    _highSeverityCount = _reports.where((r) => r['severity'] == 'high').length;
  }

  Future<void> _saveReports() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('driver_reports', jsonEncode(_reports));
    setState(() {
      _calculateStats();
    });
  }

  void _showNewReportDialog() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final locController = TextEditingController();
    String selectedType = 'damage';
    String selectedSeverity = 'medium';

    final types = [
      {'id': 'damage', 'label': 'Hư hại xe', 'icon': '🚗'},
      {'id': 'accident', 'label': 'Sự cố giao thông', 'icon': '⚠️'},
      {'id': 'complaint', 'label': 'Khiếu nại khách hàng', 'icon': '😠'},
      {'id': 'vehicle', 'label': 'Lỗi kỹ thuật', 'icon': '🔧'},
      {'id': 'other', 'label': 'Khác', 'icon': '📋'},
    ];

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
                      const Text('Gửi báo cáo sự cố mới', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 8),

                  // Report Type selection
                  const Text('Loại báo cáo *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: types.map((t) {
                      final isSel = selectedType == t['id'];
                      return ChoiceChip(
                        label: Text('${t['icon']} ${t['label']}'),
                        selected: isSel,
                        selectedColor: Colors.red.shade100,
                        backgroundColor: Colors.grey.shade100,
                        onSelected: (selected) {
                          if (selected) {
                            setModalState(() {
                              selectedType = t['id']!;
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Title
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Tiêu đề sự cố *', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),

                  // Description
                  TextField(
                    controller: descController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Mô tả chi tiết *', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),

                  // Location
                  TextField(
                    controller: locController,
                    decoration: const InputDecoration(labelText: 'Địa điểm xảy ra', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),

                  // Severity
                  const Text('Mức độ nghiêm trọng *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildSeverityOption(setModalState, 'low', 'Thấp', selectedSeverity, Colors.green),
                      const SizedBox(width: 8),
                      _buildSeverityOption(setModalState, 'medium', 'Trung bình', selectedSeverity, Colors.orange),
                      const SizedBox(width: 8),
                      _buildSeverityOption(setModalState, 'high', 'Cao', selectedSeverity, Colors.red),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  ElevatedButton(
                    onPressed: () {
                      final title = titleController.text.trim();
                      final desc = descController.text.trim();
                      if (title.isEmpty || desc.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Vui lòng điền tiêu đề và mô tả!'), backgroundColor: Colors.red),
                        );
                        return;
                      }

                      final now = DateTime.now();
                      final dateStr = DateFormat('dd/MM/yyyy').format(now);
                      final timeStr = DateFormat('dd/MM/yyyy HH:mm').format(now);

                      final newReport = {
                        'id': 'RPT${(_reports.length + 1).toString().padLeft(3, '0')}',
                        'type': selectedType,
                        'title': title,
                        'description': desc,
                        'severity': selectedSeverity,
                        'location': locController.text.trim(),
                        'date': dateStr,
                        'status': 'Chờ duyệt',
                        'createdAt': timeStr,
                      };

                      setState(() {
                        _reports.insert(0, newReport);
                      });
                      _saveReports();
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đã gửi báo cáo thành công!'), backgroundColor: Colors.green),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Gửi báo cáo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  Widget _buildSeverityOption(StateSetter setModalState, String id, String label, String current, Color color) {
    final isSelected = id == current;
    return Expanded(
      child: InkWell(
        onTap: () {
          setModalState(() {
            current = id;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.12) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? color : Colors.grey.shade300),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(color: isSelected ? color : Colors.black87, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      ),
    );
  }

  Color _getSeverityColor(String sev) {
    if (sev == 'high') return Colors.red;
    if (sev == 'medium') return Colors.orange;
    return Colors.green;
  }

  String _getSeverityText(String sev) {
    if (sev == 'high') return 'Cao';
    if (sev == 'medium') return 'Trung bình';
    return 'Thấp';
  }

  Color _getStatusColor(String status) {
    if (status == 'Đã giải quyết') return Colors.green;
    if (status == 'Đang xử lý') return Colors.blue;
    return Colors.amber;
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF16A34A);

    final filtered = _reports.where((r) {
      if (_filterStatus == 'all') return true;
      return r['status'] == _filterStatus;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Báo cáo sự cố', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(primaryGreen)))
          : Column(
              children: [
                // Stats Header
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.grey.shade50,
                  height: 100,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildStatCard('Tổng số báo cáo', '$_totalCount', Colors.blue),
                      _buildStatCard('Đang xử lý', '$_pendingCount', Colors.orange),
                      _buildStatCard('Đã giải quyết', '$_resolvedCount', Colors.green),
                      _buildStatCard('Mức độ Cao', '$_highSeverityCount', Colors.red),
                    ],
                  ),
                ),

                // Filters Layout
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Text('Bộ lọc:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _filterStatus,
                          decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10)),
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('Tất cả')),
                            DropdownMenuItem(value: 'Chờ duyệt', child: Text('Chờ duyệt')),
                            DropdownMenuItem(value: 'Đang xử lý', child: Text('Đang xử lý')),
                            DropdownMenuItem(value: 'Đã giải quyết', child: Text('Đã giải quyết')),
                          ],
                          onChanged: (val) => setState(() => _filterStatus = val ?? 'all'),
                        ),
                      ),
                    ],
                  ),
                ),

                // Reports List
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.report_gmailerrorred_outlined, size: 64, color: Colors.grey.shade300),
                              const SizedBox(height: 8),
                              const Text('Không có báo cáo nào.', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: filtered.length,
                          itemBuilder: (ctx, index) {
                            final r = filtered[index];
                            final sevColor = _getSeverityColor(r['severity'] ?? 'medium');
                            final statColor = _getStatusColor(r['status'] ?? 'Chờ duyệt');

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
                                    Expanded(
                                      child: Text(r['title'] ?? 'Báo cáo sự cố', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: statColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        r['status']?.toString() ?? 'Chờ duyệt',
                                        style: TextStyle(color: statColor, fontWeight: FontWeight.bold, fontSize: 10),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(r['description'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(color: sevColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                                child: Text(
                                                  'Mức độ: ${_getSeverityText(r['severity']?.toString() ?? 'medium')}',
                                                  style: TextStyle(color: sevColor, fontSize: 10, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                              if (r['location'] != null && r['location'] != '') ...[
                                                const SizedBox(width: 8),
                                                Text('📍 ${r['location']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                              ]
                                            ],
                                          ),
                                          Text(r['createdAt'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                onTap: () => _showReportDetailModal(r),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.red,
        onPressed: _showNewReportDialog,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Báo cáo mới', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      width: 130,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color.withOpacity(0.9), fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showReportDetailModal(Map<String, dynamic> r) {
    final sevColor = _getSeverityColor(r['severity'] ?? 'medium');
    final statColor = _getStatusColor(r['status'] ?? 'Chờ duyệt');

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
                Text('Chi tiết báo cáo ${r['id']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            _buildDetailRow('Tiêu đề', r['title'] ?? ''),
            _buildDetailRow('Phân loại', r['type'] == 'damage' ? 'Hư hại xe' : r['type'] == 'accident' ? 'Sự cố giao thông' : r['type'] == 'complaint' ? 'Khiếu nại khách hàng' : r['type'] == 'vehicle' ? 'Lỗi kỹ thuật' : 'Khác'),
            _buildDetailRow('Mức độ', _getSeverityText(r['severity'] ?? 'medium'), valueColor: sevColor),
            _buildDetailRow('Trạng thái', r['status'] ?? 'Chờ duyệt', valueColor: statColor),
            _buildDetailRow('Ngày báo cáo', r['date'] ?? ''),
            _buildDetailRow('Thời gian tạo', r['createdAt'] ?? ''),
            if (r['location'] != null && r['location'] != '') _buildDetailRow('Địa điểm', r['location']),
            const SizedBox(height: 12),
            const Text('Mô tả chi tiết sự cố:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
              child: Text(r['description'] ?? '', style: const TextStyle(fontSize: 13, color: Colors.black87)),
            ),
            const SizedBox(height: 24),
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
}


