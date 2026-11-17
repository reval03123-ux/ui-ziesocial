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

// ── Light Theme Design Tokens ────────────────────────────────────
const _bg           = Color(0xFFF8FAFC); // slate-50
const _primary      = Color(0xFF4F46E5); // indigo-600
const _slate900     = Color(0xFF0F172A); // main dark text
const _slate600     = Color(0xFF475569); // icons
const _slate500     = Color(0xFF64748B); // inactive labels
const _slate400     = Color(0xFF94A3B8); // muted icons
const _slate200     = Color(0xFFE2E8F0); // borders
const _slate100     = Color(0xFFF1F5F9); // backgrounds

class MainScreen extends StatefulWidget {
  final int initialIndex;

  const MainScreen({super.key, this.initialIndex = 0});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  late int _currentIndex;
  // 4 animated icons: indices 0, 1, 3, 4 (index 2 is center add button)
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
        .map((c) => Tween<double>(begin: 1.0, end: 1.18).animate(
              CurvedAnimation(parent: c, curve: Curves.easeOut),
            ))
        .toList();

    // Map _currentIndex (0,1,3,4) to controller index (0,1,2,3)
    final ctrlIdx = _tabToCtrlIndex(_currentIndex);
    if (ctrlIdx >= 0) _iconControllers[ctrlIdx].forward();
  }

  @override
  void dispose() {
    for (final c in _iconControllers) {
      c.dispose();
    }
    super.dispose();
  }

  /// Map tab index (0,1,3,4) → controller index (0,1,2,3)
  int _tabToCtrlIndex(int tabIndex) {
    switch (tabIndex) {
      case 0: return 0;
      case 1: return 1;
      case 3: return 2;
      case 4: return 3;
      default: return -1;
    }
  }

  void _onTabTapped(int index) async {
    final user = context.read<LoginViewModel>().user;

    // Center add button
    if (index == 2) {
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

    // Profile tab
    if (index == 4) {
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
      final ctrlIdx = _tabToCtrlIndex(index);
      if (ctrlIdx >= 0) {
        _iconControllers[ctrlIdx]
            .forward()
            .then((_) => _iconControllers[ctrlIdx].reverse());
      }
      return;
    }

    HapticFeedback.selectionClick();

    final oldCtrl = _tabToCtrlIndex(_currentIndex);
    final newCtrl = _tabToCtrlIndex(index);
    if (oldCtrl >= 0) _iconControllers[oldCtrl].reverse();
    if (newCtrl >= 0) _iconControllers[newCtrl].forward();

    setState(() {
      _currentIndex = index;
    });
  }

  void _promptLogin(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: _slate900)),
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
    final currentUserId =
        user != null ? int.tryParse(user.id) ?? 0 : 0;
    final isDesktop = MediaQuery.of(context).size.width > 600;

    // Pages for IndexedStack: 5 slots; slot 2 is placeholder (never shown)
    final pages = [
      const HomeView(),
      const SearchView(),
      const SizedBox.shrink(),
      const _ActivityPlaceholder(),
      ProfileView(
        key: ValueKey('profile_$currentUserId'),
        userId: currentUserId,
        showBackButton: false,
      ),
    ];

    final scaffold = Scaffold(
      backgroundColor: _bg,
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: _buildBottomNavBar(user),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: isDesktop
          ? Row(
              children: [
                _buildDesktopSidebar(user),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 620),
                      child: Scaffold(
                        backgroundColor: _bg,
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

  // ── Desktop Sidebar ──────────────────────────────────────────
  Widget _buildDesktopSidebar(dynamic user) {
    return Container(
      width: 72,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: _slate200, width: 1),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Icon(Icons.diversity_3_rounded,
                  size: 28, color: _primary),
            ),
            const SizedBox(height: 8),
            _buildSidebarItem(0, Icons.home_outlined, Icons.home),
            _buildSidebarItem(1, Icons.explore_outlined, Icons.explore),
            _buildSidebarAddItem(),
            _buildSidebarItem(3, Icons.favorite_border, Icons.favorite),
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
          color: isActive ? _slate100 : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          isActive ? activeIcon : icon,
          size: 26,
          color: isActive ? _primary : _slate600,
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
          color: _primary,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: _primary.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _buildSidebarProfileItem(dynamic user) {
    final isActive = _currentIndex == 4;
    return GestureDetector(
      onTap: () => _onTabTapped(4),
      child: Container(
        width: 56,
        height: 48,
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? _slate100 : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive ? _primary : _slate200,
                width: 2,
              ),
            ),
            child: ClipOval(
              child: user != null && user.name.isNotEmpty
                  ? Container(
                      color: _slate100,
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
                                    color: _primary,
                                  ),
                                ),
                              )
                            : Text(
                                user.name[0].toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _primary,
                                ),
                              ),
                      ),
                    )
                  : const Icon(Icons.person_outline_rounded,
                      size: 16, color: _slate500),
            ),
          ),
        ),
      ),
    );
  }

  // ── Bottom Nav Bar ───────────────────────────────────────────
  Widget _buildBottomNavBar(dynamic user) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        border: const Border(
          top: BorderSide(color: _slate200, width: 1),
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
          height: 62,
          child: Row(
            children: [
              _buildNavItem(0, Icons.home_outlined, Icons.home, 'Feed'),
              _buildNavItem(1, Icons.explore_outlined, Icons.explore, 'Explore'),
              _buildAddButton(),
              _buildNavItem(
                  3, Icons.favorite_border_rounded, Icons.favorite_rounded, 'Activity'),
              _buildProfileNavItem(user),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
      int index, IconData icon, IconData activeIcon, String label) {
    final isActive = _currentIndex == index;
    final ctrlIdx = _tabToCtrlIndex(index);
    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabTapped(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: ctrlIdx >= 0
                  ? _iconScales[ctrlIdx]
                  : const AlwaysStoppedAnimation(1.0),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  isActive ? activeIcon : icon,
                  key: ValueKey('${index}_$isActive'),
                  size: 24,
                  color: isActive ? _primary : _slate500,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isActive ? _primary : _slate500,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabTapped(2),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _primary.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 26),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileNavItem(dynamic user) {
    final isActive = _currentIndex == 4;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabTapped(4),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _iconScales[3],
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isActive ? _primary : _slate200,
                    width: isActive ? 2 : 1.2,
                  ),
                ),
                child: ClipOval(
                  child: user != null && user.name.isNotEmpty
                      ? Container(
                          color: _slate100,
                          child: Center(
                            child: user.avatar.isNotEmpty
                                ? Image.network(
                                    user.avatarUrl,
                                    fit: BoxFit.cover,
                                    width: 26,
                                    height: 26,
                                    errorBuilder: (context, error, stackTrace) => Text(
                                      user.name[0].toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: _primary,
                                      ),
                                    ),
                                  )
                                : Text(
                                    user.name[0].toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: _primary,
                                    ),
                                  ),
                          ),
                        )
                      : const Icon(Icons.person_outline_rounded,
                          size: 16, color: _slate500),
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Profile',
              style: TextStyle(
                fontSize: 10,
                color: isActive ? _primary : _slate500,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Activity placeholder ─────────────────────────────────────────
class _ActivityPlaceholder extends StatelessWidget {
  const _ActivityPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Activity',
          style: TextStyle(
            color: _slate900,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: _slate200),
        ),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border_rounded, size: 56, color: _slate400),
            SizedBox(height: 16),
            Text(
              'Belum Ada Notifikasi',
              style: TextStyle(
                color: _slate900,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Suka, komentar, dan aktivitas linimasa akan muncul di sini.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _slate500, fontSize: 13.5),
            ),
          ],
        ),
      ),
    );
  }
}
