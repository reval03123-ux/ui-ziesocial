import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:ziesocial/model/user_model.dart';
import 'package:ziesocial/viewmodel/login_viewmodel.dart';
import 'package:ziesocial/viewmodel/profile_viewmodel.dart';

class EditProfileView extends StatefulWidget {
  final UserModel user;

  const EditProfileView({super.key, required this.user});

  @override
  State<EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends State<EditProfileView> {
  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  late TextEditingController _bioController;

  Uint8List? _newAvatarBytes;
  String? _newAvatarFilename;

  bool _isSaving = false;
  static const Color primaryBlue = Color(0xFF3366A0);

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _usernameController = TextEditingController(text: widget.user.username);
    _bioController = TextEditingController(text: widget.user.bio);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    Navigator.pop(context); // Tutup dialog/bottomsheet opsi sumber foto
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1080,
      );

      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      String filename = picked.name.isNotEmpty ? picked.name : 'avatar.jpg';
      if (!filename.contains('.')) {
        filename = '$filename.jpg';
      }
      setState(() {
        _newAvatarBytes = bytes;
        _newAvatarFilename = filename;
      });
      HapticFeedback.selectionClick();
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Gagal memilih gambar: $e', isError: true);
    }
  }

  void _showImageSourceOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Ubah Foto Profil',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: primaryBlue),
                title: const Text('Pilih dari Galeri',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                onTap: () => _pickImage(ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: primaryBlue),
                title: const Text('Ambil Foto dari Kamera',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                onTap: () => _pickImage(ImageSource.camera),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    final username = _usernameController.text.trim().toLowerCase();
    final bio = _bioController.text.trim();

    if (name.isEmpty) {
      _showSnackBar('Nama lengkap tidak boleh kosong!', isError: true);
      return;
    }

    if (username.isEmpty) {
      _showSnackBar('Username tidak boleh kosong!', isError: true);
      return;
    }

    if (!RegExp(r'^[a-zA-Z0-9._]+$').hasMatch(username)) {
      _showSnackBar(
        'Username hanya boleh berisi huruf, angka, titik, dan garis bawah.',
        isError: true,
      );
      return;
    }

    final userId = int.tryParse(widget.user.id) ?? 0;
    if (userId <= 0) return;

    setState(() => _isSaving = true);
    HapticFeedback.lightImpact();

    final profileVm = context.read<ProfileViewModel>();
    final loginVm = context.read<LoginViewModel>();

    // 1. Jika ada foto baru yang dipilih, unggah terlebih dahulu
    String? newAvatarPath;
    if (_newAvatarBytes != null && _newAvatarFilename != null) {
      newAvatarPath = await profileVm.updateAvatar(
        userId: userId,
        bytes: _newAvatarBytes!,
        filename: _newAvatarFilename!,
      );

      if (newAvatarPath == null) {
        if (!mounted) return;
        setState(() => _isSaving = false);
        _showSnackBar(
          profileVm.errorMessage ?? 'Gagal mengunggah foto profil.',
          isError: true,
        );
        return;
      }
      loginVm.updateUserAvatar(newAvatarPath);
    }

    // 2. Perbarui data nama, username, dan bio
    final updatedUser = await profileVm.updateProfile(
      userId: userId,
      name: name,
      username: username,
      bio: bio,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (updatedUser != null) {
      // Sinkronkan ke LoginViewModel
      loginVm.updateUser(updatedUser);
      HapticFeedback.mediumImpact();
      Navigator.pop(context, true);
    } else {
      _showSnackBar(
        profileVm.errorMessage ?? 'Gagal menyimpan perubahan profil.',
        isError: true,
      );
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade700 : const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: _isSaving ? null : () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Profil',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _isSaving
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: primaryBlue,
                        ),
                      ),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.check, color: primaryBlue, size: 26),
                    tooltip: 'Simpan',
                    onPressed: _saveProfile,
                  ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: const Color(0xFFEEEEEE)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          children: [
            // ── Foto Profil & Tombol Ubah ──
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _isSaving ? null : _showImageSourceOptions,
                    child: Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFF833AB4),
                                Color(0xFFFD1D1D),
                                Color(0xFFFCB045),
                              ],
                              begin: Alignment.topRight,
                              end: Alignment.bottomLeft,
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(2.5),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: CircleAvatar(
                              radius: 46,
                              backgroundColor: const Color(0xFFE8EFF8),
                              child: _newAvatarBytes != null
                                  ? ClipOval(
                                      child: Image.memory(
                                        _newAvatarBytes!,
                                        width: 92,
                                        height: 92,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : widget.user.avatar.isNotEmpty
                                      ? ClipOval(
                                          child: Image.network(
                                            widget.user.avatarUrl,
                                            width: 92,
                                            height: 92,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    _avatarInitial(widget.user.name),
                                          ),
                                        )
                                      : _avatarInitial(widget.user.name),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 2,
                          bottom: 2,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: primaryBlue,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Gap(10),
                  GestureDetector(
                    onTap: _isSaving ? null : _showImageSourceOptions,
                    child: const Text(
                      'Ubah foto profil',
                      style: TextStyle(
                        color: primaryBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Gap(24),
            const Divider(height: 1, thickness: 0.5, color: Color(0xFFEEEEEE)),
            const Gap(16),

            // ── Form Input Data ──
            _buildInputField(
              controller: _nameController,
              label: 'Nama',
              hint: 'Nama lengkap Anda',
              icon: Icons.person_outline_rounded,
            ),
            const Gap(16),

            _buildInputField(
              controller: _usernameController,
              label: 'Username',
              hint: 'username_anda',
              prefixText: '@',
              icon: Icons.alternate_email_rounded,
            ),
            const Gap(16),

            _buildInputField(
              controller: _bioController,
              label: 'Bio',
              hint: 'Tuliskan sedikit tentang diri Anda...',
              icon: Icons.info_outline_rounded,
              maxLines: 3,
            ),
            const Gap(16),

            // Email (Hanya Tampilan / Read-only)
            _buildReadOnlyField(
              label: 'Email Terdaftar',
              value: widget.user.email,
              icon: Icons.mail_outline_rounded,
            ),

            const Gap(32),

            // Tombol Simpan di Bawah
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Simpan Perubahan',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? prefixText,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const Gap(6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 14, color: Colors.black87),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13.5),
            prefixIcon: Icon(icon, color: primaryBlue, size: 20),
            prefixText: prefixText,
            prefixStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: primaryBlue, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const Gap(6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.grey.shade500, size: 20),
              const Gap(10),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.lock_outline, size: 16, color: Colors.grey.shade400),
            ],
          ),
        ),
      ],
    );
  }

  Widget _avatarInitial(String name) {
    return Text(
      name.isNotEmpty ? name[0].toUpperCase() : '?',
      style: const TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.bold,
        color: primaryBlue,
      ),
    );
  }
}
