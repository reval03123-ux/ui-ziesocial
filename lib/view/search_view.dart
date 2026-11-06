import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import 'package:ziesocial/model/profile_model.dart';
import 'package:ziesocial/view/login_view.dart';
import 'package:ziesocial/view/profile_view.dart';
import 'package:ziesocial/view/story_player_view.dart';
import 'package:ziesocial/viewmodel/login_viewmodel.dart';
import 'package:ziesocial/viewmodel/search_viewmodel.dart';
import 'package:ziesocial/viewmodel/story_viewmodel.dart';

class SearchView extends StatefulWidget {
  const SearchView({super.key});

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  final _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  bool _isSearchFocused = false;

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() {
      setState(() => _isSearchFocused = _searchFocus.hasFocus);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _performSearch('');
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _performSearch(String query) {
    final user = context.read<LoginViewModel>().user;
    final currentUserId = user != null ? int.tryParse(user.id) : null;
    context.read<SearchViewModel>().searchUsers(query,
        currentUserId: currentUserId);
  }

  void _handleFollowToggle(SearchUserModel targetUser) {
    final currentUser = context.read<LoginViewModel>().user;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Silakan login terlebih dahulu.'),
          backgroundColor: Colors.grey.shade900,
          behavior: SnackBarBehavior.floating,
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

    HapticFeedback.selectionClick();
    final followerId = int.tryParse(currentUser.id) ?? 0;
    if (followerId > 0) {
      context.read<SearchViewModel>().toggleFollowUser(
            followerId: followerId,
            targetUser: targetUser,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchVm = context.watch<SearchViewModel>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: Builder(
        builder: (context) {
          if (searchVm.isLoading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    color: Color(0xFF3366A0),
                    strokeWidth: 2,
                  ),
                  const Gap(12),
                  Text('Mencari...', style: TextStyle(color: Colors.grey.shade500)),
                ],
              ),
            );
          }

          if (searchVm.users.isEmpty) {
            return _buildEmptyState();
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_searchController.text.isEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Disarankan Untuk Kamu',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
              ] else ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    '${searchVm.users.length} hasil ditemukan',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
              ],
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: searchVm.users.length,
                  itemBuilder: (context, index) {
                    return _buildUserTile(searchVm.users[index]);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      title: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 42,
        decoration: BoxDecoration(
          color: _isSearchFocused
              ? const Color(0xFFF0F4F8)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: _isSearchFocused
              ? Border.all(color: const Color(0xFF3366A0), width: 1.5)
              : null,
        ),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocus,
          onChanged: _performSearch,
          textInputAction: TextInputAction.search,
          style: const TextStyle(fontSize: 14, color: Colors.black87),
          decoration: InputDecoration(
            hintText: 'Cari pengguna...',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            prefixIcon: Icon(
              Icons.search,
              size: 20,
              color: _isSearchFocused
                  ? const Color(0xFF3366A0)
                  : Colors.grey.shade400,
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                    onPressed: () {
                      _searchController.clear();
                      _performSearch('');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0.5),
        child: Container(height: 0.5, color: const Color(0xFFEEEEEE)),
      ),
    );
  }

  Widget _buildUserTile(SearchUserModel user) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProfileView(userId: user.id),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Avatar
            _buildAvatar(user),
            const Gap(12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.username,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  if (user.name.isNotEmpty)
                    Text(
                      user.name,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  if (user.followersCount > 0)
                    Text(
                      _formatFollowers(user.followersCount),
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 11.5,
                      ),
                    ),
                ],
              ),
            ),

            // Follow button
            _buildFollowButton(user),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(SearchUserModel user) {
    final storyVm = context.watch<StoryViewModel>();
    final userStory = storyVm.getUserStory(user.id);
    final hasActiveStory =
        (userStory != null && userStory.stories.isNotEmpty) || user.hasStory;

    return GestureDetector(
      onTap: () {
        if (hasActiveStory && userStory != null && userStory.stories.isNotEmpty) {
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
              builder: (context) => ProfileView(userId: user.id),
            ),
          );
        }
      },
      child: Container(
        width: 50,
        height: 50,
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
            radius: 22,
            backgroundColor: const Color(0xFFE8EFF8),
            child: user.avatar.isNotEmpty
                ? ClipOval(
                    child: Image.network(
                      user.avatarUrl,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _avatarInitial(user.name),
                    ),
                  )
                : _avatarInitial(user.name),
          ),
        ),
      ),
    );
  }

  Widget _avatarInitial(String name) {
    return Text(
      name.isNotEmpty ? name[0].toUpperCase() : '?',
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 16,
        color: Color(0xFF3366A0),
      ),
    );
  }

  Widget _buildFollowButton(SearchUserModel user) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      child: SizedBox(
        height: 34,
        child: ElevatedButton(
          onPressed: () => _handleFollowToggle(user),
          style: ElevatedButton.styleFrom(
            backgroundColor:
                user.isFollowing ? Colors.white : const Color(0xFF3366A0),
            foregroundColor: user.isFollowing ? Colors.black87 : Colors.white,
            elevation: 0,
            side: user.isFollowing
                ? BorderSide(color: Colors.grey.shade300)
                : BorderSide.none,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            user.isFollowing ? 'Mengikuti' : 'Ikuti',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  String _formatFollowers(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M pengikut';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K pengikut';
    return '$count pengikut';
  }

  Widget _buildEmptyState() {
    final hasQuery = _searchController.text.isNotEmpty;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Icon(
              hasQuery
                  ? Icons.person_search_outlined
                  : Icons.group_outlined,
              size: 38,
              color: Colors.grey.shade400,
            ),
          ),
          const Gap(16),
          Text(
            hasQuery ? 'Pengguna tidak ditemukan' : 'Cari teman baru',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const Gap(6),
          Text(
            hasQuery
                ? 'Coba nama atau username yang berbeda.'
                : 'Ketik nama atau username untuk menemukan pengguna.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }
}
