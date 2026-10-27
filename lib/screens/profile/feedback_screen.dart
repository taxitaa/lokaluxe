import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/localization_provider.dart';
import '../../core/services/supabase_auth_service.dart';
import '../../core/theme/app_colors.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  List<Map<String, dynamic>> _feedback = [];
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadFeedback();
  }

  Future<void> _loadFeedback() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final user = await AuthService.checkSession();
      if (user == null) {
        throw const SupabaseAuthException(
          'Sesi akun tidak ditemukan. Masuk kembali untuk melihat kritik dan saran.',
        );
      }
      final feedback = await SupabaseAuthService.getPublicFeedback(
        accountEmail: user.email,
      );
      if (!mounted) return;
      setState(() {
        _feedback = feedback;
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('[FeedbackScreen] Could not load course feedback: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _loadError = error is SupabaseAuthException
            ? error.message
            : 'Kritik dan saran gagal dimuat. Periksa koneksi dan konfigurasi Supabase.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocalizationProvider>().strings;
    return Scaffold(
      backgroundColor: AppColors.warmCream,
      appBar: AppBar(
        title: Text(
          strings.feedback,
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
              onRefresh: _loadFeedback,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    strings.localized(
                      'Masukan untuk aplikasi LokaLuxe',
                      'Feedback for the LokaLuxe app',
                    ),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_loadError != null)
                    _buildLoadError()
                  else if (_feedback.isEmpty)
                    _buildEmptyState()
                  else
                    ..._feedback.map(_buildFeedbackCard),
                ],
              ),
            ),
    );
  }

  Widget _buildLoadError() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: [
          Text(
            _loadError!,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: AppColors.errorRed,
            ),
          ),
          TextButton.icon(
            onPressed: _loadFeedback,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(context.watch<LocalizationProvider>().strings.retry),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 28),
    child: Text(
      context.watch<LocalizationProvider>().strings.localized(
        'Belum ada kritik dan saran. Jadilah yang pertama berbagi masukan untuk aplikasi ini.',
        'No feedback yet. Be the first to share feedback about the app.',
      ),
      textAlign: TextAlign.center,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        color: AppColors.textSecondary,
      ),
    ),
  );

  Widget _buildFeedbackCard(Map<String, dynamic> item) {
    final createdAt = DateTime.tryParse((item['created_at'] ?? '').toString())
        ?.toLocal();
    final dateLabel = createdAt == null
        ? ''
        : '${createdAt.day.toString().padLeft(2, '0')}/'
              '${createdAt.month.toString().padLeft(2, '0')}/'
              '${createdAt.year}';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.person_outline_rounded,
                size: 18,
                color: AppColors.primaryGreen,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  context.watch<LocalizationProvider>().strings.localized(
                    'Pengguna',
                    'User',
                  ),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
              Text(
                dateLabel,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            (item['comment'] ?? '').toString(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}
