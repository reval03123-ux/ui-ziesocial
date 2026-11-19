import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import 'package:ziesocial/model/notification_model.dart';
import 'package:ziesocial/view/profile_view.dart';
import 'package:ziesocial/viewmodel/login_viewmodel.dart';
import 'package:ziesocial/viewmodel/notification_viewmodel.dart';
import 'package:ziesocial/viewmodel/post_viewmodel.dart';
import 'package:ziesocial/widget/comment_sheet.dart';

class NotificationView extends StatefulWidget {
  final bool isEmbedded;

  const NotificationView({
    super.key,
    this.isEmbedded = false,
  });

  @override
  State<NotificationView> createState() => _NotificationViewState();
}

class _NotificationViewState extends State<NotificationView> {
  static const Color primaryBlue = Color(0xFF3366A0);
  static const Color slate900 = Color(0xFF0F172A);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate100 = Color(0xFFF1F5F9);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    final user = context.read<LoginViewModel>().user;
    final userId = int.tryParse(user?.id ?? '') ?? 0;
    if (userId > 0) {
      final vm = context.read<NotificationViewModel>();
      vm.fetchNotifications(userId);
      // Tandai otomatis sudah dibaca ketika halaman dibuka
      vm.markAllAsRead(userId);
    }
  }

  void _handleNotificationTap(NotificationItem item) {
    if (item.type == 'follow') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProfileView(userId: item.sender.id),
        ),
      );
    } else if (item.postId != null && item.postId! > 0) {
      // Buka post terkait atau komentar jika ada di post list
      final posts = context.read<PostViewModel>().posts;
      final postIndex = posts.indexWhere((p) => p.id == item.postId);
      if (postIndex != -1) {
        final post = posts[postIndex];
        if (item.type == 'comment') {
          CommentSheet.show(context, post);
        } else {
          // Buka profile atau modal
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProfileView(userId: item.sender.id),
            ),
          );
        }
      } else {
        // Fallback navigasi ke profil pelaku interaksi
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProfileView(userId: item.sender.id),
          ),
        );
      }
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProfileView(userId: item.sender.id),
        ),
      );
    }
  }

  Widget _buildTypeBadge(String type) {
    IconData icon;
    Color bg;

    switch (type) {
      case 'like':
        icon = Icons.favorite_rounded;
        bg = const Color(0xFFEF4444); // Red
        break;
      case 'comment':
        icon = Icons.mode_comment_rounded;
        bg = const Color(0xFF10B981); // Emerald Green
        break;
      case 'follow':
        icon = Icons.person_add_rounded;
        bg = primaryBlue;
        break;
      case 'chat':
        icon = Icons.chat_bubble_rounded;
        bg = const Color(0xFF8B5CF6); // Purple
        break;
      default:
        icon = Icons.notifications_rounded;
        bg = primaryBlue;
    }

    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Center(
        child: Icon(icon, color: Colors.white, size: 9),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<LoginViewModel>().user;
    final currentUserId = int.tryParse(user?.id ?? '') ?? 0;
    final notifVm = context.watch<NotificationViewModel>();
    final notifications = notifVm.notifications;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        leading: widget.isEmbedded
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new,
                    size: 20, color: slate900),
                onPressed: () => Navigator.pop(context),
              ),
        title: const Text(
          'Notifikasi',
          style: TextStyle(
            color: slate900,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          if (notifications.isNotEmpty)
            TextButton(
              onPressed: () {
                if (currentUserId > 0) {
                  notifVm.markAllAsRead(currentUserId);
                }
              },
              child: const Text(
                'Sudah Dibaca',
                style: TextStyle(
                  color: primaryBlue,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          const Gap(8),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (currentUserId > 0) {
            await notifVm.fetchNotifications(currentUserId);
            await notifVm.markAllAsRead(currentUserId);
          }
        },
        color: primaryBlue,
        child: notifVm.isLoading && notifications.isEmpty
            ? const Center(
                child: CircularProgressIndicator(
                  color: primaryBlue,
                  strokeWidth: 2,
                ),
              )
            : notifications.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(22),
                              decoration: const BoxDecoration(
                                color: slate100,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.notifications_none_rounded,
                                size: 52,
                                color: primaryBlue,
                              ),
                            ),
                            const Gap(16),
                            const Text(
                              'Belum Ada Notifikasi',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: slate900,
                              ),
                            ),
                            const Gap(6),
                            const Text(
                              'Suka, komentar, dan pengikut baru akan muncul di sini secara real-time.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13.5,
                                color: slate500,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: notifications.length,
                    separatorBuilder: (context, index) => const Divider(
                      height: 1,
                      thickness: 0.5,
                      indent: 72,
                      color: Color(0xFFF8FAFC),
                    ),
                    itemBuilder: (context, index) {
                      final item = notifications[index];
                      final sender = item.sender;
                      final isUnread = !item.isRead;

                      return InkWell(
                        onTap: () => _handleNotificationTap(item),
                        child: Container(
                          color: isUnread
                              ? const Color(0xFFF0F7FF)
                              : Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 11,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Avatar dengan badge tipe notifikasi
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          ProfileView(userId: sender.id),
                                    ),
                                  );
                                },
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    CircleAvatar(
                                      radius: 22,
                                      backgroundColor: const Color(0xFFE2E8F0),
                                      child: sender.avatar.isNotEmpty
                                          ? ClipOval(
                                              child: Image.network(
                                                sender.avatarUrl,
                                                width: 44,
                                                height: 44,
                                                fit: BoxFit.cover,
                                                errorBuilder:
                                                    (context, error, _) => Text(
                                                  sender.name.isNotEmpty
                                                      ? sender.name[0]
                                                          .toUpperCase()
                                                      : '?',
                                                  style: const TextStyle(
                                                    color: primaryBlue,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            )
                                          : Text(
                                              sender.name.isNotEmpty
                                                  ? sender.name[0]
                                                      .toUpperCase()
                                                  : '?',
                                              style: const TextStyle(
                                                color: primaryBlue,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                    ),
                                    Positioned(
                                      right: -2,
                                      bottom: -2,
                                      child: _buildTypeBadge(item.type),
                                    ),
                                  ],
                                ),
                              ),
                              const Gap(14),

                              // Teks Notifikasi
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      color: slate900,
                                      height: 1.3,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: sender.username.isNotEmpty
                                            ? sender.username
                                            : sender.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const TextSpan(text: ' '),
                                      TextSpan(
                                        text: item.message,
                                        style: TextStyle(
                                          fontWeight: isUnread
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                          color: isUnread
                                              ? slate900
                                              : const Color(0xFF334155),
                                        ),
                                      ),
                                      const TextSpan(text: '  '),
                                      TextSpan(
                                        text: item.formattedTime,
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          color: slate500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const Gap(10),

                              // Trailing: Thumbnail Post atau Tombol Follow
                              if (item.type == 'follow') ...[
                                SizedBox(
                                  height: 32,
                                  child: OutlinedButton(
                                    onPressed: () {
                                      if (currentUserId > 0) {
                                        notifVm.toggleFollowUser(
                                          currentUserId: currentUserId,
                                          targetUserId: sender.id,
                                          item: item,
                                        );
                                      }
                                    },
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: sender.isFollowing
                                          ? const Color(0xFFE2E8F0)
                                          : primaryBlue,
                                      foregroundColor: sender.isFollowing
                                          ? slate900
                                          : Colors.white,
                                      side: BorderSide.none,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14),
                                    ),
                                    child: Text(
                                      sender.isFollowing
                                          ? 'Mengikuti'
                                          : 'Ikuti Balik',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: sender.isFollowing
                                            ? slate900
                                            : Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ] else if (item.postImageUrl != null) ...[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.network(
                                    item.postImageUrl!,
                                    width: 44,
                                    height: 44,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            Container(
                                      width: 44,
                                      height: 44,
                                      color: slate100,
                                      child: const Icon(
                                        Icons.image_outlined,
                                        size: 20,
                                        color: slate500,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
