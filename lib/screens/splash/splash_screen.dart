import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../auth/login_screen.dart';
import '../auth/register_screen.dart';
import '../home/main_navigation_screen.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double circleSize = (size.width * 0.38).clamp(120.0, 160.0);

    return Scaffold(
      backgroundColor: AppColors.pureWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              const SizedBox(height: 12),

              // 2x2 Circular Photo Grid with Star Accents
              SizedBox(
                height: circleSize * 2 + 16,
                width: circleSize * 2 + 16,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Top-Left Star
                    const Positioned(
                      top: 4,
                      left: 10,
                      child: Icon(
                        Icons.add,
                        size: 16,
                        color: AppColors.textMuted,
                      ),
                    ),

                    // Top-Right Middle Star
                    const Positioned(
                      top: 70,
                      right: 0,
                      child: Icon(
                        Icons.add,
                        size: 14,
                        color: AppColors.textMuted,
                      ),
                    ),

                    // Bottom-Left Star
                    const Positioned(
                      bottom: 40,
                      left: 2,
                      child: Icon(
                        Icons.add,
                        size: 14,
                        color: AppColors.textMuted,
                      ),
                    ),

                    // Photo 1: Top-Left (Pantai / Ocean)
                    Positioned(
                      top: 0,
                      left: 0,
                      child: _buildCirclePhoto(
                        size: circleSize,
                        imagePath: 'assets/images/splash_1.jpg',
                      ),
                    ),

                    // Photo 2: Top-Right (Travelers)
                    Positioned(
                      top: 14,
                      right: 0,
                      child: _buildCirclePhoto(
                        size: circleSize,
                        imagePath: 'assets/images/splash_2.jpg',
                      ),
                    ),

                    // Photo 3: Bottom-Left (Resort Villa Pool)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      child: _buildCirclePhoto(
                        size: circleSize,
                        imagePath: 'assets/images/splash_3.jpg',
                      ),
                    ),

                    // Photo 4: Bottom-Right (Raja Ampat Islands)
                    Positioned(
                      bottom: 14,
                      right: 0,
                      child: _buildCirclePhoto(
                        size: circleSize,
                        imagePath: 'assets/images/splash_4.jpg',
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // Main Headline
              Text(
                'Start Exploring\nthe World',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                  letterSpacing: -0.6,
                  height: 1.2,
                ),
              ),

              const SizedBox(height: 12),

              // Subtitle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Curated Indonesian luxury without tourist\ninflation & transparent budget tracking.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Primary "Mulai Jelajah" Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: AppColors.pureWhite,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Mulai Eksplorasi',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 18,
                        color: AppColors.pureWhite,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // "or continue with" Divider
              Row(
                children: [
                  const Expanded(
                    child: Divider(color: AppColors.borderLight, thickness: 1),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'or continue with',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Divider(color: AppColors.borderLight, thickness: 1),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Social Login Row: Google & Apple
              Row(
                children: [
                  // Google Button
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (context) => const MainNavigationScreen(),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.pureWhite,
                        side: const BorderSide(
                          color: AppColors.borderLight,
                          width: 1.2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 18,
                            height: 18,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFEA4335),
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              'G',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Google',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 14),

                  // Apple Button
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (context) => const MainNavigationScreen(),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.pureWhite,
                        side: const BorderSide(
                          color: AppColors.borderLight,
                          width: 1.2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.apple,
                            size: 19,
                            color: AppColors.textDark,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Apple',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Register quick link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Belum punya akun? ',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const RegisterScreen(),
                        ),
                      );
                    },
                    child: Text(
                      'Daftar Sekarang',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCirclePhoto({
    required double size,
    required String imagePath,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.pureWhite, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          imagePath,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: AppColors.surfaceCream,
            child: const Icon(
              Icons.landscape,
              color: AppColors.primaryGreen,
            ),
          ),
        ),
      ),
    );
  }
}
