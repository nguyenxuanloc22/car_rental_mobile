import 'package:flutter/material.dart';

class AdminIncidentsScreen extends StatefulWidget {
  const AdminIncidentsScreen({super.key});

  @override
  State<AdminIncidentsScreen> createState() => _AdminIncidentsScreenState();
}

class _AdminIncidentsScreenState extends State<AdminIncidentsScreen> {
  final List<Map<String, dynamic>> _incidents = [
    {
      'id': 'INC001',
      'car': 'VinFast VF8',
      'reporter': 'Hệ thống AI',
      'date': '01/02/2026',
      'severity': 'Medium',
      'status': 'Pending',
      'desc': 'Phát hiện vết xước cản trước bên phải.',
    },
    {
      'id': 'INC002',
      'car': 'Tesla Model 3',
      'reporter': 'Khách hàng (Lê D)',
      'date': '31/01/2026',
      'severity': 'High',
      'status': 'Resolved',
      'desc': 'Móp cửa sau do va chạm.',
    },
    {
      'id': 'INC003',
      'car': 'Kia Carnival',
      'reporter': 'Hệ thống AI',
      'date': '02/02/2026',
      'severity': 'Low',
      'status': 'Pending',
      'desc': 'Áp suất lốp thấp bất thường.',
    },
  ];

  void _handleProcess(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Xử lý sự cố #${item['id']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Phương tiện: ${item['car']}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Nguồn báo cáo: ${item['reporter']}'),
            const SizedBox(height: 4),
            Text('Chi tiết: ${item['desc']}'),
            const SizedBox(height: 12),
            Container(
              height: 120,
              decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
              alignment: Alignment.center,
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt, color: Colors.grey),
                  SizedBox(height: 4),
                  Text('[Ảnh hiện trường giả lập AI]', style: TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                item['status'] = 'Ignored';
              });
              _showSnackBar('Đã bỏ qua báo cáo sự cố (Đánh dấu báo cáo sai).', Colors.blue);
            },
            child: const Text('Báo cáo sai (Bỏ qua)', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                item['status'] = 'Resolved';
              });
              _showSnackBar('Đã ghi nhận hư hại và gửi thông báo phạt thành công!', Colors.green);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xác nhận phạt', style: TextStyle(color: Colors.white)),
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

  Color _getSeverityColor(String sev) {
    if (sev == 'High') return Colors.red;
    if (sev == 'Medium') return Colors.orange;
    return Colors.blue;
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF16A34A);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sự cố & Hư hại (AI Detection)', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _incidents.length,
        itemBuilder: (ctx, index) {
          final item = _incidents[index];
          final String status = item['status'];
          final String severity = item['severity'];
          final Color sevColor = _getSeverityColor(severity);

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
                      Row(
                        children: [
                          Icon(
                            status == 'Pending' ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                            color: status == 'Pending' ? Colors.red : Colors.green,
                          ),
                          const SizedBox(width: 8),
                          Text(item['car'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                      Text('#${item['id']}', style: const TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'monospace')),
                    ],
                  ),
                  const Divider(height: 24),
                  Text(item['desc'], style: const TextStyle(color: Colors.black54, fontSize: 13)),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: sevColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                        child: Text('Mức độ: $severity', style: TextStyle(color: sevColor, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
                        child: Text('Nguồn: ${item['reporter']}', style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Ngày báo cáo: ${item['date']}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                      if (status == 'Pending')
                        ElevatedButton(
                          onPressed: () => _handleProcess(item),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Xử lý ngay', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        )
                      else if (status == 'Resolved')
                        const Text('Đã giải quyết', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13))
                      else
                        const Text('Đã bỏ qua', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
