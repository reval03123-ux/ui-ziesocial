import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import 'package:ziesocial/model/story_model.dart';
import 'package:ziesocial/viewmodel/login_viewmodel.dart';
import 'package:ziesocial/viewmodel/story_viewmodel.dart';

class StoryPlayerView extends StatefulWidget {
  final List<UserStory> userStories;
  final int initialUserIndex;

  const StoryPlayerView({
    super.key,
    required this.userStories,
    this.initialUserIndex = 0,
  });

  @override
  State<StoryPlayerView> createState() => _StoryPlayerViewState();
}

class _StoryPlayerViewState extends State<StoryPlayerView>
    with SingleTickerProviderStateMixin {
  late int _currentUserIndex;
  late int _currentStoryIndex;
  late AnimationController _animController;
  bool _isPaused = false;

  static const Duration storyDuration = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    final maxIdx = widget.userStories.length - 1;
    _currentUserIndex = maxIdx >= 0 ? widget.initialUserIndex.clamp(0, maxIdx) : 0;
    _currentStoryIndex = 0;

    _animController = AnimationController(vsync: this, duration: storyDuration);
    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _nextStory();
      }
    });

    if (widget.userStories.isNotEmpty &&
        _currentUserStory.stories.isNotEmpty) {
      _animController.forward();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  UserStory get _currentUserStory =>
      widget.userStories.isNotEmpty && _currentUserIndex < widget.userStories.length
          ? widget.userStories[_currentUserIndex]
          : UserStory(
              userId: 0,
              username: '',
              name: '',
              avatar: '',
              isCurrentUser: false,
              stories: [],
            );

  StoryItem get _currentStory =>
      _currentUserStory.stories.isNotEmpty &&
              _currentStoryIndex < _currentUserStory.stories.length
          ? _currentUserStory.stories[_currentStoryIndex]
          : StoryItem(
              id: 0,
              userId: 0,
              image: '',
              caption: '',
              createDate: '',
            );

  void _nextStory() {
    if (_currentStoryIndex < _currentUserStory.stories.length - 1) {
      setState(() {
        _currentStoryIndex++;
      });
      _animController.reset();
      _animController.forward();
    } else if (_currentUserIndex < widget.userStories.length - 1) {
      setState(() {
        _currentUserIndex++;
        _currentStoryIndex = 0;
      });
      _animController.reset();
      _animController.forward();
    } else {
      Navigator.pop(context);
    }
  }

  void _previousStory() {
    if (_currentStoryIndex > 0) {
      setState(() {
        _currentStoryIndex--;
      });
      _animController.reset();
      _animController.forward();
    } else if (_currentUserIndex > 0) {
      setState(() {
        _currentUserIndex--;
        _currentStoryIndex = widget.userStories[_currentUserIndex].stories.length - 1;
      });
      _animController.reset();
      _animController.forward();
    } else {
      _animController.reset();
      _animController.forward();
    }
  }

  void _pauseStory() {
    if (!_isPaused) {
      _animController.stop();
      setState(() => _isPaused = true);
    }
  }

  void _resumeStory() {
    if (_isPaused) {
      _animController.forward();
      setState(() => _isPaused = false);
    }
  }

  Future<void> _confirmDeleteStory() async {
    _pauseStory();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Cerita?'),
        content: const Text(
          'Apakah Anda yakin ingin menghapus foto cerita ini? Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final user = context.read<LoginViewModel>().user;
      final userId = int.tryParse(user?.id ?? '') ?? 0;
      final storyId = _currentStory.id;

      final success = await context.read<StoryViewModel>().deleteStory(
            storyId: storyId,
            userId: userId,
          );

      if (success && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cerita berhasil dihapus.'),
            backgroundColor: Colors.black87,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    _resumeStory();
  }

  String _formatTimeAgo(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr.replaceAll(' ', 'T'));
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Baru saja';
      if (diff.inHours < 1) return '${diff.inMinutes}m lalu';
      if (diff.inDays < 1) return '${diff.inHours}j lalu';
      return '${diff.inDays}h lalu';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final storyUser = _currentUserStory;
    final story = _currentStory;
    final currentUser = context.read<LoginViewModel>().user;
    final isOwnStory = storyUser.isCurrentUser ||
        (currentUser != null && currentUser.id == storyUser.userId.toString());

    final totalStories = storyUser.stories.length;

    return Scaffold(
      backgroundColor: Colors.black,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: SafeArea(
          child: GestureDetector(
            onTapDown: (details) {
              final screenWidth = MediaQuery.of(context).size.width;
              if (details.globalPosition.dx < screenWidth * 0.3) {
                _previousStory();
              } else if (details.globalPosition.dx > screenWidth * 0.7) {
                _nextStory();
              }
            },
            onLongPressStart: (_) => _pauseStory(),
            onLongPressEnd: (_) => _resumeStory(),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Gambar Story
                Center(
                  child: story.imageUrl.isNotEmpty
                      ? Image.network(
                          story.imageUrl,
                          fit: BoxFit.contain,
                          width: double.infinity,
                          height: double.infinity,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) => Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.broken_image_outlined,
                                    size: 48, color: Colors.grey.shade400),
                                const Gap(8),
                                const Text(
                                  'Gagal memuat cerita',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Center(
                          child: Icon(Icons.image_not_supported_outlined,
                              size: 48, color: Colors.grey.shade400),
                        ),
                ),

                // Gradient Atas & Progress Bars + Header
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black87, Colors.transparent],
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Segmented Progress Bar
                        Row(
                          children: List.generate(totalStories, (index) {
                            return Expanded(
                              child: Container(
                                height: 2.5,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    if (index < _currentStoryIndex) {
                                      return Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(2),
                                        ),
                                      );
                                    } else if (index == _currentStoryIndex) {
                                      return AnimatedBuilder(
                                        animation: _animController,
                                        builder: (context, child) {
                                          return FractionallySizedBox(
                                            alignment: Alignment.centerLeft,
                                            widthFactor: _animController.value,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(2),
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    } else {
                                      return const SizedBox.shrink();
                                    }
                                  },
                                ),
                              ),
                            );
                          }),
                        ),
                        const Gap(10),

                        // Header (Avatar, Username, Time Ago, Delete, Close)
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 17,
                              backgroundColor: Colors.grey.shade800,
                              child: storyUser.avatar.isNotEmpty
                                  ? ClipOval(
                                      child: Image.network(
                                        storyUser.avatarUrl,
                                        width: 34,
                                        height: 34,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Text(
                                          storyUser.name.isNotEmpty
                                              ? storyUser.name[0].toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    )
                                  : Text(
                                      storyUser.name.isNotEmpty
                                          ? storyUser.name[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                            const Gap(10),
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      storyUser.username.isNotEmpty
                                          ? storyUser.username
                                          : storyUser.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const Gap(8),
                                  Text(
                                    _formatTimeAgo(story.createDate),
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.7),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isOwnStory)
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.white, size: 22),
                                onPressed: _confirmDeleteStory,
                                tooltip: 'Hapus Cerita',
                              ),
                            IconButton(
                              icon: const Icon(Icons.close,
                                  color: Colors.white, size: 24),
                              onPressed: () => Navigator.pop(context),
                              tooltip: 'Tutup',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Caption Bawah (jika ada)
                if (story.caption.isNotEmpty)
                  Positioned(
                    bottom: 24,
                    left: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        story.caption,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          height: 1.35,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

