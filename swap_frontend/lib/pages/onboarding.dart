// lib/pages/profile_setup_flow.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_page.dart';
import '../services/profile_service.dart';

class ProfileSetupFlow extends StatefulWidget {
  const ProfileSetupFlow({super.key});
  @override
  State<ProfileSetupFlow> createState() => _ProfileSetupFlowState();
}

class _ProfileSetupFlowState extends State<ProfileSetupFlow> {
  // ---- Theme (dark + purple)
  static const Color bg = Color(0xFF0A0A0B); // near-black
  static const Color card = Color(0xFF0F1115); // black-ish card
  static const Color surfaceAlt = Color(0xFF12141B); // slightly lighter card
  static const Color textPrimary = Color(0xFFEAEAF2);
  static const Color textMuted = Color(0xFFB6BDD0);
  static const Color line = Color(0xFF1F2937);
  static const Color accent = Color(0xFF7C3AED); // purple-600
  static const Color accentAlt = Color(0xFF9F67FF); // lighter purple
  static const Color accentSoft = Color(0xFF2D1B69); // dark purple bg
  static const Color chipSelectedBg = Color(0xFF1A1333);
  static const Color chipBorder = Color(0xFF2A2F3A);
  static const double kMaxContentWidth = 880;

  /* --------------------------------- Form --------------------------------- */
  final _formKey = GlobalKey<FormState>();
  final _bio = TextEditingController();
  final _fullName = TextEditingController();
  final _username = TextEditingController();
  final _city = TextEditingController();

  String? _timezone;
  int _step = 0;

  // Avatar sources
  File? _avatar; // newly picked image (local)
  String? _existingPhotoUrl; // existing photo from Firestore/Auth

  // Step 2: Skills to Offer (structured rows)
  final List<SkillEntry> _offer = [];

  // Step 3: Services You Need (structured rows)
  final List<SkillEntry> _need = [];

  // Preferences
  bool _dmOpen = true;
  bool _emailUpdates = true;
  bool _showCity = false;

  // sample options
  static const _skillCategories = <String>[
    'Engineering',
    'Design',
    'Business',
    'Content',
    'Tutoring',
    'Other',
  ];

  static const _levels = <String>['Beginner', 'Intermediate', 'Advanced'];

  static const _timezones = <String>[
    'UTC−08:00 (PST)',
    'UTC−06:00 (CST)',
    'UTC−05:00 (EST)',
    'UTC±00:00 (UTC)',
    'UTC+01:00 (CET)',
  ];

  @override
  void dispose() {
    _bio.dispose();
    _fullName.dispose();
    _username.dispose();
    _city.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadExistingUserData();
  }

  Future<void> _loadExistingUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get user data from Firestore
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) return;

      if (doc.exists) {
        final data = doc.data()!;
        // Pre-fill form with existing data
        final fullNameFirestore = (data['fullName'] ?? data['displayName']);
        if (fullNameFirestore != null) _fullName.text = fullNameFirestore;
        if (data['username'] != null) _username.text = data['username'];
        if (data['bio'] != null) _bio.text = data['bio'];
        if (data['city'] != null) _city.text = data['city'];
        if (data['timezone'] != null) _timezone = data['timezone'];
        if (data['photoUrl'] != null) _existingPhotoUrl = data['photoUrl'];

        // Pre-fill skills arrays so submitting won’t wipe them
        final existingOffer =
            (data['skillsToOffer'] as List?)
                ?.whereType<Map>()
                .map(
                  (e) => SkillEntry(
                    name: (e['name'] ?? '').toString(),
                    category: (e['category'] ?? '').toString(),
                    level: (e['level'] ?? '').toString(),
                  ),
                )
                .where((e) => e.name.isNotEmpty)
                .toList() ??
            [];

        final existingNeed =
            (data['servicesNeeded'] as List?)
                ?.whereType<Map>()
                .map(
                  (e) => SkillEntry(
                    name: (e['name'] ?? '').toString(),
                    category: (e['category'] ?? '').toString(),
                    level: (e['level'] ?? '').toString(),
                  ),
                )
                .where((e) => e.name.isNotEmpty)
                .toList() ??
            [];

        setState(() {
          _offer
            ..clear()
            ..addAll(existingOffer);
          _need
            ..clear()
            ..addAll(existingNeed);

          // Preferences if present
          if (data['dmOpen'] != null) _dmOpen = data['dmOpen'];
          if (data['emailUpdates'] != null)
            _emailUpdates = data['emailUpdates'];
          if (data['showCity'] != null) _showCity = data['showCity'];
        });
      }

      // Also check Firebase Auth data for fallbacks
      if (user.displayName != null && _fullName.text.isEmpty) {
        _fullName.text = user.displayName!;
      }
      if (_existingPhotoUrl == null && user.photoURL != null) {
        _existingPhotoUrl = user.photoURL;
      }
      if (user.email != null && _username.text.isEmpty) {
        final emailName = user.email!.split('@')[0];
        _username.text = emailName.replaceAll(RegExp(r'[^a-zA-Z0-9_\.]'), '_');
      }
    } catch (e) {
      debugPrint('Error loading existing user data: $e');
    }
  }

  Future<void> _pickAvatar() async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (x != null) setState(() => _avatar = File(x.path));
  }

  void _next() {
    if (_step == 0 && !_formKey.currentState!.validate()) return;
    if (_step < 3) {
      setState(() => _step++);
    } else {
      _submit();
    }
  }

  void _back() {
    if (_step == 0) {
      Navigator.pop(context);
    } else {
      setState(() => _step--);
    }
  }

  Future<void> _submit() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: No user is signed in')),
        );
        return;
      }

      // Upload avatar if a new one was picked
      String? photoUrl;
      if (_avatar != null) {
        try {
          final ref = FirebaseStorage.instance
              .ref()
              .child('user_avatars')
              .child('${user.uid}.jpg');
          await ref.putFile(_avatar!);
          photoUrl = await ref.getDownloadURL();
        } catch (e) {
          debugPrint('Error uploading avatar: $e');
        }
      }

      // Build payload. Because _offer/_need are prefilled from Firestore,
      // they will only be empty if the user intentionally removed them.
      final userData = <String, dynamic>{
        'fullName': _fullName.text.trim(),
        'username': _username.text.trim(),
        'bio': _bio.text.trim(),
        'city': _city.text.trim(),
        'timezone': _timezone,
        'skillsToOffer': _offer
            .map(
              (e) => {'name': e.name, 'category': e.category, 'level': e.level},
            )
            .toList(),
        'servicesNeeded': _need
            .map(
              (e) => {'name': e.name, 'category': e.category, 'level': e.level},
            )
            .toList(),
        'dmOpen': _dmOpen,
        'emailUpdates': _emailUpdates,
        'showCity': _showCity,
        if (photoUrl != null) 'photoUrl': photoUrl, // keep existing if null
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(userData, SetOptions(merge: true));

      if (_fullName.text.isNotEmpty) {
        await user.updateDisplayName(_fullName.text.trim());
      }
      if (photoUrl != null) {
        await user.updatePhotoURL(photoUrl);
      }

      // Convert your structured skills to simple strings for the backend.
      String _skillsListToText(List<SkillEntry> list) {
        // Keep it readable for embeddings: "React (Advanced), SQL (Intermediate)"
        return list
            .map((e) => e.level.isNotEmpty ? '${e.name} (${e.level})' : e.name)
            .join(', ');
      }

      final offersText = _skillsListToText(_offer);
      final needsText = _skillsListToText(_need);

      await ProfileService().upsertProfile(
        uid: user.uid,
        email: user.email ?? '',
        displayName: _fullName.text.trim().isNotEmpty
            ? _fullName.text.trim()
            : (_username.text.trim().isNotEmpty
                  ? _username.text.trim()
                  : (user.email ?? '')),
        skillsToOffer: offersText,
        servicesNeeded: needsText,
        bio: _bio.text.trim(),
        city: _city.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!')),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } catch (e, stackTrace) {
      debugPrint('Error in _submit: $e\n$stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating profile: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final stepsTotal = 4;
    final progress = (_step + 1) / stepsTotal;

    final theme = ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        primary: accent,
        surface: card,
        background: bg,
        brightness: Brightness.dark,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: textPrimary,
        centerTitle: true,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: surfaceAlt,
        labelStyle: TextStyle(color: textMuted),
        hintStyle: TextStyle(color: textMuted),
        border: OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: line, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: accent, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: line),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        side: const BorderSide(color: chipBorder),
        backgroundColor: surfaceAlt,
        selectedColor: chipSelectedBg,
        checkmarkColor: accentAlt,
        labelStyle: const TextStyle(color: textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      dividerColor: line,
      textTheme: const TextTheme(
        titleLarge: TextStyle(fontWeight: FontWeight.w700, color: textPrimary),
        bodyMedium: TextStyle(color: textMuted),
        bodySmall: TextStyle(color: textMuted),
      ),
      switchTheme: const SwitchThemeData(
        thumbColor: WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStatePropertyAll(accentSoft),
      ),
    );

    return Theme(
      data: theme,
      child: Scaffold(
        appBar: AppBar(title: const Text('Welcome to the community!')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
              child: Column(
                children: [
                  // progress + step pills
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 8,
                            color: accentAlt,
                            backgroundColor: accentSoft,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _StepHeader(current: _step),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      child: Card(
                        elevation: 0,
                        color: card,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: line),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            child: switch (_step) {
                              0 => _StepProfile(
                                key: const ValueKey('step0'),
                                formKey: _formKey,
                                fullName: _fullName,
                                username: _username,
                                bio: _bio,
                                city: _city,
                                timezone: _timezone,
                                timezones: _timezones,
                                onTimezoneChanged: (v) =>
                                    setState(() => _timezone = v),
                                avatar: _avatar,
                                existingPhotoUrl: _existingPhotoUrl,
                                onPickAvatar: _pickAvatar,
                              ),
                              1 => _StepSkillsForm(
                                key: const ValueKey('step1'),
                                title: 'Skills to Offer',
                                subtitle:
                                    'What can you teach? Be specific about your experience level and what you can help with.',
                                nameLabel: 'Skill Name',
                                addLabel: 'Add Skill',
                                categories: _skillCategories,
                                levels: _levels,
                                entries: _offer,
                                onChanged: (list) => setState(
                                  () => _offer
                                    ..clear()
                                    ..addAll(list),
                                ),
                              ),
                              2 => _StepSkillsForm(
                                key: const ValueKey('step2'),
                                title: 'Services You Need',
                                subtitle:
                                    'What do you want to learn or get help with? Add as many as you want.',
                                nameLabel: 'Service Name',
                                addLabel: 'Add Service',
                                categories: _skillCategories,
                                levels: _levels,
                                entries: _need,
                                onChanged: (list) => setState(
                                  () => _need
                                    ..clear()
                                    ..addAll(list),
                                ),
                              ),
                              3 => _StepPreferences(
                                key: const ValueKey('step3'),
                                dmOpen: _dmOpen,
                                emailUpdates: _emailUpdates,
                                showCity: _showCity,
                                onChanged: (dm, email, show) => setState(() {
                                  _dmOpen = dm;
                                  _emailUpdates = email;
                                  _showCity = show;
                                }),
                              ),
                              _ => const SizedBox.shrink(),
                            },
                          ),
                        ),
                      ),
                    ),
                  ),

                  // bottom nav
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _back,
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Back'),
                        ),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: _next,
                          icon: Icon(
                            _step < 3 ? Icons.arrow_forward : Icons.check,
                          ),
                          label: Text(
                            _step < 3 ? 'Continue' : 'Complete Setup',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* --------------------------------- Header --------------------------------- */

class _StepHeader extends StatelessWidget {
  final int current;
  const _StepHeader({required this.current});

  @override
  Widget build(BuildContext context) {
    Widget pill(String label, int idx) {
      final active = idx == current;
      final done = idx < current;

      final bg = active
          ? _ProfileSetupFlowState.accentSoft
          : (done ? const Color(0xFF142034) : const Color(0xFF12141B));
      final fg = active
          ? _ProfileSetupFlowState.accentAlt
          : (done ? const Color(0xFF5DAEFF) : _ProfileSetupFlowState.textMuted);

      final num = (idx + 1).toString();
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _ProfileSetupFlowState.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: _ProfileSetupFlowState.card,
              child: Text(
                num,
                style: TextStyle(color: fg, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: active
                    ? _ProfileSetupFlowState.accentAlt
                    : (done
                          ? Colors.white
                          : _ProfileSetupFlowState.textPrimary),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        pill('Profile', 0),
        pill('Skills to Offer', 1),
        pill('Services You Need', 2),
        pill('Preferences', 3),
      ],
    );
  }
}

/* --------------------------------- Step 1 --------------------------------- */

class _StepProfile extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController fullName;
  final TextEditingController username;
  final TextEditingController bio;
  final TextEditingController city;
  final String? timezone;
  final List<String> timezones;
  final void Function(String?) onTimezoneChanged;

  // Avatar sources
  final File? avatar; // newly picked
  final String? existingPhotoUrl; // existing from Firestore/Auth

  final VoidCallback onPickAvatar;

  const _StepProfile({
    super.key,
    required this.formKey,
    required this.fullName,
    required this.username,
    required this.bio,
    required this.city,
    required this.timezone,
    required this.timezones,
    required this.onTimezoneChanged,
    required this.avatar,
    required this.existingPhotoUrl,
    required this.onPickAvatar,
  });

  @override
  Widget build(BuildContext context) {
    // decide which image to preview
    ImageProvider? previewProvider;
    if (avatar != null) {
      previewProvider = FileImage(avatar!);
    } else if (existingPhotoUrl != null && existingPhotoUrl!.isNotEmpty) {
      previewProvider = NetworkImage(existingPhotoUrl!);
    }

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Profile Setup', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Tell us about yourself',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),

          // Avatar with purple gradient ring (supports existing + new preview)
          Center(
            child: InkWell(
              onTap: onPickAvatar,
              borderRadius: BorderRadius.circular(60),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF9F67FF), Color(0xFF7C3AED)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 44,
                      backgroundColor: _ProfileSetupFlowState.surfaceAlt,
                      foregroundImage: previewProvider,
                      child: previewProvider == null
                          ? const Text(
                              'U',
                              style: TextStyle(
                                color: _ProfileSetupFlowState.textPrimary,
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Click to add profile photo',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Name + Username
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: fullName,
                  style: const TextStyle(
                    color: _ProfileSetupFlowState.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Full Name *',
                    hintText: 'Your full name',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: username,
                  style: const TextStyle(
                    color: _ProfileSetupFlowState.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Username *',
                    hintText: '@yourhandle',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    final ok = RegExp(
                      r'^[a-z0-9_\.]{3,20}$',
                      caseSensitive: false,
                    ).hasMatch(v.trim());
                    return ok ? null : '3–20 chars, letters/numbers/._';
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: bio,
            style: const TextStyle(color: _ProfileSetupFlowState.textPrimary),
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Bio',
              hintText:
                  "Tell us about yourself, your interests, and what you're passionate about...",
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: city,
                  style: const TextStyle(
                    color: _ProfileSetupFlowState.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'City *',
                    hintText: 'e.g., Little Rock, AR',
                    prefixIcon: Icon(
                      Icons.location_on_outlined,
                      color: _ProfileSetupFlowState.textMuted,
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: timezone,
                  dropdownColor: _ProfileSetupFlowState.surfaceAlt,
                  items: timezones
                      .map(
                        (t) => DropdownMenuItem(
                          value: t,
                          child: Text(
                            t,
                            style: const TextStyle(
                              color: _ProfileSetupFlowState.textPrimary,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: onTimezoneChanged,
                  decoration: const InputDecoration(labelText: 'Timezone *'),
                  validator: (v) => v == null ? 'Select timezone' : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/* ---------------------------- Step 2 & Step 3 ----------------------------- */

class SkillEntry {
  final String name;
  final String category;
  final String level;
  SkillEntry({required this.name, required this.category, required this.level});
}

class _StepSkillsForm extends StatefulWidget {
  final String title;
  final String subtitle;
  final String nameLabel;
  final String addLabel;
  final List<String> categories;
  final List<String> levels;
  final List<SkillEntry> entries;
  final ValueChanged<List<SkillEntry>> onChanged;

  const _StepSkillsForm({
    super.key,
    required this.title,
    required this.subtitle,
    required this.nameLabel,
    required this.addLabel,
    required this.categories,
    required this.levels,
    required this.entries,
    required this.onChanged,
  });

  @override
  State<_StepSkillsForm> createState() => _StepSkillsFormState();
}

class _StepSkillsFormState extends State<_StepSkillsForm> {
  final _name = TextEditingController();
  String? _category;
  String? _level;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _add() {
    final name = _name.text.trim();
    if (name.isEmpty || _category == null || _level == null) return;
    final next = [
      ...widget.entries,
      SkillEntry(name: name, category: _category!, level: _level!),
    ];
    widget.onChanged(next);
    setState(() {
      _name.clear();
      _category = null;
      _level = null;
    });
  }

  void _removeAt(int i) {
    final next = [...widget.entries]..removeAt(i);
    widget.onChanged(next);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: _ProfileSetupFlowState.accentSoft,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _ProfileSetupFlowState.line),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Text(
            widget.subtitle,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        const SizedBox(height: 16),

        // Inputs row
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: _name,
                style: const TextStyle(
                  color: _ProfileSetupFlowState.textPrimary,
                ),
                decoration: InputDecoration(
                  labelText: widget.nameLabel,
                  hintText: 'e.g., React Development',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _category,
                dropdownColor: _ProfileSetupFlowState.surfaceAlt,
                items: widget.categories
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text(
                          c,
                          style: const TextStyle(
                            color: _ProfileSetupFlowState.textPrimary,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _category = v),
                decoration: const InputDecoration(labelText: 'Category'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _level,
                dropdownColor: _ProfileSetupFlowState.surfaceAlt,
                items: widget.levels
                    .map(
                      (l) => DropdownMenuItem(
                        value: l,
                        child: Text(
                          l,
                          style: const TextStyle(
                            color: _ProfileSetupFlowState.textPrimary,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _level = v),
                decoration: const InputDecoration(labelText: 'Level'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            onPressed: _add,
            icon: const Icon(Icons.add),
            label: Text(widget.addLabel),
          ),
        ),
        const SizedBox(height: 16),

        // Added entries list (as pill row)
        if (widget.entries.isNotEmpty)
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (int i = 0; i < widget.entries.length; i++)
                _EntryChip(
                  entry: widget.entries[i],
                  onRemove: () => _removeAt(i),
                ),
            ],
          )
        else
          Text(
            'No items added yet.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  }
}

class _EntryChip extends StatelessWidget {
  final SkillEntry entry;
  final VoidCallback onRemove;
  const _EntryChip({required this.entry, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _ProfileSetupFlowState.surfaceAlt,
        border: Border.all(color: _ProfileSetupFlowState.line),
        borderRadius: BorderRadius.circular(999),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${entry.name}  •  ${entry.category}  •  ${entry.level}',
            style: const TextStyle(color: _ProfileSetupFlowState.textPrimary),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onRemove,
            child: const Icon(
              Icons.close,
              size: 18,
              color: _ProfileSetupFlowState.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/* --------------------------------- Step 4 --------------------------------- */

class _StepPreferences extends StatelessWidget {
  final bool dmOpen;
  final bool emailUpdates;
  final bool showCity;
  final void Function(bool dm, bool email, bool show) onChanged;

  const _StepPreferences({
    super.key,
    required this.dmOpen,
    required this.emailUpdates,
    required this.showCity,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Preferences', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _ProfileSetupFlowState.accentSoft,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _ProfileSetupFlowState.line),
          ),
          child: const Text(
            'Almost done! Tell us how you prefer to swap skills.',
            style: TextStyle(color: _ProfileSetupFlowState.textPrimary),
          ),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text(
            'Allow direct messages',
            style: TextStyle(color: _ProfileSetupFlowState.textPrimary),
          ),
          value: dmOpen,
          onChanged: (v) => onChanged(v, emailUpdates, showCity),
        ),
        SwitchListTile(
          title: const Text(
            'Email me helpful updates',
            style: TextStyle(color: _ProfileSetupFlowState.textPrimary),
          ),
          value: emailUpdates,
          onChanged: (v) => onChanged(dmOpen, v, showCity),
        ),
        SwitchListTile(
          title: const Text(
            'Show my city on profile',
            style: TextStyle(color: _ProfileSetupFlowState.textPrimary),
          ),
          value: showCity,
          onChanged: (v) => onChanged(dmOpen, emailUpdates, v),
        ),
        const SizedBox(height: 16),
        Column(
          children: const [
            CircleAvatar(
              radius: 28,
              backgroundColor: _ProfileSetupFlowState.surfaceAlt,
              child: Icon(
                Icons.check_circle,
                color: _ProfileSetupFlowState.accentAlt,
                size: 36,
              ),
            ),
            SizedBox(height: 8),
            Text(
              "You're all set!",
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: _ProfileSetupFlowState.textPrimary,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Ready to start swapping skills with our amazing community.',
              style: TextStyle(color: _ProfileSetupFlowState.textMuted),
            ),
          ],
        ),
      ],
    );
  }
}
