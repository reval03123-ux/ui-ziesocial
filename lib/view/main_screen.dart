import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:ziesocial/view/create_post_view.dart';
import 'package:ziesocial/view/home_view.dart';
import 'package:ziesocial/view/login_view.dart';
import 'package:ziesocial/view/profile_view.dart';
import 'package:ziesocial/view/search_view.dart';
import 'package:ziesocial/viewmodel/login_viewmodel.dart';
import 'package:ziesocial/viewmodel/post_viewmodel.dart';
import 'package:ziesocial/viewmodel/profile_viewmodel.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;

  const MainScreen({super.key, this.initialIndex = 0});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  late int _currentIndex;
  late List<AnimationController> _iconControllers;
  late List<Animation<double>> _iconScales;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;

    _iconControllers = List.generate(
      4,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 200),
      ),
    );

    _iconScales = _iconControllers
        .map((c) => Tween<double>(begin: 1.0, end: 1.25).animate(
              CurvedAnimation(parent: c, curve: Curves.easeOut),
            ))
        .toList();

    // Animate initial icon
    _iconControllers[_currentIndex].forward();
  }

  @override
  void dispose() {
    for (final c in _iconControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _onTabTapped(int index) async {
    final user = context.read<LoginViewModel>().user;

    if (index == 2) {
      // Create Post
      if (user == null) {
        _promptLogin('Silakan login untuk membuat postingan.');
        return;
      }
      HapticFeedback.lightImpact();
      final created = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (context) => const CreatePostView()),
      );
      if (mounted && (created == true)) {
        context.read<PostViewModel>().fetchPosts(
              currentUserId: int.tryParse(user.id),
            );
      }
      return;
    }

    if (index == 3) {
      if (user == null) {
        _promptLogin('Silakan login untuk melihat profil Anda.');
        return;
      }
      final currentUserId = int.tryParse(user.id) ?? 0;
      if (currentUserId > 0) {
        context.read<ProfileViewModel>().fetchProfile(
              currentUserId,
              currentUserId: currentUserId,
            );
      }
    }

    if (index == _currentIndex) {
      // Same tab — bounce animation
      _iconControllers[index].forward().then((_) => _iconControllers[index].reverse());
      return;
    }

    HapticFeedback.selectionClick();

    // Reverse old icon
    _iconControllers[_currentIndex].reverse();
    // Forward new icon
    _iconControllers[index].forward();

    setState(() {
      _currentIndex = index;
    });
  }

  void _promptLogin(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.grey.shade900,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
          label: 'Masuk',
          textColor: Colors.blueAccent,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const LoginView()),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<LoginViewModel>().user;
    final currentUserId = user != null ? int.tryParse(user.id) ?? 0 : 0;
    final isDesktop = MediaQuery.of(context).size.width > 600;

    // ValueKey on ProfileView ensures it rebuilds when userId changes (e.g. after switching accounts)
    final pages = [
      const HomeView(),
      const SearchView(),
      const SizedBox.shrink(),
      ProfileView(
        key: ValueKey('profile_$currentUserId'),
        userId: currentUserId,
        showBackButton: false,
      ),
    ];

    final scaffold = Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: _buildBottomNavBar(user),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: isDesktop
          ? Row(
              children: [
                // Left sidebar for desktop (Instagram-like)
                _buildDesktopSidebar(user),
                // Main content area with max width
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 620),
                      child: Scaffold(
                        body: IndexedStack(
                          index: _currentIndex,
                          children: pages,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : scaffold,
    );
  }

  Widget _buildDesktopSidebar(dynamic user) {
    return Container(
      width: 72,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Colors.grey.shade200, width: 0.5),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Logo
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  colors: [Color(0xFF3366A0), Color(0xFF5B8FD4)],
                ).createShader(b),
                child: const Icon(Icons.photo_library_rounded,
                    size: 28, color: Colors.white),
              ),
            ),
            const SizedBox(height: 8),
            _buildSidebarItem(0, Icons.home_outlined, Icons.home),
            _buildSidebarItem(1, Icons.search, Icons.search),
            _buildSidebarAddItem(),
            _buildSidebarProfileItem(user),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarItem(int index, IconData icon, IconData activeIcon) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => _onTabTapped(index),
      child: Container(
        width: 56,
        height: 48,
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFE8EFF8) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          isActive ? activeIcon : icon,
          size: 26,
          color: isActive ? const Color(0xFF3366A0) : Colors.black54,
        ),
      ),
    );
  }

  Widget _buildSidebarAddItem() {
    return GestureDetector(
      onTap: () => _onTabTapped(2),
      child: Container(
        width: 44,
        height: 44,
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF3366A0), Color(0xFF5B8FD4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _buildSidebarProfileItem(dynamic user) {
    return GestureDetector(
      onTap: () => _onTabTapped(3),
      child: Container(
        width: 56,
        height: 48,
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: _currentIndex == 3 ? const Color(0xFFE8EFF8) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _currentIndex == 3 ? const Color(0xFF3366A0) : Colors.grey.shade300,
                width: 2,
              ),
            ),
            child: ClipOval(
              child: user != null && user.name.isNotEmpty
                  ? Container(
                      color: const Color(0xFFE8EFF8),
                      child: Center(
                        child: user.avatar.isNotEmpty
                            ? Image.network(
                                user.avatarUrl,
                                fit: BoxFit.cover,
                                width: 28,
                                height: 28,
                                errorBuilder: (context, error, stackTrace) => Text(
                                  user.name[0].toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF3366A0),
                                  ),
                                ),
                              )
                            : Text(
                                user.name[0].toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF3366A0),
                                ),
                              ),
                      ),
                    )
                  : Container(
                      color: Colors.grey.shade100,
                      child: const Icon(Icons.person_outline,
                          size: 16, color: Colors.grey),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavBar(dynamic user) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200, width: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, _homeIcon, _homeActiveIcon),
              _buildNavItem(1, _searchIcon, _searchActiveIcon),
              _buildAddButton(),
              _buildProfileNavItem(user),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, Widget icon, Widget activeIcon) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => _onTabTapped(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Center(
          child: ScaleTransition(
            scale: _iconScales[index],
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: isActive
                  ? KeyedSubtree(key: ValueKey('active_$index'), child: activeIcon)
                  : KeyedSubtree(key: ValueKey('inactive_$index'), child: icon),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return GestureDetector(
      onTap: () => _onTabTapped(2),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Center(
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3366A0), Color(0xFF5B8FD4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 24),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileNavItem(dynamic user) {
    return GestureDetector(
      onTap: () => _onTabTapped(3),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Center(
          child: ScaleTransition(
            scale: _iconScales[3],
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: _currentIndex == 3
                    ? Border.all(color: Colors.black87, width: 2)
                    : Border.all(color: Colors.grey.shade300, width: 1.5),
              ),
              child: ClipOval(
                child: user != null && user.name.isNotEmpty
                    ? Container(
                        color: const Color(0xFFE8EFF8),
                        child: Center(
                          child: user.avatar.isNotEmpty
                              ? Image.network(
                                  user.avatarUrl,
                                  fit: BoxFit.cover,
                                  width: 30,
                                  height: 30,
                                  errorBuilder: (context, error, stackTrace) => Text(
                                    user.name[0].toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF3366A0),
                                    ),
                                  ),
                                )
                              : Text(
                                  user.name[0].toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF3366A0),
                                  ),
                                ),
                        ),
                      )
                    : Container(
                        color: Colors.grey.shade100,
                        child: const Icon(Icons.person_outline,
                            size: 18, color: Colors.grey),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Icons
  static const _homeIcon =
      Icon(Icons.home_outlined, size: 28, color: Colors.black54);
  static const _homeActiveIcon =
      Icon(Icons.home, size: 28, color: Colors.black87);
  static const _searchIcon =
      Icon(Icons.search, size: 28, color: Colors.black54);
  static const _searchActiveIcon =
      Icon(Icons.search, size: 28, color: Colors.black87);
}
