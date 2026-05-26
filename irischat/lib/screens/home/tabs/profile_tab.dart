import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
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

  // Biến lưu trữ dữ liệu ảnh mới chọn
  Uint8List? _selectedImageBytes;
  String? _selectedFileName;

  bool _isDataInitialized = false;

  @override
  void initState() {
    super.initState();
    _initUserData();
  }

  void _initUserData() {
    final currentUser = widget.authProvider.user;
    if (currentUser != null && !_isDataInitialized) {
      _nameController.text = currentUser.displayName;
      _isDataInitialized = true;
    }
  }

  // ===========================================================================
  // HÀM CHỌN ẢNH BẰNG FILE_PICKER VỚI BYTES (GIỮ NGUYÊN LOGIC)
  // ===========================================================================
  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image, // Chỉ lọc các file hình ảnh
        withData: true, // BẮT BUỘC: Đọc dữ liệu dạng bytes
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        setState(() {
          _selectedImageBytes = file.bytes;
          _selectedFileName =
              '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
        });
      }
    } catch (e) {
      debugPrint('Lỗi chọn ảnh qua FilePicker: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // HÀM LƯU THÔNG TIN (GIỮ NGUYÊN LOGIC)
  // ===========================================================================
  void _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final currentUser = widget.authProvider.user;
    if (currentUser == null) return;

    final userProvider = context.read<UserProvider>();

    final success = await userProvider.uploadAndUpdateProfile(
      uid: currentUser.uid,
      displayName: _nameController.text,
      imageBytes: _selectedImageBytes,
      fileName: _selectedFileName,
      currentAvatarUrl: currentUser.avatarUrl,
      onSuccess: () async {
        await widget.authProvider.refreshCurrentUser(currentUser.uid);
        // Xóa bộ nhớ đệm ảnh tạm thời sau khi upload xong
        setState(() {
          _selectedImageBytes = null;
          _selectedFileName = null;
        });
      },
    );

    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Cập nhật tài khoản thành công!',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.teal.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthProvider>().user;
    final userProvider = context.watch<UserProvider>();

    if (currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_isDataInitialized) _initUserData();

    return Scaffold(
      backgroundColor: Colors.grey.shade50, // Nền app sáng, tạo độ sâu
      appBar: AppBar(
        title: Text(
          'Tài Khoản',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Colors.blueGrey.shade900,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Column(
            children: [
              // CỤM AVATAR VÀ EMAIL
              GestureDetector(
                onTap: userProvider.isLoading ? null : _pickImage,
                child: Center(
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.teal.shade50,
                          backgroundImage: _selectedImageBytes != null
                              ? MemoryImage(_selectedImageBytes!)
                                    as ImageProvider
                              : (currentUser.avatarUrl.isNotEmpty
                                    ? NetworkImage(currentUser.avatarUrl)
                                    : null),
                          child:
                              _selectedImageBytes == null &&
                                  currentUser.avatarUrl.isEmpty
                              ? Text(
                                  _nameController.text.isNotEmpty
                                      ? _nameController.text[0].toUpperCase()
                                      : 'U',
                                  style: TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal.shade700,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade600,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                currentUser.email,
                style: TextStyle(
                  color: Colors.blueGrey.shade400,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 32),

              // KHỐI FORM NHẬP LIỆU & NÚT LƯU
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nameController,
                        style: TextStyle(
                          color: Colors.blueGrey.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Tên hiển thị',
                          labelStyle: TextStyle(
                            color: Colors.blueGrey.shade400,
                          ),
                          prefixIcon: Icon(
                            Icons.person_rounded,
                            color: Colors.teal.shade500,
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Colors.teal.shade300,
                              width: 1.5,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Tên hiển thị không được để trống';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: userProvider.isLoading
                              ? null
                              : _saveProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal.shade600,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            disabledBackgroundColor: Colors.teal.shade200,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: userProvider.isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  'Lưu Thay Đổi',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // NÚT ĐĂNG XUẤT (TONAL STYLE)
              SizedBox(
                width: double.infinity,
                height: 54,
                child: TextButton.icon(
                  onPressed: () {
                    widget.authProvider.logout();
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/login',
                      (route) => false,
                    );
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.red.withValues(alpha: 0.1),
                    foregroundColor: Colors.red.shade600,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.logout_rounded, size: 22),
                  label: const Text(
                    'Đăng Xuất Tài Khoản',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
