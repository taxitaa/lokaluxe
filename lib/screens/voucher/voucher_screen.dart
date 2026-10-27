import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/models/supabase_voucher.dart';
import '../../core/services/localization_provider.dart';
import '../../core/services/session_service.dart';
import '../../core/services/supabase_auth_service.dart';
import '../../core/theme/app_colors.dart';

class VoucherScreen extends StatefulWidget {
  const VoucherScreen({super.key});

  @override
  State<VoucherScreen> createState() => _VoucherScreenState();
}

class _VoucherScreenState extends State<VoucherScreen> {
  List<SupabaseVoucher> _vouchers = const [];
  final Set<int> _updatingVoucherIds = {};
  String? _loadError;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadVouchers());
  }

  Future<void> _loadVouchers() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final session = await SessionService.getSessionData();
      if (session == null) {
        throw const SupabaseAuthException(
          'Masuk ke akun online untuk melihat voucher.',
        );
      }
      if (!SupabaseAuthService.isConfigured) {
        throw const SupabaseAuthException(
          'Supabase belum dikonfigurasi untuk memuat voucher.',
        );
      }
      final vouchers = await SupabaseAuthService.getActiveVouchers(
        accountEmail: session.email,
      );
      if (!mounted) return;
      setState(() => _vouchers = vouchers);
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _useVoucher(SupabaseVoucher voucher) async {
    final strings = context.read<LocalizationProvider>().strings;
    if (_updatingVoucherIds.contains(voucher.id)) return;
    setState(() => _updatingVoucherIds.add(voucher.id));
    try {
      final session = await SessionService.getSessionData();
      if (session == null) {
        throw const SupabaseAuthException(
          'Masuk ke akun online untuk menggunakan voucher.',
        );
      }
      await Clipboard.setData(ClipboardData(text: voucher.code));
      if (!mounted) return;
      setState(() {
        _vouchers = _vouchers
            .where((item) => item.id != voucher.id)
            .toList(growable: false);
      });
      await SupabaseAuthService.markVoucherUsed(
        accountEmail: session.email,
        voucherId: voucher.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            strings.localized(
              'Kode ${voucher.code} berhasil disalin & digunakan!',
              'Code ${voucher.code} copied and redeemed!',
            ),
            style: GoogleFonts.plusJakartaSans(color: Colors.white),
          ),
          backgroundColor: AppColors.primaryGreen,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (!_vouchers.any((item) => item.id == voucher.id)) {
          final restoredVouchers = List<SupabaseVoucher>.of(_vouchers)
            ..add(voucher)
            ..sort((a, b) => b.id.compareTo(a.id));
          _vouchers = restoredVouchers;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal menggunakan voucher: $error',
            style: GoogleFonts.plusJakartaSans(color: Colors.white),
          ),
          backgroundColor: AppColors.errorRed,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _updatingVoucherIds.remove(voucher.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocalizationProvider>().strings;
    return Scaffold(
      backgroundColor: AppColors.warmCream,
      appBar: AppBar(
        backgroundColor: AppColors.warmCream,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.chevron_left_rounded,
            size: 28,
            color: AppColors.textDark,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: Text(
          strings.localized(
            'Voucher & Hadiah Blockchain',
            'Vouchers & Blockchain Rewards',
          ),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          physics: const BouncingScrollPhysics(),
          children: [
            // Blockchain Info Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.verified_rounded,
                      color: AppColors.accentGold,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.localized(
                            'Voucher Digital Anda',
                            'Your Digital Vouchers',
                          ),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          strings.localized(
                            'Voucher hadiah tersimpan di akun Supabase Anda dan siap digunakan.',
                            'Reward vouchers are saved to your Supabase account and ready to use.',
                          ),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.8),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Text(
              strings.localized('Voucher Aktif Anda', 'Your Active Vouchers'),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),

            const SizedBox(height: 12),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(28),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_loadError != null)
              _buildLoadError()
            else if (_vouchers.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: Text(
                    strings.localized(
                      'Belum ada voucher aktif.',
                      'No active vouchers yet.',
                    ),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              )
            else
              for (final voucher in _vouchers)
                _buildVoucherCard(
                  voucher: voucher,
                  isUpdating: _updatingVoucherIds.contains(voucher.id),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadError() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
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
          const SizedBox(height: 8),
          TextButton(
            onPressed: _loadVouchers,
            child: Text(context.watch<LocalizationProvider>().strings.retry),
          ),
        ],
      ),
    );
  }

  Widget _buildVoucherCard({
    required SupabaseVoucher voucher,
    required bool isUpdating,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreenSubtle,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.confirmation_number_outlined,
                    color: AppColors.primaryGreen,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        voucher.discount,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        voucher.title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.watch<LocalizationProvider>().strings.localized(
                          'Hadiah Mini Game LokaCatch',
                          'LokaCatch Mini Game Reward',
                        ),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Dashed Divider Look
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: List.generate(
                30,
                (i) => Expanded(
                  child: Container(
                    height: 1,
                    color: i % 2 == 0
                        ? AppColors.borderLight
                        : Colors.transparent,
                  ),
                ),
              ),
            ),
          ),

          // Bottom Blockchain Hash & Status
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.watch<LocalizationProvider>().strings.localized(
                          'Kode voucher',
                          'Voucher code',
                        ),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        voucher.code,
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: AppColors.accentGold,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: isUpdating ? null : () => _useVoucher(voucher),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: AppColors.pureWhite,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: isUpdating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          context
                              .watch<LocalizationProvider>()
                              .strings
                              .localized('Gunakan', 'Redeem'),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
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
