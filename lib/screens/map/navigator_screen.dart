import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/models/map_place_model.dart';
import '../../core/models/location_model.dart';
import '../../core/services/currency_provider.dart';
import '../../core/services/localization_provider.dart';
import '../../core/services/location_provider.dart';
import '../../core/services/map_places_service.dart';
import '../../core/theme/app_colors.dart';
import 'qibla_compass_screen.dart';

class NavigatorScreen extends StatefulWidget {
  final LatLng? initialTarget;
  final PlaceCategory? initialCategory;
  final VoidCallback? onBack;

  const NavigatorScreen({
    super.key,
    this.initialTarget,
    this.initialCategory,
    this.onBack,
  });

  @override
  State<NavigatorScreen> createState() => _NavigatorScreenState();
}

class _NavigatorScreenState extends State<NavigatorScreen> {
  String _tr(String indonesian, String english) => context
      .read<LocalizationProvider>()
      .strings
      .localized(indonesian, english);

  // Map Controller
  final MapController _mapController = MapController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _mapSectionKey = GlobalKey();

  // Search & Filter State
  final TextEditingController _searchController = TextEditingController();
  PlaceCategory _selectedCategory = PlaceCategory.all;
  String _searchQuery = '';
  MapPlace? _selectedPlace;
  bool _isMapReady = false;
  bool get _isSearching => _searchQuery.isNotEmpty;

  LatLng _userLocation = const LatLng(-6.1953, 106.8231);
  String? _activeLocationId;

  // Data State
  List<MapPlace> _allPlaces = [];
  bool _isLoadingPlaces = true;
  static const String _openStreetMapUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null) {
      _selectedCategory = widget.initialCategory!;
    }
    if (widget.initialTarget != null) {
      _userLocation = widget.initialTarget!;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final selectedLocation = context
        .watch<LocationProvider?>()
        ?.currentLocation;
    final locationId = selectedLocation?.id ?? 'id-jakarta';
    if (_activeLocationId == locationId) return;

    _activeLocationId = locationId;
    if (widget.initialTarget == null) {
      _userLocation = _coordinatesFor(selectedLocation);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _centerMapOn(_userLocation, zoom: 13.5);
      _loadPlaces();
    });
  }

  static const LatLng _jakartaCenter = LatLng(-6.1953, 106.8231);

  LatLng _coordinatesFor(LocationModel? location) {
    if (location == null || !location.isIndonesia) return _jakartaCenter;

    return switch (location.id) {
      'id-bali' => const LatLng(-8.4095, 115.1889),
      'id-surabaya' => const LatLng(-7.2575, 112.7521),
      'id-medan' => const LatLng(3.5952, 98.6722),
      'id-makassar' => const LatLng(-5.1477, 119.4327),
      'id-jayapura' => const LatLng(-2.5337, 140.7181),
      _ => _jakartaCenter,
    };
  }

  String _mapAreaName(LocationModel? location) {
    if (location == null || !location.isIndonesia) return 'Jakarta';
    return location.city;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // DATA LOADING & FILTERING
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _loadPlaces() async {
    setState(() => _isLoadingPlaces = true);
    try {
      final places = await MapPlacesService.getPlaces(
        userLocation: _userLocation,
      );
      if (mounted) {
        setState(() {
          _allPlaces = places;
          _isLoadingPlaces = false;
        });
      }
    } catch (e) {
      debugPrint('[NavigatorScreen] Error loadPlaces: $e');
      if (mounted) setState(() => _isLoadingPlaces = false);
    }
  }

  List<MapPlace> get _filteredPlaces {
    return _allPlaces.where((place) {
      if (!_isSearching && place.distanceTo(_userLocation) > 50000) {
        return false;
      }

      // 1. Filter kategori
      if (_selectedCategory != PlaceCategory.all &&
          place.category != _selectedCategory) {
        return false;
      }
      // 2. Filter search query
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchName = place.name.toLowerCase().contains(q);
        final matchCity = place.city.toLowerCase().contains(q);
        final matchAddress = place.address.toLowerCase().contains(q);
        final matchCat =
            place.category.labelId.toLowerCase().contains(q) ||
            place.category.labelEn.toLowerCase().contains(q);
        final matchTags = place.tags.any((t) => t.toLowerCase().contains(q));
        if (!matchName &&
            !matchCity &&
            !matchAddress &&
            !matchCat &&
            !matchTags) {
          return false;
        }
      }
      return true;
    }).toList()..sort((a, b) {
      if (_isSearching) {
        final query = _searchQuery.toLowerCase();
        final aStartsWith = a.name.toLowerCase().startsWith(query);
        final bStartsWith = b.name.toLowerCase().startsWith(query);
        if (aStartsWith != bStartsWith) return aStartsWith ? -1 : 1;
      }
      return a.distanceTo(_userLocation).compareTo(b.distanceTo(_userLocation));
    });
  }

  // ──────────────────────────────────────────────────────────────────────────
  // MAP ANIMATION & ACTIONS
  // ──────────────────────────────────────────────────────────────────────────

  void _centerMapOn(LatLng target, {double zoom = 15.0}) {
    if (_isMapReady) {
      _mapController.move(target, zoom);
    }
  }

  void _onMarkerTap(MapPlace place) {
    setState(() => _selectedPlace = place);
    _centerMapOn(place.coordinates, zoom: 15.8);
  }

  void _onPlaceTap(MapPlace place) {
    _onMarkerTap(place);
    final mapContext = _mapSectionKey.currentContext;
    if (mapContext != null) {
      Scrollable.ensureVisible(
        mapContext,
        alignment: 0.08,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    }
  }

  void _openQiblaCompass() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const QiblaCompassScreen()));
  }

  void _zoomIn() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom + 1);
  }

  void _zoomOut() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom - 1);
  }

  /// Membuka tempat langsung di aplikasi Google Maps fisik
  Future<void> _openPlaceInGoogleMaps(MapPlace place) async {
    final success = await MapPlacesService.openInGoogleMaps(
      place.latitude,
      place.longitude,
    );
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'Tidak dapat membuka Google Maps di perangkat ini.',
              'Google Maps could not be opened on this device.',
            ),
          ),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // BUILD METHOD
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocalizationProvider>().strings;
    final selectedLocation = context
        .watch<LocationProvider?>()
        ?.currentLocation;
    final filtered = _filteredPlaces;

    return Scaffold(
      backgroundColor: AppColors.warmCream,
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                decoration: const BoxDecoration(
                  color: AppColors.pureWhite,
                  border: Border(
                    bottom: BorderSide(color: AppColors.borderLight),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: _tr('Kembali', 'Back'),
                      onPressed: () {
                        final onBack = widget.onBack;
                        if (onBack != null) {
                          onBack();
                        } else if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                      },
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: AppColors.textDark,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            'LokaLuxe Navigator',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _tr(
                              'Menjelajahi ${_mapAreaName(selectedLocation)}',
                              'Exploring ${_mapAreaName(selectedLocation)}',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: _tr(
                        'Kompas dan arah kiblat',
                        'Compass and Qibla direction',
                      ),
                      onPressed: _openQiblaCompass,
                      icon: const Icon(
                        Icons.explore_rounded,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.pureWhite,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE3EAE5)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onChanged: (value) =>
                        setState(() => _searchQuery = value.trim()),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: AppColors.textDark,
                    ),
                    decoration: InputDecoration(
                      hintText: strings.searchPlaces,
                      hintStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: AppColors.primaryGreen,
                      ),
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                              tooltip: _tr('Hapus pencarian', 'Clear search'),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: _buildCircularCategoryRow(),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ClipRRect(
                  key: _mapSectionKey,
                  borderRadius: BorderRadius.circular(24),
                  child: SizedBox(
                    height: 360,
                    child: Stack(
                      children: [
                        Positioned.fill(child: _buildMapLayer(filtered)),
                        _buildRightFloatingControls(),
                        Positioned(
                          left: 10,
                          bottom: 10,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppColors.pureWhite.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: Text(
                                '© OpenStreetMap contributors',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 9,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (_selectedPlace != null)
                          _buildFloatingPreviewCard(_selectedPlace!),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 30, 20, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _isSearching
                            ? _tr('Hasil pencarian', 'Search results')
                            : _selectedCategory == PlaceCategory.all
                            ? _tr(
                                'Tempat di sekitar ${_mapAreaName(selectedLocation)}',
                                'Places near ${_mapAreaName(selectedLocation)}',
                              )
                            : _getSectionTitle(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    Text(
                      '${filtered.length} ${_tr("lokasi", "places")}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    IconButton(
                      tooltip: _tr('Muat ulang tempat', 'Refresh places'),
                      onPressed: _loadPlaces,
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_isLoadingPlaces)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ),
              )
            else if (filtered.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  child: Text(
                    _tr(
                      'Tidak ada tempat ditemukan. Coba kategori atau kata kunci lain.',
                      'No places found. Try another category or search term.',
                    ),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) =>
                        _buildPlaceListItemCard(filtered[index]),
                    childCount: filtered.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // MAP LAYER (FlutterMap + OSM / Carto Tiles + Markers)
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildMapLayer(List<MapPlace> places) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _userLocation,
        initialZoom: 13.5,
        minZoom: 3.0,
        maxZoom: 19.0,
        onMapReady: () {
          setState(() => _isMapReady = true);
          _centerMapOn(_userLocation, zoom: 13.5);
        },
        onTap: (_, _) {
          if (_selectedPlace != null) {
            setState(() => _selectedPlace = null);
          }
        },
      ),
      children: [
        // OpenStreetMap tiles work without a private API key.
        TileLayer(
          urlTemplate: _openStreetMapUrl,
          userAgentPackageName: 'com.example.lokaluxe',
          maxZoom: 19,
        ),

        // Destination markers around the selected city.
        MarkerLayer(
          markers: [
            ...places.map((place) {
              final isSelected = _selectedPlace?.id == place.id;
              return Marker(
                point: place.coordinates,
                width: isSelected ? 56 : 46,
                height: isSelected ? 56 : 46,
                alignment: Alignment.topCenter,
                child: GestureDetector(
                  onTap: () => _onMarkerTap(place),
                  child: _buildPlaceMarker(place, isSelected),
                ),
              );
            }),
          ],
        ),
      ],
    );
  }

  /// Marker kustom per kategori dengan icon dan bayangan
  Widget _buildPlaceMarker(MapPlace place, bool isSelected) {
    final Color markerColor = _getCategoryColor(place.category);
    final IconData icon = _getCategoryIcon(place.category);

    return AnimatedScale(
      duration: const Duration(milliseconds: 250),
      scale: isSelected ? 1.15 : 1.0,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Pin Container
          Container(
            width: isSelected ? 48 : 40,
            height: isSelected ? 48 : 40,
            decoration: BoxDecoration(
              color: markerColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? AppColors.accentGold : Colors.white,
                width: isSelected ? 3.0 : 2.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? markerColor.withValues(alpha: 0.5)
                      : Colors.black.withValues(alpha: 0.25),
                  blurRadius: isSelected ? 12 : 6,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: isSelected ? 24 : 20),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // RIGHT FLOATING MAP CONTROLS
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildRightFloatingControls() {
    return Positioned(
      right: 16,
      top: 90,
      child: Column(
        children: [
          // Tombol Zoom In
          _floatingMiniButton(
            icon: Icons.add_rounded,
            tooltip: _tr('Perbesar Peta', 'Zoom in'),
            onTap: _zoomIn,
          ),
          const SizedBox(height: 8),

          // Tombol Zoom Out
          _floatingMiniButton(
            icon: Icons.remove_rounded,
            tooltip: _tr('Perkecil Peta', 'Zoom out'),
            onTap: _zoomOut,
          ),
          const SizedBox(height: 12),

          // Tombol Pusatkan ke Lokasi Pengguna (My Location)
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: AppColors.pureWhite,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _centerMapOn(_userLocation, zoom: 13.5),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    Icons.my_location_rounded,
                    size: 24,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _floatingMiniButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, color: AppColors.textDark, size: 20),
        tooltip: tooltip,
        onPressed: onTap,
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // FLOATING PREVIEW CARD
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildPlacePhoto(
    MapPlace place, {
    required double width,
    required double height,
    required BorderRadius borderRadius,
  }) {
    final imageUrl = place.imageUrl.trim();
    final placeholder = Container(
      width: width,
      height: height,
      color: AppColors.primaryGreenSubtle,
      child: Icon(
        _getCategoryIcon(place.category),
        color: AppColors.primaryGreen,
        size: 30,
      ),
    );

    if (imageUrl.isEmpty) {
      return ClipRRect(borderRadius: borderRadius, child: placeholder);
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        width: width,
        height: height,
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              color: AppColors.primaryGreenSubtle,
              alignment: Alignment.center,
              child: const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primaryGreen,
                ),
              ),
            );
          },
          errorBuilder: (_, _, _) => placeholder,
        ),
      ),
    );
  }

  Widget _buildFloatingPreviewCard(MapPlace place) {
    final currency = context.watch<CurrencyProvider>();
    final formattedDist = place.formattedDistanceTo(_userLocation);

    return Positioned(
      left: 16,
      right: 16,
      bottom: 12,
      child: Material(
        elevation: 14,
        borderRadius: BorderRadius.circular(22),
        shadowColor: Colors.black.withValues(alpha: 0.25),
        color: AppColors.pureWhite,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppColors.borderLight.withValues(alpha: 0.8),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      _buildPlacePhoto(
                        place,
                        width: 86,
                        height: 86,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getCategoryColor(place.category)
                                .withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            context.watch<LocalizationProvider>().langCode ==
                                    'en'
                                ? place.category.labelEn
                                : place.category.labelId,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),

                  // Informasi Utama
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Nama tempat dan tombol tutup.
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                place.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textDark,
                                ),
                              ),
                            ),
                            // Tombol Tutup Preview (X)
                            InkWell(
                              onTap: () =>
                                  setState(() => _selectedPlace = null),
                              borderRadius: BorderRadius.circular(20),
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(
                                  Icons.close_rounded,
                                  color: AppColors.textMuted,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),

                        // Rating Bintang & Jarak
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: AppColors.starGold,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              place.rating.toStringAsFixed(1),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '(${place.reviewCount})',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryGreenSubtle,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.near_me_rounded,
                                    size: 10,
                                    color: AppColors.primaryGreen,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    formattedDist,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primaryGreen,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Harga
                        Text(
                          place.price != null && place.price! > 0
                              ? currency.convertAndFormat(place.price!)
                              : (place.priceDisplay ?? _tr('Gratis', 'Free')),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Tombol Buka di Google Maps Fisik
              SizedBox(
                width: double.infinity,
                height: 42,
                child: ElevatedButton.icon(
                  onPressed: () => _openPlaceInGoogleMaps(place),
                  icon: const Icon(
                    Icons.map_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                  label: Text(
                    _tr('Buka di Google Maps', 'Open in Google Maps'),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Filter kategori horizontal untuk tempat yang tampil di peta dan daftar.
  Widget _buildCircularCategoryRow() {
    final categories = PlaceCategory.values;

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final category = categories[index];
          final strings = context.watch<LocalizationProvider>().strings;
          final label = strings.langCode == 'en'
              ? category.labelEn
              : category.labelId;
          final isSelected = _selectedCategory == category;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCategory = category;
                _selectedPlace = null;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.successGreen
                    : AppColors.pureWhite,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? AppColors.successGreen
                      : const Color(0xFFD8DED9),
                ),
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected) ...[
                      const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : AppColors.textDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Judul list berdasarkan filter kategori aktif
  String _getSectionTitle() {
    switch (_selectedCategory) {
      case PlaceCategory.restaurants:
        return _tr('Restoran di Sekitar Anda', 'Nearby Restaurants');
      case PlaceCategory.hotel:
        return _tr('Hotel & Penginapan Sekitar', 'Nearby Hotels & Lodging');
      case PlaceCategory.amusement:
        return _tr('Wahana Hiburan Terdekat', 'Nearby Attractions');
      case PlaceCategory.park:
        return _tr('Taman & Wisata Alam', 'Parks & Nature');
      case PlaceCategory.pool:
        return _tr('Kolam Renang & Waterpark', 'Pools & Waterparks');
      case PlaceCategory.all:
        return _tr('Destinasi Sekitar Lokasi', 'Places Near You');
    }
  }

  /// Ringkasan tempat yang bisa dipilih untuk memusatkan peta.
  Widget _buildPlaceListItemCard(MapPlace place) {
    final formattedDist = place.formattedDistanceTo(_userLocation);
    final isSelected = _selectedPlace?.id == place.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isSelected
              ? AppColors.primaryGreen.withValues(alpha: 0.45)
              : const Color(0xFFEEF1EE),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => _onPlaceTap(place),
          child: SizedBox(
            height: 96,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildPlacePhoto(
                    place,
                    width: 68,
                    height: 68,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          place.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$formattedDist · ${context.watch<LocalizationProvider>().langCode == 'en' ? place.category.labelEn : place.category.labelId}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: _tr(
                      'Buka ${place.name} di Google Maps',
                      'Open ${place.name} in Google Maps',
                    ),
                    onPressed: () => _openPlaceInGoogleMaps(place),
                    icon: const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textMuted,
                      size: 27,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 40,
                      height: 40,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // HELPER COLORS & ICONS
  // ──────────────────────────────────────────────────────────────────────────

  Color _getCategoryColor(PlaceCategory category) {
    switch (category) {
      case PlaceCategory.restaurants:
        return const Color(0xFFE76F51);
      case PlaceCategory.hotel:
        return const Color(0xFF2B5B84);
      case PlaceCategory.amusement:
        return const Color(0xFF7B2CBF);
      case PlaceCategory.park:
        return const Color(0xFF2D6A4F);
      case PlaceCategory.pool:
        return const Color(0xFF0096C7);
      case PlaceCategory.all:
        return AppColors.primaryGreen;
    }
  }

  IconData _getCategoryIcon(PlaceCategory category) {
    switch (category) {
      case PlaceCategory.restaurants:
        return Icons.restaurant_rounded;
      case PlaceCategory.hotel:
        return Icons.hotel_rounded;
      case PlaceCategory.amusement:
        return Icons.attractions_rounded;
      case PlaceCategory.park:
        return Icons.park_rounded;
      case PlaceCategory.pool:
        return Icons.pool_rounded;
      case PlaceCategory.all:
        return Icons.place_rounded;
    }
  }
}
