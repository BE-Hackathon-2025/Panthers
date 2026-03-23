// lib/pages/requests_page.dart
import 'package:flutter/material.dart';

import '../models/swap_request.dart';
import '../services/b2c_auth_service.dart';
import '../services/swap_request_service.dart';
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

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this)
      ..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 18, 24, 12),
                    child: Row(
                      children: [
                        const Text(
                          'Swap Requests',
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
                      ],
                    ),
                  ),
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
                          Tab(text: 'Incoming'),
                          Tab(text: 'Sent'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: TabBarView(
                        controller: _tab,
                        children: const [
                          _IncomingTab(),
                          _OutgoingTab(),
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

/* ============================ Incoming Tab ================================ */

class _IncomingTab extends StatefulWidget {
  const _IncomingTab();
  @override
  State<_IncomingTab> createState() => _IncomingTabState();
}

class _IncomingTabState extends State<_IncomingTab> {
  late Future<List<SwapRequest>> _future;
  final _service = SwapRequestService();

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final uid = B2CAuthService.instance.currentUser?.uid ?? '';
    setState(() {
      _future = _service.getIncomingRequests(uid);
    });
  }

  Future<void> _respond(SwapRequest req, bool accept) async {
    final uid = B2CAuthService.instance.currentUser?.uid ?? '';
    try {
      await _service.respondToRequest(req.id, uid, accept);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(accept ? 'Request accepted' : 'Request declined'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SwapRequest>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _LoadingList();
        }
        if (snap.hasError) {
          return _ErrorState('${snap.error}', onRetry: _load);
        }
        final requests = snap.data ?? [];
        if (requests.isEmpty) {
          return const _EmptyState('No incoming swap requests.');
        }
        return ListView.separated(
          itemCount: requests.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _SwapRequestCard(
            request: requests[i],
            isIncoming: true,
            onAccept: requests[i].isPending
                ? () => _respond(requests[i], true)
                : null,
            onDecline: requests[i].isPending
                ? () => _respond(requests[i], false)
                : null,
          ),
        );
      },
    );
  }
}

/* ============================ Outgoing Tab ================================ */

class _OutgoingTab extends StatefulWidget {
  const _OutgoingTab();
  @override
  State<_OutgoingTab> createState() => _OutgoingTabState();
}

class _OutgoingTabState extends State<_OutgoingTab> {
  late Future<List<SwapRequest>> _future;
  final _service = SwapRequestService();

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final uid = B2CAuthService.instance.currentUser?.uid ?? '';
    setState(() {
      _future = _service.getOutgoingRequests(uid);
    });
  }

  Future<void> _cancel(SwapRequest req) async {
    final uid = B2CAuthService.instance.currentUser?.uid ?? '';
    try {
      await _service.cancelRequest(req.id, uid);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request cancelled')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SwapRequest>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _LoadingList();
        }
        if (snap.hasError) {
          return _ErrorState('${snap.error}', onRetry: _load);
        }
        final requests = snap.data ?? [];
        if (requests.isEmpty) {
          return const _EmptyState("You haven't sent any swap requests yet.");
        }
        return ListView.separated(
          itemCount: requests.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _SwapRequestCard(
            request: requests[i],
            isIncoming: false,
            onCancel: requests[i].isPending ? () => _cancel(requests[i]) : null,
          ),
        );
      },
    );
  }
}

/* ========================= Swap Request Card ============================== */

class _SwapRequestCard extends StatelessWidget {
  const _SwapRequestCard({
    required this.request,
    required this.isIncoming,
    this.onAccept,
    this.onDecline,
    this.onCancel,
  });

  final SwapRequest request;
  final bool isIncoming;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final other =
        isIncoming ? request.requesterProfile : request.recipientProfile;
    final statusColor = _statusColor(request.status);

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
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: HomePage.surfaceAlt,
                  backgroundImage: (other?.photoUrl != null &&
                          other!.photoUrl!.isNotEmpty)
                      ? NetworkImage(other.photoUrl!)
                      : null,
                  child:
                      (other?.photoUrl == null || other!.photoUrl!.isEmpty)
                          ? const Icon(
                              Icons.person,
                              color: HomePage.textMuted,
                            )
                          : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        other?.displayName ?? other?.email ?? 'Unknown user',
                        style: const TextStyle(
                          color: HomePage.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        isIncoming
                            ? 'wants to swap with you'
                            : 'swap request sent',
                        style: const TextStyle(
                          color: HomePage.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                _statusBadge(request.status, statusColor),
              ],
            ),
            if (request.message != null && request.message!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                request.message!,
                style: const TextStyle(color: HomePage.textMuted),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip('Offers: ${request.requesterOffer}'),
                _chip('Needs: ${request.requesterNeed}'),
              ],
            ),
            if (onAccept != null || onDecline != null || onCancel != null) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onDecline != null)
                    OutlinedButton(
                      onPressed: onDecline,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: HomePage.textPrimary,
                        side: BorderSide(color: HomePage.line),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Decline'),
                    ),
                  if (onCancel != null)
                    OutlinedButton(
                      onPressed: onCancel,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: HomePage.textPrimary,
                        side: BorderSide(color: HomePage.line),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  if (onAccept != null) ...[
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: onAccept,
                      style: FilledButton.styleFrom(
                        backgroundColor: HomePage.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Accept'),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _statusColor(SwapRequestStatus status) {
    switch (status) {
      case SwapRequestStatus.accepted:
        return Colors.greenAccent;
      case SwapRequestStatus.declined:
        return Colors.redAccent;
      case SwapRequestStatus.cancelled:
        return Colors.grey;
      default:
        return Colors.amberAccent;
    }
  }

  Widget _statusBadge(SwapRequestStatus status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/* ================================ Widgets ================================= */

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

Widget _chip(String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: HomePage.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: HomePage.line),
      ),
      child: Text(
        text,
        style: const TextStyle(color: HomePage.textPrimary, fontSize: 12),
        overflow: TextOverflow.ellipsis,
      ),
    );

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

class _ErrorState extends StatelessWidget {
  const _ErrorState(this.message, {required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline, size: 42, color: Colors.redAccent),
        const SizedBox(height: 10),
        Text(
          'Error: $message',
          style: const TextStyle(color: HomePage.textMuted),
        ),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}
