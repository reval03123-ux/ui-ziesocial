import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:ziesocial/viewmodel/create_post_viewmodel.dart';
import 'package:ziesocial/viewmodel/login_viewmodel.dart';
import 'package:ziesocial/widget/app_button.dart';
import 'package:ziesocial/widget/app_text_field.dart';

class CreatePostView extends StatefulWidget {
  const CreatePostView({super.key});

  @override
  State<CreatePostView> createState() => _CreatePostViewState();
}

class _CreatePostViewState extends State<CreatePostView> {
  final _captionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  Uint8List? _selectedImageBytes;
  String? _selectedImageName;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1400,
    );

    if (image == null) return;

    final bytes = await image.readAsBytes();

    // Maksimal 5 MB
    if (bytes.length > 5 * 1024 * 1024) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ukuran gambar maksimal 5MB.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Cek ekstensi file
    final name = image.name.isNotEmpty ? image.name : image.path;
    final extension = name.split('.').last.toLowerCase();

    if (extension != 'jpg' &&
        extension != 'jpeg' &&
        extension != 'png' &&
        extension != 'webp') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Format gambar yang didukung: JPG, PNG, WEBP.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _selectedImageBytes = bytes;
      _selectedImageName = image.name.isNotEmpty ? image.name : 'post_$extension';
    });
  }

  Future<void> _createPost() async {
    if (_selectedImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih gambar terlebih dahulu.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final user = context.read<LoginViewModel>().user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User belum login.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final success = await context.read<CreatePostViewModel>().createPost(
          userId: int.parse(user.id),
          imageBytes: _selectedImageBytes!,
          filename: _selectedImageName ?? 'image.jpg',
          caption: _captionController.text.trim(),
        );

    if (!mounted) return;

    if (success) {
      final message = context.read<CreatePostViewModel>().successMessage ??
          'Postingan berhasil dibuat.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context, true);
    } else {
      final message = context.read<CreatePostViewModel>().errorMessage ??
          'Gagal membuat postingan.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<CreatePostViewModel>().isLoading;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Buat Postingan',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 550),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Preview gambar
                if (_selectedImageBytes != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 340),
                      color: Colors.black.withValues(alpha: 0.04),
                      child: Image.memory(
                        _selectedImageBytes!,
                        height: 300,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  )
                else
                  Container(
                    height: 240,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: const Color(0xFFF8FAFC),
                      border: Border.all(
                        color: Colors.grey.shade300,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined,
                            size: 48, color: Colors.grey.shade400),
                        const Gap(10),
                        Text(
                          'Pilih foto dari galeri untuk diposting',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),

                const Gap(16),

                // Tombol pilih gambar
                OutlinedButton.icon(
                  onPressed: isLoading ? null : _pickImage,
                  icon: const Icon(Icons.image_outlined, color: Color(0xFF3366A0)),
                  label: Text(
                    _selectedImageBytes != null
                        ? 'Ganti Gambar'
                        : 'Pilih Gambar',
                    style: const TextStyle(
                      color: Color(0xFF3366A0),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),

                const Gap(18),

                // Caption
                AppTextField(
                  controller: _captionController,
                  labelText: 'Caption',
                  hintText: 'Tulis caption menarik...',
                  prefixIcon: const Icon(Icons.edit_outlined),
                ),

                const Gap(24),

                // Tombol posting
                AppButton(
                  text: 'Posting',
                  isLoading: isLoading,
                  onPressed: _createPost,
                  backgroundColor: const Color(0xFF3366A0),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}