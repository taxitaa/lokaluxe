import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/services/app_strings.dart';
import '../../core/services/game_notification_service.dart';
import '../../core/services/localization_provider.dart';
import '../../core/theme/app_colors.dart';

class NotificationInboxScreen extends StatefulWidget {
  const NotificationInboxScreen({super.key});

  @override
  State<NotificationInboxScreen> createState() =>
      _NotificationInboxScreenState();
}

class _NotificationInboxScreenState extends State<NotificationInboxScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _gameNotifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final notifications = await GameNotificationService.getHistory();
      if (!mounted) return;
      setState(() {
        _gameNotifications = notifications;
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint(
        '[NotificationInboxScreen] Could not load notifications: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<LocalizationProvider>().strings.localized(
              'Notifikasi gagal dimuat. Coba lagi.',
              'Could not load notifications. Please try again.',
            ),
          ),
        ),
      );
    }
  }

  List<_InboxNotification> get _notifications {
    final notifications = _gameNotifications.map((item) {
      return _InboxNotification(
        title: (item['title'] ?? '').toString(),
        body: (item['body'] ?? '').toString(),
        date:
            DateTime.tryParse((item['createdAt'] ?? '').toString()) ??
            DateTime.now(),
        icon: Icons.card_giftcard_rounded,
      );
    }).toList();
    notifications.sort((a, b) => a.date.compareTo(b.date));
    return notifications;
  }

  String _dateLabel(DateTime date, AppStrings strings) {
    final months = strings.langCode == 'id'
        ? const [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
          ]
        : const [
            'Jan',
            'Feb',
            'Mar',
            'Apr',
            'May',
            'Jun',
            'Jul',
            'Aug',
            'Sep',
            'Oct',
            'Nov',
            'Dec',
          ];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final notificationDay = DateTime(date.year, date.month, date.day);
    final daysUntil = notificationDay.difference(today).inDays;
    final dayLabel = switch (daysUntil) {
      0 => strings.localized('Hari ini', 'Today'),
      1 => strings.localized('Besok', 'Tomorrow'),
      _ => '${date.day} ${months[date.month - 1]}',
    };
    final time =
        '${date.hour.toString().padLeft(2, '0')}.'
        '${date.minute.toString().padLeft(2, '0')}';
    return '$dayLabel • $time';
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocalizationProvider>().strings;
    return Scaffold(
      backgroundColor: AppColors.warmCream,
      appBar: AppBar(
        title: Text(
          strings.localized('Notifikasi', 'Notifications'),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        backgroundColor: AppColors.warmCream,
        foregroundColor: AppColors.textDark,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadNotifications,
              child: _notifications.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 150),
                        Icon(
                          Icons.notifications_none_rounded,
                          size: 56,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          strings.localized(
                            'Belum ada notifikasi',
                            'No notifications yet',
                          ),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          strings.localized(
                            'Notifikasi dan hadiah voucher akan muncul di sini.',
                            'Notifications and voucher rewards will appear here.',
                          ),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: _notifications.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) => _buildNotificationCard(
                        _notifications[index],
                        strings,
                      ),
                    ),
            ),
    );
  }

  Widget _buildNotificationCard(
    _InboxNotification notification,
    AppStrings strings,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight.withValues(alpha: 0.7)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primaryGreenSubtle,
            child: Icon(
              notification.icon,
              color: AppColors.primaryGreen,
              size: 20,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        notification.title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _dateLabel(notification.date, strings),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  notification.body,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  'LokaLuxe',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InboxNotification {
  final String title;
  final String body;
  final DateTime date;
  final IconData icon;

  const _InboxNotification({
    required this.title,
    required this.body,
    required this.date,
    required this.icon,
  });
}
