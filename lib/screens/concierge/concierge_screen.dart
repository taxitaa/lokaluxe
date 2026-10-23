import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/services/concierge_ai_service.dart';
import '../../core/theme/app_colors.dart';

class ConciergeScreen extends StatefulWidget {
  const ConciergeScreen({super.key});

  @override
  State<ConciergeScreen> createState() => _ConciergeScreenState();
}

class _ConciergeScreenState extends State<ConciergeScreen> {
  static const _quickPrompts = [
    'Bantu buat itinerary 3 hari di Bali',
    'Bagaimana mengatur budget trip?',
    'Rekomendasikan wisata di Yogyakarta',
  ];
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _aiService = ConciergeAiService();
  final List<_ChatMessage> _messages = [];
  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    unawaited(_aiService.warmUp());
  }

  Future<void> _sendMessage([String? textToSend]) async {
    final text = (textToSend ?? _messageController.text).trim();
    if (text.isEmpty || _isSending) return;

    _messageController.clear();
    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _isSending = true;
    });
    _scrollToLatest();

    try {
      final conversation = _messages
          .where((message) => message.isUser || !message.isError)
          .map(
            (message) => {
              'role': message.isUser ? 'user' : 'model',
              'text': message.text,
            },
          )
          .toList();
      final reply = await _aiService.reply(conversation: conversation);
      if (!mounted) return;
      setState(() => _messages.add(_ChatMessage(text: reply, isUser: false)));
    } catch (error) {
      if (!mounted) return;
      final message = error is StateError
          ? error.message.toString()
          : 'Terjadi kendala saat menghubungi AI. Silakan coba lagi.';
      setState(() {
        _messages.add(
          _ChatMessage(text: message, isUser: false, isError: true),
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
        _scrollToLatest();
      }
    }
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmCream,
      appBar: AppBar(
        backgroundColor: AppColors.pureWhite,
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: const BoxDecoration(
                color: AppColors.primaryGreenSubtle,
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: ClipOval(
                    child: Transform.scale(
                      scale: 2.5,
                      alignment: const Alignment(0, -0.25),
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.auto_awesome,
                          size: 16,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Concierge',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  'Asisten perjalanan LokaLuxe',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: AppColors.successGreen,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _TempleChatBackground(),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    physics: const BouncingScrollPhysics(),
                    itemCount: _messages.length + (_isSending ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        return const _TypingIndicator();
                      }
                      return _MessageBubble(message: _messages[index]);
                    },
                  ),
                ),
                _buildQuickPrompts(),
                const SizedBox(height: 10),
                _buildComposer(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPrompts() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _quickPrompts.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) => ActionChip(
          avatar: const Icon(
            Icons.auto_awesome_rounded,
            size: 14,
            color: AppColors.primaryGreen,
          ),
          label: Text(
            _quickPrompts[index],
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: AppColors.textDark,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: AppColors.pureWhite.withValues(alpha: 0.88),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: AppColors.accentGold.withValues(alpha: 0.32),
            ),
          ),
          onPressed: _isSending
              ? null
              : () => _sendMessage(_quickPrompts[index]),
        ),
      ),
    );
  }

  Widget _buildComposer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.pureWhite.withValues(alpha: 0.94),
        border: Border(top: BorderSide(color: AppColors.borderLight)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceCream,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.accentGold.withValues(alpha: 0.18),
                ),
              ),
              child: TextField(
                controller: _messageController,
                enabled: !_isSending,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppColors.textDark,
                ),
                decoration: InputDecoration(
                  hintText: 'Tanya seputar perjalanan...',
                  hintStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          CircleAvatar(
            backgroundColor: _isSending
                ? AppColors.textMuted
                : AppColors.primaryGreen,
            child: IconButton(
              tooltip: 'Kirim pesan',
              icon: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 18,
              ),
              onPressed: _isSending ? null : () => _sendMessage(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final bool isError;

  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
  });
}

class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final bubbleColor = isUser
        ? AppColors.pureWhite.withValues(alpha: 0.93)
        : message.isError
        ? AppColors.errorRed.withValues(alpha: 0.08)
        : AppColors.primaryGreenDark.withValues(alpha: 0.96);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          border: Border.all(
            color: isUser
                ? AppColors.borderLight
                : message.isError
                ? AppColors.errorRed.withValues(alpha: 0.3)
                : AppColors.accentGold.withValues(alpha: 0.7),
            width: message.isUser || message.isError ? 1 : 1.3,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FormattedChatText(
              text: message.text,
              color: isUser
                  ? AppColors.textDark
                  : message.isError
                  ? AppColors.errorRed
                  : Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}

class _FormattedChatText extends StatelessWidget {
  final String text;
  final Color color;

  const _FormattedChatText({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    final lines = text
        .replaceAll('\r\n', '\n')
        .split('\n')
        .map((line) => line.trim())
        .toList();
    final widgets = <Widget>[];
    for (final line in lines) {
      if (line.isEmpty) {
        widgets.add(const SizedBox(height: 7));
      } else {
        widgets.add(_buildLine(line));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildLine(String line) {
    final heading = RegExp(r'^#{1,3}\s+(.+)$').firstMatch(line);
    if (heading != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: _richText(
          heading.group(1)!,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      );
    }

    final bullet = RegExp(r'^(?:[-*•])\s+(.+)$').firstMatch(line);
    if (bullet != null) {
      return Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Icon(
                Icons.circle,
                size: 6,
                color: color == Colors.white
                    ? AppColors.accentGold
                    : AppColors.primaryGreen,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(child: _richText(bullet.group(1)!)),
          ],
        ),
      );
    }

    final numbered = RegExp(r'^(\d+)[.)]\s+(.+)$').firstMatch(line);
    if (numbered != null) {
      return Padding(
        padding: const EdgeInsets.only(left: 1, bottom: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 21,
              height: 21,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color == Colors.white
                    ? AppColors.accentGold.withValues(alpha: 0.2)
                    : AppColors.primaryGreenSubtle,
                shape: BoxShape.circle,
              ),
              child: Text(
                numbered.group(1)!,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: color == Colors.white
                      ? AppColors.accentGoldLight
                      : AppColors.primaryGreen,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: _richText(numbered.group(2)!)),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: _richText(line),
    );
  }

  Widget _richText(
    String value, {
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.w500,
  }) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'\*\*(.+?)\*\*');
    var position = 0;
    for (final match in regex.allMatches(value)) {
      if (match.start > position) {
        spans.add(TextSpan(text: value.substring(position, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(1),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      );
      position = match.end;
    }
    if (position < value.length) {
      spans.add(TextSpan(text: value.substring(position)));
    }
    return RichText(
      text: TextSpan(
        style: GoogleFonts.plusJakartaSans(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          height: 1.5,
        ),
        children: spans,
      ),
    );
  }
}

class _TempleChatBackground extends StatelessWidget {
  const _TempleChatBackground();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: AppColors.warmCream),
          Image.asset(
            'assets/images/dest_borobudur.jpg',
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.pureWhite,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Text(
          'AI sedang menyiapkan jawaban...',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
