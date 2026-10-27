import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/services/localization_provider.dart';
import '../../core/services/preferences_service.dart';
import '../../core/theme/app_colors.dart';
import '../auth/login_screen.dart';
import 'models/onboarding_item.dart';
import 'widgets/onboarding_card.dart';
import 'widgets/page_indicator.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingItem> _items = const [
    OnboardingItem(
      title: 'Jelajahi Keindahan Nusantara',
      description:
          'Temukan destinasi eksotis tersembunyi di penjuru Indonesia dengan sentuhan kurasi perjalanan yang berkelas.',
      imagePath: 'assets/images/onboarding_1.jpg',
      tagLocation: 'Danau Beratan, Bali',
      visualType: OnboardingVisualType.destination,
    ),
    OnboardingItem(
      title: 'Liburan Sesuai Budget',
      description:
          'Rancang estimasi anggaran secara transparan dan nikmati liburan impian tanpa kompromi finansial.',
      imagePath: 'assets/images/onboarding_2.jpg',
      tagLocation: 'Luxury Coastal Resort',
      visualType: OnboardingVisualType.budgetPlanner,
    ),
    OnboardingItem(
      title: 'Semua Rencana dalam Satu Aplikasi',
      description:
          'Itinerary pintar, navigasi peta interaktif, dan panduan AI Concierge siap menemani setiap langkahmu.',
      imagePath: 'assets/images/onboarding_3.jpg',
      tagLocation: 'Pulau Padar, Labuan Bajo',
      visualType: OnboardingVisualType.itineraryAndConcierge,
    ),
  ];

  Future<void> _finishOnboarding() async {
    await PreferencesService.setOnboardingCompleted(true);
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            ),
            child: child,
          );
        },
      ),
    );
  }

  void _onNextPressed() {
    if (_currentPage < _items.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finishOnboarding();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocalizationProvider>().strings;
    final items = [
      OnboardingItem(
        title: strings.localized(
          'Jelajahi Keindahan Nusantara',
          'Explore the Beauty of Indonesia',
        ),
        description: strings.localized(
          'Temukan destinasi eksotis tersembunyi di penjuru Indonesia dengan sentuhan kurasi perjalanan yang berkelas.',
          'Discover hidden exotic destinations across Indonesia with thoughtfully curated travel experiences.',
        ),
        imagePath: _items[0].imagePath,
        tagLocation: _items[0].tagLocation,
        visualType: _items[0].visualType,
      ),
      OnboardingItem(
        title: strings.localized('Liburan Sesuai Budget', 'Travel Within Your Budget'),
        description: strings.localized(
          'Rancang estimasi anggaran secara transparan dan nikmati liburan impian tanpa kompromi finansial.',
          'Plan your spending transparently and enjoy your dream holiday without financial compromise.',
        ),
        imagePath: _items[1].imagePath,
        tagLocation: _items[1].tagLocation,
        visualType: _items[1].visualType,
      ),
      OnboardingItem(
        title: strings.localized(
          'Semua Rencana dalam Satu Aplikasi',
          'All Your Plans in One App',
        ),
        description: strings.localized(
          'Itinerary pintar, navigasi peta interaktif, dan panduan AI Concierge siap menemani setiap langkahmu.',
          'Smart itineraries, interactive maps, and an AI concierge are ready to guide every step.',
        ),
        imagePath: _items[2].imagePath,
        tagLocation: _items[2].tagLocation,
        visualType: _items[2].visualType,
      ),
    ];
    final bool isLastPage = _currentPage == _items.length - 1;

    return Scaffold(
      backgroundColor: AppColors.warmCream,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: Brand & Skip Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Minimal brand mark
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.pureWhite,
                          border: Border.all(
                            color: AppColors.goldAccent.withValues(alpha: 0.5),
                            width: 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'L',
                          style: TextStyle(
                            fontFamily: 'serif',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.charcoalDark,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'LokaLuxe',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.charcoalDark,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),

                  // "Lewati" Button
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 250),
                    opacity: isLastPage ? 0.0 : 1.0,
                    child: IgnorePointer(
                      ignoring: isLastPage,
                      child: TextButton(
                        onPressed: _finishOnboarding,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          strings.localized('Lewati', 'Skip'),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Swipeable PageView
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: items.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: OnboardingCard(item: items[index]),
                  );
                },
              ),
            ),

            // Bottom Actions & Page Indicator
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: isLastPage
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MinimalPageIndicator(
                          count: items.length,
                          currentIndex: _currentPage,
                        ),
                        const SizedBox(height: 18),
                        // Full-width "Mulai Jelajah" button
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _finishOnboarding,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.charcoalDark,
                              foregroundColor: AppColors.pureWhite,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(27),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  strings.localized('Mulai Jelajah', 'Start Exploring'),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 18,
                                  color: AppColors.goldAccent,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Minimal page indicator
                        MinimalPageIndicator(
                          count: items.length,
                          currentIndex: _currentPage,
                        ),

                        // "Lanjut" Button
                        ElevatedButton(
                          onPressed: _onNextPressed,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.charcoalDark,
                            foregroundColor: AppColors.pureWhite,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                strings.localized('Lanjut', 'Continue'),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                size: 16,
                                color: AppColors.goldAccent,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
