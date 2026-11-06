import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:ziesocial/viewmodel/login_viewmodel.dart';
import 'package:ziesocial/viewmodel/story_viewmodel.dart';

class CreateStoryView extends StatefulWidget {
  final XFile? initialImage;

  const CreateStoryView({super.key, this.initialImage});

  @override
  State<CreateStoryView> createState() => _CreateStoryViewState();
}

class _CreateStoryViewState extends State<CreateStoryView> {
  XFile? _selectedImage;
  final TextEditingController _captionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialImage != null) {
      _selectedImage = widget.initialImage;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pickImage(ImageSource.gallery);
      });
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1080,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() => _selectedImage = picked);
      } else if (_selectedImage == null) {
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memilih gambar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadStory() async {
    if (_selectedImage == null) return;

    final user = context.read<LoginViewModel>().user;
    final userId = int.tryParse(user?.id ?? '') ?? 0;
    if (userId <= 0) return;

    setState(() => _isUploading = true);

    try {
      final bytes = await _selectedImage!.readAsBytes();
      String filename = _selectedImage!.name;
      if (!filename.contains('.')) {
        filename = '$filename.jpg';
      }

      if (!mounted) return;
      final success = await context.read<StoryViewModel>().uploadStory(
            userId: userId,
            bytes: bytes,
            filename: filename,
            caption: _captionController.text,
          );

      if (!mounted) return;
      setState(() => _isUploading = false);

      if (success) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Cerita Anda berhasil dibagikan!'),
              ],
            ),
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      } else {
        final err = context.read<StoryViewModel>().errorMessage ??
            'Gagal mengunggah cerita.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terjadi kesalahan: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Preview Gambar
              if (_selectedImage != null)
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(
                      File(_selectedImage!.path),
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                )
              else
                const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),

              // Gradient Overlay Atas
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 100,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black87, Colors.transparent],
                    ),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close,
                            color: Colors.white, size: 28),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.photo_library_outlined,
                                color: Colors.white, size: 26),
                            onPressed: _isUploading
                                ? null
                                : () => _pickImage(ImageSource.gallery),
                            tooltip: 'Ganti Foto',
                          ),
                          IconButton(
                            icon: const Icon(Icons.camera_alt_outlined,
                                color: Colors.white, size: 26),
                            onPressed: _isUploading
                                ? null
                                : () => _pickImage(ImageSource.camera),
                            tooltip: 'Ambil Foto',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Gradient Overlay Bawah & Input Keterangan
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black87, Colors.transparent],
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Field Caption
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          controller: _captionController,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 15),
                          maxLines: 3,
                          minLines: 1,
                          decoration: InputDecoration(
                            hintText: 'Tambahkan keterangan cerita...',
                            hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      const Gap(14),

                      // Tombol Kirim Story
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Label Story Anda
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.history_toggle_off,
                                    color: Colors.white, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  'Aktif 24 Jam',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 12),
                                ),
                              ],
                            ),
                          ),

                          // Tombol Bagikan
                          ElevatedButton.icon(
                            onPressed: _isUploading ? null : _uploadStory,
                            icon: _isUploading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.arrow_forward_ios_rounded,
                                    size: 16),
                            label: Text(
                              _isUploading ? 'Mengunggah...' : 'Bagikan Cerita',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3366A0),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

