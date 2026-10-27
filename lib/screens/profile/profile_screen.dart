import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/database/db_helper.dart';
import '../../core/models/user_model.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/game_notification_service.dart';
import '../../core/services/localization_provider.dart';
import '../../core/services/preferences_service.dart';
import '../../core/services/supabase_auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../auth/login_screen.dart';
import '../../core/models/voucher_data.dart';
import 'feedback_screen.dart';
import 'security_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _feedbackController = TextEditingController();
  UserModel? _currentUser;
  Uint8List? _profilePhoto;
  int? _completedTrips;
  bool _statsLoadFailed = false;
  bool _isSubmittingFeedback = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    final user = await AuthService.checkSession();
    if (user != null && mounted) {
      Uint8List? photo;
      try {
        final savedPhoto = await PreferencesService.getProfilePhoto(
          _profilePhotoKey(user),
        );
        if (savedPhoto != null) photo = base64Decode(savedPhoto);
      } catch (error, stackTrace) {
        debugPrint('[Profile] Gagal memuat foto profil: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      setState(() {
        _currentUser = user;
        _profilePhoto = photo;
      });
      await _loadProfileStats();
    }
  }

  String _profilePhotoKey(UserModel user) =>
      user.id?.toString() ?? user.email.trim().toLowerCase();

  Future<void> _loadProfileStats() async {
    try {
      final completedTrips = await DBHelper.getCompletedTripCount();
      if (!mounted) return;
      setState(() {
        _completedTrips = completedTrips;
        _statsLoadFailed = false;
      });
    } catch (error, stackTrace) {
      debugPrint('[Profile] Gagal memuat statistik profil: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => _statsLoadFailed = true);
    }
  }

  Future<void> _chooseProfilePhoto() async {
    final user = _currentUser;
    if (user == null) return;
    try {
      final photo = await ProfilePhotoService.pickProfilePhoto();
      if (photo == null) return;
      await PreferencesService.setProfilePhoto(
        _profilePhotoKey(user),
        base64Encode(photo),
      );
      if (mounted) setState(() => _profilePhoto = photo);
    } on UnsupportedError catch (error) {
      _showMessage(
        error.message ?? 'Fitur foto belum tersedia di perangkat ini.',
      );
    } on PlatformException catch (error, stackTrace) {
      debugPrint('[Profile] Gagal memilih foto profil: $error');
      debugPrintStack(stackTrace: stackTrace);
      _showMessage('Foto profil tidak dapat dibuka. Silakan coba lagi.');
    } on MissingPluginException catch (error, stackTrace) {
      debugPrint('[Profile] Pemilih foto tidak tersedia: $error');
      debugPrintStack(stackTrace: stackTrace);
      _showMessage('Pemilih foto belum tersedia. Mulai ulang aplikasi.');
    } catch (error, stackTrace) {
      debugPrint('[Profile] Gagal menyimpan foto profil: $error');
      debugPrintStack(stackTrace: stackTrace);
      _showMessage('Foto profil gagal disimpan. Silakan coba lagi.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showLanguagePicker() async {
    final localization = context.read<LocalizationProvider>();
    final strings = localization.strings;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.selectLanguage,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              _languageOption(
                context: sheetContext,
                localization: localization,
                languageCode: 'id',
                label: strings.indonesianLanguage,
              ),
              _languageOption(
                context: sheetContext,
                localization: localization,
                languageCode: 'en',
                label: strings.englishLanguage,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _languageOption({
    required BuildContext context,
    required LocalizationProvider localization,
    required String languageCode,
    required String label,
  }) {
    final isSelected = localization.langCode == languageCode;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: AppColors.primaryGreen)
          : null,
      onTap: () async {
        Navigator.of(context).pop();
        try {
          await localization.setLanguage(languageCode);
        } catch (error, stackTrace) {
          debugPrint('[Profile] Gagal menyimpan bahasa aplikasi: $error');
          debugPrintStack(stackTrace: stackTrace);
          _showMessage('Bahasa tidak dapat disimpan. Silakan coba lagi.');
        }
      },
    );
  }

  Future<void> _submitFeedback() async {
    final user = _currentUser;
    final comment = _feedbackController.text.trim();
    if (_isSubmittingFeedback) return;
    if (user == null) {
      _showMessage('Sesi akun tidak ditemukan. Silakan masuk kembali.');
      return;
    }
    if (comment.isEmpty) {
      _showMessage('Tulis kritik atau saran terlebih dahulu.');
      return;
    }
    if (comment.length > 2000) {
      _showMessage('Kritik dan saran maksimal 2.000 karakter.');
      return;
    }

    setState(() => _isSubmittingFeedback = true);
    try {
      await SupabaseAuthService.submitPublicFeedback(
        accountEmail: user.email,
        comment: comment,
      );
      _feedbackController.clear();
      if (mounted) {
        _showMessage(
          'Kritik dan saran terkirim dan sudah muncul di halamannya.',
        );
      }
    } catch (error, stackTrace) {
      debugPrint('[Profile] Gagal mengirim kritik dan saran: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        _showMessage(
          error is SupabaseAuthException
              ? error.message
              : 'Kritik dan saran gagal dikirim. Coba lagi nanti.',
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmittingFeedback = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LocalizationProvider>().strings;
    final displayName = _currentUser?.fullName.isNotEmpty == true
        ? _currentUser!.fullName
        : 'Amalia Nur Azizah';
    final displayEmail = _currentUser?.email.isNotEmpty == true
        ? _currentUser!.email
        : 'amalia.azizah@travel.id';
    final initials = displayName
        .trim()
        .split(' ')
        .map((e) => e.isNotEmpty ? e[0] : '')
        .take(2)
        .join()
        .toUpperCase();

    return Scaffold(
      backgroundColor: AppColors.warmCream,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Header Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.pureWhite,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.borderLight, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _chooseProfilePhoto,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: AppColors.primaryGreen,
                            backgroundImage: _profilePhoto == null
                                ? null
                                : MemoryImage(_profilePhoto!),
                            child: _profilePhoto == null
                                ? Text(
                                    initials.isNotEmpty ? initials : 'LX',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: AppColors.accentGold,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.edit_rounded,
                                size: 12,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  displayName,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textDark,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.verified_rounded,
                                size: 16,
                                color: AppColors.primaryGreen,
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            displayEmail,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accentGoldLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '✦ ${s.localMember}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Live trip and voucher totals
              Row(
                children: [
                  _buildStatCard(
                    _statsLoadFailed
                        ? '—'
                        : _completedTrips?.toString() ?? '...',
                    s.tripsCompleted,
                  ),
                  const SizedBox(width: 10),
                  _buildStatCard(
                    availableVouchers.length.toString(),
                    s.activeVouchers,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Menu Settings Section
              Text(
                s.accountPreferences,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 10),

              Container(
                decoration: BoxDecoration(
                  color: AppColors.pureWhite,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderLight, width: 1),
                ),
                child: Column(
                  children: [
                    _buildMenuItem(
                      icon: Icons.person_outline_rounded,
                      title: s.editProfile,
                      subtitle: s.profilePhotoSubtitle,
                      onTap: _chooseProfilePhoto,
                    ),
                    const Divider(color: AppColors.borderLight, height: 1),
                    _buildMenuItem(
                      icon: Icons.security_rounded,
                      title: s.securityBiometrics,
                      subtitle: s.securitySubtitle,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SecurityScreen(),
                        ),
                      ),
                    ),
                    const Divider(color: AppColors.borderLight, height: 1),
                    _buildMenuItem(
                      icon: Icons.translate_rounded,
                      title: s.changeLanguage,
                      subtitle: s.languageSetting,
                      onTap: _showLanguagePicker,
                    ),
                    const Divider(color: AppColors.borderLight, height: 1),
                    _buildMenuItem(
                      icon: Icons.forum_outlined,
                      title: s.feedback,
                      subtitle: s.feedbackSubtitle,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const FeedbackScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  s.feedbackTitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.pureWhite,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pemrograman Aplikasi Mobile',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.feedbackDescription,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _feedbackController,
                      maxLength: 2000,
                      maxLines: 3,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppColors.textDark,
                      ),
                      decoration: InputDecoration(
                        hintText: s.feedbackHint,
                        hintStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                        filled: true,
                        fillColor: AppColors.warmCream,
                        contentPadding: const EdgeInsets.all(12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.borderLight,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.primaryGreen,
                            width: 1.2,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        onPressed: _isSubmittingFeedback
                            ? null
                            : _submitFeedback,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: AppColors.pureWhite,
                          disabledBackgroundColor: AppColors.primaryGreen
                              .withValues(alpha: 0.55),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isSubmittingFeedback
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.pureWhite,
                                ),
                              )
                            : Text(
                                s.submitFeedback,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Center(
                child: Column(
                  children: [
                    TextButton(
                      onPressed: () async {
                        // Logout: Menghapus token sesi secara aman dan kembali ke Login
                        await AuthService.logout();
                        if (!context.mounted) return;
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
                          (route) => false,
                        );
                      },
                      child: Text(
                        s.logout,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.errorRed,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.pureWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight, width: 1),
        ),
        alignment: Alignment.center,
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryGreen,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.surfaceCream,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppColors.primaryGreen),
        ),
        title: Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          size: 18,
          color: AppColors.textSecondary,
        ),
        onTap: onTap,
      ),
    );
  }
}
