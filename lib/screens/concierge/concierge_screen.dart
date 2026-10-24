import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/database/db_helper.dart';
import '../../core/models/trip_model.dart';
import '../../core/services/concierge_ai_service.dart';
import '../../core/services/trip_reminder_service.dart';
import '../../core/services/trip_request_parser.dart';
import '../../core/theme/app_colors.dart';
import '../itinerary/itinerary_screen.dart';

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
  TripRequest _tripRequest = const TripRequest();
  bool _awaitingItineraryConfirmation = false;
  bool _collectingTripDetails = false;
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
      if (_awaitingItineraryConfirmation && _isConfirmation(text)) {
        _awaitingItineraryConfirmation = false;
        _collectingTripDetails = true;
        final details = text.replaceFirst(
          RegExp(
            r'^(?:ya|iya|yap|mau|boleh|setuju|oke|ok|gas|buatkan|lanjut|yes)\b[,\s]*',
            caseSensitive: false,
          ),
          '',
        );
        _tripRequest = parseTripRequest(details);
        await _continueItineraryCreation();
        return;
      }
      if (_awaitingItineraryConfirmation &&
          RegExp(
            r'^(?:tidak|nggak|enggak|belum|nanti|no)\b',
            caseSensitive: false,
          ).hasMatch(text)) {
        _awaitingItineraryConfirmation = false;
      }
      if (_collectingTripDetails) {
        _tripRequest = _tripRequest.merge(parseTripRequest(text));
        await _continueItineraryCreation();
        return;
      }

      final conversation = _messages
          .where((message) => message.isUser || !message.isError)
          .map(
            (message) => {
              'role': message.isUser ? 'user' : 'model',
              'text': message.text,
            },
          )
          .toList();
      var reply = await _aiService.reply(conversation: conversation);
      if (_shouldOfferItinerary(text)) {
        reply =
            '$reply\n\nMau aku susunkan itinerary lengkap dan '
            'menyimpannya otomatis ke menu Itinerary serta Budget Planner? '
            'Balas "mau" untuk mulai.';
        _awaitingItineraryConfirmation = true;
      }
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

  bool _isConfirmation(String text) => RegExp(
    r'^(?:ya|iya|yap|mau|boleh|setuju|oke|ok|gas|buatkan|lanjut|yes)\b',
    caseSensitive: false,
  ).hasMatch(text.trim());

  bool _shouldOfferItinerary(String text) => RegExp(
    r'\b(?:itinerary|itenerary|itinerari|rekomendasi|rekomendasikan|saran|liburan|wisata|budget|trip|perjalanan)\b',
    caseSensitive: false,
  ).hasMatch(text);

  Future<void> _continueItineraryCreation() async {
    final request = _tripRequest;
    if (request.missingFields.isNotEmpty) {
      final missing = request.missingFields
          .map((field) => '- $field')
          .join('\n');
      setState(
        () => _messages.add(
          _ChatMessage(
            text:
                'Siap, aku bantu buatkan dan simpan itinerary-mu. '
                'Supaya rencananya lengkap, kirim data berikut:\n$missing\n\n'
                'Contoh: Tujuan: Bali; tanggal mulai: 01/11/2026; '
                'durasi: 3 hari; jumlah orang: 2; budget: Rp5.000.000.',
            isUser: false,
          ),
        ),
      );
      return;
    }

    final destination = request.destination!;
    final startDate = request.startDate!;
    final durationDays = request.durationDays!;
    final travelerCount = request.travelerCount!;
    final budget = request.budget!;
    final today = DateTime.now();
    if (startDate.isBefore(DateTime(today.year, today.month, today.day))) {
      setState(
        () => _messages.add(
          const _ChatMessage(
            text:
                'Tanggal mulai harus hari ini atau tanggal mendatang. '
                'Kirim tanggal baru dalam format DD/MM/YYYY.',
            isUser: false,
          ),
        ),
      );
      return;
    }
    if (durationDays < 1 || durationDays > 30) {
      setState(
        () => _messages.add(
          const _ChatMessage(
            text:
                'Durasi itinerary harus antara 1 sampai 30 hari. '
                'Kirim jumlah hari yang sesuai.',
            isUser: false,
          ),
        ),
      );
      return;
    }
    if (travelerCount < 1 || budget <= 0) {
      setState(
        () => _messages.add(
          const _ChatMessage(
            text:
                'Jumlah orang dan total budget harus lebih dari nol. '
                'Kirim jumlah orang serta budget yang valid.',
            isUser: false,
          ),
        ),
      );
      return;
    }

    final days = await _aiService.generateItinerary(
      destination: destination,
      startDate: startDate,
      durationDays: durationDays,
      travelerCount: travelerCount,
    );
    final trip = TripModel(
      destination: destination,
      destinationTitle: destination,
      dates: startDate.toIso8601String(),
      duration: '$durationDays hari',
      durationDays: durationDays,
      travelerCount: travelerCount,
      targetBudget: budget,
      transportAllocation: 0,
      hotelAllocation: 0,
      culinaryAllocation: 0,
      activityAllocation: 0,
    );
    final tripId = await DBHelper.saveTripWithItinerary(trip: trip, days: days);

    var reminderMessage =
        'Pengingat dijadwalkan pukul 09.00 pada H-7, H-5, H-3, dan hari-H.';
    try {
      final reminderResult = await TripReminderService.schedule(
        tripId: tripId,
        destination: destination,
        startDate: startDate,
      );
      if (reminderResult == TripReminderResult.permissionRequested) {
        reminderMessage +=
            ' Izinkan notifikasi saat diminta agar pengingat tampil.';
      } else if (reminderResult == TripReminderResult.unsupported) {
        reminderMessage = 'Pengingat otomatis tersedia di aplikasi Android.';
      }
    } catch (error, stackTrace) {
      debugPrint('[ConciergeScreen] Could not schedule trip reminders: $error');
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'trip reminders',
          context: ErrorDescription('while scheduling itinerary reminders'),
        ),
      );
      reminderMessage =
          'Itinerary dan budget tersimpan, tetapi pengingat gagal dijadwalkan.';
    }

    _collectingTripDetails = false;
    setState(
      () => _messages.add(
        _ChatMessage(
          text:
              'Itinerary $destination selama $durationDays hari untuk '
              '$travelerCount orang berhasil disimpan. Budget '
              'Rp${budget.toStringAsFixed(0)} sudah masuk ke Budget Planner.\n\n'
              '$reminderMessage',
          isUser: false,
        ),
      ),
    );
    if (!mounted) return;
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const ItineraryScreen()));
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
        centerTitle: false,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        actions: const [SizedBox(width: 82)],
        flexibleSpace: const _ConciergeHeaderBackground(),
        title: Row(
          children: [
            const _ConciergeAvatar(size: 58),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Concierge',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  Text(
                    'Asisten perjalanan LokaLuxe',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: const Color(0xFF678778),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD7E9B8),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '✦  Selalu siap membantu!',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: AppColors.successGreen,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                physics: const BouncingScrollPhysics(),
                itemCount: _messages.length + (_isSending ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length) {
                    return const _TypingIndicator();
                  }
                  return _MessageBubble(
                    message: _messages[index],
                    avatarUsesClosedEyes: _messages
                        .take(index + 1)
                        .where((message) => !message.isUser)
                        .length
                        .isEven,
                  );
                },
              ),
            ),
            if (_messages.isEmpty) _buildQuickPrompts(),
            _buildComposer(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickPrompts() {
    return SizedBox(
      height: 48,
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
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: AppColors.warmCream,
        border: Border(top: BorderSide(color: AppColors.borderLight)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.pureWhite,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.035),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      enabled: !_isSending,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: AppColors.textDark,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Tanya seputar perjalanan...',
                        hintStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          color: AppColors.textMuted,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.only(
                          left: 16,
                          right: 14,
                          top: 13,
                          bottom: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          CircleAvatar(
            radius: 25,
            backgroundColor: _isSending
                ? AppColors.textMuted
                : AppColors.primaryGreen,
            child: IconButton(
              tooltip: 'Kirim pesan',
              icon: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 21,
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
  final bool avatarUsesClosedEyes;

  const _MessageBubble({
    required this.message,
    required this.avatarUsesClosedEyes,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final bubbleColor = isUser
        ? AppColors.primaryGreen
        : const Color(0xFFF0E9E3);

    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.74,
      ),
      padding: isUser
          ? const EdgeInsets.symmetric(horizontal: 17, vertical: 15)
          : const EdgeInsets.fromLTRB(58, 14, 17, 15),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(28),
          topRight: const Radius.circular(28),
          bottomLeft: Radius.circular(isUser ? 28 : 8),
          bottomRight: Radius.circular(isUser ? 8 : 28),
        ),
      ),
      child: _FormattedChatText(
        text: message.text,
        color: isUser
            ? Colors.white
            : message.isError
            ? AppColors.errorRed
            : const Color(0xFF333333),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 17),
      child: isUser
          ? Align(alignment: Alignment.centerRight, child: bubble)
          : Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.82,
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 28),
                      child: bubble,
                    ),
                    Positioned(
                      left: 0,
                      top: 0,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          _ConciergeAvatar(
                            size: 64,
                            closedEyes: avatarUsesClosedEyes,
                          ),
                          const Positioned(
                            top: -2,
                            right: -8,
                            child: Icon(
                              Icons.auto_awesome_rounded,
                              size: 15,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _ConciergeAvatar extends StatelessWidget {
  final double size;
  final bool closedEyes;

  const _ConciergeAvatar({required this.size, this.closedEyes = false});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      closedEyes
          ? 'assets/images/lokacatch_komodo_closed.png'
          : 'assets/images/lokacatch_komodo_open.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      semanticLabel: 'Maskot AI Concierge',
    );
  }
}

class _ConciergeHeaderBackground extends StatelessWidget {
  const _ConciergeHeaderBackground();

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: const _HeaderWaveClipper(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xFFF1F5E5)),
          CustomPaint(painter: _HeaderWavePainter()),
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
          Positioned(
            right: 98,
            bottom: 31,
            child: Icon(
              Icons.route_rounded,
              color: const Color(0xFF95AF6C).withValues(alpha: 0.8),
              size: 23,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderWaveClipper extends CustomClipper<Path> {
  const _HeaderWaveClipper();

  @override
  Path getClip(Size size) {
    return Path()
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
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _HeaderWavePainter extends CustomPainter {
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
        size.height * 0.64,
      )
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
          color: const Color(0xFFF0E9E3),
          borderRadius: BorderRadius.circular(24),
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
