import 'package:flutter/material.dart';
import '../services/auth_api_service.dart';
import '../models/user_profile.dart';
import 'package:intl/intl.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback onLogout;
  const ProfileScreen({super.key, required this.onLogout});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthApiService _apiService = AuthApiService();
  UserProfile? _profile;
  bool _isLoadingProfile = true;
  String? _profileError;

  // Change Password Form
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isChangingPassword = false;
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoadingProfile = true;
      _profileError = null;
    });
    try {
      final profile = await _apiService.getProfile();
      setState(() {
        _profile = profile;
        _isLoadingProfile = false;
      });
    } catch (e) {
      setState(() {
        _profileError = e.toString().replaceAll('Exception: ', '');
        _isLoadingProfile = false;
      });
    }
  }

  Future<void> _handleChangePassword() async {
    final oldPassword = _oldPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (oldPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      _showSnackBar('Vui lòng nhập đầy đủ thông tin đổi mật khẩu!', Colors.red);
      return;
    }

    if (newPassword != confirmPassword) {
      _showSnackBar('Mật khẩu xác nhận không khớp!', Colors.red);
      return;
    }

    if (newPassword.length < 6) {
      _showSnackBar('Mật khẩu mới phải có tối thiểu 6 ký tự!', Colors.red);
      return;
    }

    setState(() {
      _isChangingPassword = true;
    });

    try {
      await _apiService.changePassword(oldPassword, newPassword);
      _oldPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      _showSnackBar('Đổi mật khẩu thành công! 🎉', Colors.green);
    } catch (e) {
      _showSnackBar(e.toString().replaceAll('Exception: ', ''), Colors.red);
    } finally {
      setState(() {
        _isChangingPassword = false;
      });
    }
  }

  void _showDeleteAccountDialog() {
    String selectedReason = 'Tôi không còn nhu cầu sử dụng';
    bool confirmChecked = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red),
                SizedBox(width: 8),
                Text('Xóa tài khoản', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade100),
                    ),
                    child: Text(
                      'Cảnh báo: Khi xóa tài khoản, toàn bộ thông tin cá nhân và lịch sử đặt xe sẽ bị xóa vĩnh viễn và không thể khôi phục.',
                      style: TextStyle(color: Colors.red.shade800, fontSize: 13, height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Lý do xóa tài khoản *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedReason,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: [
                      'Tôi không còn nhu cầu sử dụng',
                      'Tôi muốn tạo tài khoản mới',
                      'Lo ngại về bảo mật',
                      'Khác',
                    ].map((reason) => DropdownMenuItem(value: reason, child: Text(reason, style: const TextStyle(fontSize: 13)))).toList(),
                    onChanged: (val) {
                      setModalState(() {
                        selectedReason = val!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: confirmChecked,
                        activeColor: Colors.red,
                        onChanged: (val) {
                          setModalState(() {
                            confirmChecked = val ?? false;
                          });
                        },
                      ),
                      const Expanded(
                        child: Text(
                          'Tôi cam kết chịu trách nhiệm về yêu cầu này và hiểu rằng hành động này không thể hoàn tác.',
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: !confirmChecked
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        _showSnackBar('Yêu cầu xóa tài khoản đã được gửi. Chúng tôi sẽ liên hệ lại sau 24h.', Colors.green);
                      },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Xác nhận xóa', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'Chưa cập nhật';
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  String _formatGender(String? genderStr) {
    if (genderStr == null || genderStr.trim().isEmpty) return 'Chưa cập nhật';
    switch (genderStr.trim().toUpperCase()) {
      case 'MALE':
        return 'Nam';
      case 'FEMALE':
        return 'Nữ';
      case 'OTHER':
        return 'Khác';
      default:
        return genderStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF16A34A);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông tin tài khoản', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
      ),
      body: _isLoadingProfile
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(primaryGreen)))
          : _profileError != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 48),
                      const SizedBox(height: 12),
                      Text(_profileError!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _loadProfile, child: const Text('Tải lại')),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Profile Header Info Card
                      Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 1,
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 36,
                                backgroundColor: primaryGreen.withValues(alpha: 0.1),
                                child: Text(
                                  _profile?.fullName.isNotEmpty == true ? _profile!.fullName[0].toUpperCase() : 'U',
                                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: primaryGreen),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _profile?.fullName ?? 'Họ tên',
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _profile?.email ?? 'Email',
                                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Tham gia: ${_formatDate(_profile?.createdAt)}',
                                      style: const TextStyle(color: Colors.black38, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Account Details Section
                      Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 1,
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Chi tiết tài khoản', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              const Divider(height: 24),
                              _buildDetailRow(
                                'Số điện thoại',
                                (_profile?.phone != null && _profile!.phone!.trim().isNotEmpty)
                                    ? _profile!.phone!.trim()
                                    : 'Chưa cập nhật',
                              ),
                              const SizedBox(height: 12),
                              _buildDetailRow('Ngày sinh', _formatDate(_profile?.dob)),
                              const SizedBox(height: 12),
                              _buildDetailRow('Giới tính', _formatGender(_profile?.gender)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Change Password Section
                      Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 1,
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Đổi mật khẩu', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              const Divider(height: 24),
                              _buildPasswordField(_oldPasswordController, 'Mật khẩu hiện tại', _obscureOld, (v) {
                                setState(() {
                                  _obscureOld = v;
                                });
                              }),
                              const SizedBox(height: 12),
                              _buildPasswordField(_newPasswordController, 'Mật khẩu mới', _obscureNew, (v) {
                                setState(() {
                                  _obscureNew = v;
                                });
                              }),
                              const SizedBox(height: 12),
                              _buildPasswordField(_confirmPasswordController, 'Xác nhận mật khẩu mới', _obscureConfirm, (v) {
                                setState(() {
                                  _obscureConfirm = v;
                                });
                              }),
                              const SizedBox(height: 20),
                              ElevatedButton(
                                onPressed: _isChangingPassword ? null : _handleChangePassword,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryGreen,
                                  minimumSize: const Size(double.infinity, 44),
                                ),
                                child: _isChangingPassword
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                                      )
                                    : const Text('Cập nhật mật khẩu', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Dangerous Zone / Delete Account
                      Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 1,
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Quản lý tài khoản', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              const Divider(height: 24),
                              OutlinedButton.icon(
                                onPressed: _showDeleteAccountDialog,
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                label: const Text('Yêu cầu xóa tài khoản', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.red),
                                  minimumSize: const Size(double.infinity, 44),
                                ),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: widget.onLogout,
                                icon: const Icon(Icons.logout, color: Colors.white),
                                label: const Text('Đăng xuất', style: TextStyle(fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade600,
                                  minimumSize: const Size(double.infinity, 44),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87)),
      ],
    );
  }

  Widget _buildPasswordField(TextEditingController controller, String hint, bool obscure, Function(bool) onToggle) {
    const primaryGreen = Color(0xFF16A34A);
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: hint,
        labelStyle: const TextStyle(fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primaryGreen, width: 2),
        ),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility : Icons.visibility_off, color: Colors.grey, size: 20),
          onPressed: () => onToggle(!obscure),
        ),
      ),
    );
  }
}
