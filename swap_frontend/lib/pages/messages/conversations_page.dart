import 'dart:async';

import 'package:flutter/material.dart';

import '../home_page.dart';
import '../../services/b2c_auth_service.dart';
import '../../models/conversation.dart';
import '../../services/messaging_service.dart';
import '../../widgets/app_sidebar.dart';
import '../../widgets/conversation_tile.dart';
import 'chat_page.dart';

/// Page displaying list of all conversations.
class ConversationsPage extends StatefulWidget {
  const ConversationsPage({super.key});

  @override
  State<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends State<ConversationsPage> {
  final _messagingService = MessagingService();
  List<Conversation> _conversations = [];
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;

  String? get _currentUid => B2CAuthService.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _loadConversations();
    // Auto-refresh every 30 seconds
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadConversations(silent: true),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadConversations({bool silent = false}) async {
    final uid = _currentUid;
    if (uid == null) {
      setState(() {
        _loading = false;
        _error = 'Not signed in';
      });
      return;
    }

    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final response = await _messagingService.getConversations(uid);
      if (mounted) {
        setState(() {
          _conversations = response.conversations;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      debugPrint('Error loading conversations: $e');
      if (mounted && !silent) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  void _openChat(Conversation conversation) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatPage(conversation: conversation),
      ),
    );
    // Refresh conversations when returning from chat
    _loadConversations(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomePage.bg,
      body: Row(
        children: [
          const AppSidebar(active: 'Messages'),
          Expanded(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _buildBody(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: HomePage.surface,
        border: Border(bottom: BorderSide(color: HomePage.line)),
      ),
      child: Row(
        children: [
          const Text(
            'Messages',
            style: TextStyle(
              color: HomePage.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => _loadConversations(),
            icon: const Icon(Icons.refresh, color: HomePage.textMuted),
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: HomePage.accent),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: HomePage.textMuted),
            const SizedBox(height: 16),
            Text(
              'Error loading conversations',
              style: const TextStyle(color: HomePage.textPrimary, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: HomePage.textMuted, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadConversations,
              style: ElevatedButton.styleFrom(
                backgroundColor: HomePage.accent,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_conversations.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadConversations,
      color: HomePage.accent,
      child: ListView.builder(
        itemCount: _conversations.length,
        itemBuilder: (context, i) => ConversationTile(
          conversation: _conversations[i],
          currentUid: _currentUid!,
          onTap: () => _openChat(_conversations[i]),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: HomePage.textMuted.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'No conversations yet',
            style: TextStyle(
              color: HomePage.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Accept a swap request to start chatting!',
            style: TextStyle(color: HomePage.textMuted, fontSize: 14),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.search),
            label: const Text('Find Matches'),
            style: ElevatedButton.styleFrom(
              backgroundColor: HomePage.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
