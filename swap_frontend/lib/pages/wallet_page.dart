import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/points.dart';
import '../services/b2c_auth_service.dart';
import '../services/points_service.dart';
import '../widgets/app_sidebar.dart';
import 'home_page.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  final _pointsService = PointsService();
  bool _loading = true;
  String? _error;
  PointsBalance? _balance;
  List<PointsTransaction> _history = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final uid = B2CAuthService.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _pointsService.getBalance(uid),
        _pointsService.getHistory(uid),
      ]);
      if (mounted) {
        setState(() {
          _balance = results[0] as PointsBalance;
          _history = results[1] as List<PointsTransaction>;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const bg = HomePage.bg;
    const surface = HomePage.surface;
    const textPrimary = HomePage.textPrimary;
    const textMuted = HomePage.textMuted;
    const line = HomePage.line;
    const accent = HomePage.accent;

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
    );

    return Theme(
      data: theme,
      child: Scaffold(
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppSidebar(active: 'Dashboard'),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: accent),
                    )
                  : _error != null
                      ? _buildErrorState()
                      : _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 56,
              color: HomePage.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: const TextStyle(
                color: HomePage.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: HomePage.textMuted,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(
                backgroundColor: HomePage.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page header
            const Text(
              'Wallet',
              style: TextStyle(
                color: HomePage.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Track your points, credits, and swap activity',
              style: TextStyle(
                color: HomePage.textMuted,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),

            // Stat cards row
            LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth =
                    (constraints.maxWidth - 32) / 3; // 2 gaps x 16
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _StatCard(
                      width: cardWidth.clamp(200, double.infinity),
                      icon: Icons.monetization_on_rounded,
                      iconColor: HomePage.accent,
                      iconBgColor: const Color(0xFF1A1333),
                      value: '${_balance?.points ?? 0}',
                      label: 'Points',
                    ),
                    _StatCard(
                      width: cardWidth.clamp(200, double.infinity),
                      icon: Icons.star_rounded,
                      iconColor: const Color(0xFF22C55E),
                      iconBgColor: const Color(0xFF0D2818),
                      value: '${_balance?.credits ?? 0}',
                      label: 'Credits',
                    ),
                    _StatCard(
                      width: cardWidth.clamp(200, double.infinity),
                      icon: Icons.swap_horiz_rounded,
                      iconColor: const Color(0xFFF59E0B),
                      iconBgColor: const Color(0xFF2D1F05),
                      value: '${_balance?.totalSwapsCompleted ?? 0}',
                      label: 'Swaps Completed',
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 32),

            // Recent Activity header
            const Text(
              'Recent Activity',
              style: TextStyle(
                color: HomePage.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),

            // Transaction list
            _history.isEmpty
                ? _buildEmptyHistory()
                : _buildTransactionList(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyHistory() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: HomePage.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HomePage.line),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.receipt_long_outlined,
            size: 48,
            color: HomePage.textMuted,
          ),
          const SizedBox(height: 16),
          const Text(
            'No transactions yet',
            style: TextStyle(
              color: HomePage.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Complete your first swap to earn points!',
            style: TextStyle(
              color: HomePage.textMuted,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList() {
    return Container(
      decoration: BoxDecoration(
        color: HomePage.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HomePage.line),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _history.length,
        separatorBuilder: (_, __) =>
            const Divider(color: HomePage.line, height: 1),
        itemBuilder: (context, index) {
          final tx = _history[index];
          return _TransactionTile(transaction: tx);
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stat card widget
// ---------------------------------------------------------------------------

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.width,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.value,
    required this.label,
  });

  final double width;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: HomePage.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: HomePage.line),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      color: HomePage.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: const TextStyle(
                      color: HomePage.textMuted,
                      fontSize: 13,
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

// ---------------------------------------------------------------------------
// Transaction list tile
// ---------------------------------------------------------------------------

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction});

  final PointsTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final isEarned = transaction.type == PointsTransactionType.earned;
    final txIcon = isEarned ? Icons.arrow_upward : Icons.arrow_downward;
    final txColor = isEarned ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
    final sign = isEarned ? '+' : '-';

    final dateFmt = DateFormat('MMM d, yyyy');
    final dateStr = dateFmt.format(transaction.createdAt);

    // Build amount string showing non-zero values.
    final parts = <String>[];
    if (transaction.points != 0) {
      parts.add('$sign${transaction.points} pts');
    }
    if (transaction.credits != 0) {
      parts.add('$sign${transaction.credits} cr');
    }
    final amountStr = parts.isNotEmpty ? parts.join('  ') : '${sign}0 pts';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          // Icon circle
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: txColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(txIcon, color: txColor, size: 20),
          ),
          const SizedBox(width: 14),

          // Description + date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: HomePage.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateStr,
                  style: const TextStyle(
                    color: HomePage.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Amount
          Text(
            amountStr,
            style: TextStyle(
              color: txColor,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
