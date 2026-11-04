import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:ziesocial/model/post_model.dart';
import 'package:ziesocial/model/profile_model.dart';
import 'package:ziesocial/model/user_model.dart';
import 'package:ziesocial/view/edit_profile_view.dart';
import 'package:ziesocial/view/login_view.dart';
import 'package:ziesocial/viewmodel/login_viewmodel.dart';
import 'package:ziesocial/viewmodel/profile_viewmodel.dart';
import 'package:ziesocial/widget/post_card.dart';

class ProfileView extends StatefulWidget {
  final int userId;
  final bool showBackButton;

  const ProfileView({
    super.key,
    required this.userId,
    this.showBackButton = true,
  });

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isFollowLoading = false;
  bool _isUploadingAvatar = false;

  static const Color primaryBlue = Color(0xFF3366A0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfile();
    });
  }

  @override
  void didUpdateWidget(covariant ProfileView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _loadProfile();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadProfile() {
    final currentUser = context.read<LoginViewModel>().user;
    final currentUserId =
        currentUser != null ? int.tryParse(currentUser.id) : null;
    context.read<ProfileViewModel>().fetchProfile(
          widget.userId,
          currentUserId: currentUserId,
        );
  }

  Future<void> _handleFollowToggle() async {
    final currentUser = context.read<LoginViewModel>().user;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Silakan login untuk mengikuti akun ini.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.grey.shade900,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          action: SnackBarAction(
            label: 'Masuk',
            textColor: Colors.blueAccent,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginView()),
              );
            },
          ),
        ),
      );
      return;
    }

    final followerId = int.tryParse(currentUser.id) ?? 0;
    if (followerId > 0) {
      setState(() => _isFollowLoading = true);
      await context.read<ProfileViewModel>().toggleFollow(
            followerId: followerId,
            followingId: widget.userId,
          );
      if (mounted) setState(() => _isFollowLoading = false);
    }
  }

  void _showAvatarPickerOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
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
                  'Ganti Foto Profil',
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
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadAvatar(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: primaryBlue),
                title: const Text('Ambil Foto dari Kamera',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadAvatar(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndUploadAvatar(ImageSource source) async {
    final currentUser = context.read<LoginViewModel>().user;
    if (currentUser == null) return;
    final currentUserId = int.tryParse(currentUser.id) ?? 0;
    if (currentUserId == 0) return;

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

      if (!mounted) return;
      setState(() => _isUploadingAvatar = true);

      final newAvatar = await context.read<ProfileViewModel>().updateAvatar(
            userId: currentUserId,
            bytes: bytes,
            filename: filename,
          );

      if (!mounted) return;
      setState(() => _isUploadingAvatar = false);

      if (newAvatar != null) {
        context.read<LoginViewModel>().updateUserAvatar(newAvatar);
        _loadProfile();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Foto profil berhasil diperbarui!'),
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } else {
        final err = context.read<ProfileViewModel>().errorMessage ??
            'Gagal mengunggah foto profil.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingAvatar = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terjadi kesalahan: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _openEditProfile(UserModel user) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileView(user: user),
      ),
    );

    if (updated == true && mounted) {
      _loadProfile();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profil berhasil diperbarui!'),
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Keluar', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Apakah kamu yakin ingin keluar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<ProfileViewModel>().clearCache();
              context.read<LoginViewModel>().logout();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginView()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }

  void _showPostDetail(PostModel post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 550),
          child: DraggableScrollableSheet(
            initialChildSize: 0.92,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (_, controller) => Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  const Gap(8),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: controller,
                      padding: const EdgeInsets.only(top: 8),
                      children: [PostCard(post: post)],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileVm = context.watch<ProfileViewModel>();
    final currentUser = context.watch<LoginViewModel>().user;
    final isOwnProfile =
        currentUser != null && currentUser.id == widget.userId.toString();

    // Mengambil data profil yang sesuai dengan userId
    final profile = profileVm.getProfile(widget.userId) ??
        (profileVm.profile != null &&
                profileVm.profile!.user.id == widget.userId.toString()
            ? profileVm.profile
            : null);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(profile, isOwnProfile),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Builder(
            builder: (context) {
              if (profileVm.isLoading && profile == null) {
                return const Center(
                  child: CircularProgressIndicator(color: primaryBlue),
                );
              }

              if (profileVm.errorMessage != null && profile == null) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 52, color: Colors.red),
                      const Gap(12),
                      Text(
                        profileVm.errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.black54),
                      ),
                      const Gap(20),
                      ElevatedButton(
                        onPressed: _loadProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                );
              }

              if (profile == null) {
                return Center(
                  child: ElevatedButton(
                    onPressed: _loadProfile,
                    child: const Text('Muat Profil'),
                  ),
                );
              }

              return RefreshIndicator(
                color: primaryBlue,
                onRefresh: () async => _loadProfile(),
                child: NestedScrollView(
                  headerSliverBuilder: (context, innerBoxIsScrolled) {
                    return [
                      SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Foto Profil & Statistik ──
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Foto Profil dengan ring & tombol kamera
                                  _buildAvatar(profile, isOwnProfile),
                                  const Gap(20),
                                  // Statistik (Postingan, Pengikut, Mengikuti)
                                  Expanded(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
                                      children: [
                                        _buildStatColumn(
                                            'Postingan', profile.stats.postsCount),
                                        _buildStatColumn(
                                            'Pengikut', profile.stats.followersCount),
                                        _buildStatColumn(
                                            'Mengikuti', profile.stats.followingCount),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const Gap(12),

                            // ── Nama User, Username, dan Bio ──
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Nama Lengkap
                                  Text(
                                    profile.user.name.isNotEmpty
                                        ? profile.user.name
                                        : profile.user.username,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.black87,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const Gap(2),
                                  // Username (@username)
                                  Text(
                                    '@${profile.user.username}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey.shade600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (profile.user.bio.isNotEmpty) ...[
                                    const Gap(6),
                                    Text(
                                      profile.user.bio,
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        color: Colors.black87,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            const Gap(14),

                            // ── Tombol Aksi (Edit Profil & Keluar / Follow) ──
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: isOwnProfile
                                  ? _buildOwnProfileActions(profile)
                                  : _buildFollowButton(profile),
                            ),

                            const Gap(14),

                            // Garis Pembatas Sebelum Tab
                            const Divider(
                                height: 1, thickness: 0.5, color: Color(0xFFEEEEEE)),
                          ],
                        ),
                      ),
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _SliverTabBarDelegate(
                          TabBar(
                            controller: _tabController,
                            indicatorColor: Colors.black87,
                            indicatorWeight: 1.5,
                            labelColor: Colors.black87,
                            unselectedLabelColor: Colors.grey.shade400,
                            tabs: const [
                              Tab(icon: Icon(Icons.grid_on_sharp, size: 22)),
                              Tab(icon: Icon(Icons.view_agenda_outlined, size: 22)),
                            ],
                          ),
                        ),
                      ),
                    ];
                  },
                  body: TabBarView(
                    controller: _tabController,
                    children: [
                      // ── Tab 1: Grid Postingan (3 Kolom khas IG) ──
                      profile.posts.isEmpty
                          ? _buildEmptyPosts()
                          : GridView.builder(
                              padding: EdgeInsets.zero,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 2,
                                mainAxisSpacing: 2,
                                childAspectRatio: 1,
                              ),
                              itemCount: profile.posts.length,
                              itemBuilder: (context, index) {
                                final post = profile.posts[index];
                                return GestureDetector(
                                  onTap: () => _showPostDetail(post),
                                  child: Container(
                                    color: Colors.grey.shade100,
                                    child: post.image.isNotEmpty
                                        ? Image.network(
                                            post.fullImageUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    const Center(
                                              child: Icon(Icons.broken_image,
                                                  color: Colors.grey),
                                            ),
                                          )
                                        : Container(
                                            color: const Color(0xFFECF0F8),
                                            child: const Center(
                                              child: Icon(Icons.article_outlined,
                                                  color: primaryBlue, size: 28),
                                            ),
                                          ),
                                  ),
                                );
                              },
                            ),

                      // ── Tab 2: Feed Postingan Lengkap ──
                      profile.posts.isEmpty
                          ? _buildEmptyPosts()
                          : ListView.builder(
                              padding:
                                  const EdgeInsets.only(top: 8, bottom: 80),
                              itemCount: profile.posts.length,
                              itemBuilder: (context, index) {
                                return PostCard(post: profile.posts[index]);
                              },
                            ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ProfileModel? profile, bool isOwnProfile) {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      centerTitle: false,
      leading: widget.showBackButton
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_new,
                  color: Colors.black87, size: 20),
              onPressed: () => Navigator.pop(context),
            )
          : null,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              profile?.user.username.isNotEmpty == true
                  ? profile!.user.username
                  : 'Profil',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.black87),
          onPressed: _loadProfile,
          tooltip: 'Segarkan',
        ),
        if (isOwnProfile)
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.black87),
            onPressed: _logout,
            tooltip: 'Keluar',
          ),
        const Gap(4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0.5),
        child: Container(height: 0.5, color: const Color(0xFFEEEEEE)),
      ),
    );
  }

  Widget _buildAvatar(ProfileModel profile, bool isOwnProfile) {
    return GestureDetector(
      onTap: isOwnProfile ? _showAvatarPickerOptions : null,
      child: Stack(
        clipBehavior: Clip.none,
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
                radius: 40,
                backgroundColor: const Color(0xFFE8EFF8),
                child: _isUploadingAvatar
                    ? const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: primaryBlue,
                        ),
                      )
                    : profile.user.avatar.isNotEmpty
                        ? ClipOval(
                            child: Image.network(
                              profile.user.avatarUrl,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  _avatarInitial(profile.user.name),
                            ),
                          )
                        : _avatarInitial(profile.user.name),
              ),
            ),
          ),
          if (isOwnProfile)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: primaryBlue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _avatarInitial(String name) {
    return Text(
      name.isNotEmpty ? name[0].toUpperCase() : '?',
      style: const TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.bold,
        color: primaryBlue,
      ),
    );
  }

  Widget _buildStatColumn(String label, int count) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _formatCount(count),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          const Gap(2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '$count';
  }

  Widget _buildFollowButton(ProfileModel profile) {
    final isFollowing = profile.stats.isFollowing;
    return Row(
      children: [
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            height: 38,
            child: ElevatedButton(
              onPressed: _isFollowLoading ? null : _handleFollowToggle,
              style: ElevatedButton.styleFrom(
                backgroundColor: isFollowing ? Colors.white : primaryBlue,
                foregroundColor: isFollowing ? Colors.black87 : Colors.white,
                elevation: 0,
                side: isFollowing
                    ? BorderSide(color: Colors.grey.shade300)
                    : BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isFollowLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isFollowing)
                          const Icon(Icons.check, size: 16)
                        else
                          const Icon(Icons.person_add_alt_1, size: 16),
                        const Gap(6),
                        Text(
                          isFollowing ? 'Mengikuti' : 'Ikuti',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  /// Tombol aksi pada profil sendiri: "Edit Profil" & "Ganti Foto"
  Widget _buildOwnProfileActions(ProfileModel profile) {
    return Row(
      children: [
        // Tombol Edit Profil Lengkap
        Expanded(
          child: SizedBox(
            height: 38,
            child: OutlinedButton.icon(
              onPressed: () => _openEditProfile(profile.user),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Edit Profil',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black87,
                backgroundColor: const Color(0xFFF9FAFB),
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
            ),
          ),
        ),
        const Gap(8),

        // Tombol Ganti Foto Cepat
        Expanded(
          child: SizedBox(
            height: 38,
            child: ElevatedButton.icon(
              onPressed: _isUploadingAvatar ? null : _showAvatarPickerOptions,
              icon: _isUploadingAvatar
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.camera_alt_outlined, size: 16),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _isUploadingAvatar ? 'Mengunggah...' : 'Ganti Foto',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyPosts() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.camera_alt_outlined, size: 52, color: Colors.grey),
          const Gap(12),
          const Text(
            'Belum ada postingan',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const Gap(6),
          Text(
            'Foto dan video akan muncul di sini.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverTabBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) => false;
}
