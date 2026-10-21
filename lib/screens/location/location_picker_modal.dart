import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/models/location_model.dart';
import '../../core/services/location_provider.dart';
import '../../core/theme/app_colors.dart';

/// Modal bottom sheet untuk memilih lokasi secara manual.
///
/// Fitur:
/// - Search bar dengan filter real-time
/// - Daftar lokasi dikelompokkan berdasarkan region
/// - Highlight lokasi aktif
/// - Animasi smooth saat memilih
/// - Tampil toggle USD/IDR jika memilih region "other"
class LocationPickerModal extends StatefulWidget {
  const LocationPickerModal({super.key});

  /// Tampilkan modal dan kembalikan lokasi yang dipilih (atau null jika dibatalkan)
  static Future<LocationModel?> show(BuildContext context) {
    return showModalBottomSheet<LocationModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const LocationPickerModal(),
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

  /// Filter daftar lokasi berdasarkan input pencarian
  void _onSearchChanged(String query) {
    setState(() {
      _filtered = LocationDatabase.search(query);
    });
  }

  @override
  Widget build(BuildContext context) {
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
              _buildHeader(),
              _buildSearchBar(),
              Expanded(
                child: _buildLocationList(scrollController),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Handle strip di bagian atas modal
  Widget _buildHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.borderLight,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  /// Header modal
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pilih Lokasi',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              Text(
                'Mata uang & waktu akan disesuaikan otomatis',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  /// Search bar untuk filter lokasi
  Widget _buildSearchBar() {
    return Padding(
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
            fontSize: 13,
            color: AppColors.textDark,
          ),
          decoration: InputDecoration(
            hintText: 'Cari kota atau negara...',
            hintStyle: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: AppColors.textMuted,
            ),
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
  }

  /// Daftar lokasi dengan scroll
  Widget _buildLocationList(ScrollController scrollController) {
    final locationProvider = context.watch<LocationProvider>();
    final activeId = locationProvider.currentLocation.id;

    if (_filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔍', style: TextStyle(fontSize: 36)),
            const SizedBox(height: 8),
            Text(
              'Tidak ada lokasi ditemukan',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    // Kelompokkan berdasarkan region
    final groups = _groupByRegion(_filtered);

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      itemCount: groups.length,
      itemBuilder: (_, i) {
        final group = groups[i];
        return _buildGroup(group, activeId, locationProvider);
      },
    );
  }

  /// Membangun satu grup lokasi (misal: "Indonesia 🇮🇩")
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
              // Badge mata uang default grup
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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

        // Item lokasi dalam grup
        ...group.locations.map(
          (loc) => _buildLocationTile(loc, activeId, locationProvider),
        ),
      ],
    );
  }

  /// Tile satu lokasi
  Widget _buildLocationTile(
    LocationModel loc,
    String activeId,
    LocationProvider locationProvider,
  ) {
    final isActive = loc.id == activeId;

    return GestureDetector(
      onTap: () async {
        // Ubah lokasi di provider (otomatis update currency + timezone)
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
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: AppColors.primaryGreen.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ],
        ),
        child: Row(
          children: [
            // Flag
            Text(loc.flag, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),

            // Info lokasi
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
                      color: isActive ? Colors.white70 : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Info timezone & currency
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildInfoBadge(
                  loc.timezone,
                  isActive ? Colors.white24 : AppColors.surfaceCream,
                  isActive ? Colors.white : AppColors.textSecondary,
                ),
                const SizedBox(height: 4),
                _buildInfoBadge(
                  loc.isOtherRegion ? 'USD/IDR' : loc.currency,
                  isActive
                      ? Colors.white24
                      : AppColors.accentGoldLight,
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

  Widget _buildInfoBadge(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }

  /// Mengelompokkan list lokasi berdasarkan region
  List<_LocationGroup> _groupByRegion(List<LocationModel> locations) {
    final Map<String, List<LocationModel>> map = {};

    for (final loc in locations) {
      map.putIfAbsent(loc.region, () []).add(loc);
    }

    final groups = <_LocationGroup>[];

    // Urutan tampilan group
    for (final region in ['indonesia', 'japan', 'eurozone', 'other']) {
      if (map.containsKey(region)) {
        groups.add(_LocationGroup.fromRegion(region, map[region]!));
      }
    }

    return groups;
  }
}

/// Helper class untuk representasi satu grup lokasi
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

  factory _LocationGroup.fromRegion(String region, List<LocationModel> locs) {
    switch (region) {
      case 'indonesia':
        return _LocationGroup(
          region: region,
          label: 'INDONESIA',
          flag: '🇮🇩',
          currency: 'IDR',
          currencyColor: AppColors.primaryGreen,
          locations: locs,
        );
      case 'japan':
        return _LocationGroup(
          region: region,
          label: 'JEPANG',
          flag: '🇯🇵',
          currency: 'JPY',
          currencyColor: const Color(0xFFE53935),
          locations: locs,
        );
      case 'eurozone':
        return _LocationGroup(
          region: region,
          label: 'ZONA EURO',
          flag: '🇪🇺',
          currency: 'EUR',
          currencyColor: const Color(0xFF1565C0),
          locations: locs,
        );
      default:
        return _LocationGroup(
          region: region,
          label: 'NEGARA LAINNYA',
          flag: '🌍',
          currency: 'USD/IDR',
          currencyColor: AppColors.accentGold,
          locations: locs,
        );
    }
  }
}
