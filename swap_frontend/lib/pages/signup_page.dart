// lib/pages/signup_page.dart
import 'package:besmart_2025/pages/landing_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import '../services/auth_service.dart';
import 'login_page.dart';
import 'onboarding.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});
  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  bool _loading = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;

  // Live requirement flags
  bool _hasMin = false;
  bool _hasUpper = false;
  bool _hasLower = false;
  bool _hasNumber = false;
  bool _hasSymbol = false;

  double _strength = 0;

  @override
  void initState() {
    super.initState();
    _password.addListener(_evaluatePassword);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  void _evaluatePassword() {
    final p = _password.text;
    final hasMin = p.length >= 8;
    final hasUpper = RegExp(r'[A-Z]').hasMatch(p);
    final hasLower = RegExp(r'[a-z]').hasMatch(p);
    final hasNumber = RegExp(r'\d').hasMatch(p);
    final hasSymbol = RegExp(
      r'[!@#\$%^&*(),.?":{}|<>_\-~`+=;\\/\[\]]',
    ).hasMatch(p);

    final met = [
      hasMin,
      hasUpper,
      hasLower,
      hasNumber,
      hasSymbol,
    ].where((e) => e).length;
    final strength = met / 5.0;

    setState(() {
      _hasMin = hasMin;
      _hasUpper = hasUpper;
      _hasLower = hasLower;
      _hasNumber = hasNumber;
      _hasSymbol = hasSymbol;
      _strength = strength;
    });
  }

  String _strengthLabel() {
    if (_strength >= .9) return 'Strong';
    if (_strength >= .7) return 'Good';
    if (_strength >= .5) return 'Fair';
    return 'Weak';
  }

  Color _strengthColor() {
    if (_strength >= .9) return const Color(0xFF00E676);
    if (_strength >= .7) return const Color(0xFF64FFDA);
    if (_strength >= .5) return const Color(0xFFFFD54F);
    return const Color(0xFFFF5252); // red
  }

  bool _allRequirementsMet() =>
      _hasMin && _hasUpper && _hasLower && _hasNumber && _hasSymbol;

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await AuthService.instance.signUpWithEmail(
        email: _email.text.trim(),
        password: _password.text.trim(),
      );
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ProfileSetupFlow()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _google() async {
    setState(() => _loading = true);
    try {
      await AuthService.instance.signInWithGoogle();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    const maxContentWidth = 1200.0;

    Widget content;
    if (isWide) {
      // Match the Login layout: form on the LEFT, 3D on the RIGHT
      content = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.only(left: 32, right: 16),
              child: Center(child: _SignUpCard()),
            ),
          ),
          const SizedBox(width: 20),
          Flexible(
            flex: 5,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final side =
                    (constraints.maxWidth.clamp(900.0, maxContentWidth)) * 0.45;
                return Align(
                  alignment: Alignment.center,
                  child: _Rainbow3DPanel(maxSide: side),
                );
              },
            ),
          ),
        ],
      );
    } else {
      content = Center(
        child: Padding(padding: const EdgeInsets.all(24), child: _SignUpCard()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Stack(
          children: [
            // Top-left logo → go Home
            Positioned(
              top: 16,
              left: 16,
              child: _LogoHomeButton(
                size: 72, // tweak size if you want
                onTap: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const LandingPage()),
                  );
                },
              ),
            ),

            // Your existing centered content
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: maxContentWidth),
                child: content,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------- UI Pieces below -------

  Widget _SignUpCard() {
    InputDecoration deco(String label, IconData icon) => InputDecoration(
      prefixIcon: Icon(icon, color: Colors.grey),
      labelText: label,
      labelStyle: const TextStyle(color: Colors.grey),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: const BorderSide(color: Colors.deepPurpleAccent),
      ),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
    );

    Widget social(IconData icon, VoidCallback? onTap) => InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        height: 48,
        width: 48,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );

    Widget divider(String text) => Row(
      children: [
        const Expanded(child: Divider(color: Colors.grey)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(text, style: const TextStyle(color: Colors.grey)),
        ),
        const Expanded(child: Divider(color: Colors.grey)),
      ],
    );

    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(32),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            const Text(
              r"Welcome to $wap",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),

            // Social
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                social(Icons.apple, () {}),
                const SizedBox(width: 16),
                social(Icons.g_mobiledata, _google),
                const SizedBox(width: 16),
                social(Icons.facebook, () {}),
              ],
            ),
            const SizedBox(height: 20),
            divider("OR"),
            const SizedBox(height: 20),

            // Name
            TextFormField(
              controller: _name,
              style: const TextStyle(color: Colors.white),
              decoration: deco("Full Name", Icons.person),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Enter your name' : null,
            ),
            const SizedBox(height: 16),

            // Email
            TextFormField(
              controller: _email,
              style: const TextStyle(color: Colors.white),
              decoration: deco("Email Address", Icons.email),
              validator: (v) => (v == null || !v.contains('@'))
                  ? 'Enter a valid email'
                  : null,
            ),
            const SizedBox(height: 16),

            // Password
            TextFormField(
              controller: _password,
              obscureText: !_showPassword,
              style: const TextStyle(color: Colors.white),
              decoration: deco("Password", Icons.lock).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    _showPassword ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey,
                  ),
                  onPressed: () =>
                      setState(() => _showPassword = !_showPassword),
                ),
              ),
              validator: (_) {
                if (!_allRequirementsMet()) {
                  return 'Password must meet all requirements.';
                }
                return null;
              },
            ),

            const SizedBox(height: 12),
            _requirementsPanel(),
            const SizedBox(height: 16),

            // Confirm
            TextFormField(
              controller: _confirmPassword,
              obscureText: !_showConfirmPassword,
              style: const TextStyle(color: Colors.white),
              decoration: deco("Confirm Password", Icons.lock).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    _showConfirmPassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: Colors.grey,
                  ),
                  onPressed: () => setState(
                    () => _showConfirmPassword = !_showConfirmPassword,
                  ),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Re-enter your password';
                if (v != _password.text) return 'Passwords do not match';
                return null;
              },
            ),

            const SizedBox(height: 24),

            // Create account
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: const LinearGradient(
                  colors: [Color(0xFF7A00FF), Color(0xFF9E00FF)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _loading ? null : _signup,
                child: _loading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        "Create Account",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),

            // Already have account
            Center(
              child: GestureDetector(
                onTap: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                ),
                child: const Text.rich(
                  TextSpan(
                    text: "Already have an account? ",
                    style: TextStyle(color: Colors.white70),
                    children: [
                      TextSpan(
                        text: "Sign in!",
                        style: TextStyle(
                          color: Colors.blueAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              "By continuing, you agree to our Terms of Service & Privacy Policy",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _requirementsPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white.withOpacity(0.08),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: _strength.clamp(0, 1),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _strengthColor(),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _strengthLabel(),
              style: TextStyle(color: _strengthColor(), fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _reqRow(_hasMin, 'At least 8 characters'),
        _reqRow(_hasUpper, 'At least 1 uppercase letter'),
        _reqRow(_hasLower, 'At least 1 lowercase letter'),
        _reqRow(_hasNumber, 'At least 1 number'),
        _reqRow(_hasSymbol, 'At least 1 symbol (!@#\$...)'),
      ],
    );
  }

  Widget _reqRow(bool ok, String text) {
    return Row(
      children: [
        Icon(
          ok ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 16,
          color: ok ? const Color(0xFF00E676) : Colors.grey,
        ),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}

class _Rainbow3DPanel extends StatelessWidget {
  const _Rainbow3DPanel({this.maxSide});
  final double? maxSide;

  @override
  Widget build(BuildContext context) {
    final side = (maxSide ?? 620).clamp(320.0, 800.0);
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: side * 0.8,
          height: side * 0.8,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0x407A00FF),
                blurRadius: 100,
                spreadRadius: 12,
              ),
            ],
          ),
        ),
        SizedBox(
          width: side,
          height: side,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: const _Rainbow3D(),
          ),
        ),
      ],
    );
  }
}

class _Rainbow3D extends StatelessWidget {
  const _Rainbow3D();

  @override
  Widget build(BuildContext context) {
    return const ModelViewer(
      src: 'assets/icon.glb',
      alt: '3D rainbow blob',
      autoRotate: true,
      autoRotateDelay: 0,
      cameraControls: true,
      disableZoom: false,
      ar: false,
      exposure: 1.1,
      shadowIntensity: 0.1,
      shadowSoftness: 0.1,
    );
  }
}

class _LogoHomeButton extends StatelessWidget {
  final VoidCallback onTap;
  final double size;
  const _LogoHomeButton({required this.onTap, this.size = 80});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: size,
        width: size,
        child: Image.asset(
          'assets/Swap-removebg-preview.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
