import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_page.dart';
import '../widgets/app_sidebar.dart';

// Color palette used throughout the page
const Color backgroundColor = Color(0xFF0F0F11);
const Color cardColor = Color(0xFF1A1A1D);
const Color accentPurple = Color(0xFF8B5CF6);
const Color textColor = Colors.white;

class PostSkillPage extends StatefulWidget {
  const PostSkillPage({super.key});

  @override
  State<PostSkillPage> createState() => _PostSkillPageState();
}

class _PostSkillPageState extends State<PostSkillPage> {
  final _formKey = GlobalKey<FormState>();
  bool _showPreview = false;

  // Controllers / state
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _hoursController = TextEditingController(
    text: '1',
  );
  final TextEditingController _tagController = TextEditingController();
  final TextEditingController _deliverableController = TextEditingController();

  String? _category;
  String? _difficulty;
  String _delivery = 'Remote Only';
  final List<String> _tags = [];
  final List<String> _deliverables = [];

  final List<String> _categories = [
    'Design',
    'Development',
    'Business',
    'Music',
    'Other',
  ];
  final List<String> _levels = ['Beginner', 'Intermediate', 'Advanced'];
  final List<String> _deliveryOptions = ['Remote Only', 'In-Person', 'Hybrid'];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _hoursController.dispose();
    _tagController.dispose();
    _deliverableController.dispose();
    super.dispose();
  }

  bool get _canPublish =>
      _titleController.text.trim().isNotEmpty &&
      _descriptionController.text.trim().isNotEmpty &&
      _category != null &&
      _difficulty != null;

  void _addTag() {
    final v = _tagController.text.trim();
    if (v.isNotEmpty) {
      setState(() {
        _tags.add(v);
        _tagController.clear();
      });
    }
  }

  void _addDeliverable() {
    final v = _deliverableController.text.trim();
    if (v.isNotEmpty) {
      setState(() {
        _deliverables.add(v);
        _deliverableController.clear();
      });
    }
  }

  void _publish() async {
    if (!_canPublish) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete the required fields.')),
      );
      return;
    }

    // Get current user
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to post a skill')),
      );
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Create skill document
      final skillData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': _category!.toLowerCase(),
        'difficulty': _difficulty!,
        'estimatedHours': int.tryParse(_hoursController.text) ?? 1,
        'deliveryFormat': _delivery,
        'tags': List<String>.from(_tags),
        'deliverables': List<String>.from(_deliverables),
        'creatorUid': user.uid,
        'creatorEmail': user.email ?? '',
        'creatorName': user.displayName ?? user.email ?? 'Anonymous',
        'createdAt': FieldValue.serverTimestamp(),
        'rating': 4.5, // Default rating for new skills
        'verified': false, // Can be set to true by admin later
        'isNew': true,
      };

      // Save to Firestore 'skills' collection
      await FirebaseFirestore.instance.collection('skills').add(skillData);

      if (!mounted) return;

      // Close loading dialog
      Navigator.of(context).pop();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Skill published successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate back to home after a short delay
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomePage()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      // Close loading dialog
      Navigator.of(context).pop();

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to publish skill: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Page theme overlays Theme.of(context) but keeps dark background
    final pageTheme = Theme.of(context).copyWith(
      scaffoldBackgroundColor: backgroundColor,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardColor.withOpacity(.6),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accentPurple, width: 2),
        ),
        hintStyle: const TextStyle(color: Colors.white70),
      ),
      textTheme: Theme.of(
        context,
      ).textTheme.apply(bodyColor: textColor, displayColor: textColor),
      colorScheme: Theme.of(
        context,
      ).colorScheme.copyWith(primary: accentPurple, secondary: accentPurple),
    );

    return Theme(
      data: pageTheme,
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ✅ Use the shared sidebar everywhere
              const AppSidebar(active: 'Post Skill'),

              // Main content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 960),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 8),
                          // Top bar with NO notification icon
                          const _TopBarNoNotifications(),
                          const SizedBox(height: 18),

                          const Text(
                            'Share Your Skills',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Help others learn while building your reputation in our community',
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 20),

                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isWide = constraints.maxWidth >= 760;
                              if (isWide) {
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Left: form cards
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          SectionCard(
                                            title: 'Basic Information',
                                            leading: Container(
                                              width: 36,
                                              height: 36,
                                              decoration: const BoxDecoration(
                                                color: Colors.white10,
                                                borderRadius: BorderRadius.all(
                                                  Radius.circular(8),
                                                ),
                                              ),
                                              child: const Center(
                                                child: Icon(
                                                  Icons.auto_awesome,
                                                  color: Color(0xFF7EEAD3),
                                                ),
                                              ),
                                            ),
                                            child: _buildBasicInfoCardContent(),
                                          ),
                                          const SizedBox(height: 28),
                                          SectionCard(
                                            title: 'Details & Logistics',
                                            leading: const Icon(
                                              Icons.access_time,
                                              color: accentPurple,
                                            ),
                                            child: _buildDetailsCardContent(),
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              OutlinedButton.icon(
                                                onPressed: () => setState(
                                                  () => _showPreview =
                                                      !_showPreview,
                                                ),
                                                icon: const Icon(
                                                  Icons.remove_red_eye,
                                                ),
                                                label: Text(
                                                  _showPreview
                                                      ? 'Hide Preview'
                                                      : 'Preview',
                                                ),
                                                style: OutlinedButton.styleFrom(
                                                  side: const BorderSide(
                                                    color: accentPurple,
                                                  ),
                                                  foregroundColor: accentPurple,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 18,
                                                        vertical: 14,
                                                      ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: ElevatedButton(
                                                  onPressed: _canPublish
                                                      ? _publish
                                                      : null,
                                                  style: ButtonStyle(
                                                    backgroundColor:
                                                        WidgetStateProperty.resolveWith<
                                                          Color?
                                                        >(
                                                          (states) =>
                                                              states.contains(
                                                                WidgetState
                                                                    .disabled,
                                                              )
                                                              ? accentPurple
                                                                    .withOpacity(
                                                                      0.45,
                                                                    )
                                                              : accentPurple,
                                                        ),
                                                    foregroundColor:
                                                        WidgetStateProperty.resolveWith<
                                                          Color?
                                                        >(
                                                          (states) =>
                                                              states.contains(
                                                                WidgetState
                                                                    .disabled,
                                                              )
                                                              ? Colors.white70
                                                              : Colors.white,
                                                        ),
                                                    padding:
                                                        WidgetStateProperty.all(
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 26,
                                                            vertical: 14,
                                                          ),
                                                        ),
                                                    shape: WidgetStateProperty.all(
                                                      RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                                  child: const Text(
                                                    'Publish Skill →',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 20),

                                    // Right: tips + optional preview
                                    SizedBox(
                                      width: 320,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          const ProTipsPanel(),
                                          const SizedBox(height: 28),
                                          if (_showPreview)
                                            PreviewCard(
                                              title: _titleController.text,
                                              description:
                                                  _descriptionController.text,
                                              category: _category ?? 'Category',
                                              hours: _hoursController.text,
                                              mode: _delivery,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }

                              // Narrow layout
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SectionCard(
                                    title: 'Basic Information',
                                    leading: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: const BoxDecoration(
                                        color: Colors.white10,
                                        borderRadius: BorderRadius.all(
                                          Radius.circular(8),
                                        ),
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.auto_awesome,
                                          color: Color(0xFF7EEAD3),
                                        ),
                                      ),
                                    ),
                                    child: _buildBasicInfoCardContent(),
                                  ),
                                  const SizedBox(height: 16),
                                  SectionCard(
                                    title: 'Details & Logistics',
                                    leading: const Icon(
                                      Icons.access_time,
                                      color: accentPurple,
                                    ),
                                    child: _buildDetailsCardContent(),
                                  ),
                                  const SizedBox(height: 12),
                                  const ProTipsPanel(),
                                  const SizedBox(height: 16),
                                  if (_showPreview)
                                    PreviewCard(
                                      title: _titleController.text,
                                      description: _descriptionController.text,
                                      category: _category ?? 'Category',
                                      hours: _hoursController.text,
                                      mode: _delivery,
                                    ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: () => setState(
                                          () => _showPreview = !_showPreview,
                                        ),
                                        icon: const Icon(Icons.remove_red_eye),
                                        label: Text(
                                          _showPreview
                                              ? 'Hide Preview'
                                              : 'Preview',
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(
                                            color: accentPurple,
                                          ),
                                          foregroundColor: accentPurple,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 18,
                                            vertical: 14,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: _canPublish
                                              ? _publish
                                              : null,
                                          style: ButtonStyle(
                                            backgroundColor:
                                                WidgetStateProperty.resolveWith<
                                                  Color?
                                                >(
                                                  (states) =>
                                                      states.contains(
                                                        WidgetState.disabled,
                                                      )
                                                      ? accentPurple
                                                            .withOpacity(0.45)
                                                      : accentPurple,
                                                ),
                                            foregroundColor:
                                                WidgetStateProperty.resolveWith<
                                                  Color?
                                                >(
                                                  (states) =>
                                                      states.contains(
                                                        WidgetState.disabled,
                                                      )
                                                      ? Colors.white70
                                                      : Colors.white,
                                                ),
                                            padding: WidgetStateProperty.all(
                                              const EdgeInsets.symmetric(
                                                horizontal: 26,
                                                vertical: 14,
                                              ),
                                            ),
                                            shape: WidgetStateProperty.all(
                                              RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                          ),
                                          child: const Text(
                                            'Publish Skill →',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------ Basic Info card content ------------------
  Widget _buildBasicInfoCardContent() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Skill Title *',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _titleController,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
            onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
            decoration: const InputDecoration(
              hintText: 'e.g., Logo Design in Figma',
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Please enter a title' : null,
          ),
          const SizedBox(height: 8),
          const Text(
            'Make it clear and specific',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 18),
          const Text(
            'Description *',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _descriptionController,
            minLines: 5,
            maxLines: 7,
            textInputAction: TextInputAction.newline,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText:
                  "Describe what you'll teach, your experience, and what students will learn...",
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Please enter a description'
                : null,
          ),
          const SizedBox(height: 8),
          const Text(
            "Be detailed about what you'll cover",
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Category *',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    DropdownField<String>(
                      value: _category,
                      hint: 'Select category',
                      items: _categories,
                      onChanged: (v) => setState(() => _category = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Difficulty Level *',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    DropdownField<String>(
                      value: _difficulty,
                      hint: 'Select level',
                      items: _levels,
                      onChanged: (v) => setState(() => _difficulty = v),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------ Details card content ------------------
  Widget _buildDetailsCardContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Estimated Hours',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _hoursController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                    decoration: const InputDecoration(hintText: '1'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Delivery Format',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  DropdownField<String>(
                    value: _delivery,
                    hint: 'Remote Only',
                    items: _deliveryOptions,
                    onChanged: (v) =>
                        setState(() => _delivery = v ?? _delivery),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text('Tags', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _tagController,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _addTag(),
                decoration: const InputDecoration(hintText: 'Add a tag...'),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _addTag,
              icon: const Icon(Icons.add, color: Colors.white),
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(accentPurple),
                padding: WidgetStateProperty.all(const EdgeInsets.all(12)),
                shape: WidgetStateProperty.all(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _tags
              .map(
                (t) => Chip(
                  label: Text(t),
                  onDeleted: () => setState(() => _tags.remove(t)),
                  backgroundColor: Colors.white10,
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 16),
        const Text(
          "What You'll Deliver",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _deliverableController,
                onSubmitted: (_) => _addDeliverable(),
                decoration: const InputDecoration(
                  hintText: 'e.g., 3 logo concepts with revisions...',
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _addDeliverable,
              icon: const Icon(Icons.add, color: Colors.white),
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(accentPurple),
                padding: WidgetStateProperty.all(const EdgeInsets.all(12)),
                shape: WidgetStateProperty.all(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _deliverables
              .map(
                (d) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: cardColor.withOpacity(.8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(d)),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () =>
                            setState(() => _deliverables.remove(d)),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

// ------------------ Model used to print request ------------------
class PostSkillRequest {
  final String title;
  final String description;
  final String category;
  final String difficulty;
  final int estimatedHours;
  final String deliveryFormat;
  final List<String> tags;
  final List<String> deliverables;

  PostSkillRequest({
    required this.title,
    required this.description,
    required this.category,
    required this.difficulty,
    required this.estimatedHours,
    required this.deliveryFormat,
    required this.tags,
    required this.deliverables,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'category': category,
    'difficulty': difficulty,
    'estimatedHours': estimatedHours,
    'deliveryFormat': deliveryFormat,
    'tags': tags,
    'deliverables': deliverables,
  };
}

// ------------------ Top bar (NO notifications here) ------------------
class _TopBarNoNotifications extends StatelessWidget {
  const _TopBarNoNotifications();

  @override
  Widget build(BuildContext context) {
    // Keeping structure simple; no bell/badge.
    return const SizedBox(
      height: 44,
      child: Row(children: [Expanded(child: SizedBox())]),
    );
  }
}

// ------------------ Reusable DropdownField ------------------
class DropdownField<T> extends StatelessWidget {
  const DropdownField({
    super.key,
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  final T? value;
  final String hint;
  final List<String> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: cardColor.withOpacity(.65),
        border: Border.all(color: Colors.white12),
      ),
      child: DropdownButtonHideUnderline(
        child: Row(
          children: [
            Expanded(
              child: DropdownButton<T>(
                value: value,
                isExpanded: true,
                dropdownColor: cardColor,
                hint: Text(hint, style: const TextStyle(color: Colors.white70)),
                items: items
                    .map(
                      (s) => DropdownMenuItem<T>(value: s as T, child: Text(s)),
                    )
                    .toList(),
                onChanged: onChanged,
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, color: Colors.white70),
          ],
        ),
      ),
    );
  }
}

// ------------------ Sidebar Navigation (aligned with HomePage) ------------------
class SidebarNav extends StatelessWidget {
  const SidebarNav({super.key, this.activeLabel, this.badgeRequests});

  final String? activeLabel;
  final String? badgeRequests;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240, // match HomePage
      decoration: const BoxDecoration(
        color: Color(0xFF0E0E10),
        border: Border(right: BorderSide(color: Color(0xFF1F2937))),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Logo (same sizing as HomePage sidebar)
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
          const Divider(color: Color(0xFF1F2937), height: 1),
          const SizedBox(height: 12),
          _navItem(
            context,
            Icons.home_rounded,
            'Home',
            active: (activeLabel ?? '') == 'Home',
            onTap: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const HomePage()),
                (route) => false,
              );
            },
          ),

          _navItem(
            context,
            Icons.explore_outlined,
            'Discover',
            active: (activeLabel ?? '') == 'Discover',
          ),
          _navItem(
            context,
            Icons.add_circle_outline,
            'Post Skill',
            active: (activeLabel ?? '') == 'Post Skill',
            onTap: () {},
          ),
          _navItem(
            context,
            Icons.inbox_outlined,
            'Requests',
            badge: badgeRequests,
            active: (activeLabel ?? '') == 'Requests',
          ),
          _navItem(
            context,
            Icons.analytics_outlined,
            'Dashboard',
            active: (activeLabel ?? '') == 'Dashboard',
          ),
          _navItem(
            context,
            Icons.person_outline,
            'Profile',
            active: (activeLabel ?? '') == 'Profile',
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1F2937)),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Share Your Skills',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Start earning by helping others learn',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: FilledButton(
                      onPressed: () {},
                      style: FilledButton.styleFrom(
                        backgroundColor: accentPurple,
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

  Widget _navItem(
    BuildContext context,
    IconData icon,
    String label, {
    bool active = false,
    String? badge,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: active ? const Color(0x201A1333) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: active ? accentPurple : Colors.white70),
        title: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.white70,
            fontWeight: active ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
        trailing: badge == null
            ? null
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF164E63),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badge,
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

class TopBarNoNotifications extends StatelessWidget {
  const TopBarNoNotifications({super.key});

  @override
  Widget build(BuildContext context) {
    // Keeping structure simple; no bell/badge.
    return SizedBox(
      height: 44,
      child: Row(
        children: const [
          // Left spacer so content below aligns nicely
          Expanded(child: SizedBox()),
        ],
      ),
    );
  }
}

// ------------------ Generic section card widget ------------------
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.leading,
  });

  final String title;
  final Widget child;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: cardColor,
      elevation: 6,
      shadowColor: Colors.black54,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (leading != null) leading!,
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

// ------------------ Pro Tips Panel ------------------
class ProTipsPanel extends StatelessWidget {
  const ProTipsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF231C35),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.lightbulb, color: accentPurple),
              SizedBox(width: 8),
              Text(
                'Pro Tips',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _bullet('Be specific about what you\'ll teach'),
          _bullet('Include examples of your work'),
          _bullet('Set realistic time estimates'),
          _bullet('Use relevant tags for discovery'),
          _bullet('Respond quickly to build trust'),
        ],
      ),
    );
  }

  Widget _bullet(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('• ', style: TextStyle(fontSize: 16, color: Colors.white70)),
        Expanded(
          child: Text(text, style: const TextStyle(color: Colors.white70)),
        ),
      ],
    ),
  );
}

// ------------------ Preview Card ------------------
class PreviewCard extends StatelessWidget {
  const PreviewCard({
    super.key,
    required this.title,
    required this.description,
    required this.category,
    required this.hours,
    required this.mode,
  });

  final String title;
  final String description;
  final String category;
  final String hours;
  final String mode;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: cardColor.withOpacity(.9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                category,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title.isEmpty ? 'Your skill title' : title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              description.isEmpty
                  ? 'Your description will appear here'
                  : description,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time, size: 14, color: Colors.white70),
                const SizedBox(width: 6),
                Text(
                  '${hours}h',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.public, size: 14, color: Colors.white70),
                const SizedBox(width: 6),
                Text(
                  mode,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
