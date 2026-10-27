import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/database/db_helper.dart';
import '../../core/database/hotel_seed_data.dart';
import '../../core/models/hotel_model.dart';
import '../../core/services/currency_provider.dart';
import '../../core/services/localization_provider.dart';
import '../../core/services/map_places_service.dart';
import '../../core/theme/app_colors.dart';
import '../itinerary/itinerary_screen.dart';

class HotelCatalogScreen extends StatefulWidget {
  final Function(HotelModel hotel)? onSelectHotel;
  final bool selectMode;
  final String? initialDestination;

  const HotelCatalogScreen({
    super.key,
    this.onSelectHotel,
    this.selectMode = false,
    this.initialDestination,
  });

  @override
  State<HotelCatalogScreen> createState() => _HotelCatalogScreenState();
}

class _HotelCatalogScreenState extends State<HotelCatalogScreen> {
  late Future<List<HotelModel>> _hotelsFuture;
  List<HotelModel> _allHotels = [];
  List<HotelModel> _filteredHotels = [];

  final TextEditingController _searchController = TextEditingController();
  String _selectedRegion = 'Semua';
  int? _selectedStar; // null = semua, 3, 4, 5
  String _sortBy = 'default'; // default, price_asc, price_desc, stars_desc

  final List<String> _regions = [
    'Semua',
    'Bali & Nusa Tenggara',
    'DKI Jakarta',
    'DI Yogyakarta',
    'Jawa',
    'Sumatera',
    'Kalimantan',
    'Sulawesi',
    'Papua & Maluku',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialDestination ?? '';
    _refreshHotels();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshHotels() {
    setState(() {
      _hotelsFuture = _loadHotelsFromDatabase();
    });
    return _hotelsFuture;
  }

  Future<List<HotelModel>> _loadHotelsFromDatabase() async {
    try {
      final list = await DBHelper.getHotelModels();
      if (list.isNotEmpty) {
        _allHotels = list;
      } else {
        // Fallback langsung ke data seed jika DB masih kosong
        _allHotels = hotelSeedData.map((e) => HotelModel.fromMap(e)).toList();
      }
    } catch (_) {
      // Fallback aman jika terjadi kegagalan koneksi DB lokal
      _allHotels = hotelSeedData.map((e) => HotelModel.fromMap(e)).toList();
    }
    _applyFilterAndSort();
    return _allHotels;
  }

  void _applyFilterAndSort() {
    final query = _searchController.text.trim().toLowerCase();
    final queryTerms = query
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty);

    List<HotelModel> result = _allHotels.where((hotel) {
      final searchableText =
          '${hotel.name} ${hotel.city} ${hotel.province} ${hotel.address}'
              .toLowerCase();
      if (!queryTerms.every(searchableText.contains)) {
        return false;
      }

      // 2. Region / Island Filter
      if (_selectedRegion != 'Semua') {
        final prov = hotel.province.toLowerCase();
        switch (_selectedRegion) {
          case 'Bali & Nusa Tenggara':
            if (!prov.contains('bali') && !prov.contains('nusa tenggara')) {
              return false;
            }
            break;
          case 'DKI Jakarta':
            if (!prov.contains('jakarta')) return false;
            break;
          case 'DI Yogyakarta':
            if (!prov.contains('yogyakarta')) return false;
            break;
          case 'Jawa':
            if (!prov.contains('jawa') && !prov.contains('banten'))
              return false;
            break;
          case 'Sumatera':
            if (!prov.contains('sumatera') &&
                !prov.contains('riau') &&
                !prov.contains('aceh') &&
                !prov.contains('lampung') &&
                !prov.contains('bangka')) {
              return false;
            }
            break;
          case 'Kalimantan':
            if (!prov.contains('kalimantan')) return false;
            break;
          case 'Sulawesi':
            if (!prov.contains('sulawesi') && !prov.contains('gorontalo')) {
              return false;
            }
            break;
          case 'Papua & Maluku':
            if (!prov.contains('papua') && !prov.contains('maluku')) {
              return false;
            }
            break;
        }
      }

      // 3. Star Rating Filter
      if (_selectedStar != null && hotel.stars != _selectedStar) {
        return false;
      }

      return true;
    }).toList();

    // 4. Sorting
    switch (_sortBy) {
      case 'price_asc':
        result.sort((a, b) => a.pricePerNight.compareTo(b.pricePerNight));
        break;
      case 'price_desc':
        result.sort((a, b) => b.pricePerNight.compareTo(a.pricePerNight));
        break;
      case 'stars_desc':
        result.sort((a, b) => b.stars.compareTo(a.stars));
        break;
      case 'name_asc':
        result.sort((a, b) => a.name.compareTo(b.name));
        break;
      default:
        // Urutan asli seed data
        break;
    }

    setState(() {
      _filteredHotels = result;
    });
  }

  void _onHotelPicked(HotelModel hotel) {
    if (widget.onSelectHotel != null) {
      widget.onSelectHotel!(hotel);
      Navigator.pop(context, hotel);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.primaryGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${hotel.name} dipilih untuk rencana perjalanan Anda!',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: 'Lihat',
            textColor: AppColors.starGold,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ItineraryScreen(pendingHotel: hotel),
                ),
              );
            },
          ),
        ),
      );
    }
  }

  Future<void> _openHotelInGoogleMaps(HotelModel hotel) async {
    final opened = await MapPlacesService.openPlaceInGoogleMaps(
      placeName: hotel.name,
      address: hotel.address,
      latitude: hotel.latitude,
      longitude: hotel.longitude,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak dapat membuka Google Maps di perangkat ini.'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  void _showHotelDetailBottomSheet(HotelModel hotel) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag Handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),

                // Hero Image with Badges
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            hotel.imageUrl,
                            height: 220,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  height: 220,
                                  color: AppColors.surfaceCream,
                                  child: const Icon(
                                    Icons.hotel_rounded,
                                    size: 64,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 28,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: AppColors.starGold,
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${hotel.stars}.0 Bintang',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      left: 28,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          hotel.province,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Content Details
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Hotel Name
                      Text(
                        hotel.name,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Location (City, Province)
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 16,
                            color: AppColors.primaryGreen,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            hotel.locationDescription,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Address Section (Dari Seed Data)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.warmCream,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.place_outlined,
                              size: 20,
                              color: AppColors.primaryGreen,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Alamat Lengkap',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryGreen,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    hotel.address,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Coordinates GPS (Dari Seed Data)
                      if (hotel.latitude != null && hotel.longitude != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.pureWhite,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.borderLight),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.explore_outlined,
                                size: 20,
                                color: AppColors.accentGold,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Koordinat GPS',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    Text(
                                      '${hotel.latitude!.toStringAsFixed(4)}°, ${hotel.longitude!.toStringAsFixed(4)}°',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(
                                      text:
                                          '${hotel.latitude}, ${hotel.longitude}',
                                    ),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Koordinat GPS berhasil disalin!',
                                      ),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.copy_rounded, size: 16),
                                label: const Text('Salin'),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.primaryGreen,
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 16),

                      // Fasilitas Hotel (Highlights)
                      Text(
                        'Fasilitas Termasuk',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildFacilityChip(Icons.wifi, 'Wi-Fi Gratis'),
                          _buildFacilityChip(
                            Icons.pool_rounded,
                            'Kolam Renang',
                          ),
                          _buildFacilityChip(
                            Icons.restaurant,
                            'Restoran & Sarapan',
                          ),
                          _buildFacilityChip(
                            Icons.room_service,
                            'Layanan 24 Jam',
                          ),
                          _buildFacilityChip(Icons.spa, 'Spa & Relaksasi'),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Price and Booking Button
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceCream,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Harga Kamar Mulai',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${context.watch<CurrencyProvider>().convertAndFormat(hotel.pricePerNight)} / night',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primaryGreen,
                                      ),
                                    ),
                                  ],
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _onHotelPicked(hotel);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryGreen,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: Text(
                                    'Pilih Hotel Ini',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _openHotelInGoogleMaps(hotel),
                                icon: const Icon(Icons.map_outlined, size: 18),
                                label: const Text('Lihat di Google Maps'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primaryGreen,
                                  side: const BorderSide(
                                    color: AppColors.primaryGreen,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  textStyle: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
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
      },
    );
  }

  Widget _buildFacilityChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primaryGreen),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocalizationProvider>().strings;
    return Scaffold(
      backgroundColor: AppColors.warmCream,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.hotelCatalogTitle,
              style: GoogleFonts.playfairDisplay(
                color: AppColors.textDark,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              strings.hotelCatalogSubtitle,
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.pureWhite,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textDark),
        actions: [
          // Sort Menu Button
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort_rounded, color: AppColors.textDark),
            tooltip: 'Urutkan Hotel',
            initialValue: _sortBy,
            onSelected: (val) {
              setState(() {
                _sortBy = val;
                _applyFilterAndSort();
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'default',
                child: Text('Rekomendasi (Default)'),
              ),
              const PopupMenuItem(
                value: 'price_asc',
                child: Text('Harga: Terendah ke Tertinggi'),
              ),
              const PopupMenuItem(
                value: 'price_desc',
                child: Text('Harga: Tertinggi ke Terendah'),
              ),
              const PopupMenuItem(
                value: 'stars_desc',
                child: Text('Bintang Tertinggi'),
              ),
              const PopupMenuItem(
                value: 'name_asc',
                child: Text('Nama Hotel (A - Z)'),
              ),
            ],
          ),
        ],
      ),
      body: FutureBuilder<List<HotelModel>>(
        future: _hotelsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.errorRed,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Gagal memuat katalog hotel:\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.errorRed,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _refreshHotels,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                      ),
                      child: const Text(
                        'Coba Lagi',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            color: AppColors.primaryGreen,
            onRefresh: _refreshHotels,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                // 1. Search Box
                SliverToBoxAdapter(
                  child: Container(
                    color: AppColors.pureWhite,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.warmCream,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => _applyFilterAndSort(),
                        style: GoogleFonts.plusJakartaSans(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: strings.searchHotels,
                          hintStyle: GoogleFonts.plusJakartaSans(
                            color: AppColors.textMuted,
                            fontSize: 13,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: AppColors.primaryGreen,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear_rounded,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    _applyFilterAndSort();
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // 2. Region / Island Chips
                SliverToBoxAdapter(
                  child: Container(
                    color: AppColors.pureWhite,
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: _regions.map((region) {
                          final isSelected = _selectedRegion == region;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(region),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  _selectedRegion = region;
                                  _applyFilterAndSort();
                                });
                              },
                              backgroundColor: AppColors.warmCream,
                              selectedColor: AppColors.primaryGreen,
                              checkmarkColor: Colors.white,
                              labelStyle: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textDark,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: isSelected
                                      ? AppColors.primaryGreen
                                      : AppColors.borderLight,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),

                // 3. Stars Filter Chips & Active Count Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Menampilkan ${_filteredHotels.length} Hotel',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        Row(
                          children: [
                            _buildStarFilterBadge(null, 'Semua'),
                            const SizedBox(width: 4),
                            _buildStarFilterBadge(5, '⭐ 5'),
                            const SizedBox(width: 4),
                            _buildStarFilterBadge(4, '⭐ 4'),
                            const SizedBox(width: 4),
                            _buildStarFilterBadge(3, '⭐ 3'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // 4. Hotel Cards List
                if (_filteredHotels.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.hotel_class_outlined,
                              size: 64,
                              color: AppColors.textMuted.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Hotel Tidak Ditemukan',
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Coba ganti kata kunci pencarian atau ubah filter wilayah.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _selectedRegion = 'Semua';
                                  _selectedStar = null;
                                  _applyFilterAndSort();
                                });
                              },
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('Reset Filter'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primaryGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final hotel = _filteredHotels[index];
                        return _buildHotelCard(hotel);
                      }, childCount: _filteredHotels.length),
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStarFilterBadge(int? star, String label) {
    final isSelected = _selectedStar == star;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedStar = isSelected && star != null ? null : star;
          _applyFilterAndSort();
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentGold : AppColors.pureWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.accentGold : AppColors.borderLight,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildHotelCard(HotelModel hotel) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _showHotelDetailBottomSheet(hotel),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hotel Image with Badges
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(18),
                    ),
                    child: Image.network(
                      hotel.imageUrl,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 180,
                        color: AppColors.surfaceCream,
                        child: const Center(
                          child: Icon(
                            Icons.hotel_rounded,
                            size: 48,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Province Badge (Top Left)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        hotel.province,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  // Stars Rating (Top Right)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: AppColors.starGold,
                            size: 16,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${hotel.stars}.0',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Hotel Info
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hotel Name
                    Text(
                      hotel.name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // City & Province
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 14,
                          color: AppColors.primaryGreen,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            hotel.locationDescription,
                            style: GoogleFonts.plusJakartaSans(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Address (Sesuai seed data)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          size: 14,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            hotel.address,
                            style: GoogleFonts.plusJakartaSans(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    const Divider(height: 20, color: AppColors.borderLight),

                    // Price and Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mulai dari',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                color: AppColors.textMuted,
                              ),
                            ),
                            Text(
                              '${context.watch<CurrencyProvider>().convertAndFormat(hotel.pricePerNight)} / night',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryGreen,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            OutlinedButton(
                              onPressed: () =>
                                  _showHotelDetailBottomSheet(hotel),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: AppColors.borderLight,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              child: Text(
                                'Detail',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textDark,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () => _onHotelPicked(hotel),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryGreen,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                'Pilih',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
