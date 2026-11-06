import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import 'package:ziesocial/model/chat_model.dart';
import 'package:ziesocial/view/chat_room_view.dart';
import 'package:ziesocial/viewmodel/chat_viewmodel.dart';
import 'package:ziesocial/viewmodel/login_viewmodel.dart';
import 'package:ziesocial/viewmodel/search_viewmodel.dart';

class ChatListView extends StatefulWidget {
  const ChatListView({super.key});

  @override
  State<ChatListView> createState() => _ChatListViewState();
}

class _ChatListViewState extends State<ChatListView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  static const Color primaryBlue = Color(0xFF3366A0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadConversations();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadConversations() {
    final user = context.read<LoginViewModel>().user;
    final userId = int.tryParse(user?.id ?? '') ?? 0;
    if (userId > 0) {
      context.read<ChatViewModel>().fetchConversations(userId);
    }
  }

  String _formatConversationTime(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr.replaceAll(' ', 'T'));
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inDays == 0) {
        final hour = dt.hour.toString().padLeft(2, '0');
        final min = dt.minute.toString().padLeft(2, '0');
        return '$hour:$min';
      } else if (diff.inDays == 1) {
        return 'Kemarin';
      } else if (diff.inDays < 7) {
        return '${diff.inDays}h lalu';
      } else {
        return '${dt.day}/${dt.month}';
      }
    } catch (_) {
      return '';
    }
  }

  void _showNewChatDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomContext) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const Gap(10),
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Mulai Obrolan Baru',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 22),
                      onPressed: () => Navigator.pop(bottomContext),
                    ),
                  ],
                ),
              ),
              // Search input
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Cari nama atau username...',
                    prefixIcon:
                        const Icon(Icons.search, color: primaryBlue, size: 22),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: (val) {
                    final currentUser = context.read<LoginViewModel>().user;
                    final myId = int.tryParse(currentUser?.id ?? '') ?? 0;
                    context.read<SearchViewModel>().searchUsers(
                          val,
                          currentUserId: myId > 0 ? myId : null,
                        );
                  },
                ),
              ),
              const Gap(8),
              Expanded(
                child: Consumer<SearchViewModel>(
                  builder: (context, searchVm, _) {
                    if (searchVm.isLoading) {
                      return const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: primaryBlue,
                        ),
                      );
                    }

                    final users = searchVm.users;
                    if (users.isEmpty) {
                      return Center(
                        child: Text(
                          'Ketik nama untuk mencari pengguna',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 14,
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: scrollController,
                      itemCount: users.length,
                      itemBuilder: (ctx, idx) {
                        final u = users[idx];
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 20,
                            backgroundColor: const Color(0xFFE2E8F0),
                            child: u.avatar.isNotEmpty
                                ? ClipOval(
                                    child: Image.network(
                                      u.avatarUrl,
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) => Text(
                                        u.name.isNotEmpty
                                            ? u.name[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                          color: primaryBlue,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  )
                                : Text(
                                    u.name.isNotEmpty
                                        ? u.name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      color: primaryBlue,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                          title: Text(
                            u.name.isNotEmpty ? u.name : u.username,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14.5,
                            ),
                          ),
                          subtitle: Text(
                            '@${u.username}',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12.5,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: primaryBlue,
                            size: 20,
                          ),
                          onTap: () {
                            Navigator.pop(bottomContext);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatRoomView(
                                  peer: ChatPeer(
                                    id: u.id,
                                    username: u.username,
                                    name: u.name,
                                    avatar: u.avatar,
                                  ),
                                ),
                              ),
                            ).then((_) => _loadConversations());
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatVm = context.watch<ChatViewModel>();
    final conversations = chatVm.conversations.where((c) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return c.peer.name.toLowerCase().contains(q) ||
          c.peer.username.toLowerCase().contains(q) ||
          c.lastMessage.message.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 20, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Pesan',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.black87,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note_rounded,
                color: primaryBlue, size: 28),
            onPressed: _showNewChatDialog,
            tooltip: 'Obrolan Baru',
          ),
          const Gap(4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: const Color(0xFFEEEEEE)),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        onPressed: _showNewChatDialog,
        tooltip: 'Mulai Chat Baru',
        child: const Icon(Icons.chat_rounded),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadConversations(),
        color: primaryBlue,
        child: Column(
          children: [
            // Field Pencarian Obrolan
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(Icons.search, color: Colors.grey.shade500, size: 20),
                    const Gap(8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _searchQuery = v),
                        decoration: const InputDecoration(
                          hintText: 'Cari pesan atau pengguna...',
                          hintStyle: TextStyle(
                            fontSize: 13.5,
                            color: Color(0xFF94A3B8),
                          ),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        child: const Icon(Icons.close,
                            size: 18, color: Colors.grey),
                      ),
                  ],
                ),
              ),
            ),

            // Konten Percakapan
            Expanded(
              child: chatVm.isLoadingConversations
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: primaryBlue,
                        strokeWidth: 2,
                      ),
                    )
                  : conversations.isEmpty
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
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.forum_outlined,
                                      size: 52,
                                      color: primaryBlue,
                                    ),
                                  ),
                                  const Gap(16),
                                  const Text(
                                    'Belum Ada Pesan',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const Gap(6),
                                  Text(
                                    'Kirim pesan langsung ke teman atau kreator favorit Anda.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      color: Colors.grey.shade500,
                                      height: 1.35,
                                    ),
                                  ),
                                  const Gap(18),
                                  ElevatedButton.icon(
                                    onPressed: _showNewChatDialog,
                                    icon: const Icon(Icons.add_comment_rounded,
                                        size: 16),
                                    label: const Text('Mulai Chat Baru'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryBlue,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: conversations.length,
                          separatorBuilder: (context, index) => const Divider(
                            height: 1,
                            thickness: 0.5,
                            indent: 76,
                            color: Color(0xFFF1F5F9),
                          ),
                          itemBuilder: (context, index) {
                            final conv = conversations[index];
                            final peer = conv.peer;
                            final lastMsg = conv.lastMessage;
                            final hasUnread = conv.unreadCount > 0;

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                              leading: Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 25,
                                    backgroundColor: const Color(0xFFE2E8F0),
                                    child: peer.avatar.isNotEmpty
                                        ? ClipOval(
                                            child: Image.network(
                                              peer.avatarUrl,
                                              width: 50,
                                              height: 50,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (context, error, stackTrace) =>
                                                      Text(
                                                peer.name.isNotEmpty
                                                    ? peer.name[0].toUpperCase()
                                                    : '?',
                                                style: const TextStyle(
                                                  color: primaryBlue,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 18,
                                                ),
                                              ),
                                            ),
                                          )
                                        : Text(
                                            peer.name.isNotEmpty
                                                ? peer.name[0].toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                              color: primaryBlue,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                            ),
                                          ),
                                  ),
                                  if (hasUnread)
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      child: Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: primaryBlue,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      peer.name.isNotEmpty
                                          ? peer.name
                                          : peer.username,
                                      style: TextStyle(
                                        fontWeight: hasUnread
                                            ? FontWeight.bold
                                            : FontWeight.w600,
                                        fontSize: 15,
                                        color: Colors.black87,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const Gap(6),
                                  Text(
                                    _formatConversationTime(lastMsg.createDate),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: hasUnread
                                          ? primaryBlue
                                          : Colors.grey.shade400,
                                      fontWeight: hasUnread
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        lastMsg.isMine
                                            ? 'Anda: ${lastMsg.message}'
                                            : lastMsg.message,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: hasUnread
                                              ? Colors.black87
                                              : Colors.grey.shade500,
                                          fontWeight: hasUnread
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                    if (hasUnread) ...[
                                      const Gap(8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: primaryBlue,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          '${conv.unreadCount}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChatRoomView(peer: peer),
                                  ),
                                ).then((_) => _loadConversations());
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

