import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/services/game_coin_service.dart';
import '../../core/theme/app_colors.dart';
import 'loka_catch_screen.dart';
import '../voucher/voucher_screen.dart';

/// Hub layar mini game - hanya menampilkan LokaCatch
class MiniGameScreen extends StatefulWidget {
  const MiniGameScreen({super.key});

  @override
  State<MiniGameScreen> createState() => _MiniGameScreenState();
}

class _MiniGameScreenState extends State<MiniGameScreen> {
  int _totalCoins = 0;
  int _totalSessions = 0;
  int _highScore = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  /// Memuat statistik game dari penyimpanan lokal
  Future<void> _loadStats() async {
    final coins = await GameCoinService.getTotalCoins();
    final sessions = await GameCoinService.getTotalSessions();
    final hs = await GameCoinService.getHighScore();
    if (mounted) {
      setState(() {
        _totalCoins = coins;
        _totalSessions = sessions;
        _highScore = hs;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmCream,
      appBar: AppBar(
        backgroundColor: AppColors.warmCream,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded,
              size: 28, color: AppColors.textDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: Text(
          'Mini Game',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        actions: [
          // Tampilan total koin
          Container(
            margin: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.accentGoldLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.accentGold, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.monetization_on_rounded,
                    size: 14, color: AppColors.accentGold),
                const SizedBox(width: 4),
                Text(
                  '$_totalCoins Koin',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Statistik game
              _buildStatsCard(),
              const SizedBox(height: 24),

              Text(
                'LokaCatch',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Mainkan LokaCatch untuk mendapatkan koin & voucher!',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),

              // Game Card: LokaCatch (Gyroscope)
              _buildGameCard(
                title: 'LokaCatch',
                subtitle: 'Kendali Gyroscope',
                description:
                    'Miringkan HP untuk menangkap 10 bahan kuliner Nusantara. Hindari bom! Menangkan hingga 50 koin.',
                emoji: '🧺',
                badge: 'GYROSCOPE',
                badgeColor: AppColors.primaryGreen,
                isNew: true,
                reward: '+50 Koin',
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const LokaCatchScreen(),
                    ),
                  );
                  // Reload stats setelah kembali dari game
                  _loadStats();
                },
              ),

              const SizedBox(height: 24),

              // Klaim voucher
              _buildVoucherSection(),
            ],
          ),
        ),
      ),
    );
  }

  /// Kartu statistik game pemain
  Widget _buildStatsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGreen.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('🪙', '$_totalCoins', 'Total Koin'),
          _buildStatDivider(),
          _buildStatItem('🎮', '$_totalSessions', 'Sesi Main'),
          _buildStatDivider(),
          _buildStatItem('🏆', '$_highScore', 'High Score'),
        ],
      ),
    );
  }

  Widget _buildStatItem(String emoji, String value, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            color: Colors.white60,
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
      height: 40,
      width: 1,
      color: Colors.white24,
    );
  }

  /// Kartu game LokaCatch dengan desain premium
  Widget _buildGameCard({
    required String title,
    required String subtitle,
    required String description,
    required String emoji,
    required String badge,
    required Color badgeColor,
    required bool isNew,
    required String reward,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.pureWhite,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.borderLight),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Emoji icon
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.surfaceCream,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 32)),
              ),
            ),
            const SizedBox(width: 14),
            // Info game
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      if (isNew)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'BARU',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: badgeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.accentGoldLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.monetization_on_rounded,
                                size: 12, color: AppColors.accentGold),
                            const SizedBox(width: 4),
                            Text(
                              reward,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Mainkan ▶',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Bagian klaim voucher berdasarkan koin yang dimiliki
  Widget _buildVoucherSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accentGoldLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Text('🎫', style: TextStyle(fontSize: 32)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tukar Koin dengan Voucher',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  'Kumpulkan koin dari LokaCatch untuk mendapatkan voucher wisata eksklusif!',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const VoucherScreen()),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentGold,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: Text(
              'Klaim',
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
}
