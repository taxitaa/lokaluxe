import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:provider/provider.dart';
import '../../core/services/localization_provider.dart';
import '../../core/theme/app_colors.dart';
import '../budget/budget_planner_screen.dart';

class DestinationDetailScreen extends StatelessWidget {
  final String title;
  final String location;
  final String imagePath;
  final String price;
  final String rating;

  const DestinationDetailScreen({
    super.key,
    required this.title,
    required this.location,
    required this.imagePath,
    required this.price,
    required this.rating,
  });

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocalizationProvider>().strings;
    return Scaffold(
      backgroundColor: AppColors.pureWhite,
      body: Stack(
        children: [
          // Scrollable Content
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hero Image with Rounded Bottom
                Stack(
                  children: [
                    SizedBox(
                      height: 340,
                      width: double.infinity,
                      child: Image.asset(
                        imagePath,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.4),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.5),
                            ],
                            stops: const [0.0, 0.4, 1.0],
                          ),
                        ),
                      ),
                    ),
                    // Back & Bookmark buttons
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            CircleAvatar(
                              backgroundColor:
                                  Colors.black.withValues(alpha: 0.4),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.chevron_left_rounded,
                                  color: Colors.white,
                                  size: 26,
                                ),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ),
                            CircleAvatar(
                              backgroundColor:
                                  Colors.black.withValues(alpha: 0.4),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.bookmark_border_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                onPressed: () {},
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Floating Badge on Image
                    Positioned(
                      bottom: 20,
                      left: 20,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: AppColors.starGold,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$rating (${strings.localized('428 ulasan terverifikasi', '428 verified reviews')})',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // Content Section
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            size: 15,
                            color: AppColors.primaryGreen,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            location,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Highlight Badges
                      Row(
                        children: [
                          _buildHighlightBadge(
                            strings.localized('🌿 Ekowisata', '🌿 Eco-tourism'),
                          ),
                          const SizedBox(width: 8),
                          _buildHighlightBadge(
                            strings.localized('📸 Spot Estetik', '📸 Scenic spot'),
                          ),
                          const SizedBox(width: 8),
                          _buildHighlightBadge(
                            strings.localized('🧭 Pemandu Lokal', '🧭 Local guide'),
                          ),
                        ],
                      ),

                      const SizedBox(height: 22),

                      Text(
                        strings.localized('Tentang Destinasi', 'About this destination'),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        strings.localized(
                          'Nikmati pesona alam nusantara dengan panorama memukau, suasana eksklusif, dan panduan budget transparan tanpa biaya tersembunyi. Pengalaman liburan berkesan yang dirancang khusus untuk kenyamanan Anda.',
                          'Enjoy the beauty of Indonesia with stunning scenery, an exclusive atmosphere, and transparent budget guidance with no hidden fees. A memorable holiday designed for your comfort.',
                        ),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textSecondary,
                          height: 1.6,
                        ),
                      ),

                      const SizedBox(height: 22),

                      // Card Estimasi Biaya
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceCream,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: AppColors.borderLight,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  strings.localized('Estimasi Biaya Paket', 'Package Cost Estimate'),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textDark,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.badgeGreenBg,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    strings.localized('Penawaran Terbaik', 'Best Deal'),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primaryGreen,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              price,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryGreen,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              strings.localized(
                                'Termasuk tiket masuk, transportasi lokal, dan asuransi perjalanan.',
                                'Includes admission, local transportation, and travel insurance.',
                              ),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 100), // Space for bottom bar
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom Action Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.pureWhite,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          strings.localized('Mulai dari', 'Starting at'),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          price,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    const BudgetPlannerScreen(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            foregroundColor: AppColors.pureWhite,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                strings.localized('Rencanakan Perjalanan', 'Plan a Trip'),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
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

  Widget _buildHighlightBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceCream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight, width: 1),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
        ),
      ),
    );
  }
}
