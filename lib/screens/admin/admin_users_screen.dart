import 'dart:math';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _roles = [];
  bool _isLoading = true;
  String? _error;

  String _searchKeyword = '';
  String _filterActive = 'all'; // all, true, false

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final uList = await _apiService.fetchAdminUsers(
        keyword: _searchKeyword.trim(),
        isActive: _filterActive == 'all' ? null : _filterActive,
      );
      final rList = await _apiService.fetchRoles();

      setState(() {
        _users = uList;
        _roles = rList;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _handleToggleStatus(Map<String, dynamic> user) async {
    final bool currentActive = user['isActive'] ?? user['active'] ?? true;
    final String action = currentActive ? 'khóa' : 'mở khóa';
    final String userId = (user['userId'] ?? user['id'] ?? '').toString();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Xác nhận $action?'),
        content: Text('Bạn có chắc chắn muốn $action tài khoản ${user['email']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: currentActive ? Colors.red : Colors.green),
            child: Text('Xác nhận', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _isLoading = true;
      });
      try {
        await _apiService.toggleAdminUserActive(userId, !currentActive);
        _showSnackBar('Đã $action tài khoản thành công!', Colors.green);
        _loadData();
      } catch (e) {
        _showSnackBar(e.toString().replaceAll('Exception: ', ''), Colors.red);
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleDeleteUser(Map<String, dynamic> user) async {
    final String userId = (user['userId'] ?? user['id'] ?? '').toString();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa tài khoản?'),
        content: Text('Hành động này sẽ xóa vĩnh viễn tài khoản ${user['email']}. Hãy xác nhận!'),
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
        await _apiService.deleteAdminUser(userId);
        _showSnackBar('Đã xóa người dùng thành công!', Colors.green);
        _loadData();
      } catch (e) {
        _showSnackBar(e.toString().replaceAll('Exception: ', ''), Colors.red);
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showResetPasswordDialog(Map<String, dynamic> user) {
    final String userId = (user['userId'] ?? user['id'] ?? '').toString();
    final passController = TextEditingController();
    bool obscure = true;

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
                const Text('Đặt lại mật khẩu', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Text('Cập nhật mật khẩu mới cho tài khoản người dùng', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const Divider(height: 24),
                
                TextField(
                  controller: passController,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu mới *',
                    border: const OutlineInputBorder(),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setModalState(() => obscure = !obscure),
                        ),
                        IconButton(
                          icon: const Icon(Icons.key, color: Colors.orange),
                          onPressed: () {
                            // Generate random
                            const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#';
                            final rand = Random();
                            final pass = List.generate(10, (index) => chars[rand.nextInt(chars.length)]).join();
                            setModalState(() {
                              passController.text = pass;
                            });
                          },
                          tooltip: 'Tạo mật khẩu ngẫu nhiên',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: () async {
                    final pass = passController.text.trim();
                    if (pass.isEmpty || pass.length < 6) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Mật khẩu tối thiểu phải 6 ký tự!'), backgroundColor: Colors.red),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    setState(() {
                      _isLoading = true;
                    });
                    try {
                      await _apiService.resetAdminUserPassword(userId, pass);
                      _showSnackBar('Đổi mật khẩu người dùng thành công!', Colors.green);
                      _loadData();
                    } catch (e) {
                      _showSnackBar(e.toString().replaceAll('Exception: ', ''), Colors.red);
                      setState(() {
                        _isLoading = false;
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  child: const Text('Xác nhận đổi mật khẩu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showUserFormDialog({Map<String, dynamic>? user}) {
    final isEdit = user != null;
    final emailController = TextEditingController(text: isEdit ? user['email'] : '');
    final nameController = TextEditingController(text: isEdit ? user['fullName'] : '');
    final phoneController = TextEditingController(text: isEdit ? (user['phone'] ?? user['phoneNumber'] ?? '') : '');
    final dobController = TextEditingController(text: isEdit ? (user['dob'] ?? '') : '');
    final passwordController = TextEditingController();
    
    String selectedGender = isEdit ? (user['gender'] ?? 'MALE') : 'MALE';
    int? selectedRoleId = isEdit ? (user['role']?['id'] ?? _roles.firstWhere((r) => r['name'] == 'CUSTOMER', orElse: () => {'id': 2})['id']) : (_roles.firstWhere((r) => r['name'] == 'CUSTOMER', orElse: () => {'id': 2})['id']);
    bool active = isEdit ? (user['isActive'] ?? user['active'] ?? true) : true;
    bool obscure = true;

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
                      Text(isEdit ? 'Chỉnh sửa tài khoản' : 'Tạo người dùng mới', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 8),

                  // Email
                  TextField(
                    controller: emailController,
                    enabled: !isEdit,
                    decoration: InputDecoration(
                      labelText: 'Email *',
                      border: const OutlineInputBorder(),
                      fillColor: isEdit ? Colors.grey.shade100 : Colors.white,
                      filled: isEdit,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Full name
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Họ và tên *', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),

                  // Password (only for create)
                  if (!isEdit) ...[
                    TextField(
                      controller: passwordController,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu *',
                        border: const OutlineInputBorder(),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                              onPressed: () => setModalState(() => obscure = !obscure),
                            ),
                            IconButton(
                              icon: const Icon(Icons.key, color: Colors.blue),
                              onPressed: () {
                                const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#';
                                final rand = Random();
                                final pass = List.generate(10, (index) => chars[rand.nextInt(chars.length)]).join();
                                setModalState(() {
                                  passwordController.text = pass;
                                });
                              },
                              tooltip: 'Tạo mật khẩu ngẫu nhiên',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Phone & Dob
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(labelText: 'Số điện thoại', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: dobController,
                          decoration: const InputDecoration(labelText: 'Ngày sinh (YYYY-MM-DD)', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Gender & Role ID
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedGender,
                          decoration: const InputDecoration(labelText: 'Giới tính', border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 'MALE', child: Text('Nam')),
                            DropdownMenuItem(value: 'FEMALE', child: Text('Nữ')),
                            DropdownMenuItem(value: 'OTHER', child: Text('Khác')),
                          ],
                          onChanged: (val) => setModalState(() => selectedGender = val ?? 'MALE'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: selectedRoleId,
                          decoration: const InputDecoration(labelText: 'Vai trò', border: OutlineInputBorder()),
                          items: _roles.map((role) {
                            return DropdownMenuItem<int>(
                              value: role['id'] as int,
                              child: Text(role['name'] ?? ''),
                            );
                          }).toList(),
                          onChanged: (val) => setModalState(() => selectedRoleId = val),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Active status toggle
                  CheckboxListTile(
                    value: active,
                    title: const Text('Kích hoạt tài khoản'),
                    onChanged: (val) => setModalState(() => active = val ?? true),
                  ),
                  const SizedBox(height: 16),

                  // Action Buttons
                  ElevatedButton(
                    onPressed: () async {
                      final email = emailController.text.trim();
                      final name = nameController.text.trim();
                      final phone = phoneController.text.trim();
                      final dob = dobController.text.trim();

                      if (email.isEmpty || name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Vui lòng nhập Email và Họ tên!'), backgroundColor: Colors.red),
                        );
                        return;
                      }

                      final Map<String, dynamic> data = {
                        'email': email,
                        'fullName': name,
                        'phone': phone,
                        'gender': selectedGender,
                        'dob': dob.isEmpty ? null : dob,
                        'roleId': selectedRoleId,
                        'isActive': active,
                      };

                      if (!isEdit) {
                        final pass = passwordController.text.trim();
                        if (pass.isEmpty || pass.length < 6) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Vui lòng điền mật khẩu tối thiểu 6 ký tự!'), backgroundColor: Colors.red),
                          );
                          return;
                        }
                        data['password'] = pass;
                      }

                      Navigator.pop(ctx);
                      setState(() {
                        _isLoading = true;
                      });

                      try {
                        if (isEdit) {
                          final String userId = (user['userId'] ?? user['id'] ?? '').toString();
                          await _apiService.updateAdminUser(userId, data);
                          _showSnackBar('Cập nhật tài khoản thành công!', Colors.green);
                        } else {
                          await _apiService.createAdminUser(data);
                          _showSnackBar('Tạo tài khoản mới thành công!', Colors.green);
                        }
                        _loadData();
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
                    child: Text(isEdit ? 'Lưu thay đổi' : 'Tạo người dùng', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  Color _getRoleColor(String rName) {
    if (rName == 'ADMIN') return Colors.purple;
    if (rName == 'STAFF') return Colors.blue;
    if (rName == 'DRIVER') return Colors.teal;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF16A34A);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý người dùng', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Box
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                TextField(
                  onChanged: (val) {
                    setState(() {
                      _searchKeyword = val;
                    });
                    _loadData();
                  },
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, size: 20),
                    hintText: 'Tìm kiếm theo tên, email...',
                    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Bộ lọc:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _filterActive,
                        decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10)),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('Tất cả trạng thái')),
                          DropdownMenuItem(value: 'true', child: Text('Đang hoạt động')),
                          DropdownMenuItem(value: 'false', child: Text('Đã khóa')),
                        ],
                        onChanged: (val) {
                          setState(() => _filterActive = val ?? 'all');
                          _loadData();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Main list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(primaryGreen)))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.people_outline, color: Colors.orange, size: 48),
                            const SizedBox(height: 12),
                            Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            ElevatedButton(onPressed: _loadData, child: const Text('Thử lại')),
                          ],
                        ),
                      )
                    : _users.isEmpty
                        ? const Center(child: Text('Không có tài khoản nào.', style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _users.length,
                            itemBuilder: (ctx, index) {
                              final u = _users[index];
                              final rName = u['role']?['name'] ?? 'CUSTOMER';
                              final active = u['isActive'] ?? u['active'] ?? true;

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
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(u['fullName'] ?? 'Người dùng', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                                Text(u['email'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: _getRoleColor(rName).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              rName,
                                              style: TextStyle(color: _getRoleColor(rName), fontWeight: FontWeight.bold, fontSize: 10),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 24),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(active ? Icons.check_circle : Icons.cancel, color: active ? Colors.green : Colors.red, size: 16),
                                              const SizedBox(width: 6),
                                              Text(active ? 'Hoạt động' : 'Đã khóa', style: TextStyle(color: active ? Colors.green : Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              // Edit button
                                              IconButton(
                                                icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                                onPressed: () => _showUserFormDialog(user: u),
                                                constraints: const BoxConstraints(),
                                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                              ),
                                              // Password Reset key
                                              IconButton(
                                                icon: const Icon(Icons.vpn_key, color: Colors.orange, size: 20),
                                                onPressed: () => _showResetPasswordDialog(u),
                                                constraints: const BoxConstraints(),
                                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                              ),
                                              // Block button
                                              IconButton(
                                                icon: Icon(active ? Icons.block : Icons.lock_open, color: active ? Colors.red : Colors.green, size: 20),
                                                onPressed: () => _handleToggleStatus(u),
                                                constraints: const BoxConstraints(),
                                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                              ),
                                              // Delete button
                                              IconButton(
                                                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                                onPressed: () => _handleDeleteUser(u),
                                                constraints: const BoxConstraints(),
                                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                              ),
                                            ],
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
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Thêm thành viên', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => _showUserFormDialog(),
      ),
    );
  }
}
