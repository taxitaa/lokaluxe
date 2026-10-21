import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/models/location_model.dart';
import '../../core/services/location_provider.dart';
import '../../core/services/localization_provider.dart';
import '../../core/services/app_strings.dart';
import '../../core/theme/app_colors.dart';

/// Modal bottom sheet untuk memilih lokasi secara manual.
///
/// Fitur:
/// - Search bar dengan filter real-time (city / country / countryCode)
/// - Daftar lokasi dikelompokkan berdasarkan region
/// - Highlight lokasi aktif dengan checkmark
/// - Menggunakan bahasa UI aktif dari [LocalizationProvider]
class LocationPickerModal extends StatefulWidget {
  final bool required;

  const LocationPickerModal({super.key, this.required = false});

  /// Tampilkan modal dan kembalikan lokasi yang dipilih (atau null jika batal)
  static Future<LocationModel?> show(
    BuildContext context, {
    bool required = false,
  }) {
    return showModalBottomSheet<LocationModel>(
      context: context,
      isScrollControlled: true,
      isDismissible: !required,
      enableDrag: !required,
      backgroundColor: Colors.transparent,
      builder: (_) => LocationPickerModal(required: required),
    );
  }

  @override
  State<LocationPickerModal> createState() => _LocationPickerModalState();
}

class _LocationPickerModalState extends State<LocationPickerModal> {
  final TextEditingController _searchController = TextEditingController();
  List<LocationModel> _filtered = LocationDatabase.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() => _filtered = LocationDatabase.search(query));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LocalizationProvider>().strings;
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.warmCream,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              _buildHandle(),
              _buildHeader(s),
              _buildSearchBar(s),
              Expanded(child: _buildLocationList(scrollController, s)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHandle() => Container(
        margin: const EdgeInsets.only(top: 12),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.borderLight,
          borderRadius: BorderRadius.circular(2),
        ),
      );

  Widget _buildHeader(AppStrings s) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.pickLocation,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  s.pickLocationSubtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (!widget.required)
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
      );

  Widget _buildSearchBar(AppStrings s) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.pureWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderLight),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 13, color: AppColors.textDark),
            decoration: InputDecoration(
              hintText: s.searchLocation,
              hintStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 13, color: AppColors.textMuted),
              prefixIcon: const Icon(Icons.search_rounded,
                  size: 20, color: AppColors.textSecondary),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded,
                          size: 18, color: AppColors.textSecondary),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      );

  Widget _buildLocationList(ScrollController scrollController, AppStrings s) {
    final locationProvider = context.watch<LocationProvider>();
    final activeId = locationProvider.currentLocation.id;

    if (_filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔍', style: TextStyle(fontSize: 36)),
            const SizedBox(height: 8),
            Text(s.locationNotFound,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    final groups = _groupByRegion(_filtered, s);
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      itemCount: groups.length,
      itemBuilder: (_, i) =>
          _buildGroup(groups[i], activeId, locationProvider),
    );
  }

  Widget _buildGroup(
    _LocationGroup group,
    String activeId,
    LocationProvider locationProvider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header grup
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Row(
            children: [
              Text(group.flag, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(
                group.label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: group.currencyColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  group.currency,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: group.currencyColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Item lokasi
        ...group.locations
            .map((loc) => _buildLocationTile(loc, activeId, locationProvider)),
      ],
    );
  }

  Widget _buildLocationTile(
    LocationModel loc,
    String activeId,
    LocationProvider locationProvider,
  ) {
    final isActive = loc.id == activeId;
    return GestureDetector(
      onTap: () async {
        await locationProvider.changeLocation(loc);
        if (mounted) Navigator.of(context).pop(loc);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primaryGreen : AppColors.pureWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? AppColors.primaryGreen : AppColors.borderLight,
            width: 1.5,
          ),
          boxShadow: [
            if (isActive)
              BoxShadow(
                color: AppColors.primaryGreen.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              )
            else
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          children: [
            Text(loc.flag, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.city,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isActive ? Colors.white : AppColors.textDark,
                    ),
                  ),
                  Text(
                    loc.country,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color:
                          isActive ? Colors.white70 : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _infoBadge(
                  loc.timezone,
                  isActive ? Colors.white24 : AppColors.surfaceCream,
                  isActive ? Colors.white : AppColors.textSecondary,
                ),
                const SizedBox(height: 4),
                _infoBadge(
                  loc.currency,
                  isActive ? Colors.white24 : AppColors.accentGoldLight,
                  isActive ? Colors.white : AppColors.accentGold,
                ),
              ],
            ),
            if (isActive) ...[
              const SizedBox(width: 10),
              const Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 20),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoBadge(String text, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(6)),
        child: Text(
          text,
          style: GoogleFonts.plusJakartaSans(
              fontSize: 9, fontWeight: FontWeight.w700, color: fg),
        ),
      );

  /// Mengelompokkan list lokasi berdasarkan region
  List<_LocationGroup> _groupByRegion(
      List<LocationModel> locations, AppStrings s) {
    final Map<String, List<LocationModel>> map = {};
    for (final loc in locations) {
      // Inisialisasi list jika belum ada, lalu tambahkan
      if (!map.containsKey(loc.region)) {
        map[loc.region] = [];
      }
      map[loc.region]!.add(loc);
    }

    final groups = <_LocationGroup>[];
    for (final region in ['indonesia', 'japan', 'eurozone', 'other']) {
      if (map.containsKey(region)) {
        groups.add(_LocationGroup.fromRegion(region, map[region]!, s));
      }
    }
    return groups;
  }
}

class _LocationGroup {
  final String region;
  final String label;
  final String flag;
  final String currency;
  final Color currencyColor;
  final List<LocationModel> locations;

  const _LocationGroup({
    required this.region,
    required this.label,
    required this.flag,
    required this.currency,
    required this.currencyColor,
    required this.locations,
  });

  factory _LocationGroup.fromRegion(
      String region, List<LocationModel> locs, AppStrings s) {
    switch (region) {
      case 'indonesia':
        return _LocationGroup(
          region: region, label: s.indonesia, flag: '🇮🇩',
          currency: 'IDR', currencyColor: AppColors.primaryGreen,
          locations: locs,
        );
      case 'japan':
        return _LocationGroup(
          region: region, label: s.japan, flag: '🇯🇵',
          currency: 'JPY', currencyColor: const Color(0xFFE53935),
          locations: locs,
        );
      case 'eurozone':
        return _LocationGroup(
          region: region, label: s.eurozone, flag: '🇪🇺',
          currency: 'EUR', currencyColor: const Color(0xFF1565C0),
          locations: locs,
        );
      default:
        return _LocationGroup(
          region: region, label: s.otherCountries, flag: '🌍',
          currency: 'USD', currencyColor: AppColors.accentGold,
          locations: locs,
        );
    }
  }
}
