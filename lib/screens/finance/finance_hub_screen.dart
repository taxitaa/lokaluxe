import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/services/currency_provider.dart';
import '../../core/services/currency_service.dart';
import '../../core/services/location_provider.dart';
import '../../core/services/timezone_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/database/db_helper.dart';
import '../../core/models/hotel_model.dart';
import '../../core/models/transport_model.dart';
import '../location/location_picker_modal.dart';

/// Layar Finance Hub yang ditingkatkan dengan:
/// - Konversi mata uang real-time (IDR ↔ USD/EUR/JPY)
/// - Caching offline kurs mata uang
/// - Harga hotel & transportasi tampil dalam mata uang pilihan
/// - Jam zona waktu real-time: WIB, WITA, WIT, London
class FinanceHubScreen extends StatefulWidget {
  const FinanceHubScreen({super.key});

  @override
  State<FinanceHubScreen> createState() => _FinanceHubScreenState();
}

class _FinanceHubScreenState extends State<FinanceHubScreen>
    with SingleTickerProviderStateMixin {
  // ---------------------------------------------------
  // TAB CONTROLLER
  // ---------------------------------------------------
  late TabController _tabController;

  // ---------------------------------------------------
  // STATE KONVERSI MATA UANG
  // ---------------------------------------------------
  final TextEditingController _convertController =
      TextEditingController(text: '1000000');
  String _targetCurrency = 'USD';
  bool _isLoadingRates = true;
  String? _ratesError;
  DateTime? _lastFetchTime;

  // ---------------------------------------------------
  // STATE ZONA WAKTU (diperbarui setiap detik)
  // ---------------------------------------------------
  Timer? _clockTimer;
  List<TimeZoneInfo> _timeZones = [];

  // ---------------------------------------------------
  // STATE DATA DATABASE
  // ---------------------------------------------------
  List<HotelModel> _hotels = [];
  List<TransportModel> _transports = [];
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initTimeZone();
    _loadDatabaseData();
    // Inisialisasi CurrencyProvider setelah frame pertama selesai render
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initCurrencyProvider();
    });
  }

  /// Menginisialisasi jam dan memulai timer update setiap detik
  void _initTimeZone() {
    _timeZones = TimeZoneService.getAllZones();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _timeZones = TimeZoneService.getAllZones();
        });
      }
    });
  }

  /// Menginisialisasi CurrencyProvider (ambil kurs dari API/cache)
  Future<void> _initCurrencyProvider() async {
    final provider = context.read<CurrencyProvider>();
    setState(() => _isLoadingRates = true);
    try {
      await provider.refreshRates();
      _lastFetchTime = provider.lastFetchTime;
      _ratesError = provider.errorMessage;
    } catch (_) {
      _ratesError = 'Gagal memuat kurs. Menggunakan data offline.';
    } finally {
      if (mounted) setState(() => _isLoadingRates = false);
    }
    // Sinkronkan target currency dengan provider
    setState(() {
      _targetCurrency = provider.selectedCurrency == 'IDR'
          ? 'USD'
          : provider.selectedCurrency;
    });
  }

  /// Memuat data hotel & transportasi dari SQLite
  Future<void> _loadDatabaseData() async {
    setState(() => _isLoadingData = true);
    try {
      final hotels = await DBHelper.getHotelModels();
      final transports = await DBHelper.getTransportModels();
      if (mounted) {
        setState(() {
          _hotels = hotels.take(5).toList(); // Tampilkan 5 teratas
          _transports = transports.take(5).toList();
          _isLoadingData = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _convertController.dispose();
    _clockTimer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------
  // BUILD
  // ---------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmCream,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCurrencyTab(),
                _buildPricesTab(),
                _buildTimeZoneTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// AppBar dengan selector mata uang global
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.warmCream,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.chevron_left_rounded,
            size: 28, color: AppColors.textDark),
        onPressed: () => Navigator.of(context).pop(),
      ),
      centerTitle: true,
      title: Text(
        'Finance & Time',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
      ),
      actions: [
        // Tombol refresh kurs
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: AppColors.textDark),
          onPressed: () async {
            await context.read<CurrencyProvider>().refreshRates(forceRefresh: true);
            if (mounted) {
              setState(() {
                _lastFetchTime = context.read<CurrencyProvider>().lastFetchTime;
                _ratesError = context.read<CurrencyProvider>().errorMessage;
              });
            }
          },
          tooltip: 'Refresh rates',
        ),
      ],
    );
  }

  /// TabBar: Konversi | Harga | Zona Waktu
  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceCream,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppColors.primaryGreen,
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textSecondary,
        dividerColor: Colors.transparent,
        labelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontSize: 12),
        tabs: const [
          Tab(text: '💱 Currency'),
          Tab(text: '💰 Prices'),
          Tab(text: '🕐 Time'),
        ],
      ),
    );
  }

  // ============================================================
  // TAB 1: KONVERSI MATA UANG
  // ============================================================

  Widget _buildCurrencyTab() {
    return Consumer<CurrencyProvider>(
      builder: (context, provider, _) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status kurs
              _buildRatesStatusBanner(provider),
              const SizedBox(height: 16),

              // Selector mata uang global
              _buildGlobalCurrencySelector(provider),
              const SizedBox(height: 20),

              // Kartu konverter cepat
              _buildQuickConverter(provider),
              const SizedBox(height: 20),

              // Grid semua kurs
              _buildAllRatesGrid(provider),
            ],
          ),
        );
      },
    );
  }

  /// Banner status kurs (online/offline/loading)
  Widget _buildRatesStatusBanner(CurrencyProvider provider) {
    if (provider.isLoading) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.primaryGreenSubtle,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Updating exchange rates...',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: AppColors.primaryGreen,
              ),
            ),
          ],
        ),
      );
    }

    if (provider.errorMessage != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3CD),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.wifi_off_rounded, color: Colors.orange, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                provider.errorMessage!,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: Colors.orange.shade800,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Sukses
    final fetchStr = provider.lastFetchTime != null
        ? 'Updated: ${TimeZoneService.formatTime(provider.lastFetchTime!.toLocal())}'
        : 'Live exchange rates';
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.badgeGreenBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              color: AppColors.successGreen, size: 16),
          const SizedBox(width: 8),
          Text(
            fetchStr,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: AppColors.successGreen,
            ),
          ),
        ],
      ),
    );
  }

  /// Shows the location that controls the app-wide currency and time zone.
  Widget _buildGlobalCurrencySelector(CurrencyProvider provider) {
    final location = context.watch<LocationProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Regional settings',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${location.currentLocation.displayName} · ${provider.selectedCurrency}',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () async {
            await LocationPickerModal.show(context);
            if (!mounted) return;
            final selected = context.read<CurrencyProvider>().selectedCurrency;
            setState(() => _targetCurrency = selected == 'IDR' ? 'USD' : selected);
          },
          icon: const Icon(Icons.location_on_outlined, size: 16),
          label: const Text('Change location'),
        ),
      ],
    );
  }

  /// Konverter cepat IDR ke mata uang pilihan
  Widget _buildQuickConverter(CurrencyProvider provider) {
    final inputVal =
        double.tryParse(_convertController.text.replaceAll('.', '')) ?? 0.0;
    final converted = CurrencyService.convert(
      amountIDR: inputVal,
      targetCurrency: _targetCurrency,
      rates: provider.rates,
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick converter',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 14),

          // Input in IDR
          _buildCurrencyRow(
            flag: '🇮🇩',
            code: 'IDR',
            child: TextField(
              controller: _convertController,
              keyboardType: TextInputType.number,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: '0',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),

          // Ikon swap
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primaryGreenSubtle,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.swap_vert_rounded,
                    color: AppColors.primaryGreen, size: 20),
              ),
            ),
          ),

          // Output target currency dengan dropdown
          _buildCurrencyRow(
            flag: CurrencyService.currencyFlags[_targetCurrency] ?? '',
            code: _targetCurrency,
            isDropdown: true,
            onCurrencyChange: (val) {
              if (val != null) setState(() => _targetCurrency = val);
            },
            child: Text(
              CurrencyService.formatAmount(converted, _targetCurrency),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryGreen,
              ),
            ),
          ),

          // Info kurs saat ini
          if (provider.rates.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceCream,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    '1 IDR = ${CurrencyService.formatAmount(provider.rates[_targetCurrency] ?? 1.0, _targetCurrency)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Baris mata uang dengan flag, kode, dan widget anak
  Widget _buildCurrencyRow({
    required String flag,
    required String code,
    required Widget child,
    bool isDropdown = false,
    ValueChanged<String?>? onCurrencyChange,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceCream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          if (isDropdown)
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: code,
                items: ['USD', 'EUR', 'JPY'].map((c) {
                  return DropdownMenuItem(
                    value: c,
                    child: Text(
                      '${CurrencyService.currencyFlags[c]} $c',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: onCurrencyChange,
              ),
            )
          else
            Text(
              '$flag $code',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
          const SizedBox(width: 12),
          Expanded(child: child),
        ],
      ),
    );
  }

  /// Grid semua kurs dari IDR
  Widget _buildAllRatesGrid(CurrencyProvider provider) {
    if (provider.rates.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rates from IDR',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 10),
        ...['USD', 'EUR', 'JPY'].map((currency) {
          final rate = provider.rates[currency] ?? 0;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.pureWhite,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Row(
              children: [
                Text(
                  CurrencyService.currencyFlags[currency] ?? '',
                  style: const TextStyle(fontSize: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currency,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        CurrencyService.currencyNames[currency] ?? '',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '1 IDR',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '= ${CurrencyService.formatAmount(rate, currency)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ============================================================
  // TAB 2: HARGA HOTEL & TRANSPORTASI (dalam mata uang pilihan)
  // ============================================================

  Widget _buildPricesTab() {
    return Consumer<CurrencyProvider>(
      builder: (context, provider, _) {
        if (_isLoadingData) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
            ),
          );
        }

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Indikator mata uang aktif
              _buildActiveCurrencyIndicator(provider),
              const SizedBox(height: 16),

              // Hotel
              _buildSectionHeader('🏨 Hotel Pilihan', Icons.hotel_rounded),
              const SizedBox(height: 10),
              ..._hotels.map((h) => _buildHotelItem(h, provider)),

              const SizedBox(height: 20),

              // Transportasi
              _buildSectionHeader('🚀 Transportasi', Icons.directions_car_rounded),
              const SizedBox(height: 10),
              ..._transports.map((t) => _buildTransportItem(t, provider)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActiveCurrencyIndicator(CurrencyProvider provider) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryGreen, AppColors.primaryGreenLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Text(
            provider.currencyFlag,
            style: const TextStyle(fontSize: 24),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Prices are shown in ${provider.selectedCurrency}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  provider.currencyName,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _tabController.animateTo(0),
            child: Text(
              'Change',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: AppColors.accentGold,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primaryGreen),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }

  /// Item harga hotel dengan konversi mata uang
  Widget _buildHotelItem(HotelModel hotel, CurrencyProvider provider) {
    final convertedPrice = provider.convertAndFormat(hotel.pricePerNight);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryGreenSubtle,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '⭐' * hotel.stars.clamp(1, 5),
                style: const TextStyle(fontSize: 8),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hotel.name,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  hotel.locationDescription,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                convertedPrice,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryGreen,
                ),
              ),
              Text(
                '/ night',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Item harga transportasi dengan konversi mata uang
  Widget _buildTransportItem(TransportModel transport, CurrencyProvider provider) {
    final convertedPrice = provider.convertAndFormat(transport.price);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surfaceCream,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                _getTransportEmoji(transport.type),
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transport.name,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${transport.type} • ${transport.route}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                convertedPrice,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryGreen,
                ),
              ),
              Text(
                transport.priceUnit,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Helper: emoji untuk tipe transportasi
  String _getTransportEmoji(String type) {
    switch (type) {
      case 'Pesawat': return '✈️';
      case 'Kereta': return '🚂';
      case 'Bus': return '🚌';
      case 'Kapal': return '🚢';
      case 'Sewa Mobil': return '🚗';
      case 'Sewa Motor': return '🛵';
      default: return '🚀';
    }
  }

  // ============================================================
  // TAB 3: ZONA WAKTU
  // ============================================================

  Widget _buildTimeZoneTab() {
    return Consumer<LocationProvider>(
      builder: (context, locProvider, _) {
        final activeLoc = locProvider.currentLocation;
        final activeZoneInfo = TimeZoneService.getZoneInfo(activeLoc.timezone);

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banner lokasi aktif
              _buildActiveLocationBanner(activeLoc, activeZoneInfo),
              const SizedBox(height: 16),

              // Kartu waktu besar untuk lokasi aktif
              _buildMainTimeCard(activeZoneInfo),
              const SizedBox(height: 16),

              // Grid zona waktu referensi (WIB, Tokyo, London, Paris)
              Text(
                'Reference time zones',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 10),
              ..._timeZones.map((tz) => _buildTimeZoneCard(tz, activeZoneInfo.code)),

              const SizedBox(height: 20),
              _buildTimeConversionInfo(),
            ],
          ),
        );
      },
    );
  }

  /// Banner info lokasi aktif dengan emoji bendera & mata uang
  Widget _buildActiveLocationBanner(
    dynamic activeLoc,
    TimeZoneInfo activeZone,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryGreen, AppColors.primaryGreenLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Text(activeLoc.flag, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${activeLoc.city}, ${activeLoc.country}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '${activeZone.name} (${activeZone.offset})',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: Colors.white70,
                  ),
                ),
                Text(
                  TimeZoneService.formatDate(activeZone.localTime),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: Colors.white60,
                  ),
                ),
              ],
            ),
          ),
          // Waktu singkat
          Text(
            TimeZoneService.formatTimeShort(activeZone.localTime),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.accentGold,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  /// Kartu waktu besar untuk zona waktu lokasi aktif
  Widget _buildMainTimeCard(TimeZoneInfo tz) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(tz.flag, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                tz.code,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreenSubtle,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  tz.offset,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            TimeZoneService.formatTime(tz.localTime),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 52,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryGreen,
              letterSpacing: -2,
            ),
          ),
          Text(
            tz.location,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Kartu zona waktu individual dalam daftar referensi.
  ///
  /// [activeCode] kode zona aktif (dari lokasi yang dipilih pengguna),
  /// digunakan untuk menambahkan highlight/badge "AKTIF" pada kartu terkait.
  Widget _buildTimeZoneCard(TimeZoneInfo tz, String activeCode) {
    final isActive = tz.code == activeCode;
    final isLondon = tz.flag == '🇬🇧';

    Color borderColor = AppColors.borderLight;
    if (isActive) borderColor = AppColors.primaryGreen.withValues(alpha: 0.5);
    else if (isLondon) borderColor = AppColors.accentGold.withValues(alpha: 0.4);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.primaryGreen.withValues(alpha: 0.05)
            : AppColors.pureWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: isActive ? 1.5 : 1.0),
      ),
      child: Row(
        children: [
          // Flag & kode zona
          Column(
            children: [
              Text(tz.flag, style: const TextStyle(fontSize: 24)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.primaryGreenSubtle
                      : isLondon
                          ? AppColors.accentGoldLight
                          : AppColors.primaryGreenSubtle,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  tz.code,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isLondon && !isActive
                        ? AppColors.accentGold
                        : AppColors.primaryGreen,
                  ),
                ),
              ),
              if (isActive) ...[
                const SizedBox(height: 3),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'AKTIF',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 7,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(width: 14),

          // Info zona
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tz.name,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  tz.location,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  'UTC ${tz.offset}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),

          // Jam digital
          Text(
            TimeZoneService.formatTime(tz.localTime),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: isActive
                  ? AppColors.primaryGreen
                  : isLondon
                      ? AppColors.accentGold
                      : AppColors.primaryGreen,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  /// Info konversi waktu antar zona
  Widget _buildTimeConversionInfo() {
    if (_timeZones.length < 4) return const SizedBox.shrink();

    final wib = _timeZones[0];
    final wita = _timeZones[1];
    final wit = _timeZones[2];
    final london = _timeZones[3];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule_rounded,
                  size: 16, color: AppColors.primaryGreen),
              const SizedBox(width: 8),
              Text(
                'Time difference (from WIB)',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildDiffRow(wib, wita, '+1 jam dari WIB'),
          _buildDiffRow(wib, wit, '+2 jam dari WIB'),
          _buildDiffRow(wib, london,
              '${london.offsetHours - wib.offsetHours} jam dari WIB'),
        ],
      ),
    );
  }

  Widget _buildDiffRow(TimeZoneInfo from, TimeZoneInfo to, String diff) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(to.flag, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text(
            '${to.code}:',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            diff,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            TimeZoneService.formatTime(to.localTime),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryGreen,
            ),
          ),
        ],
      ),
    );
  }
}
