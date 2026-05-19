import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';
import '../../../providers/user_provider.dart';

class ProfileTab extends StatefulWidget {
  final AuthProvider authProvider;

  const ProfileTab({super.key, required this.authProvider});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _avatarController = TextEditingController();

  // Biến cờ hiệu để đảm bảo chỉ đổ dữ liệu gốc vào Controller ĐÚNG 1 LẦN DUY NHẤT
  bool _isDataInitialized = false;

  @override
  void initState() {
    super.initState();
    _initUserData();
  }

  // Hàm hỗ trợ khởi tạo dữ liệu an toàn
  void _initUserData() {
    final currentUser = widget.authProvider.user;
    if (currentUser != null && !_isDataInitialized) {
      _nameController.text = currentUser.displayName;
      _avatarController.text = currentUser.avatarUrl;
      _isDataInitialized = true;
    }
  }

  @override
  void didUpdateWidget(covariant ProfileTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Nếu AuthProvider ở widget cha cập nhật (ví dụ từ null -> có dữ liệu), nạp lại data
    _initUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _avatarController.dispose();
    super.dispose();
  }

  void _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final currentUser = widget.authProvider.user;
    if (currentUser == null) return;

    final userProvider = context.read<UserProvider>();

    final success = await userProvider.updateProfile(
      uid: currentUser.uid,
      displayName: _nameController.text,
      avatarUrl: _avatarController.text,
      onSuccess: () async {
        await widget.authProvider.refreshCurrentUser(currentUser.uid);
      },
    );

    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cập nhật tài khoản thành công!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch để nhận thông tin thay đổi từ các Provider
    final currentUser = context.watch<AuthProvider>().user;
    final userProvider = context.watch<UserProvider>();

    // CHẶN LỖI NULL: Nếu Firebase chưa trả data về, hiện vòng xoay, không cố gán lung tung
    if (currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Đảm bảo nếu data vừa từ null chuyển sang có dữ liệu, Controller sẽ có data lập tức
    if (!_isDataInitialized) {
      _initUserData();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Tài khoản',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // 1. Hình ảnh Avatar hiển thị dựa theo dữ liệu realtime từ controller
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.blue.shade100,
                      backgroundImage: _avatarController.text.isNotEmpty
                          ? NetworkImage(_avatarController.text)
                          : null,
                      child: _avatarController.text.isEmpty
                          ? Text(
                              _nameController.text.isNotEmpty
                                  ? _nameController.text[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.blue,
                        child: const Icon(
                          Icons.camera_alt,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                currentUser.email,
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 32),

              // 2. Ô nhập tên hiển thị
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Tên hiển thị',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (val) => setState(
                  () {},
                ), // Giữ lại để cập nhật chữ cái trên Avatar preview
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Tên hiển thị không được để trống';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 3. Ô nhập Link Avatar
              TextFormField(
                controller: _avatarController,
                decoration: InputDecoration(
                  labelText: 'Đường dẫn ảnh đại diện (URL)',
                  prefixIcon: const Icon(Icons.link_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (val) => setState(
                  () {},
                ), // Giữ lại để cập nhật ảnh trên Avatar preview
              ),
              const SizedBox(height: 32),

              // 4. Nút bấm lưu
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: userProvider.isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: userProvider.isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Lưu thay đổi',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),

              // 5. Nút Đăng xuất
              TextButton.icon(
                onPressed: () {
                  widget.authProvider.logout();

                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/login',
                    (route) => false,
                  );
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                icon: const Icon(Icons.logout),
                label: const Text(
                  'Đăng xuất tài khoản',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
