import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import 'package:ziesocial/model/chat_model.dart';
import 'package:ziesocial/view/chat_room_view.dart';
import 'package:ziesocial/view/notification_view.dart';
import 'package:ziesocial/view/profile_view.dart';
import 'package:ziesocial/viewmodel/notification_viewmodel.dart';

class InAppNotificationBanner extends StatelessWidget {
  const InAppNotificationBanner({super.key});

  static const Color primaryBlue = Color(0xFF3366A0);
  static const Color slate900 = Color(0xFF0F172A);
  static const Color slate500 = Color(0xFF64748B);

  Widget _buildBadge(AlertType type) {
    IconData icon;
    Color bg;

    switch (type) {
      case AlertType.like:
        icon = Icons.favorite_rounded;
        bg = const Color(0xFFEF4444);
        break;
      case AlertType.comment:
        icon = Icons.mode_comment_rounded;
        bg = const Color(0xFF10B981);
        break;
      case AlertType.follow:
        icon = Icons.person_add_rounded;
        bg = primaryBlue;
        break;
      case AlertType.chat:
        icon = Icons.chat_bubble_rounded;
        bg = const Color(0xFF8B5CF6);
        break;
    }

    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Center(
        child: Icon(icon, color: Colors.white, size: 8.5),
      ),
    );
  }

  void _handleTap(BuildContext context, InAppAlert alert) {
    context.read<NotificationViewModel>().dismissAlert();

    final data = alert.rawData;
    if (alert.type == AlertType.chat) {
      final senderId = int.tryParse(data['sender_id']?.toString() ?? '') ?? 0;
      final senderName = data['sender_name']?.toString() ?? '';
      final senderUsername = data['sender_username']?.toString() ?? '';
      final senderAvatar = data['sender_avatar']?.toString() ?? '';

      if (senderId > 0) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatRoomView(
              peer: ChatPeer(
                id: senderId,
                username: senderUsername,
                name: senderName,
                avatar: senderAvatar,
              ),
            ),
          ),
        );
      }
    } else if (alert.type == AlertType.follow) {
      final senderId = int.tryParse(data['sender_id']?.toString() ?? (data['sender']?['id']?.toString() ?? '')) ?? 0;
      if (senderId > 0) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProfileView(userId: senderId),
          ),
        );
      }
    } else {
      // Like / Comment -> buka NotificationView
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const NotificationView(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final alert = context.watch<NotificationViewModel>().latestAlert;

    if (alert == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 12,
      right: 12,
      child: Dismissible(
        key: UniqueKey(),
        direction: DismissDirection.up,
        onDismissed: (_) {
          context.read<NotificationViewModel>().dismissAlert();
        },
        child: Material(
          color: Colors.transparent,
          elevation: 8,
          borderRadius: BorderRadius.circular(16),
          shadowColor: Colors.black.withValues(alpha: 0.25),
          child: InkWell(
            onTap: () => _handleTap(context, alert),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  // Avatar dengan badge icon
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFFE2E8F0),
                        child: alert.avatarUrl.isNotEmpty
                            ? ClipOval(
                                child: Image.network(
                                  alert.avatarUrl,
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Text(
                                    alert.title.isNotEmpty ? alert.title[0].toUpperCase() : '?',
                                    style: const TextStyle(
                                      color: primaryBlue,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              )
                            : Text(
                                alert.title.isNotEmpty ? alert.title[0].toUpperCase() : '?',
                                style: const TextStyle(
                                  color: primaryBlue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                      Positioned(
                        right: -1,
                        bottom: -1,
                        child: _buildBadge(alert.type),
                      ),
                    ],
                  ),
                  const Gap(12),

                  // Teks Pengirim & Konten
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          alert.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: slate900,
                          ),
                        ),
                        const Gap(2),
                        Text(
                          alert.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: slate500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Post Thumbnail atau tombol tutup
                  if (alert.postImageUrl != null && alert.postImageUrl!.isNotEmpty) ...[
                    const Gap(8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        alert.postImageUrl!,
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                      ),
                    ),
                  ] else ...[
                    const Gap(4),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16, color: slate500),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: () {
                        context.read<NotificationViewModel>().dismissAlert();
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
