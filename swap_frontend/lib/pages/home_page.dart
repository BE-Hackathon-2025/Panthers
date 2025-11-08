import 'package:flutter/material.dart';
import 'landing_page.dart';
import 'dart:async'; // for TimeoutException
import '../services/search_service.dart';
// import 'post_skill_page.dart'; // no longer used directly here
import '../services/auth_service.dart';
import '../widgets/app_sidebar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Removed debug-only imports (seed/upsert/test helpers)

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  // ---- Theme (same palette family you’ve been using)
  static const Color bg = Color(0xFF0A0A0B);
  static const Color sidebar = Color(0xFF0F1115);
  static const Color surface = Color(0xFF12141B);
  static const Color surfaceAlt = Color(0xFF12141B);
  static const Color card = Color(0xFF111318);
  static const Color textPrimary = Color(0xFFEAEAF2);
  static const Color textMuted = Color(0xFFB6BDD0);
  static const Color line = Color(0xFF1F2937);
  static const Color accent = Color(0xFF7C3AED); // purple
  static const Color accentAlt = Color(0xFF9F67FF);
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _searchService = SearchService();
  bool _loadingSearch = false;
  List<SearchResult> _searchResults = [];
  String _currentQuery = '';

  Future<void> _handleSearch(String query) async {
    final q = query.trim();
    // if empty, clear results and return to default display
    if (q.isEmpty) {
      if (mounted)
        setState(() {
          _searchResults = [];
          _currentQuery = '';
        });
      return;
    }
    setState(() {
      _loadingSearch = true;
      _searchResults = [];
    });
    try {
      // Attempt search with reasonable timeout
      final res = await _searchService.search(
        q,
        mode: 'offers',
        limit: 10,
        timeout: const Duration(seconds: 10),
      );
      if (mounted)
        setState(() {
          _searchResults = res;
          _currentQuery = q;
        });
    } catch (e) {
      // Silently handle errors - just log them
      debugPrint('Search error for "$q": $e');
      if (mounted) {
        setState(() {
          _searchResults = [];
          _currentQuery = q;
        });
      }
    } finally {
      if (mounted) setState(() => _loadingSearch = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Local aliases for theme tokens (defined on the widget class)
    final bg = HomePage.bg;
    final surface = HomePage.surface;
    // Removed unused variable surfaceAlt; use HomePage.surfaceAlt directly where needed.
    final card = HomePage.card;
    final textPrimary = HomePage.textPrimary;
    final textMuted = HomePage.textMuted;
    final line = HomePage.line;
    final accent = HomePage.accent;
    final accentAlt = HomePage.accentAlt;

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
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: textPrimary,
      ),
      inputDecorationTheme: InputDecorationTheme(
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
        side: BorderSide(color: line),
        backgroundColor: surface,
        selectedColor: const Color(0xFF1A1333),
        checkmarkColor: accentAlt,
        labelStyle: TextStyle(color: textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      dividerColor: line,
      cardTheme: CardThemeData(
        color: card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: line),
        ),
        margin: const EdgeInsets.all(0), // optional, matches tight layout
      ),
    );

    return Theme(
      data: theme,
      child: Scaffold(
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppSidebar(active: 'Home'),
            Expanded(
              child: Column(
                children: [
                  _TopBar(onSearch: _handleSearch),
                  if (_loadingSearch)
                    const LinearProgressIndicator(minHeight: 3),
                  Expanded(
                    child: _DiscoverPane(
                      searchResults: _searchResults,
                      onSearch: _handleSearch,
                      currentQuery: _currentQuery,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* =============================== (Removed Sidebar) =============================== */
// Sidebar widget removed; navigation handled by AppSidebar in its own file.

// Removed _NavItem (unused after Sidebar removal)

/* ============================= DISCOVER PANE ============================= */

class _DiscoverPane extends StatefulWidget {
  _DiscoverPane({
    Key? key,
    this.searchResults,
    this.onSearch,
    this.currentQuery,
  }) : super(key: key);

  final List<SearchResult>? searchResults;
  final ValueChanged<String>? onSearch;
  final String? currentQuery;

  @override
  State<_DiscoverPane> createState() => _DiscoverPaneState();
}

class _DiscoverPaneState extends State<_DiscoverPane> {
  late final TextEditingController _searchCtrl;
  List<_Skill> skills = [];
  bool _loadingSkills = true;

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
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    _loadSkillsFromFirestore();
  }

  Future<void> _loadSkillsFromFirestore() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('skills')
          .get();

      final loadedSkills = snapshot.docs.map((doc) {
        final data = doc.data();
        return _Skill(
          title: data['title'] ?? '',
          category: data['category'] ?? 'other',
          description: data['description'] ?? '',
          durationHours: data['estimatedHours'] ?? 1,
          mode: data['deliveryFormat'] ?? 'Remote',
          rating: (data['rating'] ?? 4.5).toDouble(),
          tags: List<String>.from(data['tags'] ?? []),
          verified: data['verified'] ?? false,
          isNew: data['isNew'] ?? false,
        );
      }).toList();

      if (mounted) {
        setState(() {
          skills = loadedSkills;
          _loadingSkills = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading skills: $e');
      if (mounted) {
        setState(() => _loadingSkills = false);
      }
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchResults = widget.searchResults;

    // If a search was performed, show backend results instead of the
    // default curated skill grid.
    if (searchResults != null && searchResults.isNotEmpty) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Search results' +
                          (widget.currentQuery?.isNotEmpty == true
                              ? ' for "${widget.currentQuery}"'
                              : ''),
                      style: TextStyle(
                        color: HomePage.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      _searchCtrl.clear();
                      widget.onSearch?.call('');
                    },
                    icon: const Icon(
                      Icons.close,
                      size: 18,
                      color: Colors.white,
                    ),
                    label: const Text('Close'),
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final maxW = constraints.maxWidth;
                    final crossAxisCount = maxW >= 1200
                        ? 3
                        : (maxW >= 780 ? 2 : 1);
                    return GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 18,
                        mainAxisSpacing: 18,
                        mainAxisExtent: 240,
                      ),
                      itemCount: searchResults.length,
                      itemBuilder: (context, i) {
                        final r = searchResults[i];
                        return Card(
                          color: HomePage.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(color: HomePage.line),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: HomePage.surfaceAlt,
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        border: Border.all(
                                          color: HomePage.line,
                                        ),
                                      ),
                                      child: Text(
                                        'profile',
                                        style: TextStyle(
                                          color: HomePage.textMuted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  r.displayName.isNotEmpty
                                      ? r.displayName
                                      : r.email,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: HomePage.textPrimary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Expanded(
                                  child: Text(
                                    r.bio,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: HomePage.textMuted),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        r.skillsToOffer,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: HomePage.textMuted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.star,
                                          color: Colors.amber,
                                          size: 18,
                                        ),
                                        Text(
                                          r.score.toStringAsFixed(2),
                                          style: TextStyle(
                                            color: HomePage.textPrimary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    }

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
                    'Find Services to Swap',
                    style: TextStyle(
                      color: HomePage.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 28,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Find amazing services and skills to learn and swap from our community',
                    style: TextStyle(color: HomePage.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 18),

                  // Search + Filters row (secondary)
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          onSubmitted: (v) => widget.onSearch?.call(v),
                          onChanged: (v) {
                            setState(() {});
                            if (v.trim().isEmpty) widget.onSearch?.call('');
                          },
                          decoration: InputDecoration(
                            prefixIcon: Icon(
                              Icons.search,
                              color: HomePage.textMuted,
                            ),
                            hintText: 'Search skills...',
                            suffixIcon: _searchCtrl.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      widget.onSearch?.call('');
                                    },
                                  )
                                : null,
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
            sliver: _loadingSkills
                ? const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  )
                : skills.isEmpty
                ? const SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: HomePage.textMuted,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No skills posted yet',
                            style: TextStyle(
                              color: HomePage.textMuted,
                              fontSize: 18,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Be the first to share your skills!',
                            style: TextStyle(
                              color: HomePage.textMuted,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : SliverLayoutBuilder(
                    builder: (context, constraints) {
                      final maxW = constraints.crossAxisExtent;
                      // nice responsive column count
                      final crossAxisCount = maxW >= 1200
                          ? 3
                          : (maxW >= 780 ? 2 : 1);

                      return SliverGrid.builder(
                        itemCount: skills.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: 18,
                          crossAxisSpacing: 18,
                          // increase card height slightly to avoid occasional overflow
                          mainAxisExtent: 260,
                        ),
                        itemBuilder: (context, i) =>
                            _SkillCard(skill: skills[i]),
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

            // tags + button: use a Row so the button can align to the right reliably.
            Row(
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final t in skill.tags.take(3))
                          Container(
                            margin: const EdgeInsets.only(right: 8),
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
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
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

class _TopBar extends StatelessWidget implements PreferredSizeWidget {
  const _TopBar({this.onSearch});

  final ValueChanged<String>? onSearch;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: preferredSize.height,
      color: HomePage.bg,
      padding: const EdgeInsets.fromLTRB(24, 10, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 44,
              child: TextField(
                onSubmitted: (v) => onSearch?.call(v),
                decoration: InputDecoration(
                  hintText: 'Search skills...',
                  prefixIcon: const Icon(
                    Icons.search,
                    color: HomePage.textMuted,
                  ),
                  filled: true,
                  fillColor: HomePage.surface,
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: BorderSide(color: HomePage.line),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: BorderSide(color: HomePage.line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: BorderSide(color: HomePage.accent),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                tooltip: 'Notifications',
                icon: const Icon(Icons.notifications_none_rounded),
                onPressed: () {},
              ),
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF22C55E),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
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
        ],
      ),
    );
  }
}
