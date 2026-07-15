import 'dart:math';
import 'package:flutter/material.dart';
import '../../services/auth_api_service.dart';
import '../../services/booking_api_service.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final AuthApiService _apiService = AuthApiService();
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
    
    // Extra controllers for Driver profile
    final licenseNumberController = TextEditingController();
    final licenseClassController = TextEditingController(text: 'B2');
    
    // Extra controllers for Staff profile
    final fleetHubIdController = TextEditingController(text: '1');
    final positionController = TextEditingController(text: 'SUPPORT');
    
    // Extra controllers for Customer profile
    final nationalIdController = TextEditingController();
    final drivingLicenseNumberController = TextEditingController();

    String selectedGender = isEdit ? (user['gender'] ?? 'MALE') : 'MALE';
    String selectedRoleName = isEdit
        ? (user['role']?['name']?.toString().toUpperCase() ?? 'CUSTOMER')
        : 'CUSTOMER';
    bool active = isEdit ? (user['isActive'] ?? user['active'] ?? true) : true;
    bool obscure = true;

    // Local error and loading state for Dialog
    String? localError;
    bool dialogLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEdit ? 'Chỉnh sửa tài khoản' : 'Tạo người dùng mới',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: dialogLoading ? null : () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 8),

                  // Form content scrollable area
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Email
                          TextField(
                            controller: emailController,
                            enabled: !isEdit && !dialogLoading,
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
                            enabled: !dialogLoading,
                            decoration: const InputDecoration(labelText: 'Họ và tên *', border: OutlineInputBorder()),
                          ),
                          const SizedBox(height: 12),

                          // Password (only for create)
                          if (!isEdit) ...[
                            TextField(
                              controller: passwordController,
                              obscureText: obscure,
                              enabled: !dialogLoading,
                              decoration: InputDecoration(
                                labelText: 'Mật khẩu *',
                                border: const OutlineInputBorder(),
                                suffixIcon: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                                      onPressed: dialogLoading ? null : () => setModalState(() => obscure = !obscure),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.key, color: Colors.blue),
                                      onPressed: dialogLoading ? null : () {
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

                          // Phone
                          TextField(
                            controller: phoneController,
                            keyboardType: TextInputType.phone,
                            enabled: !dialogLoading,
                            decoration: const InputDecoration(labelText: 'Số điện thoại *', border: OutlineInputBorder()),
                          ),
                          const SizedBox(height: 12),

                          // Date of Birth (DatePicker)
                          InkWell(
                            onTap: dialogLoading ? null : () async {
                              final DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: dobController.text.isNotEmpty
                                    ? (DateTime.tryParse(dobController.text) ?? DateTime(2000, 1, 1))
                                    : DateTime(2000, 1, 1),
                                firstDate: DateTime(1900),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                setModalState(() {
                                  dobController.text =
                                      "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                                });
                              }
                            },
                            child: IgnorePointer(
                              child: TextField(
                                controller: dobController,
                                decoration: const InputDecoration(
                                  labelText: 'Ngày sinh *',
                                  border: OutlineInputBorder(),
                                  suffixIcon: Icon(Icons.calendar_month, color: Colors.green),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Gender
                          DropdownButtonFormField<String>(
                            value: selectedGender,
                            decoration: const InputDecoration(labelText: 'Giới tính', border: OutlineInputBorder()),
                            items: const [
                              DropdownMenuItem(value: 'MALE', child: Text('Nam')),
                              DropdownMenuItem(value: 'FEMALE', child: Text('Nữ')),
                              DropdownMenuItem(value: 'OTHER', child: Text('Khác')),
                            ],
                            onChanged: dialogLoading ? null : (val) => setModalState(() => selectedGender = val ?? 'MALE'),
                          ),
                          const SizedBox(height: 12),

                          // Role Selection
                          DropdownButtonFormField<String>(
                            value: selectedRoleName,
                            decoration: const InputDecoration(labelText: 'Vai trò', border: OutlineInputBorder()),
                            items: _roles.map((role) {
                              final rName = (role['name'] ?? 'CUSTOMER').toString().toUpperCase();
                              return DropdownMenuItem<String>(
                                value: rName,
                                child: Text(rName),
                              );
                            }).toList(),
                            onChanged: dialogLoading ? null : (val) {
                              if (val != null) {
                                setModalState(() => selectedRoleName = val);
                              }
                            },
                          ),
                          const SizedBox(height: 12),

                          // Active status toggle
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: active,
                            title: const Text('Kích hoạt tài khoản'),
                            onChanged: dialogLoading ? null : (val) => setModalState(() => active = val ?? true),
                          ),
                          const SizedBox(height: 12),

                          // DYNAMIC PROFILE FIELDS FOR CREATION ONLY
                          if (!isEdit) ...[
                            const Divider(),
                            const SizedBox(height: 8),
                            if (selectedRoleName == 'DRIVER') ...[
                              const Text('Thông tin bổ sung: TÀI XẾ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                              const SizedBox(height: 10),
                              TextField(
                                controller: licenseNumberController,
                                enabled: !dialogLoading,
                                decoration: const InputDecoration(labelText: 'Số GPLX *', border: OutlineInputBorder(), hintText: 'Ví dụ: 790123456789'),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: licenseClassController,
                                enabled: !dialogLoading,
                                decoration: const InputDecoration(labelText: 'Hạng bằng lái *', border: OutlineInputBorder(), hintText: 'Ví dụ: B2, C, D'),
                              ),
                            ] else if (selectedRoleName == 'STAFF') ...[
                              const Text('Thông tin bổ sung: NHÂN VIÊN', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                              const SizedBox(height: 10),
                              TextField(
                                controller: fleetHubIdController,
                                keyboardType: TextInputType.number,
                                enabled: !dialogLoading,
                                decoration: const InputDecoration(labelText: 'Mã Hub làm việc (FleetHub ID) *', border: OutlineInputBorder(), hintText: 'Ví dụ: 1'),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: positionController,
                                enabled: !dialogLoading,
                                decoration: const InputDecoration(labelText: 'Vị trí công tác *', border: OutlineInputBorder(), hintText: 'Ví dụ: SUPPORT, MANAGER'),
                              ),
                            ] else if (selectedRoleName == 'CUSTOMER') ...[
                              const Text('Thông tin bổ sung: KHÁCH HÀNG', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                              const SizedBox(height: 10),
                              TextField(
                                controller: nationalIdController,
                                enabled: !dialogLoading,
                                decoration: const InputDecoration(labelText: 'Số CCCD/CMND *', border: OutlineInputBorder(), hintText: 'Ví dụ: 079123456789'),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: drivingLicenseNumberController,
                                enabled: !dialogLoading,
                                decoration: const InputDecoration(labelText: 'Số GPLX khách tự lái (nếu có)', border: OutlineInputBorder(), hintText: 'Ví dụ: 790123456789'),
                              ),
                            ],
                            const SizedBox(height: 16),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Display local error message
                  if (localError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      localError!,
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ],

                  // Loading indicator inside the dialog
                  if (dialogLoading) ...[
                    const SizedBox(height: 12),
                    const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                      ),
                    ),
                  ],

                  // Bottom buttons
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: dialogLoading ? null : () => Navigator.pop(ctx),
                        child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: dialogLoading ? null : () async {
                          final email = emailController.text.trim();
                          final name = nameController.text.trim();
                          final phone = phoneController.text.trim();
                          final dob = dobController.text.trim();

                          // 1. Core validations
                          if (email.isEmpty) {
                            setModalState(() {
                              localError = 'Email không được để trống!';
                            });
                            return;
                          }
                          final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                          if (!emailRegex.hasMatch(email)) {
                            setModalState(() {
                              localError = 'Email không đúng định dạng!';
                            });
                            return;
                          }

                          if (name.isEmpty) {
                            setModalState(() {
                              localError = 'Họ và tên không được để trống!';
                            });
                            return;
                          }

                          if (phone.isEmpty) {
                            setModalState(() {
                              localError = 'Số điện thoại không được để trống!';
                            });
                            return;
                          }
                          final phoneRegex = RegExp(r'^(0|\+84)[3|5|7|8|9][0-9]{8}$');
                          if (!phoneRegex.hasMatch(phone)) {
                            setModalState(() {
                              localError = 'Số điện thoại không hợp lệ (Ví dụ: 0912345678)!';
                            });
                            return;
                          }

                          if (dob.isEmpty) {
                            setModalState(() {
                              localError = 'Vui lòng chọn ngày sinh!';
                            });
                            return;
                          }

                          String? pass;
                          if (!isEdit) {
                            pass = passwordController.text.trim();
                            if (pass.isEmpty) {
                              setModalState(() {
                                localError = 'Mật khẩu không được để trống!';
                              });
                              return;
                            }
                            if (pass.length < 6) {
                              setModalState(() {
                                localError = 'Mật khẩu tối thiểu phải từ 6 ký tự!';
                              });
                              return;
                            }

                            // Dynamic fields validation
                            if (selectedRoleName == 'DRIVER') {
                              if (licenseNumberController.text.trim().isEmpty) {
                                setModalState(() {
                                  localError = 'Số GPLX cho tài xế bắt buộc điền!';
                                });
                                return;
                              }
                              if (licenseClassController.text.trim().isEmpty) {
                                setModalState(() {
                                  localError = 'Hạng bằng lái cho tài xế bắt buộc điền!';
                                });
                                return;
                              }
                            } else if (selectedRoleName == 'STAFF') {
                              if (fleetHubIdController.text.trim().isEmpty || int.tryParse(fleetHubIdController.text.trim()) == null) {
                                setModalState(() {
                                  localError = 'Mã Hub làm việc không hợp lệ!';
                                });
                                return;
                              }
                              if (positionController.text.trim().isEmpty) {
                                setModalState(() {
                                  localError = 'Vị trí công tác cho nhân viên bắt buộc điền!';
                                });
                                return;
                              }
                            } else if (selectedRoleName == 'CUSTOMER') {
                              if (nationalIdController.text.trim().isEmpty) {
                                setModalState(() {
                                  localError = 'Số CCCD cho khách hàng bắt buộc điền!';
                                });
                                return;
                              }
                            }
                          }

                          final int roleId = _roles.firstWhere(
                            (r) => r['name']?.toString().toUpperCase() == selectedRoleName,
                            orElse: () => {'id': 2},
                          )['id'] as int;

                          final Map<String, dynamic> data = {
                            'email': email,
                            'fullName': name,
                            'phone': phone,
                            'gender': selectedGender,
                            'dob': dob,
                            'role': selectedRoleName,
                            'roleName': selectedRoleName,
                            'roleId': roleId,
                            'isActive': active,
                            'isDeleted': isEdit ? (user['isDeleted'] ?? false) : false,
                          };

                          if (!isEdit && pass != null) {
                            data['password'] = pass;
                          }

                          setModalState(() {
                            dialogLoading = true;
                            localError = null;
                          });

                          try {
                            if (isEdit) {
                              final String userId = (user['userId'] ?? user['id'] ?? '').toString();
                              await _apiService.updateAdminUser(userId, data);
                            } else {
                              // 1. Call IAM-service to create user
                              final userResponse = await _apiService.createAdminUser(data);
                              final String? newUserId = userResponse['userId']?.toString() ?? userResponse['id']?.toString();

                              if (newUserId != null) {
                                final bookingApi = BookingApiService();
                                // 2. Call corresponding business profile creation API
                                if (selectedRoleName == 'DRIVER') {
                                  await bookingApi.createDriverProfile({
                                    'userId': newUserId,
                                    'licenseNumber': licenseNumberController.text.trim(),
                                    'licenseClass': licenseClassController.text.trim(),
                                    'currentLocation': 'Chưa cập nhật',
                                    'status': 'ACTIVE'
                                  });
                                } else if (selectedRoleName == 'STAFF') {
                                  await bookingApi.createStaffProfile({
                                    'userId': newUserId,
                                    'fleetHubId': int.parse(fleetHubIdController.text.trim()),
                                    'position': positionController.text.trim()
                                  });
                                } else if (selectedRoleName == 'CUSTOMER') {
                                  await bookingApi.createCustomerProfile({
                                    'userId': newUserId,
                                    'nationalId': nationalIdController.text.trim(),
                                    'drivingLicenseNumber': drivingLicenseNumberController.text.trim().isEmpty
                                        ? null
                                        : drivingLicenseNumberController.text.trim()
                                  });
                                }
                              }
                            }
                            
                            Navigator.pop(ctx); // Close Dialog on Success
                            _showSnackBar(
                              isEdit ? 'Cập nhật tài khoản thành công!' : 'Tạo tài khoản và hồ sơ nghiệp vụ thành công!',
                              Colors.green,
                            );
                            _loadData();
                          } catch (e) {
                            setModalState(() {
                              dialogLoading = false;
                              localError = e.toString().replaceAll('Exception: ', '');
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(isEdit ? 'Lưu' : 'Tạo mới'),
                      ),
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
                        initialValue: _filterActive,
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
                                              color: _getRoleColor(rName).withValues(alpha: 0.1),
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
