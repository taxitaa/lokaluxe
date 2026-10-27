import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

import '../../core/services/localization_provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/biometric_service.dart';
import '../../core/services/session_service.dart';
import '../../core/models/user_model.dart';
import '../../core/theme/app_colors.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  String _tr(String indonesian, String english) => context
      .read<LocalizationProvider>()
      .strings
      .localized(indonesian, english);

  Future<bool> _confirmFaceIdPermission() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_tr('Izinkan Face ID?', 'Allow Face ID?')),
        content: Text(
          _tr(
            'LokaLuxe akan membuka dialog autentikasi biometrik bawaan perangkat untuk memverifikasi wajah Anda. Aplikasi tidak mengakses kamera secara langsung atau menyimpan data wajah.',
            'LokaLuxe will open your device’s built-in biometric authentication prompt to verify your face. The app does not directly access the camera or store face data.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_tr('Nanti', 'Not now')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(_tr('Lanjutkan', 'Continue')),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  UserModel? _currentUser;
  bool _isLoading = true;
  bool _isProcessing = false;

  bool _isBiometricSupported = false;
  bool _hasFingerprintHardware = false;
  bool _hasFaceHardware = false;

  bool _isFingerprintEnabled = false;
  bool _isFaceIdEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSecuritySettings();
  }

  Future<void> _loadSecuritySettings() async {
    setState(() => _isLoading = true);
    try {
      final user = await AuthService.checkSession();
      final isSupported = await BiometricService.isBiometricSupported();
      final biometrics = await BiometricService.getAvailableBiometrics();

      final hasFp =
          biometrics.contains(BiometricType.fingerprint) ||
          biometrics.contains(BiometricType.strong);
      final hasFace =
          biometrics.contains(BiometricType.face) ||
          biometrics.contains(BiometricType.strong);

      bool fpEnabled = false;
      bool faceEnabled = false;

      if (user?.id != null) {
        final settings = await BiometricService.getUserSecuritySettings(
          user!.id!,
        );
        fpEnabled = settings['fingerprintEnabled'] == true;
        faceEnabled = settings['faceIdEnabled'] == true;
        if (fpEnabled || faceEnabled) {
          await SessionService.setBiometricAccountEmail(user.email);
        }
      }

      if (mounted) {
        setState(() {
          _currentUser = user;
          _isBiometricSupported = isSupported;
          _hasFingerprintHardware = hasFp || isSupported;
          _hasFaceHardware = hasFace || isSupported;
          _isFingerprintEnabled = fpEnabled;
          _isFaceIdEnabled = faceEnabled;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- TOGGLE SIDIK JARI ---
  Future<void> _toggleFingerprint(bool newValue) async {
    if (_currentUser?.id == null || _isProcessing) return;
    if (!_isBiometricSupported) {
      _showSnackBar(
        _tr(
          'Perangkat tidak mendukung sensor biometrik',
          'This device does not support biometrics',
        ),
        isError: true,
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      if (newValue) {
        // Aktifkan sidik jari: verifikasi sensor terlebih dahulu
        final verified = await BiometricService.authenticateWithFingerprint(
          reason: _tr(
            'Verifikasi sidik jari untuk mengaktifkan login.',
            'Verify your fingerprint to enable sign-in.',
          ),
        );
        if (!verified) {
          if (mounted) {
            _showSnackBar(
              _tr(
                'Verifikasi sidik jari dibatalkan atau gagal',
                'Fingerprint verification was cancelled or failed',
              ),
              isError: true,
            );
          }
          return;
        }
        await BiometricService.saveFingerprintPreference(
          _currentUser!.id!,
          true,
        );
        await SessionService.setBiometricAccountEmail(_currentUser!.email);
        if (mounted) {
          setState(() => _isFingerprintEnabled = true);
          _showSnackBar(
            _tr(
              'Sidik jari berhasil diaktifkan untuk login ✓',
              'Fingerprint sign-in enabled ✓',
            ),
          );
        }
      } else {
        // Nonaktifkan sidik jari
        final confirmed = await _showConfirmDialog(
          title: _tr('Nonaktifkan Sidik Jari?', 'Disable fingerprint?'),
          content: _tr(
            'Anda tidak dapat masuk menggunakan sidik jari sebelum mengaktifkannya kembali.',
            'You will not be able to sign in with your fingerprint until it is enabled again.',
          ),
        );
        if (confirmed != true) return;

        final verified = await BiometricService.authenticateWithFingerprint(
          reason: _tr(
            'Verifikasi sidik jari untuk mengonfirmasi penonaktifan.',
            'Verify your fingerprint to confirm disabling it.',
          ),
        );
        if (!verified) {
          if (mounted) {
            _showSnackBar(
              _tr(
                'Konfirmasi gagal atau dibatalkan',
                'Confirmation failed or was cancelled',
              ),
              isError: true,
            );
          }
          return;
        }

        await BiometricService.saveFingerprintPreference(
          _currentUser!.id!,
          false,
        );
        await _syncBiometricAccountBinding();
        if (mounted) {
          setState(() => _isFingerprintEnabled = false);
          _showSnackBar(
            _tr(
              'Sidik jari telah dinonaktifkan',
              'Fingerprint sign-in disabled',
            ),
          );
        }
      }
    } catch (e) {
      if (mounted)
        _showSnackBar(
          '${_tr('Terjadi kesalahan', 'An error occurred')}: $e',
          isError: true,
        );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // --- TOGGLE FACE ID ---
  Future<void> _toggleFaceId(bool newValue) async {
    if (_currentUser?.id == null || _isProcessing) return;
    if (!_isBiometricSupported) {
      _showSnackBar(
        _tr(
          'Perangkat tidak mendukung sensor biometrik',
          'This device does not support biometrics',
        ),
        isError: true,
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      if (newValue) {
        final allowed = await _confirmFaceIdPermission();
        if (!allowed) return;
        final verified = await BiometricService.authenticateWithFaceId(
          reason: _tr(
            'Verifikasi identitas untuk mengaktifkan Face ID',
            'Verify your identity to enable Face ID',
          ),
        );
        if (!verified) {
          if (mounted) {
            _showSnackBar(
              _tr(
                'Verifikasi Face ID dibatalkan atau gagal',
                'Face ID verification was cancelled or failed',
              ),
              isError: true,
            );
          }
          return;
        }
        await BiometricService.saveFaceIdPreference(_currentUser!.id!, true);
        await SessionService.setBiometricAccountEmail(_currentUser!.email);
        if (mounted) {
          setState(() => _isFaceIdEnabled = true);
          _showSnackBar(
            _tr(
              'Face ID berhasil diaktifkan untuk login ✓',
              'Face ID sign-in enabled ✓',
            ),
          );
        }
      } else {
        // Nonaktifkan Face ID
        final confirmed = await _showConfirmDialog(
          title: _tr('Nonaktifkan Face ID?', 'Disable Face ID?'),
          content: _tr(
            'Anda tidak dapat masuk menggunakan Face ID sebelum mengaktifkannya kembali.',
            'You will not be able to sign in with Face ID until it is enabled again.',
          ),
        );
        if (confirmed != true) return;

        final verified = await BiometricService.authenticateWithFaceId(
          reason: _tr(
            'Verifikasi Face ID untuk mengonfirmasi penonaktifan.',
            'Verify Face ID to confirm disabling it.',
          ),
        );
        if (!verified) {
          if (mounted) {
            _showSnackBar(
              _tr(
                'Konfirmasi gagal atau dibatalkan',
                'Confirmation failed or was cancelled',
              ),
              isError: true,
            );
          }
          return;
        }

        await BiometricService.saveFaceIdPreference(_currentUser!.id!, false);
        await _syncBiometricAccountBinding();
        if (mounted) {
          setState(() => _isFaceIdEnabled = false);
          _showSnackBar(_tr('Face ID telah dinonaktifkan', 'Face ID disabled'));
        }
      }
    } catch (e) {
      if (mounted)
        _showSnackBar(
          '${_tr('Terjadi kesalahan', 'An error occurred')}: $e',
          isError: true,
        );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _syncBiometricAccountBinding() async {
    final user = _currentUser;
    if (user?.id == null) return;

    final settings = await BiometricService.getUserSecuritySettings(user!.id!);
    final hasBiometricEnabled =
        settings['fingerprintEnabled'] == true ||
        settings['faceIdEnabled'] == true;
    if (hasBiometricEnabled) return;

    final boundEmail = await SessionService.getBiometricAccountEmail();
    if (boundEmail?.toLowerCase() == user.email.toLowerCase()) {
      await SessionService.clearBiometricAccountEmail();
    }
  }

  // --- PENDAFTARAN & UJI COBA SIDIK JARI ---
  Future<void> _showFingerprintRegistrationDialog() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.pureWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.borderLight,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryGreenSubtle,
                border: Border.all(color: AppColors.primaryGreen, width: 2),
              ),
              child: const Icon(
                Icons.fingerprint_rounded,
                size: 40,
                color: AppColors.primaryGreen,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _tr('Pendaftaran Sidik Jari', 'Fingerprint Registration'),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _tr(
                'Tekan tombol di bawah lalu letakkan jari Anda pada sensor sidik jari perangkat untuk mendaftarkan dan memverifikasi sidik jari di akun LokaLuxe.',
                'Tap the button below and place your finger on the device sensor to register and verify fingerprint sign-in for your LokaLuxe account.',
              ),
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceCream,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: AppColors.primaryGreen,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _tr(
                        'Pastikan sidik jari Anda telah terdaftar pada menu Pengaturan HP Anda.',
                        'Make sure your fingerprint is registered in your device settings.',
                      ),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final verified =
                      await BiometricService.authenticateWithFingerprint(
                        reason: _tr(
                          'Pindai sidik jari Anda untuk menyelesaikan pendaftaran',
                          'Scan your fingerprint to complete registration',
                        ),
                      );
                  if (verified && _currentUser?.id != null) {
                    await BiometricService.saveFingerprintPreference(
                      _currentUser!.id!,
                      true,
                    );
                    if (mounted) {
                      setState(() => _isFingerprintEnabled = true);
                      _showSnackBar(
                        _tr(
                          '✓ Sidik jari berhasil didaftarkan & diaktifkan!',
                          '✓ Fingerprint registered and enabled!',
                        ),
                      );
                    }
                  } else {
                    if (mounted) {
                      _showSnackBar(
                        _tr(
                          'Pendaftaran dibatalkan atau sidik jari tidak cocok.',
                          'Registration cancelled or fingerprint did not match.',
                        ),
                        isError: true,
                      );
                    }
                  }
                },
                icon: const Icon(Icons.touch_app_rounded, size: 20),
                label: Text(
                  _tr(
                    'Uji & Daftarkan Sidik Jari Sekarang',
                    'Test & Register Fingerprint',
                  ),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // --- PENDAFTARAN & UJI COBA FACE ID ---
  Future<void> _showFaceIdRegistrationDialog() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.pureWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.borderLight,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accentGoldLight,
                border: Border.all(color: AppColors.accentGold, width: 2),
              ),
              child: const Icon(
                Icons.face_rounded,
                size: 40,
                color: AppColors.accentGold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _tr('Pendaftaran Face ID', 'Face ID Registration'),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _tr(
                'Lanjutkan untuk membuka autentikasi wajah bawaan perangkat. Verifikasi dilakukan oleh perangkat; LokaLuxe tidak mengakses kamera secara langsung atau menyimpan data wajah.',
                'Continue to open your device’s built-in face authentication. Verification is handled by the device; LokaLuxe does not directly access the camera or store face data.',
              ),
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  if (!await _confirmFaceIdPermission() || !mounted) return;
                  final verified = await BiometricService.authenticateWithFaceId(
                    reason: _tr(
                      'Verifikasi identitas untuk menyelesaikan pendaftaran Face ID',
                      'Verify your identity to complete Face ID registration',
                    ),
                  );
                  if (verified && _currentUser?.id != null) {
                    await BiometricService.saveFaceIdPreference(
                      _currentUser!.id!,
                      true,
                    );
                    if (mounted) {
                      setState(() => _isFaceIdEnabled = true);
                      _showSnackBar(
                        _tr(
                          '✓ Face ID berhasil didaftarkan & diaktifkan!',
                          '✓ Face ID registered and enabled!',
                        ),
                      );
                    }
                  } else {
                    if (mounted) {
                      _showSnackBar(
                        _tr(
                          'Pendaftaran Face ID dibatalkan atau gagal.',
                          'Face ID registration was cancelled or failed.',
                        ),
                        isError: true,
                      );
                    }
                  }
                },
                icon: const Icon(Icons.camera_alt_outlined, size: 20),
                label: Text(
                  _tr(
                    'Uji & Daftarkan Face ID Sekarang',
                    'Test & Register Face ID',
                  ),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String content,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppColors.pureWhite,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3CD),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFF59E0B),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          content,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              _tr('Batal', 'Cancel'),
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              _tr('Nonaktifkan', 'Disable'),
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13),
        ),
        backgroundColor: isError ? AppColors.errorRed : AppColors.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocalizationProvider>().strings;
    return Scaffold(
      backgroundColor: AppColors.warmCream,
      appBar: AppBar(
        backgroundColor: AppColors.pureWhite,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          color: AppColors.textDark,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          strings.securityBiometrics,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.borderLight),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryGreen,
                strokeWidth: 2.5,
              ),
            )
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero Banner dengan Status
                  _buildHeroBanner(),
                  const SizedBox(height: 24),

                  // Section: Autentikasi Biometrik
                  _buildSectionLabel(
                    _tr(
                      'Metode Autentikasi Biometrik',
                      'Biometric Authentication',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildBiometricCards(),
                  const SizedBox(height: 24),

                  // Section: Informasi Keamanan
                  _buildSectionLabel(
                    _tr(
                      'Informasi Keamanan & Privasi',
                      'Security & Privacy Information',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSecurityInfoSection(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildHeroBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF144638), Color(0xFF1D5A49)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF144638).withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.shield_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _tr('Keamanan Akun Anda', 'Your Account Security'),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _tr(
                        'Pilih dan daftarkan metode biometrik yang Anda sukai',
                        'Choose and register your preferred biometric method',
                      ),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                _buildStatusBadge(
                  label: _tr('Sidik Jari', 'Fingerprint'),
                  isActive: _isFingerprintEnabled,
                  icon: Icons.fingerprint_rounded,
                ),
                const SizedBox(width: 8),
                _buildStatusBadge(
                  label: 'Face ID',
                  isActive: _isFaceIdEnabled,
                  icon: Icons.face_rounded,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge({
    required String label,
    required bool isActive,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.white.withValues(alpha: 0.25)
            : Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive
              ? Colors.white.withValues(alpha: 0.4)
              : Colors.transparent,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            '$label: ${isActive ? _tr("Aktif", "Active") : _tr("Mati", "Off")}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.textDark,
      ),
    );
  }

  Widget _buildBiometricCards() {
    return Column(
      children: [
        // CARD 1: SIDIK JARI
        _buildMethodCard(
          icon: Icons.fingerprint_rounded,
          iconBgColor: AppColors.primaryGreenSubtle,
          iconColor: AppColors.primaryGreen,
          title: _tr('Sidik Jari (Fingerprint)', 'Fingerprint'),
          subtitle: _isFingerprintEnabled
              ? _tr(
                  'Aktif — Terdaftar untuk masuk cepat',
                  'Active — Registered for quick sign-in',
                )
              : (_hasFingerprintHardware
                    ? _tr(
                        'Sensor siap · Ketuk switch atau daftarkan sidik jari',
                        'Sensor ready · Use the switch or register a fingerprint',
                      )
                    : _tr(
                        'Sensor belum terdeteksi di perangkat',
                        'Sensor not detected on this device',
                      )),
          isEnabled: _isFingerprintEnabled,
          onToggle: _toggleFingerprint,
          actionLabel: _tr(
            'Daftarkan / Uji Sidik Jari',
            'Register / Test Fingerprint',
          ),
          actionIcon: Icons.fingerprint_rounded,
          onActionTap: _showFingerprintRegistrationDialog,
        ),

        const SizedBox(height: 14),

        // CARD 2: FACE ID
        _buildMethodCard(
          icon: Icons.face_rounded,
          iconBgColor: AppColors.accentGoldLight,
          iconColor: AppColors.accentGold,
          title: _tr('Face ID (Pengenalan Wajah)', 'Face ID'),
          subtitle: _isFaceIdEnabled
              ? _tr(
                  'Aktif — Buka kunci cepat dengan Face ID',
                  'Active — Unlock quickly with Face ID',
                )
              : (_hasFaceHardware
                    ? _tr(
                        'Face ID siap · Ketuk switch atau daftarkan wajah',
                        'Face ID ready · Use the switch or register your face',
                      )
                    : _tr(
                        'Sensor belum terdeteksi di perangkat',
                        'Sensor not detected on this device',
                      )),
          isEnabled: _isFaceIdEnabled,
          onToggle: _toggleFaceId,
          actionLabel: _tr(
            'Daftarkan / Uji Face ID',
            'Register / Test Face ID',
          ),
          actionIcon: Icons.camera_front_rounded,
          onActionTap: _showFaceIdRegistrationDialog,
        ),
      ],
    );
  }

  Widget _buildMethodCard({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isEnabled,
    required ValueChanged<bool> onToggle,
    required String actionLabel,
    required IconData actionIcon,
    required VoidCallback onActionTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isEnabled
              ? AppColors.primaryGreen.withValues(alpha: 0.3)
              : AppColors.borderLight,
          width: isEnabled ? 1.4 : 1,
        ),
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
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, size: 26, color: iconColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: isEnabled
                              ? AppColors.successGreen
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: isEnabled,
                  onChanged: _isBiometricSupported ? onToggle : null,
                  activeTrackColor: AppColors.primaryGreen,
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.borderLight, height: 1),
          // Action Tile: Daftarkan / Uji Coba
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onActionTap,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(actionIcon, size: 16, color: AppColors.primaryGreen),
                    const SizedBox(width: 8),
                    Text(
                      actionLabel,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 13,
                      color: AppColors.primaryGreen,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityInfoSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: [
          _buildInfoTile(
            icon: Icons.fingerprint_rounded,
            title: _tr(
              'Pendaftaran Sidik Jari Baru',
              'Register a New Fingerprint',
            ),
            subtitle: _tr(
              'Untuk menambahkan sidik jari fisik baru, buka Pengaturan HP Anda > Keamanan > Sidik Jari. Setelah terdaftar di HP, aktifkan di LokaLuxe.',
              'To add a new fingerprint, open your device Settings > Security > Fingerprint. Once registered on your device, enable it in LokaLuxe.',
            ),
          ),
          const Divider(
            color: AppColors.borderLight,
            height: 1,
            indent: 56,
            endIndent: 16,
          ),
          _buildInfoTile(
            icon: Icons.lock_outline_rounded,
            title: _tr('Keamanan Data Lokal', 'Local Data Security'),
            subtitle: _tr(
              'Data sidik jari dan wajah tidak pernah diunggah ke server mana pun. Sensor diverifikasi secara langsung oleh Android Keystore / iOS Keychain.',
              'Fingerprint and face data are never uploaded to a server. Sensors are verified directly by Android Keystore / iOS Keychain.',
            ),
          ),
          const Divider(
            color: AppColors.borderLight,
            height: 1,
            indent: 56,
            endIndent: 16,
          ),
          _buildInfoTile(
            icon: Icons.token_rounded,
            title: _tr('Token Sesi Terenkripsi', 'Encrypted Session Token'),
            subtitle: _tr(
              'Sesi akun disimpan di Flutter Secure Storage menggunakan enkripsi AES-256 yang aman.',
              'Your account session is stored in Flutter Secure Storage using AES-256 encryption.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surfaceCream,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.primaryGreen),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    height: 1.45,
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
