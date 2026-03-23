// lib/widgets/app_sidebar.dart
import 'package:flutter/material.dart';
import '../pages/post_skill_page.dart';
import '../pages/home_page.dart';
import '../pages/landing_page.dart';
import '../pages/profile_page.dart';
import '../pages/request_page.dart';
import '../pages/wallet_page.dart';
import '../pages/messages/conversations_page.dart';
import '../services/b2c_auth_service.dart';
import '../services/messaging_service.dart';

class AppSidebar extends StatefulWidget {
  const AppSidebar({super.key, this.active = 'Home'});

  final String active;

  static const double width = 240;

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar> {
  final _messagingService = MessagingService();
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchUnreadCount();
  }

  Future<void> _fetchUnreadCount() async {
    final uid = B2CAuthService.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    try {
      final count = await _messagingService.getTotalUnreadCount(uid);
      if (mounted) {
        setState(() => _unreadCount = count);
      }
    } catch (e) {
      debugPrint('Error fetching unread count: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isActive(String label) =>
        widget.active.toLowerCase() == label.toLowerCase();

    return Container(
      width: AppSidebar.width,
      decoration: BoxDecoration(
        color: HomePage.sidebar,
        border: Border(right: BorderSide(color: HomePage.line)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                height: 70,
                child: Image.asset(
                  'assets/Swap-removebg-preview.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Divider(color: HomePage.line, height: 1),
          const SizedBox(height: 12),
          _NavItem(
            icon: Icons.home_rounded,
            label: 'Home',
            active: isActive('Home'),
            onTap: () => Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => HomePage()),
              (route) => false,
            ),
          ),
          _NavItem(
            icon: Icons.add_circle_outline,
            label: 'Post Skill',
            active: isActive('Post Skill'),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const PostSkillPage())),
          ),
          _NavItem(
            icon: Icons.inbox_outlined,
            label: 'Requests',
            active: isActive('Requests'),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const RequestsPage())),
          ),
          _NavItem(
            icon: Icons.chat_bubble_outline,
            label: 'Messages',
            badge: _unreadCount > 0 ? '$_unreadCount' : null,
            active: isActive('Messages'),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ConversationsPage())),
          ),
          _NavItem(
            icon: Icons.analytics_outlined,
            label: 'Dashboard',
            active: isActive('Dashboard'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const WalletPage()),
            ),
          ),
          _NavItem(
            icon: Icons.person_outline,
            label: 'Profile',
            active: isActive('Profile'),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ProfilePage())),
          ),
          const Spacer(),
          _NavItem(
            icon: Icons.logout_rounded,
            label: 'Log Out',
            onTap: () async {
              await B2CAuthService.instance.signOut();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LandingPage()),
                (route) => false,
              );
            },
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0x151A1333),
                border: Border.all(color: HomePage.line),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Share Your Skills',
                      style: TextStyle(
                        color: HomePage.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Start earning by helping others learn',
                      style: TextStyle(color: HomePage.textMuted, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: FilledButton(
                      onPressed: () {
                        final currentRoute = ModalRoute.of(
                          context,
                        )?.settings.name;
                        if (currentRoute != 'post_skill') {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const PostSkillPage(),
                              settings: const RouteSettings(name: 'post_skill'),
                            ),
                          );
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: HomePage.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Post a Skill'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    this.active = false,
    this.badge,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final String? badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: active ? const Color(0x201A1333) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: active ? HomePage.accentAlt : HomePage.textMuted,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : HomePage.textMuted,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        trailing: badge == null
            ? null
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF164E63),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: HomePage.line),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    height: 1,
                  ),
                ),
              ),
        onTap: onTap,
      ),
    );
  }
}
