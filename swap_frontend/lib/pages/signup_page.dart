// lib/pages/signup_page.dart
import 'package:besmart_2025/pages/landing_page.dart';
import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import '../services/b2c_auth_service.dart';
import 'login_page.dart';
import 'home_page.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});
  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  bool _loading = false;

  Future<void> _signup() async {
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
            r"Welcome to $wap",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Create your account to get started",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 32),

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
      src: 'assets/assets/icon.glb',
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
