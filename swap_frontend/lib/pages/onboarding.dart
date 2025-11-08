// lib/pages/profile_setup_flow.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ProfileSetupFlow extends StatefulWidget {
  const ProfileSetupFlow({super.key});
  @override
  State<ProfileSetupFlow> createState() => _ProfileSetupFlowState();
}

/* ----------------------------- Theme & models ----------------------------- */

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

  // simple model for entries
  static Map<String, dynamic> entryToMap(SkillEntry e) => {
    'name': e.name,
    'category': e.category,
    'level': e.level,
  };

  /* --------------------------------- Form --------------------------------- */
  final _formKey = GlobalKey<FormState>();
  final _bio = TextEditingController();
  final _fullName = TextEditingController();
  final _username = TextEditingController();
  final _city = TextEditingController();

  String? _timezone;
  int _step = 0;
  File? _avatar;

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

  void _submit() {
    final payload = {
      'fullName': _fullName.text.trim(),
      'username': _username.text.trim(),
      'bio': _bio.text.trim(),
      'city': _city.text.trim(),
      'timezone': _timezone,
      'skillsOffer': _offer.map(entryToMap).toList(),
      'servicesNeed': _need.map(entryToMap).toList(),
      'dmOpen': _dmOpen,
      'emailUpdates': _emailUpdates,
      'showCity': _showCity,
      // avatar: _avatar
    };
    Navigator.pop(context, payload);
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
  final File? avatar;
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
    required this.onPickAvatar,
  });

  @override
  Widget build(BuildContext context) {
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

          // Avatar with purple gradient ring
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
                      backgroundImage: avatar != null
                          ? FileImage(avatar!)
                          : null,
                      child: avatar == null
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
