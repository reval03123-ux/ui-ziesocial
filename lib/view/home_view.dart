import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import 'package:ziesocial/view/create_post_view.dart';
import 'package:ziesocial/view/login_view.dart';
import 'package:ziesocial/viewmodel/login_viewmodel.dart';
import 'package:ziesocial/viewmodel/post_viewmodel.dart';
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
    await context.read<PostViewModel>().fetchPosts(currentUserId: userId);
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

  Widget _buildStoriesBar(dynamic user) {
    final stories = _generateDummyStories(user);
    return SizedBox(
      height: 115,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: stories.length,
        itemBuilder: (context, index) {
          final story = stories[index];
          final isOwnStory = index == 0 && user != null;

          return GestureDetector(
            onTap: () {
              if (isOwnStory) {
                // Navigate to create post
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Gradient ring
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: isOwnStory || !story['hasStory']
                              ? null
                              : const LinearGradient(
                                  colors: [
                                    Color(0xFF833AB4),
                                    Color(0xFFFD1D1D),
                                    Color(0xFFFCB045),
                                  ],
                                  begin: Alignment.topRight,
                                  end: Alignment.bottomLeft,
                                ),
                          color: isOwnStory || !story['hasStory']
                              ? Colors.grey.shade300
                              : null,
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
                            child: story['avatar'] != null && story['avatar'].toString().isNotEmpty
                                ? ClipOval(
                                    child: Image.network(
                                      story['avatar'].toString(),
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          _storyInitial(story['name']),
                                    ),
                                  )
                                : _storyInitial(story['name']),
                          ),
                        ),
                      ),
                      if (isOwnStory)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: const BoxDecoration(
                              color: Color(0xFF3366A0),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.add, color: Colors.white, size: 14),
                          ),
                        ),
                    ],
                  ),
                  const Gap(4),
                  SizedBox(
                    width: 68,
                    child: Text(
                      isOwnStory ? 'Story Kamu' : story['name'].toString(),
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

  List<Map<String, dynamic>> _generateDummyStories(dynamic user) {
    final stories = <Map<String, dynamic>>[];
    if (user != null) {
      stories.add({
        'name': user.name,
        'avatar': user.avatarUrl,
        'hasStory': false,
        'isOwn': true,
      });
    }
    return stories;
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


