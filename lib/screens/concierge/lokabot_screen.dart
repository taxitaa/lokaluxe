import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/services/lokabot_service.dart';
import '../../core/theme/app_colors.dart';
import 'concierge_screen.dart';

class LokaBotScreen extends StatefulWidget {
  const LokaBotScreen({super.key});

  @override
  State<LokaBotScreen> createState() => _LokaBotScreenState();
}

class _LokaBotScreenState extends State<LokaBotScreen> {
  static const _examples = [
    'Sisa anggaran saya berapa?',
    'Wisata di Yogyakarta',
    'Hotel di bawah 500 ribu',
  ];

  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_LokaBotMessage> _messages = [];
  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage([String? suggestion]) async {
    final text = (suggestion ?? _messageController.text).trim();
    if (text.isEmpty || _isSending) return;

    _messageController.clear();
    setState(() {
      _messages.add(_LokaBotMessage(text: text, isUser: true));
      _isSending = true;
    });
    _scrollToLatest();

    try {
      final reply = await jawabLokaBot(text);
      if (!mounted) return;
      setState(() {
        _messages.add(
          _LokaBotMessage(
            text: reply.text,
            isUser: false,
            showConciergeButton: !reply.isRecognized,
          ),
        );
      });
    } catch (error, stackTrace) {
      debugPrint('[LokaBotScreen] Could not answer from local data: $error');
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'LokaBot',
          context: ErrorDescription('while reading local travel data'),
        ),
      );
      if (!mounted) return;
      setState(() {
        _messages.add(
          _LokaBotMessage(
            text: 'Data lokal tidak dapat dibaca: $error',
            isUser: false,
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
        _scrollToLatest();
      }
    }
  }

  void _openConcierge() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ConciergeScreen(),
      ),
    );
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
        toolbarHeight: 120,
        backgroundColor: AppColors.warmCream,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 12,
        title: Row(
          children: [
            IconButton(
              tooltip: 'Kembali',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppColors.primaryGreen,
                size: 19,
              ),
            ),
            const _MonkeyHeadAvatar(
              size: 62,
              semanticLabel: 'Maskot LokaBot, orangutan',
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'LokaBot',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  Text(
                    'Asisten offline LokaLuxe',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 5),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.badgeGreenBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      child: Text(
                        'Offline • tanpa internet',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppColors.successGreen,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        flexibleSpace: const _LokaBotHeaderBackground(),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _buildExamples()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                    itemCount: _messages.length + (_isSending ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        return const _TypingIndicator();
                      }
                      final message = _messages[index];
                      return _MessageBubble(
                        message: message,
                        onOpenConcierge:
                            message.showConciergeButton ? _openConcierge : null,
                      );
                    },
                  ),
          ),
          _buildComposer(),
        ],
      ),
    );
  }

  Widget _buildExamples() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 16),
      children: [
        Text(
          'Ada yang bisa saya bantu?',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 12),
        for (final example in _examples)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ActionChip(
              onPressed: _isSending ? null : () => _sendMessage(example),
              backgroundColor: AppColors.pureWhite,
              side: BorderSide(color: AppColors.borderLight),
              shape: const StadiumBorder(),
              label: Text(
                example,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: AppColors.textDark,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildComposer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: AppColors.warmCream,
        border: Border(top: BorderSide(color: AppColors.borderLight)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                enabled: !_isSending,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppColors.textDark,
                ),
                decoration: InputDecoration(
                  hintText: 'Tanya seputar perjalananmu...',
                  hintStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                  filled: true,
                  fillColor: AppColors.pureWhite,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: const BorderSide(
                      color: AppColors.primaryGreen,
                      width: 1,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 52,
              height: 52,
              child: IconButton.filled(
                onPressed: _isSending ? null : () => _sendMessage(),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  disabledBackgroundColor: AppColors.textMuted,
                  foregroundColor: Colors.white,
                  shape: const CircleBorder(),
                ),
                icon: const Icon(Icons.send_rounded, size: 21),
                tooltip: 'Kirim',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LokaBotMessage {
  final String text;
  final bool isUser;
  final bool showConciergeButton;

  const _LokaBotMessage({
    required this.text,
    required this.isUser,
    this.showConciergeButton = false,
  });
}

class _MessageBubble extends StatelessWidget {
  final _LokaBotMessage message;
  final VoidCallback? onOpenConcierge;

  const _MessageBubble({required this.message, this.onOpenConcierge});

  @override
  Widget build(BuildContext context) {
    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(
        color: message.isUser ? AppColors.primaryGreen : AppColors.surfaceCream,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(19),
          topRight: const Radius.circular(19),
          bottomLeft: Radius.circular(message.isUser ? 19 : 5),
          bottomRight: Radius.circular(message.isUser ? 5 : 19),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              height: 1.5,
              color: message.isUser ? Colors.white : AppColors.textDark,
            ),
          ),
          if (onOpenConcierge != null) ...[
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: onOpenConcierge,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                textStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              icon: const Icon(Icons.auto_awesome_rounded, size: 15),
              label: const Text('Buka AI Concierge'),
            ),
          ],
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: message.isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            const Padding(
              padding: EdgeInsets.only(top: 5, right: 8),
              child: _MonkeyHeadAvatar(
                size: 42,
                semanticLabel: 'Orangutan LokaBot',
                showSparkle: true,
              ),
            ),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 330),
              child: bubble,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonkeyHeadAvatar extends StatelessWidget {
  const _MonkeyHeadAvatar({
    required this.size,
    required this.semanticLabel,
    this.showSparkle = false,
  });

  static const _sourceSize = 736.0;
  static const _cropLeft = 305.0;
  static const _cropTop = 215.0;
  static const _cropSize = 165.0;

  final double size;
  final String semanticLabel;
  final bool showSparkle;

  @override
  Widget build(BuildContext context) {
    final imageSize = size * _sourceSize / _cropSize;

    return Semantics(
      image: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: SizedBox(
          width: size + (showSparkle ? 6 : 0),
          height: size + (showSparkle ? 4 : 0),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              SizedBox(
                width: size,
                height: size,
                child: ClipPath(
                  clipper: const _MonkeyHeadClipper(),
                  child: ClipRect(
                    child: OverflowBox(
                      alignment: Alignment.topLeft,
                      minWidth: imageSize,
                      maxWidth: imageSize,
                      minHeight: imageSize,
                      maxHeight: imageSize,
                      child: Transform.translate(
                        offset: Offset(
                          -_cropLeft * size / _cropSize,
                          -_cropTop * size / _cropSize,
                        ),
                        child: Image.asset(
                          'assets/images/monyet.jpeg',
                          width: imageSize,
                          height: imageSize,
                          fit: BoxFit.fill,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (showSparkle)
                Positioned(
                  top: -3,
                  right: 0,
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: size * .29,
                    color: AppColors.primaryGreen,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonkeyHeadClipper extends CustomClipper<Path> {
  const _MonkeyHeadClipper();

  @override
  Path getClip(Size size) {
    double x(double fraction) => size.width * fraction;
    double y(double fraction) => size.height * fraction;

    return Path()
      ..moveTo(x(.49), y(.07))
      ..cubicTo(x(.60), y(.08), x(.68), y(.12), x(.74), y(.22))
      ..cubicTo(x(.79), y(.28), x(.79), y(.34), x(.82), y(.40))
      ..cubicTo(x(.90), y(.41), x(.94), y(.46), x(.93), y(.53))
      ..cubicTo(x(.92), y(.60), x(.87), y(.62), x(.82), y(.63))
      ..cubicTo(x(.80), y(.76), x(.73), y(.84), x(.63), y(.88))
      ..cubicTo(x(.58), y(.91), x(.51), y(.94), x(.43), y(.91))
      ..cubicTo(x(.32), y(.88), x(.25), y(.81), x(.21), y(.72))
      ..cubicTo(x(.19), y(.67), x(.17), y(.64), x(.12), y(.63))
      ..cubicTo(x(.06), y(.62), x(.04), y(.57), x(.04), y(.52))
      ..cubicTo(x(.04), y(.46), x(.08), y(.42), x(.16), y(.40))
      ..cubicTo(x(.18), y(.32), x(.20), y(.25), x(.26), y(.18))
      ..cubicTo(x(.32), y(.11), x(.39), y(.08), x(.49), y(.07))
      ..close();
  }

  @override
  bool shouldReclip(covariant _MonkeyHeadClipper oldClipper) => false;
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          const _MonkeyHeadAvatar(
            size: 42,
            semanticLabel: 'Orangutan LokaBot sedang mengetik',
            showSparkle: true,
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
            decoration: BoxDecoration(
              color: AppColors.surfaceCream,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              'LokaBot sedang mengetik...',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LokaBotHeaderBackground extends StatelessWidget {
  const _LokaBotHeaderBackground();

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: const _LokaBotHeaderClipper(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xFFF1F5E5)),
          CustomPaint(painter: _LokaBotHeaderPainter()),
          const Positioned(
            right: 66,
            top: 29,
            child: Icon(
              Icons.flight_rounded,
              color: AppColors.primaryGreen,
              size: 34,
            ),
          ),
          const Positioned(
            right: 22,
            bottom: 26,
            child: Icon(Icons.map_rounded, color: Color(0xFF8EB17E), size: 30),
          ),
          const Positioned(
            right: 39,
            top: 53,
            child: Icon(Icons.auto_awesome, color: Color(0xFFC4CF5D), size: 17),
          ),
        ],
      ),
    );
  }
}

class _LokaBotHeaderClipper extends CustomClipper<Path> {
  const _LokaBotHeaderClipper();

  @override
  Path getClip(Size size) => Path()
    ..lineTo(0, size.height * 0.68)
    ..quadraticBezierTo(
      size.width * 0.22,
      size.height * 0.96,
      size.width * 0.42,
      size.height * 0.76,
    )
    ..quadraticBezierTo(
      size.width * 0.70,
      size.height * 0.52,
      size.width,
      size.height * 0.78,
    )
    ..lineTo(size.width, 0)
    ..close();

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _LokaBotHeaderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFE6EED2);
    final path = Path()
      ..moveTo(0, size.height * 0.50)
      ..quadraticBezierTo(
        size.width * 0.20,
        size.height * 0.05,
        size.width * 0.42,
        size.height * 0.42,
      )
      ..quadraticBezierTo(
        size.width * 0.70,
        size.height * 0.76,
        size.width,
        size.height * 0.38,
      )
      ..lineTo(size.width, size.height * 0.73)
      ..quadraticBezierTo(
        size.width * 0.71,
        size.height * 0.49,
        size.width * 0.42,
        size.height * 0.76,
      )
      ..quadraticBezierTo(
        size.width * 0.20,
        size.height * 0.94,
        0,
        size.height * 0.70,
      )
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
