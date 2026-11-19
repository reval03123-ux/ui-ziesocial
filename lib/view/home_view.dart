import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import 'package:ziesocial/model/story_model.dart';
import 'package:ziesocial/view/chat_list_view.dart';
import 'package:ziesocial/view/create_story_view.dart';
import 'package:ziesocial/view/login_view.dart';
import 'package:ziesocial/view/notification_view.dart';
import 'package:ziesocial/view/profile_view.dart';
import 'package:ziesocial/view/story_player_view.dart';
import 'package:ziesocial/viewmodel/chat_viewmodel.dart';
import 'package:ziesocial/viewmodel/login_viewmodel.dart';
import 'package:ziesocial/viewmodel/notification_viewmodel.dart';
import 'package:ziesocial/viewmodel/post_viewmodel.dart';
import 'package:ziesocial/viewmodel/story_viewmodel.dart';
import 'package:ziesocial/widget/post_card.dart';

// ── Light Theme Tokens ───────────────────────────────────────────
const _primary      = Color(0xFF4F46E5); // indigo-600
const _primaryLight = Color(0xFF818CF8); // indigo-400
const _emerald      = Color(0xFF34D399); // emerald-400
const _slate900     = Color(0xFF0F172A); // main dark text
const _slate800     = Color(0xFF1E293B); // labels
const _slate600     = Color(0xFF475569); // icons
const _slate500     = Color(0xFF64748B); // subtitles
const _slate200     = Color(0xFFE2E8F0); // borders
const _slate100     = Color(0xFFF1F5F9); // card bg / avatar bg
const _red          = Color(0xFFEF4444); // badge

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
      duration: const Duration(milliseconds: 700),
    );
    _logoAnim =
        CurvedAnimation(parent: _logoAnimController, curve: Curves.easeOutBack);
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
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
              color: _primary,
              backgroundColor: Colors.white,
              onRefresh: _refreshPosts,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // Stories Tray
                  SliverToBoxAdapter(
                    child: _buildStoriesBar(user),
                  ),

                  // Feed list
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return PostCard(post: postVm.posts[index]);
                      },
                      childCount: postVm.posts.length,
                    ),
                  ),

                  // Delightful End-of-Feed State
                  SliverToBoxAdapter(
                    child: _buildEndOfFeed(),
                  ),

                  const SliverToBoxAdapter(child: Gap(90)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(dynamic user) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(60),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          border: const Border(
            bottom: BorderSide(color: _slate200, width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 60,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // App Title
                  ScaleTransition(
                    scale: _logoAnim,
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                        children: [
                          TextSpan(
                            text: 'Zie',
                            style: TextStyle(color: _slate900),
                          ),
                          TextSpan(
                            text: 'Social',
                            style: TextStyle(color: _primary),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),

                  // Actions
                  if (user != null) ...[
                    // Notifications
                    Consumer<NotificationViewModel>(
                      builder: (ctx, notifVm, _) {
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            IconButton(
                              onPressed: () {
                                Navigator.push(
                                  ctx,
                                  MaterialPageRoute(
                                    builder: (_) => const NotificationView(),
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.notifications_none_rounded,
                                color: _slate600,
                                size: 24,
                              ),
                              tooltip: 'Notifikasi',
                              padding: EdgeInsets.zero,
                              constraints:
                                  const BoxConstraints(minWidth: 40, minHeight: 40),
                            ),
                            if (notifVm.unreadCount > 0)
                              Positioned(
                                right: 6,
                                top: 6,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: _red,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 10,
                                    minHeight: 10,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const Gap(4),

                    // Direct Messages
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
                                  ctx
                                      .read<ChatViewModel>()
                                      .fetchConversations(uid);
                                }
                              },
                              icon: const Icon(
                                Icons.chat_bubble_outline_rounded,
                                color: _slate600,
                                size: 22,
                              ),
                              tooltip: 'Pesan',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 40, minHeight: 40),
                            ),
                            if (chatVm.totalUnreadCount > 0)
                              Positioned(
                                right: 4,
                                top: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4.5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: _red,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: Colors.white, width: 1.5),
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  child: Center(
                                    child: Text(
                                      chatVm.totalUnreadCount > 99
                                          ? '99+'
                                          : '${chatVm.totalUnreadCount}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
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
                    const Gap(4),

                    // Profile Avatar Icon
                    GestureDetector(
                      onTap: () {
                        final uid = int.tryParse(user.id.toString()) ?? 0;
                        if (uid > 0) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProfileView(userId: uid),
                            ),
                          );
                        }
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: _slate200, width: 1.2),
                        ),
                        child: ClipOval(
                          child: (user.avatarUrl != null &&
                                  user.avatarUrl.toString().trim().isNotEmpty)
                              ? Image.network(
                                  user.avatarUrl.toString(),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      _initial(user.name),
                                )
                              : _initial(user.name ?? 'U'),
                        ),
                      ),
                    ),
                  ] else ...[
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const LoginView()),
                        );
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                      ),
                      child: const Text('Masuk',
                          style: TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _initial(dynamic name) {
    final n = name?.toString() ?? '';
    return Container(
      color: _slate100,
      alignment: Alignment.center,
      child: Text(
        n.isNotEmpty ? n[0].toUpperCase() : '?',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: _primary,
        ),
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
        content: const Text(
          'Silakan masuk untuk membagikan cerita.',
          style: TextStyle(color: _slate900),
        ),
        backgroundColor: Colors.white,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: _slate200),
        ),
        action: SnackBarAction(
          label: 'Masuk',
          textColor: _primary,
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

    final myUserId =
        user != null ? int.tryParse(user.id.toString()) ?? 0 : 0;
    UserStory? myStory;
    if (myUserId > 0) {
      myStory = storyVm.getMyStory(myUserId);
    }

    final otherUserStories = allUserStories
        .where((s) => s.userId != myUserId && s.stories.isNotEmpty)
        .toList();

    final hasMyStory = myStory != null && myStory.stories.isNotEmpty;
    final totalCount = 1 + otherUserStories.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 0),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFEEEEEE), width: 0.8),
        ),
      ),
      child: SizedBox(
        height: 98,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: totalCount,
          itemBuilder: (context, index) {
            if (index == 0) {
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
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: hasMyStory
                                  ? const LinearGradient(
                                      colors: [_primary, _primaryLight, _emerald],
                                      begin: Alignment.bottomLeft,
                                      end: Alignment.topRight,
                                    )
                                  : null,
                              border: hasMyStory
                                  ? null
                                  : Border.all(color: _slate200, width: 2),
                            ),
                            padding: hasMyStory
                                ? const EdgeInsets.all(2.5)
                                : EdgeInsets.zero,
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(1.5),
                              child: CircleAvatar(
                                radius: 28,
                                backgroundColor: _slate100,
                                child: (user != null &&
                                        user.avatarUrl != null &&
                                        user.avatarUrl
                                            .toString()
                                            .trim()
                                            .isNotEmpty)
                                    ? ClipOval(
                                        child: Image.network(
                                          user.avatarUrl.toString(),
                                          width: 56,
                                          height: 56,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) =>
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
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: _primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.15),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.add,
                                  color: Colors.white,
                                  size: 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Gap(6),
                      const SizedBox(
                        width: 66,
                        child: Text(
                          'Cerita Anda',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _slate800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [_primary, _primaryLight, _emerald],
                          begin: Alignment.bottomLeft,
                          end: Alignment.topRight,
                        ),
                      ),
                      padding: const EdgeInsets.all(2.5),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(1.5),
                        child: CircleAvatar(
                          radius: 28,
                          backgroundColor: _slate100,
                          child: storyUser.avatar.isNotEmpty &&
                                  storyUser.avatarUrl.isNotEmpty
                              ? ClipOval(
                                  child: Image.network(
                                    storyUser.avatarUrl,
                                    width: 56,
                                    height: 56,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        _storyInitial(storyUser.name),
                                  ),
                                )
                              : _storyInitial(storyUser.name),
                        ),
                      ),
                    ),
                    const Gap(6),
                    SizedBox(
                      width: 66,
                      child: Text(
                        storyUser.username.isNotEmpty
                            ? storyUser.username
                            : storyUser.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: _slate600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _storyInitial(dynamic name) {
    final n = name?.toString() ?? '';
    return Text(
      n.isNotEmpty ? n[0].toUpperCase() : '?',
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 18,
        color: _primary,
      ),
    );
  }

  Widget _buildEndOfFeed() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              size: 26,
              color: Color(0xFF10B981),
            ),
          ),
          const Gap(12),
          const Text(
            'Anda Sudah Melihat Semua',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _slate900,
            ),
          ),
          const Gap(4),
          const Text(
            'Jelajahi karya kreator lain di tab Explore untuk inspirasi baru hari ini.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: _slate500,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: _primary,
            strokeWidth: 2.2,
          ),
          Gap(16),
          Text(
            'Memuat postingan...',
            style: TextStyle(color: _slate500, fontSize: 13),
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
                color: const Color(0xFFFEE2E2),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                size: 38,
                color: _red,
              ),
            ),
            const Gap(16),
            const Text(
              'Gagal Memuat Postingan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _slate900,
              ),
            ),
            const Gap(8),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: _slate500),
            ),
            const Gap(24),
            ElevatedButton.icon(
              onPressed: _refreshPosts,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
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
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFC7D2FE)),
              ),
              child: const Icon(
                Icons.photo_library_outlined,
                size: 44,
                color: _primary,
              ),
            ),
            const Gap(20),
            const Text(
              'Belum Ada Postingan',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _slate900,
              ),
            ),
            const Gap(8),
            Text(
              user != null
                  ? 'Bagikan momen pertamamu atau ikuti teman untuk melihat karya mereka!'
                  : 'Masuk untuk melihat postingan terbaru dari kreator favoritmu.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: _slate500,
                height: 1.4,
              ),
            ),
            const Gap(24),
            ElevatedButton(
              onPressed: _refreshPosts,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
              ),
              child: const Text('Muat Ulang'),
            ),
          ],
        ),
      ),
    );
  }
}
