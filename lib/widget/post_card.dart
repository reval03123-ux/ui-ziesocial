import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import 'package:ziesocial/model/post_model.dart';
import 'package:ziesocial/view/login_view.dart';
import 'package:ziesocial/view/profile_view.dart';
import 'package:ziesocial/viewmodel/login_viewmodel.dart';
import 'package:ziesocial/viewmodel/post_viewmodel.dart';
import 'package:ziesocial/viewmodel/profile_viewmodel.dart';
import 'package:ziesocial/widget/comment_sheet.dart';

class PostCard extends StatefulWidget {
  final PostModel post;

  const PostCard({super.key, required this.post});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _heartController;
  late Animation<double> _heartScale;
  bool _showHeart = false;

  @override
  void initState() {
    super.initState();
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _heartScale = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 0.0, end: 1.3)
              .chain(CurveTween(curve: Curves.elasticOut)),
          weight: 60),
      TweenSequenceItem(
          tween: Tween(begin: 1.3, end: 0.0)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 40),
    ]).animate(_heartController)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          if (mounted) setState(() => _showHeart = false);
        }
      });
  }

  @override
  void dispose() {
    _heartController.dispose();
    super.dispose();
  }

  void _handleLike(BuildContext context) {
    final user = context.read<LoginViewModel>().user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Silakan masuk untuk menyukai postingan.'),
          backgroundColor: Colors.grey.shade900,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          action: SnackBarAction(
            label: 'Masuk',
            textColor: Colors.blueAccent,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LoginView()),
            ),
          ),
        ),
      );
      return;
    }

    HapticFeedback.lightImpact();
    final userId = int.tryParse(user.id) ?? 0;
    if (userId > 0) {
      context.read<PostViewModel>().toggleLike(post: widget.post, userId: userId);
    }
  }

  void _handleDoubleTap(BuildContext context) {
    if (!widget.post.isLiked) {
      _handleLike(context);
    }
    setState(() => _showHeart = true);
    _heartController.forward(from: 0);
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    // Watch only what we need
    final postVm = context.watch<PostViewModel>();
    // Find updated post from viewmodel (for like state)
    final post = postVm.posts.firstWhere(
      (p) => p.id == widget.post.id,
      orElse: () => widget.post,
    );

    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          _buildHeader(context, post),

          // ── Image ──
          if (post.image.isNotEmpty) _buildImage(context, post),

          // ── Actions ──
          _buildActions(context, post),

          // ── Likes ──
          if (post.likeCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(
                '${_formatCount(post.likeCount)} suka',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.black87,
                ),
              ),
            ),

          // ── Caption ──
          if (post.caption.isNotEmpty) _buildCaption(post),

          // ── Comments link ──
          _buildCommentsLink(context, post),

          // ── Date ──
          if (post.createDate.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                _formatDate(post.createDate),
                style: TextStyle(color: Colors.grey.shade400, fontSize: 10.5),
              ),
            ),

          Divider(height: 1, thickness: 0.5, color: Colors.grey.shade100),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, PostModel post) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => ProfileView(userId: post.author.id)),
            ),
            child: _buildAuthorAvatar(post),
          ),
          const Gap(10),
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ProfileView(userId: post.author.id)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.author.username.isNotEmpty
                        ? post.author.username
                        : post.author.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                      color: Colors.black87,
                    ),
                  ),
                  if (post.author.name.isNotEmpty &&
                      post.author.name != post.author.username)
                    Text(
                      post.author.name,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500),
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz, color: Colors.black87, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () => _showPostOptions(context, post),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthorAvatar(PostModel post) {
    return Container(
      width: 38,
      height: 38,
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
      padding: const EdgeInsets.all(2),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        padding: const EdgeInsets.all(1.5),
        child: CircleAvatar(
          radius: 15,
          backgroundColor: const Color(0xFFE8EFF8),
          child: post.author.avatar.isNotEmpty
              ? ClipOval(
                  child: Image.network(
                    post.author.avatarUrl,
                    width: 30,
                    height: 30,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _initial(post.author.name),
                  ),
                )
              : _initial(post.author.name),
        ),
      ),
    );
  }

  Widget _initial(String name) {
    return Text(
      name.isNotEmpty ? name[0].toUpperCase() : '?',
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 12,
        color: Color(0xFF3366A0),
      ),
    );
  }

  Widget _buildImage(BuildContext context, PostModel post) {
    return GestureDetector(
      onDoubleTap: () => _handleDoubleTap(context),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            constraints: const BoxConstraints(
              maxHeight: 460,
              minHeight: 200,
            ),
            width: double.infinity,
            color: const Color(0xFFF8FAFC),
            child: Image.network(
              post.fullImageUrl,
              width: double.infinity,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  height: 300,
                  color: Colors.grey.shade50,
                  child: Center(
                    child: CircularProgressIndicator(
                      value: progress.expectedTotalBytes != null
                          ? progress.cumulativeBytesLoaded /
                              progress.expectedTotalBytes!
                          : null,
                      strokeWidth: 2,
                      color: const Color(0xFF3366A0),
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) => Container(
                height: 200,
                color: Colors.grey.shade100,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image_outlined,
                          size: 40, color: Colors.grey.shade400),
                      const Gap(8),
                      Text('Gagal memuat gambar',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Double-tap heart animation
          if (_showHeart)
            ScaleTransition(
              scale: _heartScale,
              child: const Icon(
                Icons.favorite,
                size: 90,
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: Colors.black26,
                    blurRadius: 12,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context, PostModel post) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          // Like
          _ActionButton(
            icon: post.isLiked ? Icons.favorite : Icons.favorite_border,
            color: post.isLiked ? Colors.red : Colors.black87,
            onTap: () => _handleLike(context),
          ),
          const Gap(4),
          // Comment
          _ActionButton(
            icon: Icons.chat_bubble_outline,
            color: Colors.black87,
            onTap: () => CommentSheet.show(context, post),
          ),
          const Gap(4),
          // Share
          _ActionButton(
            icon: Icons.near_me_outlined,
            color: Colors.black87,
            onTap: () {},
          ),
          const Spacer(),
          // Bookmark
          _ActionButton(
            icon: Icons.bookmark_border,
            color: Colors.black87,
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildCaption(PostModel post) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
              color: Colors.black87, fontSize: 13.5, height: 1.3),
          children: [
            TextSpan(
              text: '${post.author.username} ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: post.caption),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentsLink(BuildContext context, PostModel post) {
    if (post.commentCount == 0) {
      return GestureDetector(
        onTap: () => CommentSheet.show(context, post),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
          child: Text(
            'Tambahkan komentar...',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: () => CommentSheet.show(context, post),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
        child: Text(
          'Lihat semua ${post.commentCount} komentar',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
        ),
      ),
    );
  }

  void _showPostOptions(BuildContext context, PostModel post) {
    final currentUser = context.read<LoginViewModel>().user;
    final currentUserId = int.tryParse(currentUser?.id ?? '') ?? 0;
    final isMyPost = currentUserId > 0 && currentUserId == post.author.id;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              if (isMyPost) ...[
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text(
                    'Hapus Postingan',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    _confirmDeletePost(context, post, currentUserId);
                  },
                ),
                const Divider(height: 1),
              ] else ...[
                ListTile(
                  leading: const Icon(Icons.flag_outlined),
                  title: const Text('Laporkan'),
                  onTap: () => Navigator.pop(bottomSheetContext),
                ),
                ListTile(
                  leading: const Icon(Icons.not_interested_outlined),
                  title: const Text('Jangan tampilkan lagi'),
                  onTap: () => Navigator.pop(bottomSheetContext),
                ),
              ],
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text('Bagikan'),
                onTap: () => Navigator.pop(bottomSheetContext),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeletePost(BuildContext context, PostModel post, int userId) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Hapus Postingan?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Apakah kamu yakin ingin menghapus postingan ini? Postingan yang dihapus tidak dapat dipulihkan.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);

              final postVm = context.read<PostViewModel>();
              final profileVm = context.read<ProfileViewModel>();
              final messenger = ScaffoldMessenger.of(context);

              messenger.showSnackBar(
                const SnackBar(
                  content: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text('Menghapus postingan...'),
                    ],
                  ),
                  duration: Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );

              final success = await postVm.deletePost(
                postId: post.id,
                userId: userId,
              );

              if (success) {
                profileVm.removePost(post.id);
                profileVm.fetchProfile(userId, currentUserId: userId);

                messenger.hideCurrentSnackBar();
                messenger.showSnackBar(
                  SnackBar(
                    content: const Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text('Postingan berhasil dihapus'),
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
                messenger.hideCurrentSnackBar();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                        postVm.errorMessage ?? 'Gagal menghapus postingan'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Hapus'),
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

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr.replaceAll(' ', 'T'));
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inMinutes < 1) return 'Baru saja';
      if (diff.inHours < 1) return '${diff.inMinutes} menit lalu';
      if (diff.inDays < 1) return '${diff.inHours} jam lalu';
      if (diff.inDays < 7) return '${diff.inDays} hari lalu';
      return dateStr.split(' ').first;
    } catch (_) {
      return dateStr;
    }
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 26, color: color),
      ),
    );
  }
}
