// lib/pages/home_page.dart
import 'package:flutter/material.dart';
import 'landing_page.dart';
import '../services/auth_service.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  // ---- Theme (same palette family you’ve been using)
  static const Color bg = Color(0xFF0A0A0B);
  static const Color sidebar = Color(0xFF0F1115);
  static const Color surface = Color(0xFF12141B);
  static const Color card = Color(0xFF111318);
  static const Color textPrimary = Color(0xFFEAEAF2);
  static const Color textMuted = Color(0xFFB6BDD0);
  static const Color line = Color(0xFF1F2937);
  static const Color accent = Color(0xFF7C3AED); // purple
  static const Color accentAlt = Color(0xFF9F67FF);
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.dark,
        surface: surface,
        background: bg,
        primary: accent,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: textPrimary,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderSide: BorderSide(color: line),
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: line),
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: accent),
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
        hintStyle: TextStyle(color: textMuted),
        labelStyle: TextStyle(color: textMuted),
      ),
      chipTheme: ChipThemeData(
        side: const BorderSide(color: line),
        backgroundColor: surface,
        selectedColor: const Color(0xFF1A1333),
        checkmarkColor: accentAlt,
        labelStyle: const TextStyle(color: textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      dividerColor: line,
      cardTheme: CardThemeData(
        color: card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: line),
        ),
        margin: const EdgeInsets.all(0), // optional, matches tight layout
      ),
    );

    return Theme(
      data: theme,
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: Padding(
            padding: const EdgeInsets.only(left: 16, right: 8),
            child: Row(
              children: [
                // Mini logo circle
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0x1510B981),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: line),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Swap',
                    style: TextStyle(fontSize: 11, color: textMuted, height: 1),
                  ),
                ),
                const SizedBox(width: 12),
                // Search in app bar (like screenshot)
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search, color: textMuted),
                      hintText: 'Search skills...',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  tooltip: 'Notifications',
                  icon: const Icon(Icons.notifications_none_rounded),
                  onPressed: () {},
                ),
                IconButton(
                  tooltip: 'Sign out',
                  icon: const Icon(Icons.logout),
                  onPressed: () async {
                    await AuthService.instance.signOut();
                    if (!context.mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LandingPage()),
                      (route) => false,
                    );
                  },
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Sidebar(),
            Expanded(child: _DiscoverPane()),
          ],
        ),
      ),
    );
  }
}

/* =============================== SIDEBAR =============================== */

class _Sidebar extends StatelessWidget {
  const _Sidebar();

  static const double _w = 240;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _w,
      decoration: const BoxDecoration(
        color: HomePage.sidebar,
        border: Border(right: BorderSide(color: HomePage.line)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          _NavItem(icon: Icons.home_rounded, label: 'Home', active: true),
          _NavItem(icon: Icons.explore_outlined, label: 'Discover'),
          _NavItem(icon: Icons.add_circle_outline, label: 'Post Skill'),
          _NavItem(icon: Icons.inbox_outlined, label: 'Requests', badge: '2'),
          _NavItem(icon: Icons.analytics_outlined, label: 'Dashboard'),
          _NavItem(icon: Icons.person_outline, label: 'Profile'),
          const Spacer(),
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
                      onPressed: () {},
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
  });

  final IconData icon;
  final String label;
  final bool active;
  final String? badge;

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
        onTap: () {},
      ),
    );
  }
}

/* ============================= DISCOVER PANE ============================= */

class _DiscoverPane extends StatelessWidget {
  _DiscoverPane();

  final List<_Skill> skills = [
    _Skill(
      title: 'Piano Fundamentals',
      category: 'music',
      description:
          'Learn piano basics with proper technique from day one. We\'ll cover finger positioning, scales, and simple songs.',
      durationHours: 4,
      mode: 'Both',
      rating: 4.4,
      tags: ['piano', 'music theory', 'sheet music', 'beginner'],
      verified: true,
    ),
    _Skill(
      title: 'Technical Writing for Developers',
      category: 'writing',
      description:
          'Turn technical knowledge into clear, engaging documentation. I\'ll show you how to explain APIs and systems.',
      durationHours: 3,
      mode: 'Remote',
      rating: 4.7,
      tags: ['technical writing', 'documentation', 'api', 'clarity'],
      verified: true,
    ),
    _Skill(
      title: 'React Hooks Masterclass',
      category: 'coding',
      description:
          'Master modern React development with hooks! useState, useEffect, useMemo, and custom hooks with patterns.',
      durationHours: 4,
      mode: 'Remote',
      rating: 4.9,
      tags: ['react', 'javascript', 'hooks', 'frontend'],
      verified: false,
    ),
    _Skill(
      title: 'Spanish Conversation for Beginners',
      category: 'language',
      description:
          'Practice essential phrases and build confidence in real conversation scenarios.',
      durationHours: 2,
      mode: 'Both',
      rating: 4.6,
      tags: ['spanish', 'conversation', 'travel'],
      verified: true,
      isNew: true,
    ),
    _Skill(
      title: 'Logo Design in Figma',
      category: 'design',
      description:
          'Learn to create professional logos in Figma with a simple, repeatable process.',
      durationHours: 3,
      mode: 'Remote',
      rating: 4.8,
      tags: ['figma', 'logo', 'branding', 'vector'],
      verified: true,
      isNew: true,
    ),
  ];

  final List<String> categories = const [
    'All Skills',
    'Design',
    'Coding',
    'Writing',
    'Language',
    'Tutoring',
    'Music',
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
              ).copyWith(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),
                  const Text(
                    'Discover Skills',
                    style: TextStyle(
                      color: HomePage.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 28,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Find amazing skills to learn from our community',
                    style: TextStyle(color: HomePage.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 18),

                  // Search + Filters row (secondary)
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            prefixIcon: Icon(
                              Icons.search,
                              color: HomePage.textMuted,
                            ),
                            hintText: 'Search skills...',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(
                          Icons.tune_rounded,
                          color: HomePage.textMuted,
                        ),
                        label: const Text('Filters'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: HomePage.line),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          backgroundColor: HomePage.surface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Category chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (int i = 0; i < categories.length; i++) ...[
                          _CategoryChip(label: categories[i], selected: i == 0),
                          const SizedBox(width: 10),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // Grid of skill cards
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
            ).copyWith(bottom: 24),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                final maxW = constraints.crossAxisExtent;
                // nice responsive column count
                final crossAxisCount = maxW >= 1200 ? 3 : (maxW >= 780 ? 2 : 1);

                return SliverGrid.builder(
                  itemCount: skills.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 18,
                    crossAxisSpacing: 18,
                    mainAxisExtent: 220,
                  ),
                  itemBuilder: (context, i) => _SkillCard(skill: skills[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/* ============================== WIDGET PIECES ============================= */

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, this.selected = false});
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF1A1333) : HomePage.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: HomePage.line),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? HomePage.accentAlt : HomePage.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SkillCard extends StatelessWidget {
  const _SkillCard({required this.skill});
  final _Skill skill;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // top badges row
            Row(
              children: [
                _Pill(skill.category),
                const SizedBox(width: 8),
                if (skill.verified)
                  const _Pill(
                    'Verified',
                    icon: Icons.verified,
                    color: HomePage.success,
                  ),
                if (skill.isNew) ...[
                  const SizedBox(width: 6),
                  const _Pill('New', color: HomePage.warning),
                ],
                const Spacer(),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.favorite_border, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 18,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              skill.title,
              style: const TextStyle(
                color: HomePage.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Text(
                skill.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: HomePage.textMuted, fontSize: 13),
              ),
            ),
            const SizedBox(height: 10),

            // meta + actions
            Row(
              children: [
                const Icon(
                  Icons.access_time,
                  size: 16,
                  color: HomePage.textMuted,
                ),
                const SizedBox(width: 6),
                Text(
                  '${skill.durationHours}h',
                  style: const TextStyle(color: HomePage.textMuted),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.public, size: 16, color: HomePage.textMuted),
                const SizedBox(width: 6),
                Text(
                  skill.mode,
                  style: const TextStyle(color: HomePage.textMuted),
                ),
                const Spacer(),
                const Icon(Icons.star_rounded, size: 18, color: Colors.amber),
                const SizedBox(width: 4),
                Text(
                  '${skill.rating}',
                  style: const TextStyle(
                    color: HomePage.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // tags + button
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in skill.tags.take(3))
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: HomePage.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: HomePage.line),
                    ),
                    child: Text(
                      t,
                      style: const TextStyle(
                        color: HomePage.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                const Spacer(),
                SizedBox(
                  height: 40,
                  child: FilledButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.mail_outline, size: 18),
                    label: const Text('Request'),
                    style: FilledButton.styleFrom(
                      backgroundColor: HomePage.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, {this.icon, this.color});
  final String text;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFF6B7280); // gray badge by default
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(.15),
        border: Border.all(color: HomePage.line),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: c),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: TextStyle(
              color: c,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/* ================================ MODELS ================================= */

class _Skill {
  final String title;
  final String category; // small label (music/writing/coding/etc)
  final String description;
  final int durationHours;
  final String mode; // Remote / In-person / Both
  final double rating;
  final List<String> tags;
  final bool verified;
  final bool isNew;

  _Skill({
    required this.title,
    required this.category,
    required this.description,
    required this.durationHours,
    required this.mode,
    required this.rating,
    required this.tags,
    this.verified = false,
    this.isNew = false,
  });
}
