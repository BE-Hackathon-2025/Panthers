import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../config.dart';
import '../home_page.dart';
import '../../services/b2c_auth_service.dart';
import '../../services/swap_request_service.dart';
import '../../models/conversation.dart';
import '../../models/swap_request.dart';
import '../../services/messaging_service.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/message_input.dart';

/// Page for a single chat conversation.
class ChatPage extends StatefulWidget {
  final Conversation conversation;

  const ChatPage({super.key, required this.conversation});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _messagingService = MessagingService();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  List<Message> _messages = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;
  Timer? _pollTimer;

  // Swap request tracking for completion banner
  SwapRequest? _swapRequest;
  bool _loadingSwapRequest = true;

  String get _currentUid => B2CAuthService.instance.currentUser?.uid ?? '';

  String get _otherUid => widget.conversation.participantUids
      .firstWhere((uid) => uid != _currentUid, orElse: () => '');

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _markAsRead();
    _startPolling();
    _loadSwapRequest();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) {
        _loadMessages(silent: true);
        _loadSwapRequest(silent: true);
      },
    );
  }

  Future<void> _loadSwapRequest({bool silent = false}) async {
    try {
      final sr = await SwapRequestService().getRequest(
        widget.conversation.swapRequestId,
        _currentUid,
      );
      if (mounted) {
        setState(() {
          _swapRequest = sr;
          _loadingSwapRequest = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading swap request: $e');
      if (mounted && !silent) {
        setState(() => _loadingSwapRequest = false);
      }
    }
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final messages = await _messagingService.getMessages(
        widget.conversation.id,
        _currentUid,
      );
      if (mounted) {
        setState(() {
          _messages = messages.reversed.toList();
          _loading = false;
        });

        if (!silent) {
          _scrollToBottom();
        }
      }
    } catch (e) {
      debugPrint('Error loading messages: $e');
      if (mounted && !silent) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _markAsRead() async {
    try {
      await _messagingService.markConversationRead(
        widget.conversation.id,
        _currentUid,
      );
    } catch (e) {
      debugPrint('Error marking as read: $e');
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _sending) return;

    setState(() => _sending = true);

    try {
      final message = await _messagingService.sendMessage(
        widget.conversation.id,
        _currentUid,
        content,
      );

      if (mounted) {
        setState(() {
          _messages.add(message);
          _messageController.clear();
          _sending = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Error sending message: $e');
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'block':
        _showBlockDialog();
        break;
      case 'report':
        _showReportDialog();
        break;
    }
  }

  void _showBlockDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: HomePage.surface,
        title: const Text(
          'Block User',
          style: TextStyle(color: HomePage.textPrimary),
        ),
        content: const Text(
          'Are you sure you want to block this user? You won\'t be able to message each other anymore.',
          style: TextStyle(color: HomePage.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              try {
                final uri = Uri.parse(
                  '${AppConfig.apiBaseUrl}/moderation/block',
                ).replace(queryParameters: {'uid': _currentUid});
                final response = await http.post(
                  uri,
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode({
                    'blocked_uid': _otherUid,
                    'reason': 'blocked_from_chat',
                  }),
                );
                if (!mounted) return;
                if (response.statusCode == 200) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('User blocked')),
                  );
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Failed to block user: ${response.statusCode}',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error blocking user: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Block'),
          ),
        ],
      ),
    );
  }

  void _showReportDialog() {
    String selectedReason = 'spam';
    final detailsController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: HomePage.surface,
          title: const Text(
            'Report User',
            style: TextStyle(color: HomePage.textPrimary),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Why are you reporting this user?',
                  style: TextStyle(color: HomePage.textMuted),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedReason,
                  dropdownColor: HomePage.surface,
                  style: const TextStyle(color: HomePage.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Reason',
                    labelStyle: const TextStyle(color: HomePage.textMuted),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: HomePage.line),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'spam', child: Text('Spam')),
                    DropdownMenuItem(value: 'harassment', child: Text('Harassment')),
                    DropdownMenuItem(
                      value: 'inappropriate_content',
                      child: Text('Inappropriate Content'),
                    ),
                    DropdownMenuItem(value: 'scam', child: Text('Scam')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedReason = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: detailsController,
                  maxLines: 3,
                  style: const TextStyle(color: HomePage.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Details',
                    hintText: 'Please describe the issue...',
                    labelStyle: const TextStyle(color: HomePage.textMuted),
                    hintStyle: const TextStyle(color: HomePage.textMuted),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: HomePage.line),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().length < 10) {
                      return 'Please provide at least 10 characters';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                Navigator.of(dialogContext).pop();
                try {
                  final uri = Uri.parse(
                    '${AppConfig.apiBaseUrl}/moderation/report',
                  ).replace(queryParameters: {'uid': _currentUid});
                  final response = await http.post(
                    uri,
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode({
                      'reported_uid': _otherUid,
                      'reason': selectedReason,
                      'details': detailsController.text.trim(),
                      'conversation_id': widget.conversation.id,
                    }),
                  );
                  if (!mounted) return;
                  if (response.statusCode == 200) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Report submitted. Our team will review it.'),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Failed to submit report: ${response.statusCode}',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error submitting report: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.orange),
              child: const Text('Report'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCompletionDialog() {
    final hoursCtrl = TextEditingController(text: '1');
    String skillLevel = 'intermediate';
    final notesCtrl = TextEditingController();
    bool submitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: HomePage.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: HomePage.line),
          ),
          title: const Text(
            'Confirm Swap Completion',
            style: TextStyle(
              color: HomePage.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: hoursCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: HomePage.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Hours spent',
                    hintText: 'e.g. 2',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: skillLevel,
                  dropdownColor: HomePage.surface,
                  style: const TextStyle(color: HomePage.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Skill Level',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'beginner', child: Text('Beginner')),
                    DropdownMenuItem(
                        value: 'intermediate', child: Text('Intermediate')),
                    DropdownMenuItem(value: 'advanced', child: Text('Advanced')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => skillLevel = v);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  style: const TextStyle(color: HomePage.textPrimary),
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    hintText: 'How did the swap go?',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.of(ctx).pop(),
              child: Text('Cancel',
                  style: TextStyle(color: HomePage.textMuted)),
            ),
            FilledButton(
              onPressed: submitting
                  ? null
                  : () async {
                      final hours = double.tryParse(hoursCtrl.text.trim());
                      if (hours == null || hours <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Please enter valid hours.')),
                        );
                        return;
                      }
                      setDialogState(() => submitting = true);
                      try {
                        final updated = await SwapRequestService()
                            .confirmCompletion(
                          _swapRequest!.id,
                          _currentUid,
                          hours: hours,
                          skillLevel: skillLevel,
                          notes: notesCtrl.text.trim().isNotEmpty
                              ? notesCtrl.text.trim()
                              : null,
                        );
                        if (mounted) {
                          setState(() => _swapRequest = updated);
                          _loadMessages(silent: true);
                        }
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      } catch (e) {
                        debugPrint('Confirm error: $e');
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      } finally {
                        if (ctx.mounted) {
                          setDialogState(() => submitting = false);
                        }
                      }
                    },
              style: FilledButton.styleFrom(
                backgroundColor: HomePage.accent,
                foregroundColor: Colors.white,
              ),
              child: submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionBanner() {
    final sr = _swapRequest;
    if (sr == null || _loadingSwapRequest) return const SizedBox.shrink();

    // Only show for accepted or completed swaps
    if (sr.status != SwapRequestStatus.accepted &&
        sr.status != SwapRequestStatus.completed) {
      return const SizedBox.shrink();
    }

    final isRequester = _currentUid == sr.requesterUid;
    final iConfirmed =
        isRequester ? sr.requesterConfirmed : sr.recipientConfirmed;
    final theyConfirmed =
        isRequester ? sr.recipientConfirmed : sr.requesterConfirmed;

    final other = widget.conversation.otherParticipant;
    final otherName = other?.displayName ?? 'the other user';

    // Both confirmed / completed
    if (sr.isCompleted) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: const Color(0xFF0D2818),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: HomePage.success, size: 20),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Swap completed! Points have been awarded.',
                style: TextStyle(
                  color: HomePage.success,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // I confirmed, waiting for them
    if (iConfirmed && !theyConfirmed) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: const Color(0xFF1A1333),
        child: Row(
          children: [
            const Icon(Icons.hourglass_top, color: HomePage.accentAlt, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Waiting for $otherName to confirm completion...',
                style: const TextStyle(
                  color: HomePage.accentAlt,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // They confirmed, I haven't
    if (!iConfirmed && theyConfirmed) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: const Color(0xFF1A2B1A),
        child: Row(
          children: [
            const Icon(Icons.celebration, color: Color(0xFFF59E0B), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$otherName has confirmed completion! Confirm your side to earn points.',
                style: const TextStyle(
                  color: Color(0xFFF59E0B),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 30,
              child: FilledButton(
                onPressed: _showCompletionDialog,
                style: FilledButton.styleFrom(
                  backgroundColor: HomePage.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: const Text('Confirm', style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
      );
    }

    // Neither confirmed
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: HomePage.surface,
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Swap in progress. Done exchanging skills?',
              style: TextStyle(
                color: HomePage.textMuted,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 32,
            child: FilledButton.icon(
              onPressed: _showCompletionDialog,
              icon: const Icon(Icons.check_circle_outline, size: 16),
              label: const Text('Mark Complete', style: TextStyle(fontSize: 12)),
              style: FilledButton.styleFrom(
                backgroundColor: HomePage.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final other = widget.conversation.otherParticipant;
    final displayName = other?.displayName ?? 'User';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    return Scaffold(
      backgroundColor: HomePage.bg,
      appBar: AppBar(
        backgroundColor: HomePage.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: HomePage.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: other?.photoUrl != null && other!.photoUrl!.isNotEmpty
                  ? NetworkImage(other.photoUrl!)
                  : null,
              backgroundColor: HomePage.surfaceAlt,
              child: other?.photoUrl == null || other!.photoUrl!.isEmpty
                  ? Text(
                      initial,
                      style: const TextStyle(
                        color: HomePage.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    color: HomePage.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (other?.skillsToOffer != null) ...[
                  Text(
                    other!.skillsToOffer!.length > 30
                        ? '${other.skillsToOffer!.substring(0, 30)}...'
                        : other.skillsToOffer!,
                    style: const TextStyle(
                      color: HomePage.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            icon: const Icon(Icons.more_vert, color: HomePage.textMuted),
            color: HomePage.surface,
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'block',
                child: Row(
                  children: [
                    Icon(Icons.block, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text('Block User', style: TextStyle(color: HomePage.textPrimary)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.flag, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Text('Report', style: TextStyle(color: HomePage.textPrimary)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildCompletionBanner(),
          Expanded(child: _buildMessageList()),
          MessageInput(
            controller: _messageController,
            onSend: _sendMessage,
            sending: _sending,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
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
              'Error loading messages',
              style: const TextStyle(color: HomePage.textPrimary),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loadMessages,
              style: ElevatedButton.styleFrom(backgroundColor: HomePage.accent),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_messages.isEmpty) {
      return const Center(
        child: Text(
          'No messages yet. Say hello!',
          style: TextStyle(color: HomePage.textMuted),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, i) {
        final message = _messages[i];
        final isMe = message.senderUid == _currentUid;
        final isLast = i == _messages.length - 1;

        return MessageBubble(
          message: message,
          isMe: isMe,
          showReadReceipt: isMe && isLast,
        );
      },
    );
  }
}
