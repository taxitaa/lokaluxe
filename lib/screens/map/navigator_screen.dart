import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as flutter_map;
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/models/map_place_model.dart';
import '../../core/services/localization_provider.dart';
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
  static const _initialZoom = 14.5;
  static const _defaultSearchRadius = 3000; // Radius pencarian 3.000 meter

  String _tr(String indonesian, String english) => context
      .read<LocalizationProvider>()
      .strings
      .localized(indonesian, english);

  bool get _isEnglish =>
      context.read<LocalizationProvider>().strings.langCode == 'en';

  // Map Controller dari package flutter_map
  final flutter_map.MapController _mapController = flutter_map.MapController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _mapSectionKey = GlobalKey();

  // Search & Filter State
  final TextEditingController _searchController = TextEditingController();
  PlaceCategory _selectedCategory = PlaceCategory.all;
  String _searchQuery = '';
  MapPlace? _selectedPlace;
  RouteInfo? _activeRoute;

  bool _isMapReady = false;
  bool _isRequestingLocation = false;
  bool _locationServiceDisabled = false;
  bool _permissionPermanentlyDenied = false;
  bool _isLoadingPlaces = true;
  String? _locationError;
  String? _placesError;

  bool get _isSearching => _searchQuery.isNotEmpty;

  LatLng? _userLocation;
  late LatLng _mapCenter;
  final int _searchRadiusMeters = _defaultSearchRadius;
  StreamSubscription<Position>? _positionSubscription;
  DateTime? _lastPlacesRequestAt;
  int _placesRequestGeneration = 0;

  // Data Murni dari OpenStreetMap Overpass API
  List<MapPlace> _allPlaces = [];

  // Kategori Chip yang ditampilkan di UI
  static const List<PlaceCategory> _displayCategories = [
    PlaceCategory.all,
    PlaceCategory.amusement,
    PlaceCategory.hotel,
    PlaceCategory.park,
    PlaceCategory.restaurants,
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null) {
      _selectedCategory = widget.initialCategory!;
    }
    _mapCenter = widget.initialTarget ?? const LatLng(-6.2088, 106.8456);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startLocationUpdates();
    });
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // GPS & LOCATION UPDATES (Geolocator)
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _startLocationUpdates({bool requestPermission = true}) async {
    if (_isRequestingLocation) return;
    setState(() {
      _isRequestingLocation = true;
      _locationError = null;
    });

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        setState(() {
          _locationServiceDisabled = true;
          _locationError = _tr(
            'Layanan lokasi perangkat sedang nonaktif.',
            'Device location services are turned off.',
          );
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && requestPermission) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _permissionPermanentlyDenied = true;
          _locationError = _tr(
            'Izin lokasi ditolak permanen. Buka pengaturan aplikasi.',
            'Location permission permanently denied. Open app settings.',
          );
        });
        return;
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.unableToDetermine) {
        setState(() {
          _locationError = _tr(
            'Izin lokasi diperlukan untuk menemukan tempat sekitar.',
            'Location permission is required to find nearby places.',
          );
        });
        return;
      }

      // Ambil posisi riil perangkat terkini
      final currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );

      _updateDeviceLocation(currentPosition, forceSearch: true);

      // Mulai listener stream posisi secara hemat daya
      await _positionSubscription?.cancel();
      final LocationSettings locationSettings = switch (defaultTargetPlatform) {
        TargetPlatform.android => AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 20,
            intervalDuration: const Duration(seconds: 10),
          ),
        TargetPlatform.iOS || TargetPlatform.macOS => AppleSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 20,
            pauseLocationUpdatesAutomatically: false,
          ),
        _ => const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 20,
          ),
      };

      _positionSubscription =
          Geolocator.getPositionStream(locationSettings: locationSettings)
              .listen(
        (pos) => _updateDeviceLocation(pos),
        onError: (Object error) {
          debugPrint('[NavigatorScreen] Location stream error: $error');
        },
      );
    } on LocationServiceDisabledException {
      if (!mounted) return;
      setState(() {
        _locationServiceDisabled = true;
        _locationError = _tr(
          'Layanan GPS perangkat belum aktif.',
          'Device GPS is turned off.',
        );
      });
    } on PermissionDeniedException {
      if (!mounted) return;
      setState(() {
        _locationError = _tr(
          'Akses lokasi tidak diizinkan.',
          'Location access not permitted.',
        );
      });
    } catch (error) {
      debugPrint('[NavigatorScreen] Lokasi GPS gagal: $error');
      if (!mounted) return;
      setState(() {
        _locationError = _tr(
          'Gagal membaca koordinat GPS perangkat.',
          'Failed to read device GPS coordinates.',
        );
      });
    } finally {
      if (mounted) setState(() => _isRequestingLocation = false);
    }
  }

  void _updateDeviceLocation(Position position, {bool forceSearch = false}) {
    if (!mounted) return;
    final nextLocation = LatLng(position.latitude, position.longitude);
    final previousLocation = _userLocation;

    final shouldRefreshPlaces = forceSearch ||
        previousLocation == null ||
        const Distance().as(LengthUnit.Meter, previousLocation, nextLocation) >=
            250;

    setState(() {
      _userLocation = nextLocation;
      _mapCenter = nextLocation;
      _locationError = null;
      _locationServiceDisabled = false;
      _permissionPermanentlyDenied = false;

      // Update rute jika sedang aktif
      if (_activeRoute != null) {
        _activeRoute = RouteInfo.fromLocations(
          origin: nextLocation,
          destination: _activeRoute!.destination,
        );
      }
    });

    if (_isMapReady && (previousLocation == null || forceSearch)) {
      _centerMapOn(nextLocation, zoom: _initialZoom);
    }

    if (shouldRefreshPlaces) {
      _loadPlaces();
    }
  }

  Future<void> _refreshLocation() async {
    await _startLocationUpdates(requestPermission: true);
    final loc = _userLocation;
    if (loc != null) {
      _centerMapOn(loc, zoom: _initialZoom);
      await _loadPlaces(forceRefresh: true);
    }
  }

  Future<void> _openLocationSettings() async {
    final opened = _permissionPermanentlyDenied
        ? await Geolocator.openAppSettings()
        : await Geolocator.openLocationSettings();
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'Pengaturan lokasi tidak dapat dibuka secara otomatis.',
              'Location settings could not be opened automatically.',
            ),
          ),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // PENCARIAN TEMPAT (MURNI OPENSTREETMAP OVERPASS API)
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _loadPlaces({
    bool forceRefresh = false,
    bool bypassThrottle = false,
  }) async {
    final location = _userLocation;
    if (location == null) return;

    final now = DateTime.now();
    final lastRequest = _lastPlacesRequestAt;
    if (!forceRefresh &&
        !bypassThrottle &&
        lastRequest != null &&
        now.difference(lastRequest) < const Duration(seconds: 3)) {
      return;
    }

    _lastPlacesRequestAt = now;
    final requestGeneration = ++_placesRequestGeneration;

    setState(() {
      _isLoadingPlaces = true;
      _placesError = null;
    });

    try {
      final places = await MapPlacesService.getPlaces(
        userLocation: location,
        radiusMeters: _searchRadiusMeters,
        category: _selectedCategory,
        forceRefresh: forceRefresh,
      );

      if (!mounted || requestGeneration != _placesRequestGeneration) return;

      setState(() {
        _allPlaces = places;
        _isLoadingPlaces = false;
        _placesError = null;
      });
    } catch (error) {
      debugPrint('[NavigatorScreen] Gagal memuat tempat Overpass: $error');
      if (!mounted || requestGeneration != _placesRequestGeneration) return;

      setState(() {
        _isLoadingPlaces = false;
        _placesError = _tr(
          'Gagal memuat tempat sekitar dari server OpenStreetMap Overpass. Silakan periksa jaringan dan coba lagi.',
          'Failed to load nearby places from OpenStreetMap Overpass servers. Please check your connection and retry.',
        );
      });
    }
  }

  // Filter daftar tempat berdasarkan pencarian teks & kategori
  List<MapPlace> get _filteredPlaces {
    return _allPlaces.where((place) {
      if (_selectedCategory != PlaceCategory.all &&
          place.category != _selectedCategory) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchName = place.name.toLowerCase().contains(q);
        final matchCity = place.city.toLowerCase().contains(q);
        final matchCat = place.category.labelId.toLowerCase().contains(q) ||
            place.category.labelEn.toLowerCase().contains(q);
        final matchAddr = place.address.toLowerCase().contains(q);
        if (!matchName && !matchCity && !matchCat && !matchAddr) return false;
      }
      return true;
    }).toList();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // INTERAKSI PETA & PEMUSATAN LOKASI (MAPCONTROLLER)
  // ──────────────────────────────────────────────────────────────────────────

  /// Memusatkan peta internal ke koordinat tujuan secara mulus
  void _centerMapOn(LatLng target, {double zoom = 16.5}) {
    if (_isMapReady) {
      _mapController.move(target, zoom);
    }
  }

  void _onMarkerTap(MapPlace place) {
    setState(() {
      _selectedPlace = place;
    });
    _centerMapOn(place.coordinates, zoom: 16.5);
  }

  /// Ketika pengguna mengetuk salah satu kartu tempat pada daftar di bawah peta:
  /// Peta langsung berpusat (pan & zoom) ke koordinat tempat dan marker penandanya aktif
  void _onPlaceTap(MapPlace place) {
    setState(() {
      _selectedPlace = place;
    });
    _centerMapOn(place.coordinates, zoom: 16.5);

    // Scroll peta ke area pandang yang nyaman
    final mapContext = _mapSectionKey.currentContext;
    if (mapContext != null) {
      Scrollable.ensureVisible(
        mapContext,
        alignment: 0.05,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // INTEGRASI BUKA GOOGLE MAPS EKSTERNAL VIA URL_LAUNCHER
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _openExternalGoogleMaps(MapPlace place) async {
    // 1. Pusatkan peta lokal ke titik tempat terlebih dahulu
    _onPlaceTap(place);

    // 2. Buka aplikasi Google Maps eksternal
    final success = await MapPlacesService.openPlaceInGoogleMaps(
      latitude: place.latitude,
      longitude: place.longitude,
      placeName: place.name,
      address: place.address,
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'Tidak dapat membuka aplikasi Google Maps.',
              'Could not open Google Maps application.',
            ),
          ),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  /// Menghitung rute garis lurus, sudut bearing, dan arah mata angin in-app
  void _calculateAndShowRoute(MapPlace place) {
    final userLoc = _userLocation;
    if (userLoc == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'Lokasi GPS Anda belum terdeteksi untuk menghitung rute.',
              'Your GPS location is not available yet to calculate route.',
            ),
          ),
          backgroundColor: AppColors.errorRed,
        ),
      );
      _startLocationUpdates();
      return;
    }

    final route = RouteInfo.fromLocations(
      origin: userLoc,
      destination: place,
    );

    setState(() {
      _selectedPlace = place;
      _activeRoute = route;
    });

    // Posisikan kamera peta agar posisi pengguna dan tujuan terlihat bersamaan
    if (_isMapReady) {
      final bounds = flutter_map.LatLngBounds.fromPoints([
        userLoc,
        place.coordinates,
      ]);
      _mapController.fitCamera(
        flutter_map.CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 50),
          maxZoom: 17.0,
        ),
      );
    }
  }

  void _clearRoute() {
    setState(() {
      _activeRoute = null;
    });
    if (_userLocation != null) {
      _centerMapOn(_userLocation!, zoom: _initialZoom);
    }
  }

  // Kompas dan Arah Kiblat (Dibiarkan tetap seperti semula sesuai instruksi)
  void _openQiblaCompass() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const QiblaCompassScreen()),
    );
  }

  void _zoomIn() {
    if (_isMapReady) {
      final zoom = (_mapController.camera.zoom + 1).clamp(2.0, 19.0);
      _mapController.move(_mapController.camera.center, zoom);
    }
  }

  void _zoomOut() {
    if (_isMapReady) {
      final zoom = (_mapController.camera.zoom - 1).clamp(2.0, 19.0);
      _mapController.move(_mapController.camera.center, zoom);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // BUILD METHOD
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocalizationProvider>().strings;
    final filtered = _filteredPlaces;

    return Scaffold(
      backgroundColor: AppColors.warmCream,
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // ─── 1. APPBAR DENGAN TOMBOL KOMPAS TETAP UTUH ─────────────────────
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
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
                            _userLocation == null
                                ? _tr(
                                    'Mendeteksi sinyal GPS...',
                                    'Detecting GPS signal...',
                                  )
                                : _tr(
                                    'Peta Interaktif OpenStreetMap',
                                    'Interactive OpenStreetMap',
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

                    // Kompas dan Arah Kiblat (Dibiarkan tetap seperti semula sesuai instruksi)
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

            // ─── 2. BARIS KOORDINAT GPS REAL-TIME & REFRESH ────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                child: _buildGpsBar(),
              ),
            ),

            // ─── 3. KOTAK PENCARIAN TEMPAT ────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.pureWhite,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE3EAE5)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
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

            // ─── 4. CHIP KATEGORI HORIZONTAL ──────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _buildCategoryChips(),
              ),
            ),

            // ─── 5. PETA OPENSTREETMAP INTERAKTIF PENUH ────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ClipRRect(
                  key: _mapSectionKey,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    height: 380,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.borderLight),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Stack(
                      children: [
                        // Peta OSM Layer
                        Positioned.fill(child: _buildMapLayer(filtered)),

                        // Tombol Zoom & Recenter Melayang
                        _buildFloatingMapControls(),

                        // Atribusi OSM Publik
                        Positioned(
                          left: 10,
                          bottom: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.pureWhite.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '© OpenStreetMap contributors',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),

                        // Kartu Informasi Detail Tempat Terpilih
                        if (_selectedPlace != null && _activeRoute == null)
                          _buildDetailInfoCard(_selectedPlace!),

                        // Panel Informasi Rute Perjalanan & Bearing
                        if (_activeRoute != null)
                          _buildRouteInfoPanel(_activeRoute!),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ─── 6. HEADER DAFTAR TEMPAT SEKITAR ───────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isSearching
                                ? _tr('Hasil Pencarian', 'Search Results')
                                : _getCategoryTitle(),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _tr(
                              'Radius LBS ~${_searchRadiusMeters ~/ 1000} km dari posisi Anda',
                              'LBS radius ~${_searchRadiusMeters ~/ 1000} km from your position',
                            ),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_userLocation != null && _placesError == null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreenSubtle,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _isLoadingPlaces
                              ? _tr('Mencari...', 'Searching...')
                              : '${filtered.length} tempat',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // ─── 7. STATUS / ERROR / DAFTAR TEMPAT ──────────────────────────────
            if (_userLocation == null)
              SliverToBoxAdapter(child: _buildLocationStatusCard())
            else if (_locationError != null)
              SliverToBoxAdapter(child: _buildLocationStatusCard())
            else if (_placesError != null)
              SliverToBoxAdapter(child: _buildPlacesErrorCard())
            else if (_isLoadingPlaces)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(40),
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
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: AppColors.pureWhite,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.radar_rounded,
                          size: 40,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _tr(
                            'Tidak ada tempat ditemukan dalam radius 3.000 meter.',
                            'No places found within 3,000 meters radius.',
                          ),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () => _loadPlaces(forceRefresh: true),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: Text(_tr('Coba Lagi', 'Retry')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
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
  // KOMPONEN UI GPS BAR (Real-Time Coordinates & Refresh Button)
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildGpsBar() {
    final location = _userLocation;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Indikator Titik Hijau Berdenyut GPS
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: location != null ? AppColors.successGreen : Colors.orange,
              boxShadow: [
                BoxShadow(
                  color: (location != null
                          ? AppColors.successGreen
                          : Colors.orange)
                      .withValues(alpha: 0.5),
                  blurRadius: 6,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Tombol Koordinat Real-Time (Dapat disentuh untuk memusatkan peta)
          Expanded(
            child: InkWell(
              onTap: location != null
                  ? () => _centerMapOn(location, zoom: _initialZoom)
                  : _refreshLocation,
              borderRadius: BorderRadius.circular(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _tr('Koordinat GPS Riil', 'Real-Time GPS Coordinates'),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.touch_app_rounded,
                        size: 12,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    location != null
                        ? '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}'
                        : _tr('Mencari posisi perangkat...', 'Acquiring GPS position...'),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Tombol Refresh Lokasi GPS
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isRequestingLocation ? null : _refreshLocation,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreenSubtle,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _isRequestingLocation
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primaryGreen,
                        ),
                      )
                    : const Icon(
                        Icons.my_location_rounded,
                        size: 20,
                        color: AppColors.primaryGreen,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // CHIP KATEGORI HORIZONTAL (Semua, Hiburan, Hotel, Taman, Kuliner)
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _displayCategories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = _displayCategories[index];
          final isSelected = _selectedCategory == category;
          final label = _isEnglish ? category.labelEn : category.labelId;
          final icon = _getCategoryIcon(category);

          return GestureDetector(
            onTap: () {
              if (_selectedCategory == category) return;
              setState(() {
                _selectedCategory = category;
                _selectedPlace = null;
                _activeRoute = null;
              });
              _loadPlaces(bypassThrottle: true);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryGreen
                    : AppColors.pureWhite,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primaryGreen
                      : const Color(0xFFDCE3DE),
                  width: 1.2,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primaryGreen.withValues(alpha: 0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: isSelected ? Colors.white : AppColors.primaryGreen,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? Colors.white : AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // PETA OPENSTREETMAP LAYER & MARKERS
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildMapLayer(List<MapPlace> places) {
    final markers = <flutter_map.Marker>[
      // 1. Marker Posisi Pengguna (Titik Hijau Berdenyut)
      if (_userLocation case final userLoc?)
        flutter_map.Marker(
          point: userLoc,
          width: 50,
          height: 50,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryGreen.withValues(alpha: 0.2),
                ),
              ),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 6),
                  ],
                ),
              ),
            ],
          ),
        ),

      // 2. Marker Tempat Sekitar
      ...places.map((place) {
        final isSelected = _selectedPlace?.id == place.id;
        final color = _getCategoryColor(place.category);

        return flutter_map.Marker(
          point: place.coordinates,
          width: isSelected ? 46 : 38,
          height: isSelected ? 46 : 38,
          child: GestureDetector(
            onTap: () => _onMarkerTap(place),
            child: AnimatedScale(
              duration: const Duration(milliseconds: 200),
              scale: isSelected ? 1.2 : 1.0,
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.accentGold : color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: isSelected ? 3.0 : 2.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isSelected
                          ? AppColors.accentGold.withValues(alpha: 0.5)
                          : Colors.black26,
                      blurRadius: isSelected ? 10 : 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  _getCategoryIcon(place.category),
                  color: Colors.white,
                  size: isSelected ? 22 : 18,
                ),
              ),
            ),
          ),
        );
      }),
    ];

    // Polylines untuk rute garis lurus jika rute aktif
    final polylines = <flutter_map.Polyline>[
      if (_activeRoute != null && _userLocation != null)
        flutter_map.Polyline(
          points: [_userLocation!, _activeRoute!.destination.coordinates],
          strokeWidth: 4.0,
          color: AppColors.primaryGreen,
          pattern: flutter_map.StrokePattern.dashed(
            segments: const [10, 6],
          ),
        ),
    ];

    return flutter_map.FlutterMap(
      mapController: _mapController,
      options: flutter_map.MapOptions(
        initialCenter: _userLocation ?? _mapCenter,
        initialZoom: _userLocation == null ? 3.0 : _initialZoom,
        minZoom: 2.0,
        maxZoom: 19.0,
        onMapReady: () {
          if (mounted) setState(() => _isMapReady = true);
          if (_userLocation != null) {
            _centerMapOn(_userLocation!, zoom: _initialZoom);
          }
        },
        onTap: (_, _) {
          if (_selectedPlace != null && _activeRoute == null) {
            setState(() => _selectedPlace = null);
          }
        },
      ),
      children: [
        // Tile Layer OpenStreetMap publik tanpa API Key berbayar
        flutter_map.TileLayer(
          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: const ['a','b','c'],
          userAgentPackageName: 'com.lokaluxe.app',
          maxZoom: 19,
        ),

        // Garis Rute (Polyline)
        if (polylines.isNotEmpty)
          flutter_map.PolylineLayer(polylines: polylines),

        // Marker Layer
        flutter_map.MarkerLayer(markers: markers),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // FLOATING MAP CONTROLS (Zoom & My Location)
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildFloatingMapControls() {
    return Positioned(
      right: 14,
      top: 14,
      child: Column(
        children: [
          _miniMapButton(
            icon: Icons.add_rounded,
            tooltip: _tr('Perbesar', 'Zoom in'),
            onTap: _zoomIn,
          ),
          const SizedBox(height: 6),
          _miniMapButton(
            icon: Icons.remove_rounded,
            tooltip: _tr('Perkecil', 'Zoom out'),
            onTap: _zoomOut,
          ),
          const SizedBox(height: 8),
          _miniMapButton(
            icon: Icons.my_location_rounded,
            tooltip: _tr('Pusatkan ke Lokasi Saya', 'Center to my location'),
            color: AppColors.primaryGreen,
            iconColor: Colors.white,
            onTap: () {
              final loc = _userLocation;
              if (loc != null) {
                _centerMapOn(loc, zoom: _initialZoom);
              } else {
                _startLocationUpdates();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _miniMapButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color color = AppColors.pureWhite,
    Color iconColor = AppColors.textDark,
  }) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, color: iconColor, size: 20),
        tooltip: tooltip,
        onPressed: onTap,
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // KARTU INFORMASI DETAIL TEMPAT (Nama, Kategori, Jarak meter, Alamat & Navigasi)
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildDetailInfoCard(MapPlace place) {
    final userLoc = _userLocation;
    final distanceMeters =
        userLoc != null ? place.distanceTo(userLoc).round() : null;
    final categoryLabel =
        _isEnglish ? place.category.labelEn : place.category.labelId;
    final catColor = _getCategoryColor(place.category);

    return Positioned(
      left: 14,
      right: 14,
      bottom: 14,
      child: Material(
        elevation: 12,
        borderRadius: BorderRadius.circular(18),
        color: AppColors.pureWhite,
        shadowColor: Colors.black.withValues(alpha: 0.2),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Nama Tempat, Kategori & Tombol Tutup
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: catColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getCategoryIcon(place.category),
                      color: catColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          place.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: catColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                categoryLabel,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: catColor,
                                ),
                              ),
                            ),
                            if (distanceMeters != null) ...[
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.near_me_rounded,
                                size: 12,
                                color: AppColors.primaryGreen,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '$distanceMeters meter',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryGreen,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () => setState(() => _selectedPlace = null),
                    borderRadius: BorderRadius.circular(16),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Alamat Lengkap Tempat
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 15,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      place.address.isNotEmpty
                          ? place.address
                          : (place.city.isNotEmpty
                              ? place.city
                              : 'Area sekitar lokasi'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Tombol Aksi: Buka di Google Maps Eksternal & Lihat Rute In-App
              Row(
                children: [
                  // Tombol 1: Buka di Google Maps Eksternal
                  Expanded(
                    flex: 5,
                    child: SizedBox(
                      height: 42,
                      child: ElevatedButton.icon(
                        onPressed: () => _openExternalGoogleMaps(place),
                        icon: const Icon(
                          Icons.open_in_new_rounded,
                          size: 17,
                          color: Colors.white,
                        ),
                        label: Text(
                          _tr('Buka Google Maps', 'Open Google Maps'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Tombol 2: Petunjuk Arah Garis Lurus (Bearing)
                  Expanded(
                    flex: 4,
                    child: SizedBox(
                      height: 42,
                      child: OutlinedButton.icon(
                        onPressed: () => _calculateAndShowRoute(place),
                        icon: const Icon(
                          Icons.navigation_rounded,
                          size: 16,
                          color: AppColors.primaryGreen,
                        ),
                        label: Text(
                          _tr('Arah Rute', 'Direction'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: AppColors.primaryGreen,
                            width: 1.2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // PANEL INFORMASI RUTE PERJALANAN (Bearing & 8 Arah Mata Angin)
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildRouteInfoPanel(RouteInfo route) {
    final directionName =
        route.direction.localizedLabel(_isEnglish);
    final bearingRound = route.bearingDegrees.round();
    final distFormatted = route.formattedDistance();

    return Positioned(
      left: 12,
      right: 12,
      bottom: 12,
      child: Material(
        elevation: 14,
        borderRadius: BorderRadius.circular(20),
        color: AppColors.pureWhite,
        shadowColor: Colors.black.withValues(alpha: 0.25),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primaryGreen, width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Baris Judul & Tombol Tutup Rute
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: AppColors.primaryGreenSubtle,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.route_rounded,
                          size: 16,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _tr('Petunjuk Arah Rute', 'Route Guidance'),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: _clearRoute,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          Text(
                            _tr('Tutup Rute', 'Close Route'),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Nama Destinasi
              Text(
                route.destination.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 10),

              // Metrik Panel: Jarak Garis Lurus, Arah Mata Angin & Sudut Bearing
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCream,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    // Kolom 1: Arah Mata Angin dengan Indikator Kompas
                    Expanded(
                      flex: 4,
                      child: Row(
                        children: [
                          Transform.rotate(
                            angle: route.bearingDegrees * (math.pi / 180.0),
                            child: const Icon(
                              Icons.navigation_rounded,
                              color: AppColors.primaryGreen,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  directionName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryGreen,
                                  ),
                                ),
                                Text(
                                  'Bearing $bearingRound°',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    Container(
                      width: 1,
                      height: 32,
                      color: AppColors.borderLight,
                    ),
                    const SizedBox(width: 10),

                    // Kolom 2: Jarak Garis Lurus
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            distFormatted,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
                          Text(
                            _tr('Jarak Lurus', 'Straight line'),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Tombol Buka di Google Maps Langsung dari Panel Rute
              SizedBox(
                width: double.infinity,
                height: 40,
                child: ElevatedButton.icon(
                  onPressed: () => _openExternalGoogleMaps(route.destination),
                  icon: const Icon(
                    Icons.directions_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                  label: Text(
                    _tr(
                      'Navigasi Langsung di Google Maps',
                      'Direct Navigation in Google Maps',
                    ),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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

  // ──────────────────────────────────────────────────────────────────────────
  // STATUS & ERROR CARDS (Dengan Tombol "Coba Lagi" / Retry Responsif)
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildLocationStatusCard() {
    final message = _locationError ??
        _tr(
          'Mendeteksi koordinat GPS riil perangkat...',
          'Detecting real device GPS coordinates...',
        );
    final needsSettings =
        _locationServiceDisabled || _permissionPermanentlyDenied;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.pureWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          children: [
            Icon(
              _locationServiceDisabled
                  ? Icons.location_disabled_rounded
                  : Icons.my_location_rounded,
              color: AppColors.primaryGreen,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            if (_isRequestingLocation)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primaryGreen,
                ),
              )
            else
              TextButton(
                onPressed: needsSettings
                    ? _openLocationSettings
                    : () => _startLocationUpdates(requestPermission: true),
                child: Text(
                  needsSettings
                      ? _tr('Pengaturan', 'Settings')
                      : _tr('Coba lagi', 'Retry'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlacesErrorCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.pureWhite,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFF3D2D2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.wifi_off_rounded,
                  color: AppColors.errorRed,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _tr(
                          'Koneksi OpenStreetMap Terkendala',
                          'OpenStreetMap Connection Issue',
                        ),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _placesError!,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () => _loadPlaces(forceRefresh: true),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: Text(
                  _tr('Coba Lagi', 'Retry'),
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // DAFTAR TEMPAT KARTU LIST & TOMBOL NAVIGASI GOOGLE MAPS
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildPlaceListItemCard(MapPlace place) {
    final userLoc = _userLocation;
    final distanceMeters =
        userLoc != null ? place.distanceTo(userLoc).round() : null;
    final isSelected = _selectedPlace?.id == place.id;
    final catColor = _getCategoryColor(place.category);
    final categoryLabel =
        _isEnglish ? place.category.labelEn : place.category.labelId;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected
              ? AppColors.primaryGreen
              : const Color(0xFFECEEEB),
          width: isSelected ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          // Ketuk kartu: pusatkan peta secara mulus ke titik koordinat tempat tersebut
          onTap: () => _onPlaceTap(place),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Icon Kategori
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    _getCategoryIcon(place.category),
                    color: catColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),

                // Informasi Utama Tempat
                Expanded(
                  child: Column(
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
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            categoryLabel,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: catColor,
                            ),
                          ),
                          if (distanceMeters != null) ...[
                            Text(
                              ' • $distanceMeters m',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryGreen,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        place.address.isNotEmpty ? place.address : place.city,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Tombol Navigasi Google Maps Eksternal
                // Memusatkan peta & langsung membuka aplikasi Google Maps
                Tooltip(
                  message: _tr(
                    'Buka di Google Maps Eksternal',
                    'Open in Google Maps App',
                  ),
                  child: Material(
                    color: AppColors.primaryGreenSubtle,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _openExternalGoogleMaps(place),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        child: const Icon(
                          Icons.directions_rounded,
                          color: AppColors.primaryGreen,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // HELPER JUDUL, WARNA & IKON KATEGORI
  // ──────────────────────────────────────────────────────────────────────────

  String _getCategoryTitle() {
    switch (_selectedCategory) {
      case PlaceCategory.restaurants:
        return _tr('Kuliner & Restoran Terdekat', 'Nearby Culinary & Food');
      case PlaceCategory.hotel:
        return _tr('Hotel & Penginapan Terdekat', 'Nearby Hotels & Lodging');
      case PlaceCategory.amusement:
        return _tr('Wahana & Hiburan Terdekat', 'Nearby Amusement & Attractions');
      case PlaceCategory.park:
        return _tr('Taman & Alam Terdekat', 'Nearby Parks & Nature');
      case PlaceCategory.pool:
        return _tr('Kolam & Waterpark Terdekat', 'Nearby Pools & Waterparks');
      case PlaceCategory.all:
        return _tr('Tempat Nyata di Sekitar Anda', 'Real Places Near You');
    }
  }

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
