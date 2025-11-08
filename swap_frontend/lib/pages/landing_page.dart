import 'package:flutter/material.dart';
import 'login_page.dart';
import 'onboarding.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0A0A0B); // near-black
    const surface = Color(0xFF0F1115); // black-ish card
    const surfaceAlt = Color(0xFF12141B); // slightly lighter card
    const textPrimary = Color(0xFFEAEAF2);
    const textMuted = Color(0xFFB6BDD0);
    const accent = Color(0xFF7C3AED); // purple
    const accentAlt = Color(0xFF9F67FF); // light purple for hovers/borders

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              ignoring: true,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.45, -0.05),
                    radius: 0.55,
                    colors: [accent.withOpacity(0.10), Colors.transparent],
                    stops: const [0.0, 1.0],
                  ),
                ),
              ),
            ),
          ),
          // Page content
          SingleChildScrollView(
            child: Column(
              children: const [
                _NavBar(
                  surface: surface,
                  textPrimary: textPrimary,
                  textMuted: textMuted,
                  accent: accent,
                ),
                _HeroSection(
                  textPrimary: textPrimary,
                  textMuted: textMuted,
                  accent: accent,
                  accentAlt: accentAlt,
                  surfaceAlt: surfaceAlt,
                ),
                _StatsRow(
                  surface: surface,
                  textPrimary: textPrimary,
                  textMuted: textMuted,
                ),
                _HowItWorks(
                  textPrimary: textPrimary,
                  textMuted: textMuted,
                  surfaceAlt: surfaceAlt,
                  accent: accent,
                ),
                _PopularCategories(
                  textPrimary: textPrimary,
                  textMuted: textMuted,
                  surfaceAlt: surfaceAlt,
                ),
                _Testimonials(
                  textPrimary: textPrimary,
                  textMuted: textMuted,
                  surfaceAlt: surfaceAlt,
                ),
                _Footer(
                  textPrimary: textPrimary,
                  textMuted: textMuted,
                  surface: Color(0xFF0E1014),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.surface,
    required this.textPrimary,
    required this.textMuted,
    required this.accent,
  });

  final Color surface, textPrimary, textMuted, accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: surface,
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: _MaxWidth(
        child: Row(
          children: [
            // Logo
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withOpacity(.45),
                        blurRadius: 16,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'S',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Swap',
                  style: TextStyle(
                    fontSize: 18,
                    color: textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const Spacer(),
            TextButton(
              onPressed: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const LoginPage()));
              },
              child: Text(
                'Log In',
                style: TextStyle(color: textMuted, fontSize: 16),
              ),
            ),
            const SizedBox(width: 12),
            // Purple CTA
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileSetupFlow()),
                );
              },
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('Get Started'),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                shadowColor: accent.withOpacity(.55),
                elevation: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ================= HERO ================= */

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.textPrimary,
    required this.textMuted,
    required this.accent,
    required this.accentAlt,
    required this.surfaceAlt,
  });

  final Color textPrimary, textMuted, accent, accentAlt, surfaceAlt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 56, bottom: 40),
      child: _MaxWidth(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: accent.withOpacity(.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: accentAlt.withOpacity(.35)), // was .5
                // removed BoxShadow to avoid neon
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, size: 16, color: accent),
                  const SizedBox(width: 8),
                  Text(
                    'No money, just skills',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            // Crisp title (no shadow)
            Text(
              'Trade skills',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textPrimary,
                fontSize: 56,
                height: 1.1,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                // removed shadows
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 860,
              child: Text(
                "Turn what you can do into what you need. Swap design, coding, writing, tutoring and more with our trusted community.",
                textAlign: TextAlign.center,
                style: TextStyle(color: textMuted, fontSize: 18, height: 1.6),
              ),
            ),
            const SizedBox(height: 28),
            // CTAs
            Wrap(
              spacing: 14,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                // Purple primary
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ProfileSetupFlow(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Get Started'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    shadowColor: accent.withOpacity(.55),
                    elevation: 8,
                  ),
                ),
                // Ghost button on dark surface
                OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: surfaceAlt.withOpacity(.7)),
                    foregroundColor: textPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    backgroundColor: surfaceAlt.withOpacity(.35),
                  ),
                  child: const Text('Explore Skills'),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

/* ============ STATS / HOW / CATS / TESTIMONIALS / FOOTER ============ */

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.surface,
    required this.textPrimary,
    required this.textMuted,
  });

  final Color surface, textPrimary, textMuted;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: surface,
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: _MaxWidth(
        child: Wrap(
          spacing: 24,
          runSpacing: 24,
          alignment: WrapAlignment.center,
          children: const [
            _StatCard(value: '4', label: 'Completed Swaps'),
            _StatCard(value: '4.9/5', label: 'Average Rating'),
            _StatCard(value: '10', label: 'Verified Users'),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  const _StatCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    const textPrimary = Color(0xFFEAEAF2);
    const textMuted = Color(0xFFB6BDD0);
    const surfaceAlt = Color(0xFF12141B);

    return Container(
      width: 260,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      decoration: BoxDecoration(
        color: surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.25),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.06),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.verified, color: textPrimary, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: textMuted, fontSize: 14)),
        ],
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks({
    required this.textPrimary,
    required this.textMuted,
    required this.surfaceAlt,
    required this.accent,
  });

  final Color textPrimary, textMuted, surfaceAlt, accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56),
      child: _MaxWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'How it works',
              style: TextStyle(
                color: textPrimary,
                fontSize: 34,
                fontWeight: FontWeight.w800,
                shadows: [
                  Shadow(color: accent.withOpacity(.18), blurRadius: 14),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Three simple steps to start swapping',
              style: TextStyle(color: textMuted),
            ),
            const SizedBox(height: 26),
            Wrap(
              spacing: 18,
              runSpacing: 18,
              alignment: WrapAlignment.center,
              children: const [
                _StepCard(
                  step: '1',
                  title: 'Share Your Expertise',
                  body:
                      "Whether you're a small business owner, freelancer, or student, your skills are valuable.",
                ),
                _StepCard(
                  step: '2',
                  title: 'Access Services',
                  body:
                      "Need a website, logo, marketing help, or any service? Connect with a community of skilled swappers and trade services that work for both of you.",
                ),
                _StepCard(
                  step: '3',
                  title: 'Swap securely',
                  body:
                      "We hold swaps in review until both parties confirm. Safe, secure, and satisfaction guaranteed.",
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final String step, title, body;
  const _StepCard({
    required this.step,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    const surfaceAlt = Color(0xFF12141B);
    const textPrimary = Color(0xFFEAEAF2);
    const textMuted = Color(0xFFB6BDD0);
    const accent = Color(0xFF7C3AED);

    return Container(
      width: 320,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: accent.withOpacity(.15),
            child: Text(
              step,
              style: const TextStyle(
                color: accent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              color: textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(body, style: const TextStyle(color: textMuted, height: 1.5)),
        ],
      ),
    );
  }
}

class _PopularCategories extends StatelessWidget {
  const _PopularCategories({
    required this.textPrimary,
    required this.textMuted,
    required this.surfaceAlt,
  });

  final Color textPrimary, textMuted, surfaceAlt;

  @override
  Widget build(BuildContext context) {
    final cards = <_CategoryCard>[
      const _CategoryCard(
        title: 'Design',
        chips: ['UI/UX', 'Graphic Design', 'Branding'],
        icon: Icons.palette_outlined,
      ),
      const _CategoryCard(
        title: 'Coding',
        chips: ['Web Dev', 'Mobile Apps', 'Data Science'],
        icon: Icons.code,
      ),
      const _CategoryCard(
        title: 'Writing',
        chips: ['Content', 'Copywriting', 'Technical'],
        icon: Icons.menu_book_outlined,
      ),
      const _CategoryCard(
        title: 'Language',
        chips: ['Spanish', 'French', 'Mandarin'],
        icon: Icons.translate,
      ),
      const _CategoryCard(
        title: 'Tutoring',
        chips: ['Math', 'Science', 'Business'],
        icon: Icons.school_outlined,
      ),
      const _CategoryCard(
        title: 'Music',
        chips: ['Guitar', 'Piano', 'Production'],
        icon: Icons.music_note_outlined,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56),
      child: _MaxWidth(
        child: Column(
          children: [
            Text(
              'Popular skill categories',
              style: TextStyle(
                color: textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Discover what our community is trading',
              style: TextStyle(color: textMuted),
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth;
                int cols = 1;
                if (w >= 1100) {
                  cols = 3;
                } else if (w >= 740)
                  cols = 2;

                return Wrap(
                  spacing: 18,
                  runSpacing: 18,
                  children: cards
                      .map(
                        (card) => SizedBox(
                          width: (w - (18 * (cols - 1))) / cols,
                          child: card,
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final String title;
  final List<String> chips;
  final IconData icon;
  const _CategoryCard({
    required this.title,
    required this.chips,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    const surfaceAlt = Color(0xFF12141B);
    const textPrimary = Color(0xFFEAEAF2);
    const textMuted = Color(0xFFB6BDD0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: textPrimary),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: chips
                .map(
                  (c) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.06),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(c, style: const TextStyle(color: textMuted)),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _Testimonials extends StatelessWidget {
  const _Testimonials({
    required this.textPrimary,
    required this.textMuted,
    required this.surfaceAlt,
  });

  final Color textPrimary, textMuted, surfaceAlt;

  @override
  Widget build(BuildContext context) {
    final data = const [
      (
        'S',
        'Sarah M.',
        'Learned React from an amazing developer in exchange for teaching French. Perfect platform!',
        'French ↔ React',
      ),
      (
        'M',
        'Marcus K.',
        'Got professional logo design by helping with math tutoring. Both of us won!',
        'Math ↔ Design',
      ),
      (
        'E',
        'Elena R.',
        'Amazing community. Improved my writing skills while teaching piano. Highly recommend!',
        'Piano ↔ Writing',
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56),
      child: _MaxWidth(
        child: Column(
          children: [
            Text(
              'What our community says',
              style: TextStyle(
                color: textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Real stories from real skill swappers',
              style: TextStyle(color: textMuted),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 18,
              runSpacing: 18,
              children: data
                  .map(
                    (t) => _TestimonialCard(
                      initials: t.$1,
                      name: t.$2,
                      text: t.$3,
                      chip: t.$4,
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _TestimonialCard extends StatelessWidget {
  final String initials, name, text, chip;
  const _TestimonialCard({
    required this.initials,
    required this.name,
    required this.text,
    required this.chip,
  });

  @override
  Widget build(BuildContext context) {
    const surfaceAlt = Color(0xFF12141B);
    const textPrimary = Color(0xFFEAEAF2);
    const textMuted = Color(0xFFB6BDD0);

    return Container(
      width: 360,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.white.withOpacity(.08),
                child: Text(
                  initials,
                  style: const TextStyle(color: textPrimary),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                name,
                style: const TextStyle(
                  color: textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              const _Stars(),
            ],
          ),
          const SizedBox(height: 12),
          Text(text, style: const TextStyle(color: textMuted, height: 1.5)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.06),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(chip, style: const TextStyle(color: textMuted)),
          ),
        ],
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars();

  @override
  Widget build(BuildContext context) {
    const c = Color(0xFFFFD166);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (_) => const Icon(Icons.star, size: 16, color: c),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.textPrimary,
    required this.textMuted,
    required this.surface,
  });

  final Color textPrimary, textMuted, surface;

  @override
  Widget build(BuildContext context) {
    Widget col(String head, List<String> items) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              head,
              style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            ...items.map(
              (e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(e, style: TextStyle(color: textMuted)),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      color: surface,
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: _MaxWidth(
        child: Column(
          children: [
            LayoutBuilder(
              builder: (context, c) {
                if (c.maxWidth < 760) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      col('Platform', [
                        'About',
                        'Trust & Safety',
                        'Pricing',
                        'Help Center',
                      ]),
                      const SizedBox(height: 18),
                      col('Legal', [
                        'Terms of Service',
                        'Privacy Policy',
                        'Cookie Policy',
                      ]),
                      const SizedBox(height: 18),
                      col('Connect', ['Twitter', 'LinkedIn', 'Discord']),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              color: Colors.white24,
                              shape: BoxShape.rectangle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'The skill-exchange platform where skills meets opportunity.',
                              style: TextStyle(color: textMuted),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 40),
                    col('Platform', [
                      'About',
                      'Trust & Safety',
                      'Pricing',
                      'Help Center',
                    ]),
                    const SizedBox(width: 20),
                    col('Legal', [
                      'Terms of Service',
                      'Privacy Policy',
                      'Cookie Policy',
                    ]),
                    const SizedBox(width: 20),
                    col('Connect', ['Twitter', 'LinkedIn', 'Discord']),
                  ],
                );
              },
            ),
            const SizedBox(height: 26),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '© 2024 Swap. All rights reserved.',
                style: TextStyle(color: textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaxWidth extends StatelessWidget {
  final double maxWidth;
  final Widget child;
  const _MaxWidth({this.maxWidth = 1180, required this.child});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: child,
        ),
      ),
    );
  }
}
