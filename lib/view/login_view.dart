import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import 'package:ziesocial/view/main_screen.dart';
import 'package:ziesocial/view/register_view.dart';
import 'package:ziesocial/viewmodel/login_viewmodel.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> with TickerProviderStateMixin {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = true;

  // ── Light Theme Design Tokens (Tailwind Slate & Indigo) ───────────────────
  static const Color _bg           = Color(0xFFF8FAFC); // slate-50 / page bg
  static const Color _cardBg       = Colors.white;      // card container
  static const Color _inputBg      = Color(0xFFF8FAFC); // slate-50
  static const Color _primary      = Color(0xFF4F46E5); // indigo-600
  static const Color _slate900     = Color(0xFF0F172A); // main text
  static const Color _slate800     = Color(0xFF1E293B); // label text
  static const Color _slate600     = Color(0xFF475569); // body text
  static const Color _slate500     = Color(0xFF64748B); // muted text
  static const Color _slate400     = Color(0xFF94A3B8); // placeholder / icons
  static const Color _slate300     = Color(0xFFCBD5E1); // unchecked border
  static const Color _slate200     = Color(0xFFE2E8F0); // container borders

  late AnimationController _fadeCtrl;
  late AnimationController _slideCtrl;
  late Animation<double>  _fadeAnim;
  late Animation<Offset>  _slideAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _fadeAnim  = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _fadeCtrl.forward();
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final identifier = _identifierController.text.trim();
    final password   = _passwordController.text;
    if (identifier.isEmpty || password.isEmpty) {
      _showSnackBar('Email dan kata sandi wajib diisi!', isError: true);
      return;
    }
    HapticFeedback.lightImpact();
    final success = await context.read<LoginViewModel>().login(
          email: identifier,
          password: password,
        );
    if (!mounted) return;
    if (success) {
      HapticFeedback.mediumImpact();
      Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          pageBuilder: (context, anim, secondaryAnim) => const MainScreen(),
          transitionsBuilder: (context, anim, secondaryAnim, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
        (route) => false,
      );
    } else {
      final err = context.read<LoginViewModel>().errorMessage;
      _showSnackBar(err ?? 'Login gagal. Periksa email dan password.', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            color: isError ? const Color(0xFF991B1B) : _slate900,
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: isError ? const Color(0xFFFEE2E2) : Colors.white,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isError ? const Color(0xFFF87171) : _slate200,
            width: 1,
          ),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<LoginViewModel>().isLoading;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: _bg,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      children: [
                        const Gap(12),

                        // ── Brand Section with Ambient Glow ─────────────────
                        _buildBrand(),

                        const Gap(24),

                        // ── Login Card ───────────────────────────────────────
                        _buildLoginCard(isLoading),

                        const Gap(24),

                        // ── Register Link ───────────────────────────────────
                        _buildRegisterRow(),

                        const Gap(16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Brand Section ──────────────────────────────────────────────────────────
  Widget _buildBrand() {
    return Column(
      children: [
        // App Name
        RichText(
          text: const TextSpan(
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: _slate900,
            ),
            children: [
              TextSpan(text: 'Zie'),
              TextSpan(
                text: 'Social',
                style: TextStyle(color: _primary),
              ),
            ],
          ),
        ),
        const Gap(6),

        // Slogan
        const Text(
          'CONNECT. CREATE. INSPIRE.',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.2,
            color: _slate500,
          ),
        ),
      ],
    );
  }

  // ─── Login Card ─────────────────────────────────────────────────────────────
  Widget _buildLoginCard(bool isLoading) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _slate200.withValues(alpha: 0.9), width: 1),
        boxShadow: [
          BoxShadow(
            color: _slate400.withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          const Text(
            'Selamat Datang Kembali',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: _slate900,
            ),
          ),
          const Gap(20),

          // ── Email / Username Field ─────────────────────────────────────────
          _fieldLabel(
            title: 'Email atau Username',
            badge: 'Wajib',
          ),
          const Gap(8),
          _buildTextField(
            controller: _identifierController,
            hint: 'nama@email.com',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          const Gap(18),

          // ── Password Field ────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Kata Sandi',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _slate800,
                ),
              ),
              GestureDetector(
                onTap: () {
                  _showSnackBar('Silakan hubungi administrator untuk mereset kata sandi.');
                },
                child: const Text(
                  'Lupa kata sandi?',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _primary,
                  ),
                ),
              ),
            ],
          ),
          const Gap(8),
          _buildPasswordField(),
          const Gap(16),

          // ── Remember Me Checkbox ───────────────────────────────────────────
          GestureDetector(
            onTap: () => setState(() => _rememberMe = !_rememberMe),
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                _buildCheckbox(),
                const Gap(10),
                const Text(
                  'Ingat saya di perangkat ini',
                  style: TextStyle(
                    fontSize: 13,
                    color: _slate600,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const Gap(22),

          // ── Main Submit Button ─────────────────────────────────────────────
          _buildSubmitButton(isLoading),
        ],
      ),
    );
  }

  // ─── Sub-widgets & Fields ───────────────────────────────────────────────────

  Widget _fieldLabel({required String title, String? badge}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _slate800,
          ),
        ),
        if (badge != null)
          Text(
            badge,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: _slate400,
            ),
          ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.done,
    VoidCallback? onSubmit,
    bool obscure = false,
    Widget? suffix,
  }) {
    return SizedBox(
      height: 48,
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        onSubmitted: onSubmit != null ? (_) => onSubmit() : null,
        style: const TextStyle(
          fontSize: 14,
          color: _slate900,
          fontWeight: FontWeight.w400,
        ),
        cursorColor: _primary,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: _slate400, fontSize: 14),
          prefixIcon: Icon(icon, color: _slate400, size: 20),
          suffixIcon: suffix,
          filled: true,
          fillColor: _inputBg,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _slate200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _slate200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _primary, width: 1.8),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return _buildTextField(
      controller: _passwordController,
      hint: '••••••••',
      icon: Icons.lock_outline_rounded,
      obscure: _obscurePassword,
      textInputAction: TextInputAction.done,
      onSubmit: _login,
      suffix: IconButton(
        icon: Icon(
          _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          color: _slate400,
          size: 20,
        ),
        splashRadius: 20,
        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
      ),
    );
  }

  Widget _buildCheckbox() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: _rememberMe ? _primary : _inputBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: _rememberMe ? _primary : _slate300,
          width: 1.5,
        ),
        boxShadow: [
          if (!_rememberMe)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
        ],
      ),
      child: _rememberMe
          ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
          : null,
    );
  }

  Widget _buildSubmitButton(bool isLoading) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: isLoading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          disabledBackgroundColor: _primary.withValues(alpha: 0.6),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: const StadiumBorder(),
          shadowColor: _primary.withValues(alpha: 0.35),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: isLoading
              ? const SizedBox(
                  key: ValueKey('loading'),
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.2,
                  ),
                )
              : const Row(
                  key: ValueKey('idle'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Masuk',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                        color: Colors.white,
                      ),
                    ),
                    Gap(8),
                    Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
                  ],
                ),
        ),
      ),
    );
  }

  // ─── Register Row ────────────────────────────────────────────────────────────
  Widget _buildRegisterRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Belum punya akun? ',
          style: TextStyle(
            fontSize: 14,
            color: _slate600,
            fontWeight: FontWeight.w400,
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RegisterView()),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Daftar sekarang',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _primary,
                ),
              ),
              Gap(2),
              Icon(Icons.chevron_right_rounded, size: 16, color: _primary),
            ],
          ),
        ),
      ],
    );
  }
}
