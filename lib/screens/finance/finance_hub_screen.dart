import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/services/currency_provider.dart';
import '../../core/services/currency_service.dart';
import '../../core/services/app_strings.dart';
import '../../core/services/localization_provider.dart';
import '../../core/services/location_provider.dart';
import '../../core/services/timezone_service.dart';
import '../../core/theme/app_colors.dart';

enum FinanceHubPage { currency, time }

/// Separate currency conversion and local-time pages.
class FinanceHubScreen extends StatefulWidget {
  final FinanceHubPage page;

  const FinanceHubScreen.currency({super.key}) : page = FinanceHubPage.currency;
  const FinanceHubScreen.time({super.key}) : page = FinanceHubPage.time;

  @override
  State<FinanceHubScreen> createState() => _FinanceHubScreenState();
}

class _FinanceHubScreenState extends State<FinanceHubScreen> {
  // ---------------------------------------------------
  // STATE KONVERSI MATA UANG
  // ---------------------------------------------------
  final TextEditingController _convertController = TextEditingController();
  String _sourceCurrency = 'IDR';
  String _targetCurrency = 'USD';

  // ---------------------------------------------------
  // STATE ZONA WAKTU (diperbarui setiap detik)
  // ---------------------------------------------------
  Timer? _clockTimer;
  List<TimeZoneInfo> _timeZones = [];

  @override
  void initState() {
    super.initState();
    if (widget.page == FinanceHubPage.time) {
      _initTimeZone();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initCurrencyProvider();
      });
    }
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
    await provider.refreshRates();
    // Sinkronkan target currency dengan provider
    if (!mounted) return;
    setState(() {
      _targetCurrency = provider.selectedCurrency == 'IDR'
          ? 'USD'
          : provider.selectedCurrency;
    });
  }

  @override
  void dispose() {
    _convertController.dispose();
    _clockTimer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------
  // BUILD
  // ---------------------------------------------------

  @override
  Widget build(BuildContext context) {
    context.watch<LocalizationProvider>();
    return Scaffold(
      backgroundColor: AppColors.warmCream,
      appBar: _buildAppBar(),
      body: widget.page == FinanceHubPage.currency
          ? _buildCurrencyTab()
          : _buildTimeZoneTab(),
    );
  }

  /// App bar for the Finance & Time screen.
  PreferredSizeWidget _buildAppBar() {
    final strings = context.watch<LocalizationProvider>().strings;
    return AppBar(
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
        widget.page == FinanceHubPage.currency
            ? strings.currency
            : strings.timezone,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
      ),
    );
  }

  // ============================================================
  // CURRENCY CONVERSION PAGE
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

              // Kartu konverter cepat
              _buildQuickConverter(provider),
              const SizedBox(height: 20),

              // Kurs sesuai mata uang tujuan yang dipilih.
              _buildAllRatesGrid(provider),
            ],
          ),
        );
      },
    );
  }

  /// Banner status kurs (online/offline/loading)
  Widget _buildRatesStatusBanner(CurrencyProvider provider) {
    final strings = context.read<LocalizationProvider>().strings;
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
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.primaryGreen,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              strings.ratesLoading,
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
          border: Border.all(
            color: const Color(0xFFFFD700).withValues(alpha: 0.5),
          ),
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

    return const SizedBox.shrink();
  }

  /// Konverter mata uang dengan pasangan sumber dan tujuan yang dapat ditukar.
  Widget _buildQuickConverter(CurrencyProvider provider) {
    final strings = context.read<LocalizationProvider>().strings;
    final inputVal =
        double.tryParse(_convertController.text.trim().replaceAll(',', '.')) ??
        0.0;
    final amountInIDR = _sourceCurrency == 'IDR'
        ? inputVal
        : inputVal /
              CurrencyService.convert(
                amountIDR: 1,
                targetCurrency: _sourceCurrency,
                rates: provider.rates,
              );
    final converted = CurrencyService.convert(
      amountIDR: amountInIDR,
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
            strings.quickConverter,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 14),

          _buildCurrencyRow(
            flag: CurrencyService.currencyFlags[_sourceCurrency] ?? '',
            code: _sourceCurrency,
            isDropdown: true,
            onCurrencyChange: (value) {
              if (value != null) setState(() => _sourceCurrency = value);
            },
            child: TextField(
              controller: _convertController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: strings.amountHint,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: IconButton(
                onPressed: () {
                  final nextValue = inputVal == 0
                      ? ''
                      : _formatInputAmount(converted, _targetCurrency);
                  setState(() {
                    final previousSource = _sourceCurrency;
                    _sourceCurrency = _targetCurrency;
                    _targetCurrency = previousSource;
                    _convertController.value = TextEditingValue(
                      text: nextValue,
                      selection: TextSelection.collapsed(
                        offset: nextValue.length,
                      ),
                    );
                  });
                  context.read<CurrencyProvider>().changeCurrency(
                    _targetCurrency,
                  );
                },
                icon: const Icon(
                  Icons.swap_vert_rounded,
                  color: AppColors.primaryGreen,
                  size: 24,
                ),
                tooltip: strings.swapCurrencies,
              ),
            ),
          ),

          _buildCurrencyRow(
            flag: CurrencyService.currencyFlags[_targetCurrency] ?? '',
            code: _targetCurrency,
            isDropdown: true,
            onCurrencyChange: (value) {
              if (value == null) return;
              setState(() => _targetCurrency = value);
              context.read<CurrencyProvider>().changeCurrency(value);
            },
            child: Text(
              _convertController.text.trim().isEmpty
                  ? '—'
                  : CurrencyService.formatAmount(converted, _targetCurrency),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatInputAmount(double amount, String currency) {
    if (currency == 'IDR' || currency == 'JPY') {
      return amount.round().toString();
    }
    return amount.toStringAsFixed(2);
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
                items: CurrencyService.currencySymbols.keys.map((c) {
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

  /// Shows IDR equivalents for each supported foreign currency.
  Widget _buildAllRatesGrid(CurrencyProvider provider) {
    final strings = context.read<LocalizationProvider>().strings;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.ratesFromIDR,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 10),
          for (final currency in ['USD', 'JPY', 'EUR'])
            if (provider.rates[currency] case final rate? when rate > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    Text(
                      CurrencyService.currencyFlags[currency] ?? '',
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '1 $currency =',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    Text(
                      CurrencyService.formatAmount(1 / rate, 'IDR'),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  // ============================================================
  // TIME PAGE
  // ============================================================

  Widget _buildTimeZoneTab() {
    final strings = context.read<LocalizationProvider>().strings;
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
                strings.referenceTimezones,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 10),
              ..._timeZones.map(
                (tz) => _buildTimeZoneCard(tz, activeZoneInfo.code),
              ),

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
    final strings = context.read<LocalizationProvider>().strings;
    final isActive = tz.code == activeCode;
    final isLondon = tz.flag == '🇬🇧';

    Color borderColor = AppColors.borderLight;
    if (isActive)
      borderColor = AppColors.primaryGreen.withValues(alpha: 0.5);
    else if (isLondon)
      borderColor = AppColors.accentGold.withValues(alpha: 0.4);

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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    strings.activeZone,
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
    final strings = context.read<LocalizationProvider>().strings;
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
              const Icon(
                Icons.schedule_rounded,
                size: 16,
                color: AppColors.primaryGreen,
              ),
              const SizedBox(width: 8),
              Text(
                strings.timeDifference,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildDiffRow(wib, wita, strings.hoursFromWib.fill({'hours': '+1'})),
          _buildDiffRow(wib, wit, strings.hoursFromWib.fill({'hours': '+2'})),
          _buildDiffRow(
            wib,
            london,
            strings.hoursFromWib.fill({
              'hours': '${london.offsetHours - wib.offsetHours}',
            }),
          ),
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
