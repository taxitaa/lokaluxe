import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/models/user_model.dart';
import '../../core/services/app_strings.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/currency_provider.dart';
import '../../core/services/currency_service.dart';
import '../../core/services/localization_provider.dart';
import '../../core/services/location_provider.dart';
import '../../core/services/preferences_service.dart';
import '../../core/services/timezone_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/database/db_helper.dart';
import '../../core/models/trip_model.dart';
import '../budget/budget_planner_screen.dart';
import '../finance/finance_hub_screen.dart';
import '../game/mini_game_screen.dart';
import '../itinerary/itinerary_screen.dart';
import '../location/location_picker_modal.dart';
import 'search_results_screen.dart';
import 'popular_wisata_screen.dart';
import 'notification_inbox_screen.dart';
import '../voucher/voucher_screen.dart';
import '../hotel/hotel_catalog_screen.dart';
import '../wisata/wisata_catalog_screen.dart';
import '../transportasi/transport_catalog_screen.dart';

class BerandaScreen extends StatefulWidget {
  final Function(int) onTabChange;
  final int profileRefreshToken;

  const BerandaScreen({
    super.key,
    required this.onTabChange,
    this.profileRefreshToken = 0,
  });

  @override
  State<BerandaScreen> createState() => _BerandaScreenState();
}

class _BerandaScreenState extends State<BerandaScreen> {
  int _selectedCategoryIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  late final Future<List<Map<String, dynamic>>> _popularWisataFuture =
      DBHelper.getWisata();
  double? _remainingBudget;
  TripModel? _activeTrip;
  UserModel? _currentUser;
  Uint8List? _profilePhoto;
  bool _budgetLoadFailed = false;

  @override
  void initState() {
    super.initState();
    _loadRemainingBudget();
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant BerandaScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profileRefreshToken != widget.profileRefreshToken) {
      _loadCurrentUser();
    }
  }

  void _open(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  Future<void> _openWisataCatalog({String? initialDestination}) async {
    final wisata = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => WisataCatalogScreen(
          initialDestination: initialDestination,
          onSelectWisata: (_) {},
        ),
      ),
    );
    if (wisata == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ItineraryScreen(pendingWisata: wisata),
      ),
    );
    await _loadRemainingBudget();
  }

  Future<void> _loadRemainingBudget() async {
    try {
      final trip = await DBHelper.getActiveTrip();
      final remainingBudget = await DBHelper.getRemainingBudget();
      if (!mounted) return;
      setState(() {
        _activeTrip = trip;
        _remainingBudget = remainingBudget;
        _budgetLoadFailed = false;
      });
    } catch (error) {
      debugPrint('[BerandaScreen] Could not load remaining budget: $error');
      if (!mounted) return;
      setState(() {
        _activeTrip = null;
        _remainingBudget = null;
        _budgetLoadFailed = true;
      });
    }
  }

  Future<void> _loadCurrentUser() async {
    final user = await AuthService.checkSession();
    if (!mounted) return;
    Uint8List? photo;
    if (user != null) {
      try {
        final userKey = user.id?.toString() ?? user.email.trim().toLowerCase();
        final savedPhoto = await PreferencesService.getProfilePhoto(userKey);
        if (savedPhoto != null) photo = base64Decode(savedPhoto);
      } catch (error, stackTrace) {
        debugPrint('[BerandaScreen] Could not load profile photo: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
    if (!mounted) return;
    setState(() {
      _currentUser = user;
      _profilePhoto = photo;
    });
  }

  String get _displayName {
    final name = _currentUser?.fullName.trim();
    return name == null || name.isEmpty ? 'Traveler' : name;
  }

  String get _profileInitials {
    final parts = _displayName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2);
    return parts.map((part) => part[0].toUpperCase()).join();
  }

  Future<void> _openBudgetPlanner() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const BudgetPlannerScreen()));
    await _loadRemainingBudget();
  }

  Future<void> _openItinerary() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ItineraryScreen()));
    await _loadRemainingBudget();
  }

  void _submitSearch(String query) {
    final keyword = query.trim();
    if (keyword.isEmpty) return;
    _open(SearchResultsScreen(query: keyword));
  }

  @override
  Widget build(BuildContext context) {
    // Reaktif terhadap perubahan bahasa
    final s = context.watch<LocalizationProvider>().strings;
    final currencyProvider = context.watch<CurrencyProvider>();

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
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.pureWhite,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: _softShadow(0.05),
                                border: Border.all(
                                  color: AppColors.borderLight,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    loc.flag,
                                    style: const TextStyle(fontSize: 13),
                                  ),
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
                                    color: AppColors.textSecondary,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Badge mata uang / toggle USD-IDR
                            _buildCurrencyBadge(currency, symbol),
                          ],
                        ),
                      );
                    },
                  ),

                  // Notif + Avatar
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Notifikasi',
                        onPressed: () => _open(
                          const NotificationInboxScreen(),
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.pureWhite,
                          fixedSize: const Size(38, 38),
                          shadowColor: Colors.black.withValues(alpha: 0.05),
                          elevation: 1,
                        ),
                        icon: const Icon(
                          Icons.notifications_none_rounded,
                          size: 20,
                          color: AppColors.textDark,
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
                              color: AppColors.accentGold,
                              width: 1.5,
                            ),
                            color: AppColors.primaryGreen,
                          ),
                          alignment: Alignment.center,
                          clipBehavior: Clip.antiAlias,
                          child: _profilePhoto == null
                              ? Text(
                                  _profileInitials,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : Image.memory(
                                  _profilePhoto!,
                                  width: 38,
                                  height: 38,
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // 2. Greeting & Tagline — lokalisasi otomatis
              Text(
                s.greeting.fill({'name': _displayName.split(' ').first}),
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

              // 3. Remaining budget opens the trip budget planner.
              InkWell(
                onTap: _openBudgetPlanner,
                borderRadius: BorderRadius.circular(99),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
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
                        _activeTrip == null
                            ? 'Trip budget '
                            : '${s.budgetRemaining} ',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white70,
                        ),
                      ),
                      Text(
                        _budgetLoadFailed
                            ? 'Unavailable'
                            : _activeTrip == null
                            ? 'Atur sekarang'
                            : _remainingBudget == null
                            ? '...'
                            : currencyProvider.convertAndFormat(
                                _remainingBudget!,
                              ),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accentGold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: AppColors.accentGold,
                      ),
                    ],
                  ),
                ),
              ),
              if (_activeTrip != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Total budget: ${currencyProvider.convertAndFormat(_activeTrip!.targetBudget)}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ],

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
                        textInputAction: TextInputAction.search,
                        onSubmitted: _submitSearch,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: AppColors.textDark,
                        ),
                        decoration: InputDecoration(
                          hintText: s.searchHint,
                          hintStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 20,
                            color: AppColors.textSecondary,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 13,
                          ),
                        ),
                      ),
                    ),
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
                    onTap: _openBudgetPlanner,
                  ),
                  _buildQuickAction(
                    icon: Icons.route_outlined,
                    label: 'Itinerary',
                    color: AppColors.accentGold,
                    onTap: _openItinerary,
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
              const SizedBox(height: 12),
              Consumer<LocationProvider>(
                builder: (context, locationProvider, _) {
                  final location = locationProvider.currentLocation;
                  final currencyFlag =
                      CurrencyService.currencyFlags[location.currency] ??
                      location.flag;

                  return Row(
                    children: [
                      Expanded(
                        child: _buildFinancePreviewCard(
                          title: 'Currency',
                          value: '$currencyFlag ${location.currency}',
                          subtitle: location.displayName,
                          icon: Icons.currency_exchange_rounded,
                          color: AppColors.primaryGreen,
                          onTap: () => _open(const FinanceHubScreen.currency()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StreamBuilder<DateTime>(
                          stream: Stream<DateTime>.periodic(
                            const Duration(seconds: 1),
                            (_) => DateTime.now(),
                          ),
                          initialData: DateTime.now(),
                          builder: (context, snapshot) {
                            final zone = TimeZoneService.getZoneInfo(
                              location.timezone,
                              now: snapshot.data,
                            );
                            return _buildFinancePreviewCard(
                              title: 'Time',
                              value: TimeZoneService.formatTimeShort(
                                zone.localTime,
                              ),
                              subtitle: '${location.city} · ${zone.code}',
                              icon: Icons.access_time_rounded,
                              color: AppColors.accentGold,
                              onTap: () => _open(const FinanceHubScreen.time()),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 24),

              // 6. Kategori Pilihan
              _sectionHeader(s.categories),
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
                        if (index == 0)
                          _open(const HotelCatalogScreen());
                        else if (index == 1)
                          _open(const TransportCatalogScreen());
                        else if (index == 2)
                          _openWisataCatalog();
                      },
                      borderRadius: BorderRadius.circular(99),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primaryGreen
                              : AppColors.pureWhite,
                          borderRadius: BorderRadius.circular(99),
                          boxShadow: isSelected ? null : _softShadow(0.05),
                        ),
                        child: Row(
                          children: [
                            Text(
                              categories[index]['icon']!,
                              style: const TextStyle(fontSize: 13),
                            ),
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

              // 7. Popular attractions by region
              _sectionHeader(
                s.popularIn,
                action: s.viewAll,
                onTap: () => _open(const PopularWisataScreen()),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 230,
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _popularWisataFuture,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Gagal memuat wisata: ${snapshot.error}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: AppColors.errorRed,
                          ),
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final featured = _featuredWisataByRegion(snapshot.data!);
                    if (featured.isEmpty) {
                      return Center(
                        child: Text(
                          'Belum ada data wisata.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      clipBehavior: Clip.none,
                      itemCount: featured.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 14),
                      itemBuilder: (context, index) {
                        final wisata = featured[index];
                        final price = (wisata['harga_tiket'] as num?)
                            ?.toDouble();
                        return _buildPopularCard(
                          wisata: wisata,
                          price: price == null
                              ? ''
                              : price == 0
                              ? 'Gratis'
                              : currencyProvider.convertAndFormat(price),
                          onTap: () => _openWisataCatalog(
                            initialDestination: (wisata['nama_wisata'] ?? '')
                                .toString(),
                          ),
                        );
                      },
                    );
                  },
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

  List<Map<String, dynamic>> _featuredWisataByRegion(
    List<Map<String, dynamic>> wisataList,
  ) {
    final featured = <Map<String, dynamic>>[];
    final regions = <String>{};
    for (final wisata in wisataList) {
      final region = (wisata['provinsi'] ?? '').toString().trim();
      if (regions.add(region)) featured.add(wisata);
    }
    return featured;
  }

  Widget _sectionHeader(String title, {String? action, VoidCallback? onTap}) =>
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          if (action != null)
            InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                child: Text(
                  action,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accentGold,
                  ),
                ),
              ),
            ),
        ],
      );

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) => InkWell(
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
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
      ],
    ),
  );

  Widget _buildFinancePreviewCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Container(
      height: 120,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: _softShadow(0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 21, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: color,
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildPopularCard({
    required Map<String, dynamic> wisata,
    required String price,
    required VoidCallback onTap,
  }) {
    final imageUrl = (wisata['image_url'] ?? '').toString().trim();
    final province = (wisata['provinsi'] ?? '').toString().trim();
    final city = (wisata['kota_kabupaten'] ?? '').toString().trim();
    final location = [
      city,
      province,
    ].where((part) => part.isNotEmpty).join(', ');
    final fallback = Container(
      height: 120,
      width: double.infinity,
      color: AppColors.surfaceCream,
      alignment: Alignment.center,
      child: const Icon(
        Icons.attractions_rounded,
        size: 40,
        color: AppColors.primaryGreen,
      ),
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 210,
        decoration: BoxDecoration(
          color: AppColors.pureWhite,
          borderRadius: BorderRadius.circular(24),
          boxShadow: _softShadow(0.06),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 120,
              width: double.infinity,
              child: imageUrl.isEmpty
                  ? fallback
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => fallback,
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (wisata['nama_wisata'] ?? '').toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    location.isEmpty ? province : location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          price,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      if (province.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Container(
                          constraints: const BoxConstraints(maxWidth: 88),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accentGoldLight,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            province,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                      ],
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

  // ─── Currency Badge / Toggle ──────────────────────────────────────────────

  Widget _buildCurrencyBadge(String currency, String symbol) {
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
}
