import 'package:flutter/material.dart';
import 'landing_page.dart';
import 'profile_page.dart';
import '../services/search_service.dart';
import '../services/skill_service.dart';
import '../services/b2c_auth_service.dart';
import '../services/swap_request_service.dart';
import '../widgets/app_sidebar.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  // ---- Theme (same palette family you've been using)
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
  List<SkillSearchResult> _searchResults = [];
  String _currentQuery = '';

  @override
  void initState() {
    super.initState();
    _loadInitialResults();
  }

  String? get _myUid => B2CAuthService.instance.currentUser?.uid;

  List<SkillSearchResult> _excludeSelf(List<SkillSearchResult> results) {
    final uid = _myUid;
    if (uid == null) return results;
    return results.where((r) => r.postedBy != uid).toList();
  }

  Future<void> _loadInitialResults() async {
    setState(() => _loadingSearch = true);
    try {
      final res = await _searchService.searchSkills(
        'skills',
        limit: 12,
        timeout: const Duration(seconds: 10),
      );
      if (mounted) {
        setState(() {
          _searchResults = _excludeSelf(res);
          _currentQuery = '';
        });
      }
    } catch (e) {
      debugPrint('Initial load error: $e');
    } finally {
      if (mounted) setState(() => _loadingSearch = false);
    }
  }

  Future<void> _handleSearch(String query, {String? category}) async {
    final q = query.trim();
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
      final res = await _searchService.searchSkills(
        q,
        category: category,
        limit: 10,
        timeout: const Duration(seconds: 10),
      );
      if (mounted)
        setState(() {
          _searchResults = _excludeSelf(res);
          _currentQuery = q;
        });
    } catch (e) {
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
    final bg = HomePage.bg;
    final surface = HomePage.surface;
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
        margin: const EdgeInsets.all(0),
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
                  _TopBar(onSearch: (q) => _handleSearch(q)),
                  if (_loadingSearch)
                    const LinearProgressIndicator(minHeight: 3),
                  Expanded(
                    child: _DiscoverPane(
                      searchResults: _searchResults,
                      onSearch: (q) => _handleSearch(q),
                      onCategorySearch: (cat) => _handleSearch(cat, category: cat),
                      currentQuery: _currentQuery,
                      onClearSearch: () {
                        _loadInitialResults();
                      },
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

/* ============================= DISCOVER PANE ============================= */

class _DiscoverPane extends StatefulWidget {
  _DiscoverPane({
    Key? key,
    this.searchResults,
    this.onSearch,
    this.onCategorySearch,
    this.currentQuery,
    this.onClearSearch,
  }) : super(key: key);

  final List<SkillSearchResult>? searchResults;
  final ValueChanged<String>? onSearch;
  final ValueChanged<String>? onCategorySearch;
  final String? currentQuery;
  final VoidCallback? onClearSearch;

  @override
  State<_DiscoverPane> createState() => _DiscoverPaneState();
}

class _DiscoverPaneState extends State<_DiscoverPane> {
  String _selectedCategory = 'All Skills';

  final List<String> categories = const [
    'All Skills',
    'Design',
    'Coding',
    'Writing',
    'Language',
    'Tutoring',
    'Music',
  ];

  void _onCategoryTap(String category) {
    setState(() => _selectedCategory = category);
    if (category == 'All Skills') {
      widget.onClearSearch?.call();
    } else {
      widget.onCategorySearch?.call(category);
    }
  }

  void _showRequestDialog(BuildContext context, SkillSearchResult skill) {
    showDialog(
      context: context,
      builder: (ctx) => _SkillRequestDialog(skill: skill),
    );
  }

  @override
  Widget build(BuildContext context) {
    final searchResults = widget.searchResults;
    final hasResults = searchResults != null && searchResults.isNotEmpty;
    final hasQuery = widget.currentQuery?.isNotEmpty == true;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    hasQuery
                        ? 'Search results for "${widget.currentQuery}"'
                        : 'Find Services to Swap',
                    style: const TextStyle(
                      color: HomePage.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (hasQuery)
                  TextButton.icon(
                    onPressed: () {
                      setState(() => _selectedCategory = 'All Skills');
                      widget.onClearSearch?.call();
                    },
                    icon: const Icon(
                      Icons.close,
                      size: 18,
                      color: Colors.white,
                    ),
                    label: const Text('Clear'),
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                  ),
              ],
            ),
            if (!hasQuery)
              const Text(
                'Find amazing services and skills to learn and swap from our community',
                style: TextStyle(color: HomePage.textMuted, fontSize: 13),
              ),
            const SizedBox(height: 14),

            // Category chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (int i = 0; i < categories.length; i++) ...[
                    _CategoryChip(
                      label: categories[i],
                      selected: _selectedCategory == categories[i],
                      onTap: () => _onCategoryTap(categories[i]),
                    ),
                    const SizedBox(width: 10),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Results grid
            Expanded(
              child: hasResults
                  ? LayoutBuilder(
                      builder: (context, constraints) {
                        final maxW = constraints.maxWidth;
                        final crossAxisCount = maxW >= 1200
                            ? 3
                            : (maxW >= 780 ? 2 : 1);
                        return GridView.builder(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 18,
                            mainAxisSpacing: 18,
                            mainAxisExtent: 310,
                          ),
                          itemCount: searchResults!.length,
                          itemBuilder: (context, i) {
                            final r = searchResults[i];
                            return _SkillCard(
                              result: r,
                              onRequest: () =>
                                  _showRequestDialog(context, r),
                            );
                          },
                        );
                      },
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.search_off,
                            size: 64,
                            color: HomePage.textMuted,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            hasQuery
                                ? 'No results found for "${widget.currentQuery}"'
                                : 'No skills posted yet',
                            style: const TextStyle(
                              color: HomePage.textMuted,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            hasQuery
                                ? 'Try a different search term'
                                : 'Be the first to share your skills!',
                            style: const TextStyle(
                              color: HomePage.textMuted,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ============================== WIDGET PIECES ============================= */

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    this.selected = false,
    this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF1A1333) : HomePage.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? HomePage.accent : HomePage.line,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? HomePage.accentAlt : HomePage.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Skill-centric card widget for search results.
class _SkillCard extends StatelessWidget {
  const _SkillCard({
    required this.result,
    this.onRequest,
  });
  final SkillSearchResult result;
  final VoidCallback? onRequest;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomePage.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProfilePage(uid: result.postedBy),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: HomePage.line),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top: Title + badges
              Row(
                children: [
                  Expanded(
                    child: Text(
                      result.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: HomePage.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _badge(result.category, HomePage.accent),
                ],
              ),
              const SizedBox(height: 4),
              // Difficulty + delivery + hours
              Row(
                children: [
                  _pill(result.difficulty, const Color(0xFFF59E0B)),
                  const SizedBox(width: 8),
                  _pill(result.delivery, HomePage.textMuted),
                  const SizedBox(width: 8),
                  _pill(
                    '${result.estimatedHours.toStringAsFixed(result.estimatedHours == result.estimatedHours.roundToDouble() ? 0 : 1)}h',
                    HomePage.textMuted,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Description
              Expanded(
                child: Text(
                  result.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: HomePage.textMuted,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Tags row
              if (result.tags.isNotEmpty)
                SizedBox(
                  height: 28,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: result.tags.length > 4 ? 4 : result.tags.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (_, i) {
                      if (i == 3 && result.tags.length > 4) {
                        return _tagChip('+${result.tags.length - 3}', highlight: true);
                      }
                      return _tagChip(result.tags[i]);
                    },
                  ),
                ),
              const SizedBox(height: 10),
              // Bottom: poster info + credits + request button
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Posted by ${result.posterName.isNotEmpty ? result.posterName : 'User'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: HomePage.textMuted,
                            fontSize: 12,
                          ),
                        ),
                        if (result.posterCity.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.location_on_outlined,
                                  size: 12, color: HomePage.textMuted),
                              const SizedBox(width: 2),
                              Text(
                                result.posterCity,
                                style: const TextStyle(
                                  color: HomePage.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                              if (result.posterSwapCredits > 0) ...[
                                const SizedBox(width: 8),
                                Icon(Icons.verified_outlined,
                                    size: 12, color: HomePage.success),
                                const SizedBox(width: 2),
                                Text(
                                  '${result.posterSwapCredits}',
                                  style: TextStyle(
                                    color: HomePage.success,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 34,
                    child: FilledButton.icon(
                      onPressed: onRequest,
                      icon: const Icon(Icons.swap_horiz, size: 16),
                      label: const Text('Request', style: TextStyle(fontSize: 13)),
                      style: FilledButton.styleFrom(
                        backgroundColor: HomePage.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  static Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: HomePage.surfaceAlt,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: HomePage.line),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 11),
      ),
    );
  }

  static Widget _tagChip(String text, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: highlight ? const Color(0xFF1A1333) : HomePage.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: highlight
              ? HomePage.accent.withValues(alpha: 0.4)
              : HomePage.line,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: highlight ? HomePage.accentAlt : HomePage.textPrimary,
          fontSize: 12,
          fontWeight: highlight ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }
}

/// Swap request dialog with skill selectors.
class _SkillRequestDialog extends StatefulWidget {
  const _SkillRequestDialog({required this.skill});
  final SkillSearchResult skill;

  @override
  State<_SkillRequestDialog> createState() => _SkillRequestDialogState();
}

class _SkillRequestDialogState extends State<_SkillRequestDialog> {
  final _msgCtrl = TextEditingController();
  bool _sending = false;
  bool _loadingSkills = true;

  List<Skill> _recipientSkills = [];
  List<Skill> _mySkills = [];

  Skill? _selectedNeed; // what I need from them
  Skill? _selectedOffer; // what I'm offering

  @override
  void initState() {
    super.initState();
    _loadSkills();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSkills() async {
    final myUid = B2CAuthService.instance.currentUser?.uid;
    if (myUid == null) {
      setState(() => _loadingSkills = false);
      return;
    }

    try {
      final skillService = SkillService();
      final futures = await Future.wait([
        skillService.getSkillsByUser(widget.skill.postedBy),
        skillService.getSkillsByUser(myUid),
      ]);
      if (mounted) {
        setState(() {
          _recipientSkills = futures[0];
          _mySkills = futures[1];
          _loadingSkills = false;

          // Pre-select the clicked skill as "what I need"
          final match = _recipientSkills.where(
            (s) => s.id == widget.skill.skillId || s.id == widget.skill.id,
          );
          if (match.isNotEmpty) {
            _selectedNeed = match.first;
          } else if (_recipientSkills.isNotEmpty) {
            _selectedNeed = _recipientSkills.first;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading skills for dialog: $e');
      if (mounted) setState(() => _loadingSkills = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipientName = widget.skill.posterName.isNotEmpty
        ? widget.skill.posterName
        : 'User';

    return AlertDialog(
      backgroundColor: HomePage.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: HomePage.line),
      ),
      title: Text(
        'Send Swap Request to $recipientName',
        style: const TextStyle(
          color: HomePage.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: SizedBox(
        width: 440,
        child: _loadingSkills
            ? const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // What I need from them
                  const Text(
                    'What you need from them',
                    style: TextStyle(
                      color: HomePage.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _recipientSkills.isNotEmpty
                      ? DropdownButtonFormField<Skill>(
                          value: _selectedNeed,
                          dropdownColor: HomePage.surface,
                          style: const TextStyle(color: HomePage.textPrimary),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: HomePage.line),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          ),
                          items: _recipientSkills
                              .map((s) => DropdownMenuItem<Skill>(
                                    value: s,
                                    child: Text(
                                      '${s.title} (${s.category})',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _selectedNeed = v),
                        )
                      : const Text(
                          'No skills posted by this user',
                          style: TextStyle(color: HomePage.textMuted),
                        ),
                  const SizedBox(height: 16),
                  // What I'm offering
                  const Text(
                    'What you\'re offering',
                    style: TextStyle(
                      color: HomePage.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _mySkills.isNotEmpty
                      ? DropdownButtonFormField<Skill>(
                          value: _selectedOffer,
                          dropdownColor: HomePage.surface,
                          style: const TextStyle(color: HomePage.textPrimary),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: HomePage.line),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          ),
                          items: _mySkills
                              .map((s) => DropdownMenuItem<Skill>(
                                    value: s,
                                    child: Text(
                                      '${s.title} (${s.category})',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _selectedOffer = v),
                        )
                      : const Text(
                          'You haven\'t posted any skills yet. Post a skill first!',
                          style: TextStyle(color: HomePage.textMuted),
                        ),
                  const SizedBox(height: 16),
                  // Message
                  TextField(
                    controller: _msgCtrl,
                    style: const TextStyle(color: HomePage.textPrimary),
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Message (optional)',
                      hintText: 'Add a personal note...',
                    ),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(color: HomePage.textMuted),
          ),
        ),
        FilledButton(
          onPressed: _sending || _selectedNeed == null || _selectedOffer == null
              ? null
              : _sendRequest,
          style: FilledButton.styleFrom(
            backgroundColor: HomePage.accent,
            foregroundColor: Colors.white,
          ),
          child: _sending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Send Request'),
        ),
      ],
    );
  }

  Future<void> _sendRequest() async {
    final currentUser = B2CAuthService.instance.currentUser;
    if (currentUser == null || _selectedNeed == null || _selectedOffer == null) {
      return;
    }

    setState(() => _sending = true);
    try {
      await SwapRequestService().createRequest(
        requesterUid: currentUser.uid,
        recipientUid: widget.skill.postedBy,
        requesterOffer: _selectedOffer!.title,
        requesterNeed: _selectedNeed!.title,
        message: _msgCtrl.text.trim().isNotEmpty ? _msgCtrl.text.trim() : null,
        requesterOfferSkillId: _selectedOffer!.id,
        requesterNeedSkillId: _selectedNeed!.id,
      );
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Swap request sent!'),
            backgroundColor: HomePage.success,
          ),
        );
      }
    } catch (e) {
      debugPrint('Request error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send request: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
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
              await B2CAuthService.instance.signOut();
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
