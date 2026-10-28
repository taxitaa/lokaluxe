import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as flutter_map;
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/models/map_place_model.dart';
import '../../core/services/currency_provider.dart';
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
  static const _initialZoom = 13.5;
  static const _initialSearchRadius = 5000;
  static const _maximumSearchRadius = 25000;

  String _tr(String indonesian, String english) => context
      .read<LocalizationProvider>()
      .strings
      .localized(indonesian, english);

  // Map Controller
  final flutter_map.MapController _mapController = flutter_map.MapController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _mapSectionKey = GlobalKey();

  // Search & Filter State
  final TextEditingController _searchController = TextEditingController();
  PlaceCategory _selectedCategory = PlaceCategory.all;
  String _searchQuery = '';
  MapPlace? _selectedPlace;
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
  int _searchRadiusMeters = _initialSearchRadius;
  StreamSubscription<Position>? _positionSubscription;
  DateTime? _lastPlacesRequestAt;
  int _placesRequestGeneration = 0;

  // Data State
  List<MapPlace> _allPlaces = [];
  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null) {
      _selectedCategory = widget.initialCategory!;
    }
    _mapCenter = widget.initialTarget ?? const LatLng(0, 0);
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
  // DATA LOADING & FILTERING
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
            'Aktifkan layanan lokasi untuk mencari tempat di sekitar Anda.',
            'Turn on location services to find places near you.',
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
            'Izin lokasi ditolak permanen. Aktifkan izin lokasi melalui pengaturan aplikasi.',
            'Location permission is permanently denied. Enable it in app settings.',
          );
        });
        return;
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.unableToDetermine) {
        setState(() {
          _locationError = _tr(
            'Izin lokasi diperlukan untuk menampilkan tempat terdekat.',
            'Location permission is required to show nearby places.',
          );
        });
        return;
      }

      final currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      _updateDeviceLocation(currentPosition, forceSearch: true);

      await _positionSubscription?.cancel();
      final LocationSettings locationSettings = switch (defaultTargetPlatform) {
        TargetPlatform.android => AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 25,
          intervalDuration: const Duration(seconds: 15),
        ),
        TargetPlatform.iOS || TargetPlatform.macOS => AppleSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 25,
          pauseLocationUpdatesAutomatically: false,
        ),
        _ => const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 25,
        ),
      };
      _positionSubscription =
          Geolocator.getPositionStream(locationSettings: locationSettings)
              .listen(
                _updateDeviceLocation,
                onError: (Object error) {
                  debugPrint('[NavigatorScreen] Location stream error: $error');
                  if (mounted && _userLocation == null) {
                    setState(() {
                      _locationError = _tr(
                        'Lokasi perangkat tidak dapat diperbarui. Coba lagi.',
                        'Device location could not be updated. Try again.',
                      );
                    });
                  }
                },
              );
    } on LocationServiceDisabledException {
      if (!mounted) return;
      setState(() {
        _locationServiceDisabled = true;
        _locationError = _tr(
          'Layanan lokasi perangkat sedang mati.',
          'Device location services are turned off.',
        );
      });
    } on PermissionDeniedException {
      if (!mounted) return;
      setState(() {
        _locationError = _tr(
          'Akses lokasi ditolak. Izinkan aplikasi mengakses lokasi.',
          'Location access was denied. Allow the app to access your location.',
        );
      });
    } catch (error) {
      debugPrint('[NavigatorScreen] Could not obtain device location: $error');
      if (!mounted) return;
      setState(() {
        _locationError = _tr(
          'Lokasi tidak dapat diperoleh. Periksa GPS dan coba lagi.',
          'Could not get your location. Check GPS and try again.',
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
    final shouldRefreshPlaces =
        forceSearch ||
        previousLocation == null ||
        const Distance().as(LengthUnit.Meter, previousLocation, nextLocation) >=
            250;

    setState(() {
      _userLocation = nextLocation;
      _mapCenter = nextLocation;
      _locationError = null;
      _locationServiceDisabled = false;
      _permissionPermanentlyDenied = false;
      if (_selectedPlace != null &&
          _selectedPlace!.distanceTo(nextLocation) > _searchRadiusMeters) {
        _selectedPlace = null;
      }
    });

    if (_isMapReady && previousLocation == null) {
      _centerMapOn(nextLocation, zoom: _initialZoom);
    }
    if (shouldRefreshPlaces) _loadPlaces();
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
              'Pengaturan lokasi tidak dapat dibuka.',
              'Could not open location settings.',
            ),
          ),
        ),
      );
    }
  }

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
        now.difference(lastRequest) < const Duration(seconds: 4)) {
      return;
    }

    _lastPlacesRequestAt = now;
    final requestGeneration = ++_placesRequestGeneration;
    setState(() {
      _isLoadingPlaces = true;
      _placesError = null;
    });
    try {
      final places = await MapPlacesService.searchNearbyPlaces(
        userLocation: location,
        radiusMeters: _searchRadiusMeters,
        category: _selectedCategory,
        forceRefresh: forceRefresh,
      );
      if (!mounted || requestGeneration != _placesRequestGeneration) return;
      if (_userLocation != location) {
        _lastPlacesRequestAt = null;
        _loadPlaces(forceRefresh: true);
        return;
      }
      setState(() {
        _allPlaces = places;
        _isLoadingPlaces = false;
      });
    } catch (error) {
      debugPrint('[NavigatorScreen] Nearby place search failed: $error');
      if (!mounted || requestGeneration != _placesRequestGeneration) return;
      if (_userLocation != location) {
        _lastPlacesRequestAt = null;
        _loadPlaces(forceRefresh: true);
        return;
      }
      setState(() {
        _placesError = _placesFailureMessage(error);
        _allPlaces = [];
        _isLoadingPlaces = false;
      });
    }
  }

  String _placesFailureMessage(Object error) {
    if (error is! MapPlacesSearchException) {
      return _tr(
        'Pencarian tempat gagal. Silakan coba lagi.',
        'Place search failed. Please try again.',
      );
    }

    return switch (error.kind) {
      MapPlacesFailureKind.network => _tr(
        'Tidak dapat terhubung ke layanan pencarian tempat. Periksa koneksi internet Anda.',
        'Could not connect to the place search service. Check your internet connection.',
      ),
      MapPlacesFailureKind.timeout => _tr(
        'Layanan pencarian tempat terlalu lama merespons. Coba lagi sebentar.',
        'The nearby places service timed out. Please try again shortly.',
      ),
      MapPlacesFailureKind.rateLimited => _tr(
        'Layanan peta sedang membatasi permintaan. Tunggu sebentar lalu coba lagi.',
        'The map service is rate limiting requests. Wait briefly and retry.',
      ),
      MapPlacesFailureKind.invalidRequest => _tr(
        'Permintaan pencarian tempat tidak valid.',
        'The place search request is invalid.',
      ),
      MapPlacesFailureKind.invalidResponse => _tr(
        'Layanan pencarian tempat mengirim respons yang tidak dapat dibaca.',
        'The nearby places service returned an unreadable response.',
      ),
      MapPlacesFailureKind.server => _tr(
        'Server pencarian tempat sedang sibuk atau mengalami gangguan (HTTP ${error.statusCode ?? "?"}). Coba lagi nanti.',
        'The nearby places server is busy or unavailable (HTTP ${error.statusCode ?? "?"}). Try again later.',
      ),
    };
  }

  void _expandSearchRadius() {
    if (_searchRadiusMeters < 10000) {
      _searchRadiusMeters = 10000;
    } else {
      _searchRadiusMeters = _maximumSearchRadius;
    }
    _loadPlaces(forceRefresh: true);
  }

  List<MapPlace> get _filteredPlaces {
    final userLocation = _userLocation;
    if (userLocation == null) return [];

    return _allPlaces.where((place) {
      if (place.distanceTo(userLocation) > _searchRadiusMeters) return false;

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
      return a.distanceTo(userLocation).compareTo(b.distanceTo(userLocation));
    });
  }

  // ──────────────────────────────────────────────────────────────────────────
  // MAP ANIMATION & ACTIONS
  // ──────────────────────────────────────────────────────────────────────────

  void _centerMapOn(LatLng target, {double zoom = 15.0}) {
    if (_isMapReady) _mapController.move(target, zoom);
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

  String _distanceLabel(MapPlace place) {
    final location = _userLocation;
    if (location == null) {
      return _tr('Jarak tidak tersedia', 'Distance unavailable');
    }
    final distance = place.formattedDistanceTo(location);
    return _tr('$distance dari lokasi Anda', '$distance from your location');
  }

  void _openQiblaCompass() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const QiblaCompassScreen()));
  }

  void _zoomIn() {
    if (_isMapReady) {
      _mapController.move(
        _mapController.camera.center,
        (_mapController.camera.zoom + 1).clamp(2, 20).toDouble(),
      );
    }
  }

  void _zoomOut() {
    if (_isMapReady) {
      _mapController.move(
        _mapController.camera.center,
        (_mapController.camera.zoom - 1).clamp(2, 20).toDouble(),
      );
    }
  }

  /// Opens a place link in the installed map application or browser.
  Future<void> _openPlaceInGoogleMaps(MapPlace place) async {
    final success = await MapPlacesService.openInGoogleMaps(
      place.latitude,
      place.longitude,
      placeId: place.id,
      googleMapsUri: place.googleMapsUri,
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
                              _userLocation == null
                                  ? 'Mendeteksi lokasi perangkat'
                                  : 'Lokasi saya',
                              _userLocation == null
                                  ? 'Detecting device location'
                                  : 'My location',
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
                            ? _tr('Tempat di sekitar Anda', 'Places near you')
                            : _getSectionTitle(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    if (_userLocation != null && _placesError == null)
                      Text(
                        _isLoadingPlaces
                            ? _tr('Memuat...', 'Loading...')
                            : '${filtered.length} ${_tr("lokasi", "places")}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    IconButton(
                      tooltip: _tr('Muat ulang tempat', 'Refresh places'),
                      onPressed: _userLocation != null && _isLoadingPlaces
                          ? null
                          : _userLocation == null
                          ? _startLocationUpdates
                          : () => _loadPlaces(forceRefresh: true),
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_userLocation == null)
              SliverToBoxAdapter(child: _buildLocationStatusCard())
            else if (_locationError != null)
              SliverToBoxAdapter(child: _buildLocationStatusCard())
            else if (_placesError != null)
              SliverToBoxAdapter(child: _buildPlacesErrorCard())
            else if (_isLoadingPlaces)
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _tr(
                          'Tidak ada tempat dalam radius ${_searchRadiusMeters ~/ 1000} km. Perluas radius pencarian atau pilih kategori lain.',
                          'No places found within ${_searchRadiusMeters ~/ 1000} km. Expand the search radius or choose another category.',
                        ),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (_searchRadiusMeters < _maximumSearchRadius)
                        TextButton.icon(
                          onPressed: _expandSearchRadius,
                          icon: const Icon(Icons.radar_rounded),
                          label: Text(
                            _tr(
                              'Perluas radius pencarian',
                              'Expand search radius',
                            ),
                          ),
                        ),
                    ],
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
  // OPENSTREETMAP LAYER
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildMapLayer(List<MapPlace> places) {
    final markers = <flutter_map.Marker>[
      if (_userLocation case final userLocation?)
        flutter_map.Marker(
          point: userLocation,
          width: 48,
          height: 48,
          child: Tooltip(
            message: _tr('Lokasi Saya', 'My location'),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.primaryGreen,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.pureWhite, width: 3),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 8),
                ],
              ),
              child: const Icon(
                Icons.my_location_rounded,
                color: AppColors.pureWhite,
                size: 23,
              ),
            ),
          ),
        ),
      ...places.map(
        (place) => flutter_map.Marker(
          point: place.coordinates,
          width: 44,
          height: 48,
          child: GestureDetector(
            onTap: () => _onMarkerTap(place),
            child: Tooltip(
              message: place.name,
              child: Icon(
                _getCategoryIcon(place.category),
                color: _markerColor(place.category),
                size: 38,
                shadows: const [
                  Shadow(color: Colors.black45, blurRadius: 4),
                ],
              ),
            ),
          ),
        ),
      ),
    ];

    return Stack(
      children: [
        flutter_map.FlutterMap(
          mapController: _mapController,
          options: flutter_map.MapOptions(
            initialCenter: _mapCenter,
            initialZoom: _userLocation == null ? 2 : _initialZoom,
            minZoom: 2,
            maxZoom: 20,
            onMapReady: () {
              if (mounted) setState(() => _isMapReady = true);
              _centerMapOn(
                _userLocation ?? _mapCenter,
                zoom: _userLocation == null ? 2 : _initialZoom,
              );
            },
            onTap: (_, _) {
              if (_selectedPlace != null) {
                setState(() => _selectedPlace = null);
              }
            },
          ),
          children: [
            flutter_map.TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.lokaluxe',
              maxZoom: 19,
            ),
            flutter_map.MarkerLayer(markers: markers),
          ],
        ),
        Positioned(
          left: 8,
          bottom: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.pureWhite.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(5),
            ),
            child: const Text(
              '© OpenStreetMap contributors',
              style: TextStyle(fontSize: 10, color: AppColors.textDark),
            ),
          ),
        ),
      ],
    );
  }

  Color _markerColor(PlaceCategory category) {
    return switch (category) {
      PlaceCategory.hotel => const Color(0xFF3B82F6),
      PlaceCategory.restaurants => const Color(0xFFF97316),
      PlaceCategory.park => AppColors.primaryGreen,
      PlaceCategory.pool => const Color(0xFF06B6D4),
      PlaceCategory.amusement => const Color(0xFF8B5CF6),
      PlaceCategory.all => AppColors.accentGold,
    };
  }

  // ──────────────────────────────────────────────────────────────────────────
  // RIGHT FLOATING MAP CONTROLS
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _centerOnCurrentLocation() async {
    await _startLocationUpdates();
    final location = _userLocation;
    if (location != null) _centerMapOn(location, zoom: _initialZoom);
  }

  Widget _buildLocationStatusCard() {
    final message =
        _locationError ??
        _tr('Mendeteksi lokasi perangkat...', 'Detecting device location...');
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
                    : _startLocationUpdates,
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.pureWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _placesError!,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _loadPlaces(forceRefresh: true),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(_tr('Coba lagi', 'Retry')),
            ),
          ],
        ),
      ),
    );
  }

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
                onTap: _centerOnCurrentLocation,
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
    final formattedDist = _distanceLabel(place);

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

                        // OSM does not provide ratings consistently; show only verified values.
                        Row(
                          children: [
                            if (place.rating > 0) ...[
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
                              if (place.reviewCount > 0) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '(${place.reviewCount})',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                              const SizedBox(width: 8),
                            ],
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
                        if ((place.price ?? 0) > 0 ||
                            (place.priceDisplay?.isNotEmpty ?? false))
                          Text(
                            (place.price ?? 0) > 0
                                ? currency.convertAndFormat(place.price!)
                                : place.priceDisplay!,
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
              if (_selectedCategory == category) return;
              setState(() {
                _selectedCategory = category;
                _selectedPlace = null;
              });
              _loadPlaces(bypassThrottle: true);
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
    final formattedDist = _distanceLabel(place);
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
