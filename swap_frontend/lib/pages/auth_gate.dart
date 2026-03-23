import 'package:flutter/material.dart';
import '../services/b2c_auth_service.dart';
import '../services/profile_service.dart';
import 'home_page.dart';
import 'landing_page.dart';
import 'onboarding.dart';

/// Routes to [HomePage] if a B2C session is active and a profile exists,
/// [ProfileSetupFlow] if signed in but no profile, otherwise [LandingPage].
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Future<Map<String, dynamic>?>? _profileFuture;

  @override
  void initState() {
    super.initState();
    // Show auth error as a dialog after the first frame
    final error = B2CAuthService.instance.lastAuthError;
    if (error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Auth callback debug'),
            content: SingleChildScrollView(
              child: SelectableText(error),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      });
    }

    // If signed in, kick off the profile check
    final user = B2CAuthService.instance.currentUser;
    if (B2CAuthService.instance.isSignedIn && user != null) {
      _profileFuture = ProfileService().getProfile(user.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!B2CAuthService.instance.isSignedIn) {
      return const LandingPage();
    }

    return FutureBuilder<Map<String, dynamic>?>(
      future: _profileFuture,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0F0F11),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
            ),
          );
        }
        // Profile exists → home; no profile or error → onboarding
        if (snap.hasData && snap.data != null) {
          return const HomePage();
        }
        return const ProfileSetupFlow();
      },
    );
  }
}
