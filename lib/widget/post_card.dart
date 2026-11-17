import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import 'package:ziesocial/model/post_model.dart';
import 'package:ziesocial/view/login_view.dart';
import 'package:ziesocial/view/profile_view.dart';
import 'package:ziesocial/view/story_player_view.dart';
import 'package:ziesocial/viewmodel/login_viewmodel.dart';
import 'package:ziesocial/viewmodel/post_viewmodel.dart';
import 'package:ziesocial/viewmodel/profile_viewmodel.dart';
import 'package:ziesocial/viewmodel/story_viewmodel.dart';
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
  bool _isBookmarked = false;

  @override
  void initState() {
    super.initState();
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _heartScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.25)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.25, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 40,
      ),
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
    final postVm = context.watch<PostViewModel>();
    final post = postVm.posts.firstWhere(
      (p) => p.id == widget.post.id,
      orElse: () => widget.post,
    );

    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header (User Info & Options) ──
          _buildHeader(context, post),

          // ── Media Image (Full-bleed edge-to-edge) ──
          if (post.image.isNotEmpty) _buildImage(context, post),

          // ── Action Bar (Like, Comment, Share, Bookmark) ──
          _buildActions(context, post),

          // ── Likes Count ──
          if (post.likeCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
              child: Text(
                '${_formatCount(post.likeCount)} suka',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                  color: Colors.black87,
                ),
              ),
            ),

          // ── Caption ──
          if (post.caption.isNotEmpty) _buildCaption(post),

          // ── Comments Link ──
          _buildCommentsLink(context, post),

          // ── Date / Timestamp ──
          if (post.createDate.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 3, 14, 12),
              child: Text(
                _formatDate(post.createDate).toUpperCase(),
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.2,
                ),
              ),
            ),

          Divider(height: 1, thickness: 0.5, color: Colors.grey.shade100),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, PostModel post) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              final storyVm = context.read<StoryViewModel>();
              final userStory = storyVm.getUserStory(post.author.id);
              if (userStory != null && userStory.stories.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StoryPlayerView(
                      userStories: [userStory],
                      initialUserIndex: 0,
                    ),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfileView(userId: post.author.id),
                  ),
                );
              }
            },
            child: _buildAuthorAvatar(post),
          ),
          const Gap(10),
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfileView(userId: post.author.id),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.author.username.isNotEmpty
                        ? post.author.username
                        : post.author.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (post.author.name.isNotEmpty &&
                      post.author.name != post.author.username)
                    Text(
                      post.author.name,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.grey.shade500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.black87, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () => _showPostOptions(context, post),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthorAvatar(PostModel post) {
    final storyVm = context.watch<StoryViewModel>();
    final hasActiveStory =
        post.author.hasStory || storyVm.hasActiveStory(post.author.id);

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: hasActiveStory
            ? const LinearGradient(
                colors: [
                  Color(0xFF833AB4),
                  Color(0xFFFD1D1D),
                  Color(0xFFFCB045),
                ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              )
            : null,
      ),
      padding: hasActiveStory ? const EdgeInsets.all(2) : EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: hasActiveStory
              ? null
              : Border.all(color: Colors.grey.shade300, width: 0.8),
        ),
        padding: hasActiveStory ? const EdgeInsets.all(1.5) : EdgeInsets.zero,
        child: CircleAvatar(
          radius: 15,
          backgroundColor: const Color(0xFFF1F5F9),
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
        color: Color(0xFF4F46E5),
      ),
    );
  }

  // ── Image (Full width with double tap like) ──────────────────────────────
  Widget _buildImage(BuildContext context, PostModel post) {
    return GestureDetector(
      onDoubleTap: () => _handleDoubleTap(context),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            constraints: const BoxConstraints(
              maxHeight: 520,
              minHeight: 220,
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
                  height: 320,
                  color: Colors.grey.shade50,
                  child: Center(
                    child: CircularProgressIndicator(
                      value: progress.expectedTotalBytes != null
                          ? progress.cumulativeBytesLoaded /
                              progress.expectedTotalBytes!
                          : null,
                      strokeWidth: 2,
                      color: const Color(0xFF4F46E5),
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) => Container(
                height: 220,
                color: Colors.grey.shade100,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image_outlined,
                          size: 40, color: Colors.grey.shade400),
                      const Gap(8),
                      Text(
                        'Gagal memuat gambar',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Double-tap heart animation (Instagram style)
          if (_showHeart)
            ScaleTransition(
              scale: _heartScale,
              child: const Icon(
                Icons.favorite,
                size: 96,
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: Colors.black38,
                    blurRadius: 18,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Actions (Like, Comment, Share, Bookmark) ─────────────────────────────
  Widget _buildActions(BuildContext context, PostModel post) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          // Like button
          _ActionButton(
            icon: post.isLiked ? Icons.favorite : Icons.favorite_border,
            color: post.isLiked ? const Color(0xFFED4956) : Colors.black87,
            onTap: () => _handleLike(context),
          ),
          const Gap(4),

          // Comment button
          _ActionButton(
            icon: Icons.chat_bubble_outline_rounded,
            color: Colors.black87,
            onTap: () => CommentSheet.show(context, post),
          ),
          const Gap(4),

          // Share / Direct message button
          _ActionButton(
            icon: Icons.near_me_outlined,
            color: Colors.black87,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Tautan postingan berhasil disalin!'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            },
          ),
          const Spacer(),

          // Bookmark button
          _ActionButton(
            icon: _isBookmarked
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded,
            color: Colors.black87,
            onTap: () {
              setState(() => _isBookmarked = !_isBookmarked);
              HapticFeedback.lightImpact();
            },
          ),
        ],
      ),
    );
  }

  // ── Caption ───────────────────────────────────────────────────────────────
  Widget _buildCaption(PostModel post) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 13.5,
            height: 1.35,
          ),
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

  // ── Comments Link ─────────────────────────────────────────────────────────
  Widget _buildCommentsLink(BuildContext context, PostModel post) {
    if (post.commentCount == 0) {
      return GestureDetector(
        onTap: () => CommentSheet.show(context, post),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 2, 14, 4),
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
        padding: const EdgeInsets.fromLTRB(14, 2, 14, 4),
        child: Text(
          'Lihat semua ${post.commentCount} komentar',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
        ),
      ),
    );
  }

  // ── Post Options Bottom Sheet ─────────────────────────────────────────────
  void _showPostOptions(BuildContext context, PostModel post) {
    final currentUser = context.read<LoginViewModel>().user;
    final currentUserId = int.tryParse(currentUser?.id ?? '') ?? 0;
    final isMyPost = currentUserId > 0 && currentUserId == post.author.id;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (bottomSheetContext) => SafeArea(
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
                  leading: const Icon(Icons.report_problem_outlined),
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
        backgroundColor: Colors.white,
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
                      postVm.errorMessage ?? 'Gagal menghapus postingan',
                    ),
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
