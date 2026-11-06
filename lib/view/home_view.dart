import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import 'package:ziesocial/model/story_model.dart';
import 'package:ziesocial/view/chat_list_view.dart';
import 'package:ziesocial/view/create_post_view.dart';
import 'package:ziesocial/view/create_story_view.dart';
import 'package:ziesocial/view/login_view.dart';
import 'package:ziesocial/view/story_player_view.dart';
import 'package:ziesocial/viewmodel/chat_viewmodel.dart';
import 'package:ziesocial/viewmodel/login_viewmodel.dart';
import 'package:ziesocial/viewmodel/post_viewmodel.dart';
import 'package:ziesocial/viewmodel/story_viewmodel.dart';
import 'package:ziesocial/widget/post_card.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> with TickerProviderStateMixin {
  late AnimationController _logoAnimController;
  late Animation<double> _logoAnim;

  @override
  void initState() {
    super.initState();
    _logoAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _logoAnim = CurvedAnimation(parent: _logoAnimController, curve: Curves.elasticOut);
    _logoAnimController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshPosts();
    });
  }

  @override
  void dispose() {
    _logoAnimController.dispose();
    super.dispose();
  }

  Future<void> _refreshPosts() async {
    final user = context.read<LoginViewModel>().user;
    final userId = user != null ? int.tryParse(user.id) : null;
    await Future.wait([
      context.read<PostViewModel>().fetchPosts(currentUserId: userId),
      context.read<StoryViewModel>().fetchStories(currentUserId: userId),
      if (userId != null)
        context.read<ChatViewModel>().fetchConversations(userId),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<LoginViewModel>().user;
    final postVm = context.watch<PostViewModel>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(user),
      body: Builder(
        builder: (context) {
          if (postVm.isLoading && postVm.posts.isEmpty) {
            return _buildLoadingState();
          }

          if (postVm.errorMessage != null && postVm.posts.isEmpty) {
            return _buildErrorState(postVm.errorMessage!);
          }

          if (postVm.posts.isEmpty) {
            return _buildEmptyState(user);
          }

          return RefreshIndicator(
            color: const Color(0xFF3366A0),
            onRefresh: _refreshPosts,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Stories bar
                SliverToBoxAdapter(
                  child: _buildStoriesBar(user),
                ),
                // Divider
                const SliverToBoxAdapter(
                  child: Divider(height: 1, thickness: 0.5, color: Color(0xFFEEEEEE)),
                ),
                // Posts
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return PostCard(post: postVm.posts[index]);
                    },
                    childCount: postVm.posts.length,
                  ),
                ),
                const SliverToBoxAdapter(child: Gap(80)),
              ],
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(dynamic user) {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      centerTitle: false,
      title: ScaleTransition(
        scale: _logoAnim,
        child: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF3366A0), Color(0xFF5B8FD4), Color(0xFF3366A0)],
          ).createShader(bounds),
          child: const Text(
            'ZieSocial',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 24,
              letterSpacing: -0.5,
              color: Colors.white,
            ),
          ),
        ),
      ),
      actions: [
        if (user != null) ...[
          IconButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CreatePostView()),
              );
              if (context.mounted) _refreshPosts();
            },
            icon: const Icon(Icons.add_box_outlined, color: Colors.black87, size: 26),
            tooltip: 'Buat postingan',
          ),
          IconButton(
            onPressed: _refreshPosts,
            icon: const Icon(Icons.favorite_border, color: Colors.black87, size: 26),
            tooltip: 'Notifikasi',
          ),
          Consumer<ChatViewModel>(
            builder: (ctx, chatVm, _) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    onPressed: () async {
                      await Navigator.push(
                        ctx,
                        MaterialPageRoute(
                          builder: (_) => const ChatListView(),
                        ),
                      );
                      if (!ctx.mounted) return;
                      final u = ctx.read<LoginViewModel>().user;
                      final uid = int.tryParse(u?.id ?? '') ?? 0;
                      if (uid > 0) {
                        ctx.read<ChatViewModel>().fetchConversations(uid);
                      }
                    },
                    icon: const Icon(
                      Icons.near_me_outlined,
                      color: Colors.black87,
                      size: 25,
                    ),
                    tooltip: 'Pesan',
                  ),
                  if (chatVm.totalUnreadCount > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE11D48),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Center(
                          child: Text(
                            chatVm.totalUnreadCount > 99
                                ? '99+'
                                : '${chatVm.totalUnreadCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ] else ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginView()),
                );
              },
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF3366A0),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              ),
              child: const Text('Masuk', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0.5),
        child: Container(height: 0.5, color: const Color(0xFFEEEEEE)),
      ),
    );
  }

  void _openCreateStory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateStoryView()),
    );
  }

  void _promptLogin() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Silakan masuk untuk membagikan cerita.'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
  }

  Widget _buildStoriesBar(dynamic user) {
    final storyVm = context.watch<StoryViewModel>();
    final allUserStories = storyVm.userStories;

    final myUserId = user != null ? int.tryParse(user.id.toString()) ?? 0 : 0;
    UserStory? myStory;
    if (myUserId > 0) {
      myStory = storyVm.getMyStory(myUserId);
    }

    final otherUserStories = allUserStories
        .where((s) => s.userId != myUserId && s.stories.isNotEmpty)
        .toList();

    final hasMyStory = myStory != null && myStory.stories.isNotEmpty;
    final totalCount = 1 + otherUserStories.length;

    return SizedBox(
      height: 115,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: totalCount,
        itemBuilder: (context, index) {
          if (index == 0) {
            // Cerita Saya
            return GestureDetector(
              onTap: () {
                if (user == null) {
                  _promptLogin();
                  return;
                }
                if (hasMyStory) {
                  final playerList = [myStory!, ...otherUserStories];
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StoryPlayerView(
                        userStories: playerList,
                        initialUserIndex: 0,
                      ),
                    ),
                  );
                } else {
                  _openCreateStory();
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: hasMyStory
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
                          child: Container(
                            margin: hasMyStory
                                ? const EdgeInsets.all(2.5)
                                : EdgeInsets.zero,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: hasMyStory
                                  ? null
                                  : Border.all(
                                      color: Colors.grey.shade300,
                                      width: 0.8,
                                    ),
                            ),
                            child: CircleAvatar(
                              radius: 30,
                              backgroundColor: const Color(0xFFE8EFF8),
                              child: (user != null &&
                                      user.avatarUrl != null &&
                                      user.avatarUrl.toString().trim().isNotEmpty)
                                  ? ClipOval(
                                      child: Image.network(
                                        user.avatarUrl.toString(),
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                _storyInitial(user?.name),
                                      ),
                                    )
                                  : _storyInitial(user?.name ?? 'Anda'),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () {
                              if (user == null) {
                                _promptLogin();
                              } else {
                                _openCreateStory();
                              }
                            },
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: const Color(0xFF3366A0),
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(Icons.add,
                                  color: Colors.white, size: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Gap(4),
                    const SizedBox(
                      width: 68,
                      child: Text(
                        'Cerita Anda',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // Cerita Pengguna Lain
          final otherIndex = index - 1;
          final storyUser = otherUserStories[otherIndex];

          return GestureDetector(
            onTap: () {
              final playerList = [
                if (hasMyStory) myStory!,
                ...otherUserStories,
              ];
              final playerIndex = (hasMyStory ? 1 : 0) + otherIndex;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StoryPlayerView(
                    userStories: playerList,
                    initialUserIndex: playerIndex,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                children: [
                  Container(
                    width: 70,
                    height: 70,
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
                      margin: const EdgeInsets.all(2.5),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: CircleAvatar(
                        radius: 30,
                        backgroundColor: const Color(0xFFE8EFF8),
                        child: storyUser.avatar.isNotEmpty &&
                                storyUser.avatarUrl.isNotEmpty
                            ? ClipOval(
                                child: Image.network(
                                  storyUser.avatarUrl,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder:
                                      (context, error, stackTrace) =>
                                          _storyInitial(storyUser.name),
                                ),
                              )
                            : _storyInitial(storyUser.name),
                      ),
                    ),
                  ),
                  const Gap(4),
                  SizedBox(
                    width: 68,
                    child: Text(
                      storyUser.username.isNotEmpty
                          ? storyUser.username
                          : storyUser.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _storyInitial(dynamic name) {
    final n = name?.toString() ?? '';
    return Text(
      n.isNotEmpty ? n[0].toUpperCase() : '?',
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 20,
        color: Color(0xFF3366A0),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: Color(0xFF3366A0),
            strokeWidth: 2,
          ),
          const Gap(16),
          Text(
            'Memuat postingan...',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String errorMessage) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.wifi_off_rounded, size: 40, color: Colors.red.shade300),
            ),
            const Gap(16),
            const Text(
              'Gagal memuat',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const Gap(8),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const Gap(24),
            ElevatedButton.icon(
              onPressed: _refreshPosts,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3366A0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(dynamic user) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF3366A0).withValues(alpha: 0.1), const Color(0xFF5B8FD4).withValues(alpha: 0.1)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.photo_library_outlined, size: 48, color: Color(0xFF3366A0)),
            ),
            const Gap(20),
            const Text(
              'Belum ada postingan',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const Gap(8),
            Text(
              user != null
                  ? 'Ikuti teman atau buat postingan pertamamu!'
                  : 'Masuk untuk melihat postingan dari orang yang kamu ikuti.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.4),
            ),
            const Gap(24),
            if (user != null)
              ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CreatePostView()),
                  );
                  if (context.mounted) _refreshPosts();
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Buat Postingan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3366A0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginView()),
                  );
                },
                icon: const Icon(Icons.login, size: 18),
                label: const Text('Masuk'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3366A0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
              ),
            const Gap(12),
            TextButton(
              onPressed: _refreshPosts,
              child: Text('Refresh', style: TextStyle(color: Colors.grey.shade500)),
            ),
          ],
        ),
      ),
    );
  }
}


