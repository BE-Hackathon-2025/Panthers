import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import '../services/auth_service.dart';
import 'signup_page.dart';
import 'forgot_password_page.dart';
import 'home_page.dart';
import 'landing_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await AuthService.instance.signInWithEmail(
        email: _email.text.trim(),
        password: _password.text.trim(),
      );
      if (mounted) {
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
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
      if (mounted) {
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
      }
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

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Stack(
          children: [
            // Main content
            LayoutBuilder(
              builder: (context, constraints) {
                const maxContentWidth = 1200.0;

                Widget content;
                if (isWide) {
                  content = Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(
                        flex: 5,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 32, right: 16),
                          child: Center(
                            child: _AuthCard(
                              formKey: _formKey,
                              email: _email,
                              password: _password,
                              loading: _loading,
                              onLogin: _login,
                              onGoogle: _google,
                              showPassword: _showPassword,
                              toggleShowPassword: () => setState(
                                () => _showPassword = !_showPassword,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Flexible(
                        flex: 5,
                        child: Align(
                          alignment: Alignment.center,
                          child: _Rainbow3DPanel(
                            maxSide:
                                (constraints.maxWidth.clamp(
                                  900.0,
                                  maxContentWidth,
                                )) *
                                0.45,
                          ),
                        ),
                      ),
                    ],
                  );
                } else {
                  content = Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: _AuthCard(
                        formKey: _formKey,
                        email: _email,
                        password: _password,
                        loading: _loading,
                        onLogin: _login,
                        onGoogle: _google,
                        showPassword: _showPassword,
                        toggleShowPassword: () =>
                            setState(() => _showPassword = !_showPassword),
                      ),
                    ),
                  );
                }

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: maxContentWidth,
                    ),
                    child: content,
                  ),
                );
              },
            ),

            // Page-level "S" (top-left)
            Positioned(
              top: 16,
              left: 16,
              child: SLogoButton(
                onTap: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const LandingPage()),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthCard extends StatelessWidget {
  const _AuthCard({
    required this.formKey,
    required this.email,
    required this.password,
    required this.loading,
    required this.onLogin,
    required this.onGoogle,
    required this.showPassword,
    required this.toggleShowPassword,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController email;
  final TextEditingController password;
  final bool loading;
  final VoidCallback onLogin;
  final VoidCallback onGoogle;
  final bool showPassword;
  final VoidCallback toggleShowPassword;

  @override
  Widget build(BuildContext context) {
    final gradient = const LinearGradient(
      colors: [Color(0xFF6C63FF), Color(0xFF7A00FF)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );

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
        borderSide: const BorderSide(color: Colors.blueAccent),
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
      child: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Sign in",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),

            // Social buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                social(Icons.apple, () {}),
                const SizedBox(width: 16),
                social(Icons.g_mobiledata, onGoogle),
                const SizedBox(width: 16),
                social(Icons.facebook, () {}),
              ],
            ),
            const SizedBox(height: 20),

            divider("OR"),
            const SizedBox(height: 20),

            TextFormField(
              controller: email,
              style: const TextStyle(color: Colors.white),
              decoration: deco("Email Address", Icons.email),
              validator: (v) => (v == null || !v.contains('@'))
                  ? 'Enter a valid email'
                  : null,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: password,
              obscureText: !showPassword,
              style: const TextStyle(color: Colors.white),
              decoration: deco("Password", Icons.lock).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    showPassword ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey,
                  ),
                  onPressed: toggleShowPassword,
                ),
              ),
              validator: (v) =>
                  (v == null || v.length < 6) ? 'Min 6 characters' : null,
            ),
            const SizedBox(height: 12),

            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ForgotPasswordPage(),
                    ),
                  );
                },
                child: const Text(
                  "Forgot password?",
                  style: TextStyle(color: Colors.blueAccent),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: gradient,
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
                onPressed: loading ? null : onLogin,
                child: loading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        "Sign in",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),

            Center(
              child: GestureDetector(
                onTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const SignUpPage())),
                child: const Text.rich(
                  TextSpan(
                    text: "Don’t have an account? ",
                    style: TextStyle(color: Colors.white70),
                    children: [
                      TextSpan(
                        text: "Sign up!",
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
    );
  }
}

class _Rainbow3DPanel extends StatelessWidget {
  const _Rainbow3DPanel({this.maxSide});

  final double? maxSide;

  @override
  Widget build(BuildContext context) {
    final double side = ((maxSide ?? 480).clamp(320.0, 600.0)).toDouble();

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
    return ModelViewer(
      src: 'assets/Hamburger.glb',
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

class SLogoButton extends StatelessWidget {
  final VoidCallback onTap;
  final double size;
  const SLogoButton({super.key, required this.onTap, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(size),
      child: Container(
        height: size,
        width: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(size),
          border: Border.all(color: Colors.white24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Text(
          'S',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}
