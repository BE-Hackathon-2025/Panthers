// lib/pages/requests_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/app_sidebar.dart';
import 'home_page.dart';

class RequestsPage extends StatefulWidget {
  const RequestsPage({super.key});
  @override
  State<RequestsPage> createState() => _RequestsPageState();
}

class _RequestsPageState extends State<RequestsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _search = TextEditingController();

  final _categories = const [
    'All',
    'Design',
    'Coding',
    'Writing',
    'Language',
    'Tutoring',
    'Music',
    'Other',
  ];
  String _category = 'All';
  String _mode = 'Any'; // Any | Remote | In-person
  String _hours = 'Any'; // Any | ≤2 | 2–5 | 5+
  String _sort = 'Newest'; // Newest | Hours ↑ | Hours ↓

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this)
      ..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomePage.bg,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppSidebar(active: 'Requests'),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Page header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 18, 24, 12),
                    child: Row(
                      children: [
                        const Text(
                          'Requests',
                          style: TextStyle(
                            color: HomePage.textPrimary,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 12),
                        _Badge(
                          text: 'Live',
                          icon: Icons.bolt,
                          fg: Colors.white,
                          bg: HomePage.accent,
                        ),
                        const Spacer(),
                        if (_tab.index != 0)
                          FilledButton.icon(
                            onPressed: () =>
                                Navigator.of(context).pushNamed('/request/new'),
                            style: FilledButton.styleFrom(
                              backgroundColor: HomePage.accent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.add),
                            label: const Text('New request'),
                          ),
                      ],
                    ),
                  ),

                  // Tabs
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      decoration: BoxDecoration(
                        color: HomePage.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: HomePage.line),
                      ),
                      child: TabBar(
                        controller: _tab,
                        isScrollable: true,
                        indicator: BoxDecoration(
                          color: HomePage.surfaceAlt,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: HomePage.accentAlt),
                        ),
                        padding: const EdgeInsets.all(6),
                        labelColor: Colors.white,
                        unselectedLabelColor: HomePage.textMuted,
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.w800,
                        ),
                        tabs: const [
                          Tab(text: 'Browse'),
                          Tab(text: 'My Requests'),
                          Tab(text: 'My Offers'),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: TabBarView(
                        controller: _tab,
                        children: [
                          _BrowseTab(
                            search: _search,
                            category: _category,
                            mode: _mode,
                            hours: _hours,
                            sort: _sort,
                            categories: _categories,
                            onCategory: (v) => setState(() => _category = v),
                            onMode: (v) => setState(() => _mode = v),
                            onHours: (v) => setState(() => _hours = v),
                            onSort: (v) => setState(() => _sort = v),
                          ),
                          const _MyRequestsTab(),
                          const _MyOffersTab(),
                        ],
                      ),
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

/* =============================== Browse Tab =============================== */

class _BrowseTab extends StatelessWidget {
  const _BrowseTab({
    required this.search,
    required this.category,
    required this.mode,
    required this.hours,
    required this.sort,
    required this.categories,
    required this.onCategory,
    required this.onMode,
    required this.onHours,
    required this.onSort,
  });

  final TextEditingController search;
  final String category;
  final String mode;
  final String hours;
  final String sort;
  final List<String> categories;
  final ValueChanged<String> onCategory;
  final ValueChanged<String> onMode;
  final ValueChanged<String> onHours;
  final ValueChanged<String> onSort;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    final baseQuery = FirebaseFirestore.instance
        .collection('requests')
        .where('status', isEqualTo: 'OPEN')
        .orderBy('createdAt', descending: true);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SearchAndFiltersRow(
          search: search,
          categories: categories,
          category: category,
          onCategory: onCategory,
          mode: mode,
          onMode: onMode,
          hours: hours,
          onHours: onHours,
          sort: sort,
          onSort: onSort,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: baseQuery.snapshots(),
            builder: (c, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const _LoadingList();
              }
              final all = snap.data?.docs ?? [];
              final q = search.text.trim().toLowerCase();

              bool hoursMatch(int h) {
                if (hours == 'Any') return true;
                if (hours == '≤2') return h <= 2;
                if (hours == '2–5') return h >= 2 && h <= 5;
                return h >= 5;
              }

              List<QueryDocumentSnapshot<Map<String, dynamic>>> items = all
                  .where((d) {
                    final data = d.data();
                    if (uid != null && data['userId'] == uid) return false;
                    if (category != 'All' && data['category'] != category)
                      return false;
                    if (mode != 'Any' && data['mode'] != mode) return false;
                    final est = (data['estHours'] ?? 0) as int;
                    if (!hoursMatch(est)) return false;
                    if (q.isNotEmpty) {
                      final t = (data['title'] ?? '').toString().toLowerCase();
                      final de = (data['details'] ?? '')
                          .toString()
                          .toLowerCase();
                      if (!t.contains(q) && !de.contains(q)) return false;
                    }
                    return true;
                  })
                  .toList();

              // sort
              items.sort((a, b) {
                if (sort == 'Newest') {
                  final ta = a['createdAt'] as Timestamp?;
                  final tb = b['createdAt'] as Timestamp?;
                  return (tb?.millisecondsSinceEpoch ?? 0).compareTo(
                    ta?.millisecondsSinceEpoch ?? 0,
                  );
                } else if (sort == 'Hours ↑') {
                  return ((a['estHours'] ?? 0) as int).compareTo(
                    (b['estHours'] ?? 0) as int,
                  );
                } else {
                  return ((b['estHours'] ?? 0) as int).compareTo(
                    (a['estHours'] ?? 0) as int,
                  );
                }
              });

              if (items.isEmpty) {
                return const _EmptyState('No matching requests right now.');
              }

              final w = MediaQuery.of(context).size.width;
              final cross = w >= 1400 ? 3 : (w >= 900 ? 2 : 1);

              return GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cross,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: cross == 1 ? 1.3 : 1.7,
                ),
                itemCount: items.length,
                itemBuilder: (_, i) => _RequestCard(doc: items[i]),
              );
            },
          ),
        ),
      ],
    );
  }
}

/* ============================= My Requests Tab ============================ */

class _MyRequestsTab extends StatelessWidget {
  const _MyRequestsTab();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final q = FirebaseFirestore.instance
        .collection('requests')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (c, snap) {
        if (!snap.hasData) return const _LoadingList();
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const _EmptyState("You haven't posted any requests yet.");
        }
        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final d = docs[i].data();
            return Card(
              color: HomePage.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: HomePage.line),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    _StatusDot(status: (d['status'] ?? 'OPEN').toString()),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d['title'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: HomePage.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 10,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _chip(d['category'] ?? 'Other'),
                              _chip('${d['estHours'] ?? 0}h'),
                              _chip(d['mode'] ?? 'Remote'),
                              _Badge(
                                text: 'Status: ${d['status'] ?? 'OPEN'}',
                                fg: HomePage.textMuted,
                                bg: HomePage.surfaceAlt,
                                icon: Icons.info_outline,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: () => _openOffersSheet(context, docs[i].id),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: HomePage.line),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('View offers'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () async {
                        final isClosed = (d['status'] ?? 'OPEN') == 'CLOSED';
                        await docs[i].reference.update({
                          'status': isClosed ? 'OPEN' : 'CLOSED',
                        });
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: HomePage.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        (d['status'] ?? 'OPEN') == 'CLOSED'
                            ? 'Reopen'
                            : 'Close',
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/* ============================== My Offers Tab ============================= */

class _MyOffersTab extends StatelessWidget {
  const _MyOffersTab();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final q = FirebaseFirestore.instance
        .collectionGroup('offers')
        .where('helperId', isEqualTo: uid)
        .orderBy('createdAt', descending: true);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) return const _LoadingList();
        final offers = snap.data!.docs;
        if (offers.isEmpty) {
          return const _EmptyState('You haven’t offered to help yet.');
        }
        return ListView.separated(
          itemCount: offers.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final o = offers[i].data();
            return Card(
              color: HomePage.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: HomePage.line),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(14),
                title: Text(
                  o['message']?.toString().isNotEmpty == true
                      ? o['message']
                      : '(no message)',
                  style: const TextStyle(
                    color: HomePage.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Wrap(
                    spacing: 10,
                    children: [
                      _chip('ETA: ${o['etaHours'] ?? '—'}h'),
                      _chip('Status: ${o['status'] ?? 'PENDING'}'),
                    ],
                  ),
                ),
                trailing: OutlinedButton(
                  onPressed: () async {
                    await offers[i].reference.update({'status': 'WITHDRAWN'});
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: HomePage.textPrimary,
                    side: BorderSide(color: HomePage.line),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Withdraw'),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/* ================================ Widgets ================================= */

class _SearchAndFiltersRow extends StatelessWidget {
  const _SearchAndFiltersRow({
    required this.search,
    required this.categories,
    required this.category,
    required this.onCategory,
    required this.mode,
    required this.onMode,
    required this.hours,
    required this.onHours,
    required this.sort,
    required this.onSort,
  });

  final TextEditingController search;
  final List<String> categories;
  final String category;
  final ValueChanged<String> onCategory;
  final String mode;
  final ValueChanged<String> onMode;
  final String hours;
  final ValueChanged<String> onHours;
  final String sort;
  final ValueChanged<String> onSort;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: HomePage.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HomePage.line),
      ),
      child: Column(
        children: [
          // Search
          TextField(
            controller: search,
            onChanged: (_) => (context as Element).markNeedsBuild(),
            style: const TextStyle(color: HomePage.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search requests…',
              prefixIcon: const Icon(Icons.search, color: HomePage.textMuted),
              filled: true,
              fillColor: HomePage.surfaceAlt,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: HomePage.line),
                borderRadius: BorderRadius.circular(10),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: HomePage.accentAlt),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Filters row
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in categories)
                    _pill(
                      label: c,
                      selected: c == category,
                      onTap: () => onCategory(c),
                    ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _seg('Mode', ['Any', 'Remote', 'In-person'], mode, onMode),
                  const SizedBox(width: 8),
                  _seg('Hours', ['Any', '≤2', '2–5', '5+'], hours, onHours),
                  const SizedBox(width: 8),
                  _SortDropdown(value: sort, onChanged: onSort),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SortDropdown extends StatelessWidget {
  const _SortDropdown({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: HomePage.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: HomePage.line),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: HomePage.surface,
          onChanged: (v) => onChanged(v ?? value),
          items: const [
            DropdownMenuItem(value: 'Newest', child: Text('Newest')),
            DropdownMenuItem(value: 'Hours ↑', child: Text('Hours ↑')),
            DropdownMenuItem(value: 'Hours ↓', child: Text('Hours ↓')),
          ],
          style: const TextStyle(color: HomePage.textPrimary),
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.doc});
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  @override
  Widget build(BuildContext context) {
    final d = doc.data();
    return Card(
      color: HomePage.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: HomePage.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // top row
            Row(
              children: [
                _chip((d['category'] ?? 'Other').toString().toLowerCase()),
                const Spacer(),
                Icon(
                  Icons.favorite_border,
                  size: 18,
                  color: HomePage.textMuted,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              d['title'] ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: HomePage.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Text(
                d['details'] ?? '',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: HomePage.textMuted),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _meta(icon: Icons.access_time, text: '${d['estHours'] ?? 0}h'),
                const SizedBox(width: 12),
                _meta(icon: Icons.public, text: d['mode'] ?? 'Remote'),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () => _showOfferDialog(context, doc.id),
                  icon: const Icon(Icons.mail_outline),
                  label: const Text('Offer help'),
                  style: FilledButton.styleFrom(
                    backgroundColor: HomePage.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
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

  static Widget _meta({required IconData icon, required String text}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: HomePage.textMuted),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(color: HomePage.textMuted)),
      ],
    );
  }
}

/* ================================ Helpers ================================= */

class _Badge extends StatelessWidget {
  const _Badge({
    required this.text,
    this.icon,
    required this.fg,
    required this.bg,
  });

  final String text;
  final IconData? icon;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: bg.withOpacity(0.6)),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: TextStyle(color: fg, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    Color c;
    if (status == 'OPEN')
      c = Colors.greenAccent.withOpacity(0.8);
    else if (status == 'MATCHED')
      c = Colors.amberAccent.withOpacity(0.9);
    else
      c = Colors.redAccent;
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle),
    );
  }
}

Widget _chip(String text) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
  decoration: BoxDecoration(
    color: HomePage.surfaceAlt,
    borderRadius: BorderRadius.circular(999),
    border: Border.all(color: HomePage.line),
  ),
  child: Text(text, style: const TextStyle(color: HomePage.textPrimary)),
);

Widget _pill({
  required String label,
  required bool selected,
  VoidCallback? onTap,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(999),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? HomePage.surfaceAlt : HomePage.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected ? HomePage.accentAlt : HomePage.line,
          width: selected ? 2 : 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : HomePage.textMuted,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
    ),
  );
}

Widget _seg(
  String title,
  List<String> opts,
  String cur,
  ValueChanged<String> set,
) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('$title:', style: const TextStyle(color: HomePage.textMuted)),
      const SizedBox(width: 8),
      Wrap(
        spacing: 6,
        children: opts
            .map(
              (o) => ChoiceChip(
                label: Text(o),
                selected: o == cur,
                onSelected: (_) => set(o),
                selectedColor: HomePage.accent,
                labelStyle: TextStyle(
                  color: o == cur ? Colors.white : HomePage.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                backgroundColor: HomePage.surface,
                shape: StadiumBorder(
                  side: BorderSide(
                    color: o == cur ? HomePage.accentAlt : HomePage.line,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    ],
  );
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();
  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.inbox_rounded, size: 42, color: HomePage.textMuted),
        const SizedBox(height: 10),
        Text(text, style: const TextStyle(color: HomePage.textMuted)),
      ],
    );
  }
}

/* ======================== Offer dialog & offers sheet ===================== */

void _showOfferDialog(BuildContext context, String requestId) {
  final msg = TextEditingController();
  final eta = TextEditingController();
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: HomePage.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: HomePage.line),
      ),
      title: const Text(
        'Send an offer',
        style: TextStyle(
          color: HomePage.textPrimary,
          fontWeight: FontWeight.w800,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: msg,
            style: const TextStyle(color: HomePage.textPrimary),
            decoration: const InputDecoration(labelText: 'Message'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: eta,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: HomePage.textPrimary),
            decoration: const InputDecoration(
              labelText: 'ETA (hours, optional)',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            final uid = FirebaseAuth.instance.currentUser!.uid;
            await FirebaseFirestore.instance
                .collection('requests')
                .doc(requestId)
                .collection('offers')
                .add({
                  'helperId': uid,
                  'message': msg.text.trim(),
                  'etaHours': int.tryParse(eta.text.trim()),
                  'status': 'PENDING',
                  'createdAt': FieldValue.serverTimestamp(),
                });
            // ignore: use_build_context_synchronously
            Navigator.pop(context);
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Offer sent')));
          },
          style: FilledButton.styleFrom(
            backgroundColor: HomePage.accent,
            foregroundColor: Colors.white,
          ),
          child: const Text('Send'),
        ),
      ],
    ),
  );
}

void _openOffersSheet(BuildContext context, String requestId) {
  showModalBottomSheet(
    context: context,
    backgroundColor: HomePage.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _OffersSheet(requestId: requestId),
  );
}

class _OffersSheet extends StatelessWidget {
  const _OffersSheet({required this.requestId});
  final String requestId;

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance
        .collection('requests')
        .doc(requestId)
        .collection('offers')
        .orderBy('createdAt', descending: true);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 5,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: HomePage.line,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const Text(
            'Offers',
            style: TextStyle(
              color: HomePage.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 10),
          Flexible(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: ref.snapshots(),
              builder: (_, snap) {
                if (!snap.hasData) return const _LoadingList();
                final docs = snap.data!.docs;
                if (docs.isEmpty) return const _EmptyState('No offers yet.');
                return ListView.separated(
                  shrinkWrap: true,
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final o = docs[i].data();
                    return Container(
                      decoration: BoxDecoration(
                        color: HomePage.surfaceAlt,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: HomePage.line),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.white10,
                            child: Icon(Icons.person, color: Colors.white),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  o['message']?.toString().isNotEmpty == true
                                      ? o['message']
                                      : '(no message)',
                                  style: const TextStyle(
                                    color: HomePage.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    _chip('ETA: ${o['etaHours'] ?? '—'}h'),
                                    _chip(
                                      'Status: ${o['status'] ?? 'PENDING'}',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          FilledButton(
                            onPressed: () async {
                              final batch = FirebaseFirestore.instance.batch();
                              final requestRef = FirebaseFirestore.instance
                                  .collection('requests')
                                  .doc(requestId);

                              batch.update(docs[i].reference, {
                                'status': 'ACCEPTED',
                              });
                              for (final other in docs) {
                                if (other.id == docs[i].id) continue;
                                batch.update(other.reference, {
                                  'status': 'DECLINED',
                                });
                              }
                              batch.update(requestRef, {
                                'status': 'MATCHED',
                                'matchedHelperId': o['helperId'],
                              });

                              await batch.commit();
                              // ignore: use_build_context_synchronously
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Offer accepted')),
                              );
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: HomePage.accent,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Accept'),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
