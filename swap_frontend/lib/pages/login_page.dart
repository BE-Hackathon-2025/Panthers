import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import '../services/b2c_auth_service.dart';
import 'signup_page.dart';
import 'home_page.dart';
import 'landing_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _loading = false;

  Future<void> _login() async {
    setState(() => _loading = true);
    try {
      await B2CAuthService.instance.signIn();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      // Show a prominent dialog so the error is clearly visible
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Sign-in debug'),
          content: SelectableText('$e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
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
                              loading: _loading,
                              onLogin: _login,
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
                        loading: _loading,
                        onLogin: _login,
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
    required this.loading,
    required this.onLogin,
  });

  final bool loading;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    const gradient = LinearGradient(
      colors: [Color(0xFF6C63FF), Color(0xFF7A00FF)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            r"Welcome back to $wap",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Sign in to continue",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 32),

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
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SignUpPage()),
              ),
              child: const Text.rich(
                TextSpan(
                  text: "Don't have an account? ",
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
      src: 'assets/assets/icon.glb',
      alt: '3D rainbow blob',
      autoRotate: true,
      autoRotateDelay: 0,
      cameraControls: true,
      disableZoom: false,
      ar: false,
      exposure: 1.1,
    );
  }
}

class SLogoButton extends StatelessWidget {
  final VoidCallback onTap;
  final double size;
  const SLogoButton({super.key, required this.onTap, this.size = 80});

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
