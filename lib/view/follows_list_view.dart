import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import 'package:ziesocial/model/profile_model.dart';
import 'package:ziesocial/view/profile_view.dart';
import 'package:ziesocial/viewmodel/login_viewmodel.dart';
import 'package:ziesocial/viewmodel/profile_viewmodel.dart';

class FollowsListView extends StatefulWidget {
  final int userId;
  final String username;
  final int initialTab; // 0: Pengikut (Followers), 1: Mengikuti (Following)
  final int followersCount;
  final int followingCount;

  const FollowsListView({
    super.key,
    required this.userId,
    required this.username,
    this.initialTab = 0,
    required this.followersCount,
    required this.followingCount,
  });

  @override
  State<FollowsListView> createState() => _FollowsListViewState();
}

class _FollowsListViewState extends State<FollowsListView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const Color primaryBlue = Color(0xFF3366A0);
  static const Color slate900 = Color(0xFF0F172A);
  static const Color slate500 = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 20, color: slate900),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.username.isNotEmpty ? widget.username : 'Pengguna',
          style: const TextStyle(
            color: slate900,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: slate900,
          unselectedLabelColor: slate500,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14.5,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.normal,
            fontSize: 14.5,
          ),
          indicatorColor: primaryBlue,
          indicatorWeight: 2.5,
          tabs: [
            Tab(text: '${widget.followersCount} Pengikut'),
            Tab(text: '${widget.followingCount} Mengikuti'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _FollowsTabContent(
            userId: widget.userId,
            type: 'followers',
            emptyTitle: 'Belum Ada Pengikut',
            emptySubtitle: 'Saat seseorang mengikuti akun ini, mereka akan muncul di sini.',
          ),
          _FollowsTabContent(
            userId: widget.userId,
            type: 'following',
            emptyTitle: 'Belum Mengikuti Siapapun',
            emptySubtitle: 'Akun yang diikuti akan muncul di sini.',
          ),
        ],
      ),
    );
  }
}

class _FollowsTabContent extends StatefulWidget {
  final int userId;
  final String type; // 'followers' atau 'following'
  final String emptyTitle;
  final String emptySubtitle;

  const _FollowsTabContent({
    required this.userId,
    required this.type,
    required this.emptyTitle,
    required this.emptySubtitle,
  });

  @override
  State<_FollowsTabContent> createState() => _FollowsTabContentState();
}

class _FollowsTabContentState extends State<_FollowsTabContent> {
  final TextEditingController _searchController = TextEditingController();
  List<FollowUserModel> _users = [];
  bool _isLoading = true;
  String _searchQuery = '';

  static const Color primaryBlue = Color(0xFF3366A0);
  static const Color slate900 = Color(0xFF0F172A);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate100 = Color(0xFFF1F5F9);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUsers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);

    final currentUser = context.read<LoginViewModel>().user;
    final currentUserId = int.tryParse(currentUser?.id ?? '') ?? 0;

    final profileVm = context.read<ProfileViewModel>();
    final list = await profileVm.fetchFollowsList(
      userId: widget.userId,
      type: widget.type,
      currentUserId: currentUserId > 0 ? currentUserId : null,
    );

    if (mounted) {
      setState(() {
        _users = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleFollow(FollowUserModel user) async {
    final currentUser = context.read<LoginViewModel>().user;
    final currentUserId = int.tryParse(currentUser?.id ?? '') ?? 0;
    if (currentUserId <= 0) return;

    final prevStatus = user.isFollowing;
    setState(() {
      final idx = _users.indexWhere((u) => u.id == user.id);
      if (idx != -1) {
        _users[idx] = user.copyWith(isFollowing: !prevStatus);
      }
    });

    final profileVm = context.read<ProfileViewModel>();
    final success = await profileVm.toggleFollowUser(
      followerId: currentUserId,
      followingId: user.id,
    );

    if (!success && mounted) {
      // Kembalikan status jika gagal
      setState(() {
        final idx = _users.indexWhere((u) => u.id == user.id);
        if (idx != -1) {
          _users[idx] = user.copyWith(isFollowing: prevStatus);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredUsers = _users.where((u) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return u.username.toLowerCase().contains(q) ||
          u.name.toLowerCase().contains(q);
    }).toList();

    return Column(
      children: [
        // Bar Pencarian
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: slate100,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(Icons.search, color: slate500, size: 20),
                const Gap(8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    decoration: const InputDecoration(
                      hintText: 'Cari...',
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
                    child: const Icon(Icons.close, size: 18, color: Colors.grey),
                  ),
              ],
            ),
          ),
        ),

        // Konten List Pengguna
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadUsers,
            color: primaryBlue,
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: primaryBlue,
                      strokeWidth: 2,
                    ),
                  )
                : filteredUsers.isEmpty
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
                                    Icons.people_outline_rounded,
                                    size: 48,
                                    color: primaryBlue,
                                  ),
                                ),
                                const Gap(16),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'Tidak Ditemukan'
                                      : widget.emptyTitle,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: slate900,
                                  ),
                                ),
                                const Gap(6),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'Tidak ada akun yang cocok dengan "$_searchQuery"'
                                      : widget.emptySubtitle,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: slate500,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: filteredUsers.length,
                        separatorBuilder: (context, index) => const Divider(
                          height: 1,
                          thickness: 0.5,
                          indent: 72,
                          color: Color(0xFFF1F5F9),
                        ),
                        itemBuilder: (context, index) {
                          final user = filteredUsers[index];

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 2,
                            ),
                            leading: CircleAvatar(
                              radius: 22,
                              backgroundColor: const Color(0xFFE2E8F0),
                              child: user.avatar.isNotEmpty
                                  ? ClipOval(
                                      child: Image.network(
                                        user.avatarUrl,
                                        width: 44,
                                        height: 44,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) =>
                                            Text(
                                          user.name.isNotEmpty
                                              ? user.name[0].toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                            color: primaryBlue,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    )
                                  : Text(
                                      user.name.isNotEmpty
                                          ? user.name[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        color: primaryBlue,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                            title: Text(
                              user.username,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14.5,
                                color: slate900,
                              ),
                            ),
                            subtitle: Text(
                              user.name.isNotEmpty ? user.name : '@${user.username}',
                              style: const TextStyle(
                                color: slate500,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: user.isMe
                                ? null
                                : SizedBox(
                                    height: 32,
                                    child: OutlinedButton(
                                      onPressed: () => _toggleFollow(user),
                                      style: OutlinedButton.styleFrom(
                                        backgroundColor: user.isFollowing
                                            ? const Color(0xFFE2E8F0)
                                            : primaryBlue,
                                        foregroundColor: user.isFollowing
                                            ? slate900
                                            : Colors.white,
                                        side: BorderSide.none,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                      child: Text(
                                        user.isFollowing
                                            ? 'Mengikuti'
                                            : 'Ikuti',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: user.isFollowing
                                              ? slate900
                                              : Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ProfileView(userId: user.id),
                                ),
                              ).then((_) => _loadUsers());
                            },
                          );
                        },
                      ),
          ),
        ),
      ],
    );
  }
}
