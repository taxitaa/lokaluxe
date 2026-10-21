import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/services/app_strings.dart';
import '../../core/services/currency_provider.dart';
import '../../core/services/currency_service.dart';
import '../../core/services/localization_provider.dart';
import '../../core/services/location_provider.dart';
import '../../core/theme/app_colors.dart';
import '../budget/budget_planner_screen.dart';
import '../destination/destination_detail_screen.dart';
import '../finance/finance_hub_screen.dart';
import '../game/mini_game_screen.dart';
import '../itinerary/itinerary_screen.dart';
import '../location/location_picker_modal.dart';
import '../voucher/voucher_screen.dart';
import '../hotel/hotel_catalog_screen.dart';
import '../wisata/wisata_catalog_screen.dart';
import '../transportasi/transport_catalog_screen.dart';

class BerandaScreen extends StatefulWidget {
  final Function(int) onTabChange;
  const BerandaScreen({super.key, required this.onTabChange});

  @override
  State<BerandaScreen> createState() => _BerandaScreenState();
}

class _BerandaScreenState extends State<BerandaScreen> {
  int _selectedCategoryIndex = 0;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _open(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    // Reaktif terhadap perubahan bahasa
    final s = context.watch<LocalizationProvider>().strings;

    // Kategori menggunakan string lokalisasi
    final categories = [
      {'icon': '🏨', 'name': s.hotels},
      {'icon': '🚗', 'name': s.transport},
      {'icon': '🏛️', 'name': s.wisata},
    ];

    return Scaffold(
      backgroundColor: AppColors.warmCream,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Top Bar: Location pill + Profile Avatar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Location pill — reaktif terhadap lokasi & bahasa
                  Consumer2<LocationProvider, CurrencyProvider>(
                    builder: (ctx, locProvider, currProvider, _) {
                      final loc = locProvider.currentLocation;
                      final currency = currProvider.selectedCurrency;
                      final symbol =
                          CurrencyService.currencySymbols[currency] ?? '';

                      return GestureDetector(
                        onTap: () => LocationPickerModal.show(context),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.currentLocation,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.0,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 3),
                            // Pill lokasi
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.pureWhite,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: _softShadow(0.05),
                                border: Border.all(
                                    color: AppColors.borderLight, width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(loc.flag,
                                      style: const TextStyle(fontSize: 13)),
                                  const SizedBox(width: 5),
                                  Text(
                                    '${loc.city}, ${loc.countryCode}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 15,
                                      color: AppColors.textSecondary),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Badge mata uang / toggle USD-IDR
                            _buildCurrencyBadge(
                                locProvider, currency, symbol, s),
                          ],
                        ),
                      );
                    },
                  ),

                  // Notif + Avatar
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.pureWhite,
                          shape: BoxShape.circle,
                          boxShadow: _softShadow(0.05),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            const Icon(Icons.notifications_none_rounded,
                                size: 20, color: AppColors.textDark),
                            Positioned(
                              top: 8,
                              right: 9,
                              child: Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: AppColors.accentGold,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      InkWell(
                        onTap: () => widget.onTabChange(3),
                        customBorder: const CircleBorder(),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppColors.accentGold, width: 1.5),
                            color: AppColors.primaryGreen,
                          ),
                          alignment: Alignment.center,
                          child: const Text('AMALIA',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // 2. Greeting & Tagline — lokalisasi otomatis
              Text(
                s.greeting.fill({'name': 'Amalia'}),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              RichText(
                text: TextSpan(
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                  children: [
                    TextSpan(
                      text: '${s.tagline} ',
                      style: const TextStyle(color: AppColors.textDark),
                    ),
                    TextSpan(
                      text: s.taglineHighlight,
                      style: const TextStyle(color: AppColors.accentGold),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // 3. Sisa Budget Pill → Finance Hub
              InkWell(
                onTap: () => _open(const FinanceHubScreen()),
                borderRadius: BorderRadius.circular(99),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('💰', style: TextStyle(fontSize: 13)),
                      const SizedBox(width: 6),
                      Text(
                        '${s.budgetRemaining} ',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white70,
                        ),
                      ),
                      Text(
                        'Rp 4.960.000',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accentGold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right_rounded,
                          size: 16, color: AppColors.accentGold),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // 4. Search Bar
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.pureWhite,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: _softShadow(0.06),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 13, color: AppColors.textDark),
                        decoration: InputDecoration(
                          hintText: s.searchHint,
                          hintStyle: GoogleFonts.plusJakartaSans(
                              fontSize: 13, color: AppColors.textMuted),
                          prefixIcon: const Icon(Icons.search_rounded,
                              size: 20, color: AppColors.textSecondary),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 13),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryGreen,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.tune_rounded,
                        size: 20, color: AppColors.accentGold),
                  ),
                ],
              ),

              const SizedBox(height: 22),

              // 5. Quick Feature Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildQuickAction(
                    icon: Icons.calculate_outlined,
                    label: 'Budget Trip',
                    color: AppColors.primaryGreen,
                    onTap: () => _open(const BudgetPlannerScreen()),
                  ),
                  _buildQuickAction(
                    icon: Icons.route_outlined,
                    label: 'Itinerary',
                    color: AppColors.accentGold,
                    onTap: () => _open(const ItineraryScreen()),
                  ),
                  _buildQuickAction(
                    icon: Icons.sports_esports_outlined,
                    label: s.miniGame,
                    color: AppColors.primaryGreen,
                    onTap: () => _open(const MiniGameScreen()),
                  ),
                  _buildQuickAction(
                    icon: Icons.card_giftcard_outlined,
                    label: s.voucher,
                    color: AppColors.accentGold,
                    onTap: () => _open(const VoucherScreen()),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // 6. Kategori Pilihan
              _sectionHeader(s.categories, s.viewAll),
              const SizedBox(height: 12),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final isSelected = _selectedCategoryIndex == index;
                    return InkWell(
                      onTap: () {
                        setState(() => _selectedCategoryIndex = index);
                        if (index == 0) _open(const HotelCatalogScreen());
                        else if (index == 1) _open(const TransportCatalogScreen());
                        else if (index == 2) _open(const WisataCatalogScreen());
                      },
                      borderRadius: BorderRadius.circular(99),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primaryGreen
                              : AppColors.pureWhite,
                          borderRadius: BorderRadius.circular(99),
                          boxShadow: isSelected ? null : _softShadow(0.05),
                        ),
                        child: Row(
                          children: [
                            Text(categories[index]['icon']!,
                                style: const TextStyle(fontSize: 13)),
                            const SizedBox(width: 6),
                            Text(
                              categories[index]['name']!,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // 7. Group Tours
              _sectionHeader(s.groupTours, s.viewAll),
              const SizedBox(height: 12),
              SizedBox(
                height: 230,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  clipBehavior: Clip.none,
                  children: [
                    _buildTourCard(
                      imagePath: 'assets/images/dest_tanahlot.jpg',
                      rating: '4.9',
                      title: 'Riata Bridge / Tanah Lot',
                      location: 'Tabanan, Bali',
                      price: 'Rp 1.250.000',
                      badgeText: s.topChoice,
                      perUnit: s.perPerson,
                      onTap: () => _open(const DestinationDetailScreen(
                        title: 'Riata Bridge & Tanah Lot',
                        location: 'Tabanan, Bali',
                        imagePath: 'assets/images/dest_tanahlot.jpg',
                        price: 'Rp 1.250.000',
                        rating: '4.9',
                      )),
                    ),
                    const SizedBox(width: 14),
                    _buildTourCard(
                      imagePath: 'assets/images/dest_borobudur.jpg',
                      rating: '4.8',
                      title: 'Candi Borobudur Sunrise',
                      location: 'Magelang, Jawa Tengah',
                      price: 'Rp 750.000',
                      badgeText: 'Popular',
                      perUnit: s.perPerson,
                      onTap: () => _open(const DestinationDetailScreen(
                        title: 'Candi Borobudur Sunrise',
                        location: 'Magelang, Jawa Tengah',
                        imagePath: 'assets/images/dest_borobudur.jpg',
                        price: 'Rp 750.000',
                        rating: '4.8',
                      )),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 8. Paling Populer
              _sectionHeader(s.popularIn, s.topChoice),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => _open(const DestinationDetailScreen(
                  title: 'Nusa Penida Island Tour',
                  location: 'Klungkung, Bali',
                  imagePath: 'assets/images/dest_nusapenida.jpg',
                  price: 'Rp 650.000',
                  rating: '4.9',
                )),
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.pureWhite,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: _softShadow(0.06),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          width: 84,
                          height: 84,
                          child: Image.asset(
                            'assets/images/dest_nusapenida.jpg',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.accentGoldLight,
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                s.topChoice,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.accentGold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Nusa Penida Island Tour',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Icon(Icons.star_rounded,
                                    size: 14, color: AppColors.starGold),
                                const SizedBox(width: 3),
                                Text(
                                  '4.9 (425 reviews) • 1 ${s.perDay.replaceAll('/', '').trim()}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Rp 650.000',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
                          Text(
                            s.perPerson,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  List<BoxShadow> _softShadow(double alpha) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: alpha),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];

  Widget _sectionHeader(String title, String action) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              )),
          Text(action,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.accentGold,
              )),
        ],
      );

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.pureWhite,
                borderRadius: BorderRadius.circular(20),
                boxShadow: _softShadow(0.06),
              ),
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(height: 6),
            Text(label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                )),
          ],
        ),
      );

  Widget _buildTourCard({
    required String imagePath,
    required String rating,
    required String title,
    required String location,
    required String price,
    required String badgeText,
    required String perUnit,
    required VoidCallback onTap,
  }) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 210,
          decoration: BoxDecoration(
            color: AppColors.pureWhite,
            borderRadius: BorderRadius.circular(24),
            boxShadow: _softShadow(0.06),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(24)),
                    child: SizedBox(
                      height: 120,
                      width: double.infinity,
                      child: Image.asset(imagePath, fit: BoxFit.cover),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded,
                              size: 13, color: AppColors.starGold),
                          const SizedBox(width: 3),
                          Text(rating,
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        )),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded,
                            size: 11, color: AppColors.textSecondary),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  color: AppColors.textSecondary)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text('$price $perUnit',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textDark,
                              )),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.accentGoldLight,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(badgeText,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                              )),
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

  // ─── Currency Badge / Toggle ──────────────────────────────────────────────

  Widget _buildCurrencyBadge(
    LocationProvider locProvider,
    String currency,
    String symbol,
    AppStrings s,
  ) {
    if (locProvider.needsCurrencySelector) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _currencyChip(
            label: 'USD',
            isSelected: currency == 'USD',
            onTap: () => locProvider.changeOtherRegionCurrency('USD'),
          ),
          const SizedBox(width: 4),
          _currencyChip(
            label: 'IDR',
            isSelected: currency == 'IDR',
            onTap: () => locProvider.changeOtherRegionCurrency('IDR'),
          ),
        ],
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$symbol $currency',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryGreen,
        ),
      ),
    );
  }

  Widget _currencyChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryGreen : AppColors.pureWhite,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? AppColors.primaryGreen
                  : AppColors.borderLight,
            ),
          ),
          child: Text(label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              )),
        ),
      );
}