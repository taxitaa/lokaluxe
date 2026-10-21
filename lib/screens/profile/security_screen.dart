import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
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
  UserModel? _currentUser;
  bool _isLoading = true;
  bool _isProcessing = false;

  bool _isBiometricSupported = false;
  bool _hasFingerprintHardware = false;
  bool _hasFaceHardware = false;

  bool _isFingerprintEnabled = false;
  bool _isFaceIdEnabled = false;
  String? _savedPin;

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

      final hasFp = biometrics.contains(BiometricType.fingerprint) ||
          biometrics.contains(BiometricType.strong);
      final hasFace = biometrics.contains(BiometricType.face) ||
          biometrics.contains(BiometricType.strong);

      bool fpEnabled = false;
      bool faceEnabled = false;
      String? pin;

      if (user?.id != null) {
        final settings =
            await BiometricService.getUserSecuritySettings(user!.id!);
        fpEnabled = settings['fingerprintEnabled'] == true;
        faceEnabled = settings['faceIdEnabled'] == true;
        pin = settings['securityPin'] as String?;
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
          _savedPin = pin;
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
        'Perangkat tidak mendukung sensor biometrik',
        isError: true,
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      if (newValue) {
        // Aktifkan sidik jari: verifikasi sensor terlebih dahulu
        final verified = await BiometricService.authenticateWithFingerprint(
          reason: 'Letakkan jari Anda pada sensor sidik jari untuk mengaktifkan',
        );
        if (!verified) {
          if (mounted) {
            _showSnackBar('Verifikasi sidik jari dibatalkan atau gagal', isError: true);
          }
          return;
        }
        await BiometricService.saveFingerprintPreference(_currentUser!.id!, true);
        await SessionService.setBiometricAccountEmail(_currentUser!.email);
        if (mounted) {
          setState(() => _isFingerprintEnabled = true);
          _showSnackBar('Sidik jari berhasil diaktifkan untuk login ✓');
        }
      } else {
        // Nonaktifkan sidik jari
        final confirmed = await _showConfirmDialog(
          title: 'Nonaktifkan Sidik Jari?',
          content: 'Anda tidak dapat masuk menggunakan sidik jari sebelum mengaktifkannya kembali.',
        );
        if (confirmed != true) return;

        final verified = await BiometricService.authenticateWithFingerprint(
          reason: 'Verifikasi sidik jari untuk mengonfirmasi penonaktifan',
        );
        if (!verified) {
          if (mounted) {
            _showSnackBar('Konfirmasi gagal atau dibatalkan', isError: true);
          }
          return;
        }

        await BiometricService.saveFingerprintPreference(_currentUser!.id!, false);
        await _syncBiometricAccountBinding();
        if (mounted) {
          setState(() => _isFingerprintEnabled = false);
          _showSnackBar('Sidik jari telah dinonaktifkan');
        }
      }
    } catch (e) {
      if (mounted) _showSnackBar('Terjadi kesalahan: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // --- TOGGLE FACE ID ---
  Future<void> _toggleFaceId(bool newValue) async {
    if (_currentUser?.id == null || _isProcessing) return;
    if (!_isBiometricSupported) {
      _showSnackBar(
        'Perangkat tidak mendukung sensor biometrik',
        isError: true,
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      if (newValue) {
        // Aktifkan Face ID: verifikasi sensor terlebih dahulu
        final verified = await BiometricService.authenticateWithFaceId(
          reason: 'Arahkan wajah Anda ke kamera untuk mengaktifkan Face ID',
        );
        if (!verified) {
          if (mounted) {
            _showSnackBar('Verifikasi Face ID dibatalkan atau gagal', isError: true);
          }
          return;
        }
        await BiometricService.saveFaceIdPreference(_currentUser!.id!, true);
        await SessionService.setBiometricAccountEmail(_currentUser!.email);
        if (mounted) {
          setState(() => _isFaceIdEnabled = true);
          _showSnackBar('Face ID berhasil diaktifkan untuk login ✓');
        }
      } else {
        // Nonaktifkan Face ID
        final confirmed = await _showConfirmDialog(
          title: 'Nonaktifkan Face ID?',
          content: 'Anda tidak dapat masuk menggunakan Face ID sebelum mengaktifkannya kembali.',
        );
        if (confirmed != true) return;

        final verified = await BiometricService.authenticateWithFaceId(
          reason: 'Verifikasi Face ID untuk mengonfirmasi penonaktifan',
        );
        if (!verified) {
          if (mounted) {
            _showSnackBar('Konfirmasi gagal atau dibatalkan', isError: true);
          }
          return;
        }

        await BiometricService.saveFaceIdPreference(_currentUser!.id!, false);
        await _syncBiometricAccountBinding();
        if (mounted) {
          setState(() => _isFaceIdEnabled = false);
          _showSnackBar('Face ID telah dinonaktifkan');
        }
      }
    } catch (e) {
      if (mounted) _showSnackBar('Terjadi kesalahan: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _syncBiometricAccountBinding() async {
    final user = _currentUser;
    if (user?.id == null) return;

    final settings =
        await BiometricService.getUserSecuritySettings(user!.id!);
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
              'Pendaftaran Sidik Jari',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tekan tombol di bawah lalu letakkan jari Anda pada sensor sidik jari perangkat untuk mendaftarkan dan memverifikasi sidik jari di akun LokaLuxe.',
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
                  const Icon(Icons.info_outline_rounded,
                      size: 18, color: AppColors.primaryGreen),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Pastikan sidik jari Anda telah terdaftar pada menu Pengaturan HP Anda.',
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
                    reason: 'Pindai sidik jari Anda untuk menyelesaikan pendaftaran',
                  );
                  if (verified && _currentUser?.id != null) {
                    await BiometricService.saveFingerprintPreference(
                      _currentUser!.id!,
                      true,
                    );
                    if (mounted) {
                      setState(() => _isFingerprintEnabled = true);
                      _showSnackBar('✓ Sidik jari berhasil didaftarkan & diaktifkan!');
                    }
                  } else {
                    if (mounted) {
                      _showSnackBar('Pendaftaran dibatalkan atau sidik jari tidak cocok.',
                          isError: true);
                    }
                  }
                },
                icon: const Icon(Icons.touch_app_rounded, size: 20),
                label: Text(
                  'Uji & Daftarkan Sidik Jari Sekarang',
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
              'Pendaftaran Face ID',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Arahkan wajah Anda ke kamera depan perangkat untuk memverifikasi dan mengaktifkan Face ID di akun LokaLuxe.',
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
                  final verified =
                      await BiometricService.authenticateWithFaceId(
                    reason: 'Arahkan wajah Anda untuk menyelesaikan pendaftaran Face ID',
                  );
                  if (verified && _currentUser?.id != null) {
                    await BiometricService.saveFaceIdPreference(
                      _currentUser!.id!,
                      true,
                    );
                    if (mounted) {
                      setState(() => _isFaceIdEnabled = true);
                      _showSnackBar('✓ Face ID berhasil didaftarkan & diaktifkan!');
                    }
                  } else {
                    if (mounted) {
                      _showSnackBar('Pendaftaran Face ID dibatalkan atau gagal.',
                          isError: true);
                    }
                  }
                },
                icon: const Icon(Icons.camera_alt_outlined, size: 20),
                label: Text(
                  'Uji & Daftarkan Face ID Sekarang',
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

  // --- PENGATURAN PIN KEAMANAN ---
  Future<void> _showPinDialog() async {
    final pinController = TextEditingController();
    final confirmController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        backgroundColor: AppColors.pureWhite,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryGreenSubtle,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.pin_rounded,
                  color: AppColors.primaryGreen, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              _savedPin != null ? 'Ubah PIN Keamanan' : 'Atur PIN Keamanan',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Masukkan 6 digit angka untuk PIN alternatif login.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'PIN Baru (6 Angka)',
                filled: true,
                fillColor: AppColors.surfaceCream,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: confirmController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Konfirmasi PIN',
                filled: true,
                fillColor: AppColors.surfaceCream,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Batal',
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final pin = pinController.text.trim();
              final confirm = confirmController.text.trim();

              if (pin.length != 6) {
                _showSnackBar('PIN harus terdiri dari 6 angka', isError: true);
                return;
              }
              if (pin != confirm) {
                _showSnackBar('Konfirmasi PIN tidak cocok', isError: true);
                return;
              }

              if (_currentUser?.id != null) {
                await BiometricService.saveSecurityPin(_currentUser!.id!, pin);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
                if (mounted) {
                  setState(() => _savedPin = pin);
                  _showSnackBar('PIN Keamanan berhasil disimpan ✓');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Simpan',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
            ),
          ),
        ],
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
              child: const Icon(Icons.warning_amber_rounded,
                  color: Color(0xFFF59E0B), size: 20),
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
              'Batal',
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
              'Nonaktifkan',
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
          'Security & Biometrics',
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
                  _buildSectionLabel('Metode Autentikasi Biometrik'),
                  const SizedBox(height: 12),
                  _buildBiometricCards(),
                  const SizedBox(height: 24),

                  // Section: PIN Alternatif
                  _buildSectionLabel('PIN Keamanan Cadangan'),
                  const SizedBox(height: 12),
                  _buildPinCard(),
                  const SizedBox(height: 24),

                  // Section: Informasi Keamanan
                  _buildSectionLabel('Informasi Keamanan & Privasi'),
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
                      'Keamanan Akun Anda',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Pilih dan daftarkan metode biometrik yang Anda sukai',
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
          // Badges Row
                    // Badges Row
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                _buildStatusBadge(
                  label: 'Sidik Jari',
                  isActive: _isFingerprintEnabled,
                  icon: Icons.fingerprint_rounded,
                ),
                const SizedBox(width: 8),
                _buildStatusBadge(
                  label: 'Face ID',
                  isActive: _isFaceIdEnabled,
                  icon: Icons.face_rounded,
                ),
                const SizedBox(width: 8),
                _buildStatusBadge(
                  label: 'PIN',
                  isActive: _savedPin != null,
                  icon: Icons.pin_rounded,
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
            '$label: ${isActive ? "Aktif" : "Mati"}',
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
          title: 'Sidik Jari (Fingerprint)',
          subtitle: _isFingerprintEnabled
              ? 'Aktif — Terdaftar untuk masuk cepat'
              : (_hasFingerprintHardware
                  ? 'Sensor siap · Ketuk switch atau daftarkan sidik jari'
                  : 'Sensor belum terdeteksi di perangkat'),
          isEnabled: _isFingerprintEnabled,
          onToggle: _toggleFingerprint,
          actionLabel: 'Daftarkan / Uji Sidik Jari',
          actionIcon: Icons.fingerprint_rounded,
          onActionTap: _showFingerprintRegistrationDialog,
        ),

        const SizedBox(height: 14),

        // CARD 2: FACE ID
        _buildMethodCard(
          icon: Icons.face_rounded,
          iconBgColor: AppColors.accentGoldLight,
          iconColor: AppColors.accentGold,
          title: 'Face ID (Pengenalan Wajah)',
          subtitle: _isFaceIdEnabled
              ? 'Aktif — Buka kunci cepat dengan kamera depan'
              : (_hasFaceHardware
                  ? 'Kamera siap · Ketuk switch atau daftarkan wajah'
                  : 'Sensor belum terdeteksi di perangkat'),
          isEnabled: _isFaceIdEnabled,
          onToggle: _toggleFaceId,
          actionLabel: 'Daftarkan / Uji Face ID',
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
          color: isEnabled ? AppColors.primaryGreen.withValues(alpha: 0.3) : AppColors.borderLight,
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
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

  Widget _buildPinCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceCream,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.pin_rounded,
                size: 24, color: AppColors.primaryGreen),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PIN Keamanan (6 Digit)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _savedPin != null
                      ? 'PIN terpasang (● ● ● ● ● ●)'
                      : 'Belum diatur — Atur sebagai cadangan biometrik',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: _savedPin != null
                        ? AppColors.successGreen
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: _showPinDialog,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryGreen,
              side: const BorderSide(color: AppColors.primaryGreen),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            child: Text(
              _savedPin != null ? 'Ubah' : 'Atur',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
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
            title: 'Pendaftaran Sidik Jari Baru',
            subtitle:
                'Untuk menambahkan sidik jari fisik baru, buka Pengaturan HP Anda > Keamanan > Sidik Jari. Setelah terdaftar di HP, aktifkan di LokaLuxe.',
          ),
          const Divider(color: AppColors.borderLight, height: 1, indent: 56, endIndent: 16),
          _buildInfoTile(
            icon: Icons.lock_outline_rounded,
            title: 'Keamanan Data Lokal',
            subtitle:
                'Data sidik jari dan wajah tidak pernah diunggah ke server mana pun. Sensor diverifikasi secara langsung oleh Android Keystore / iOS Keychain.',
          ),
          const Divider(color: AppColors.borderLight, height: 1, indent: 56, endIndent: 16),
          _buildInfoTile(
            icon: Icons.token_rounded,
            title: 'Token Sesi Terenkripsi',
            subtitle:
                'Sesi akun disimpan di Flutter Secure Storage menggunakan enkripsi AES-256 yang aman.',
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
