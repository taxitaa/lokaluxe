import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../core/models/map_place_model.dart';
import '../../core/services/currency_provider.dart';
import '../../core/services/location_provider.dart';
import '../../core/services/map_places_service.dart';
import '../../core/theme/app_colors.dart';

class NavigatorScreen extends StatefulWidget {
  final LatLng? initialTarget;
  final PlaceCategory? initialCategory;

  const NavigatorScreen({
    super.key,
    this.initialTarget,
    this.initialCategory,
  });

  @override
  State<NavigatorScreen> createState() => _NavigatorScreenState();
}

class _NavigatorScreenState extends State<NavigatorScreen>
    with SingleTickerProviderStateMixin {
  // Map Controller
  final MapController _mapController = MapController();

  // Search & Filter State
  final TextEditingController _searchController = TextEditingController();
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  PlaceCategory _selectedCategory = PlaceCategory.all;
  String _searchQuery = '';
  MapPlace? _selectedPlace;
  bool _isMapReady = false;

  // Location & Permission State
  LatLng _userLocation = const LatLng(-6.1953, 106.8231); // Default Jakarta Pusat
  bool _hasLocationPermission = false;
  bool _isLoadingLocation = false;
  bool _hasCenteredOnUser = false;
  StreamSubscription<Position>? _positionStreamSub;

  // Data State
  List<MapPlace> _allPlaces = [];
  bool _isLoadingPlaces = true;
  final Set<String> _favoritePlaceIds = {};

  // Tile styles (Carto Voyager looks like modern Google Maps)
  final String _cartoVoyagerUrl =
      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png';
  final List<String> _cartoSubdomains = const ['a', 'b', 'c', 'd'];

  // Animation controller for pulse / blue dot radar
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null) {
      _selectedCategory = widget.initialCategory!;
    }
    if (widget.initialTarget != null) {
      _userLocation = widget.initialTarget!;
    }

    // Pulse animation for blue dot GPS marker
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.6).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Initial data load
    _loadPlaces();

    // Trigger permission dialog and location check after first build frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLocationPermissionOnStart();
    });
  }

  @override
  void dispose() {
    _positionStreamSub?.cancel();
    _pulseController.dispose();
    _searchController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // LOCATION & PERMISSION FLOW
  // ──────────────────────────────────────────────────────────────────────────

  /// Saat halaman dibuka pertama kali, tampilkan pop-up izin lokasi
  Future<void> _checkLocationPermissionOnStart() async {
    // Periksa status izin saat ini
    final status = await Permission.location.status;

    if (status.isGranted) {
      _hasLocationPermission = true;
      await _detectCurrentLocation();
    } else {
      // Belum diberikan izin -> Tampilkan pop-up dialog izin LokaLuxe
      if (!mounted) return;
      _showLocationPermissionDialog();
    }
  }

  /// Dialog notifikasi izin akses lokasi ala LokaLuxe
  void _showLocationPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 16,
          backgroundColor: AppColors.pureWhite,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon Header bergaya GPS Radar
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primaryGreenSubtle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryGreen.withValues(alpha: 0.15),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.location_on_rounded,
                      size: 40,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Judul dialog
                Text(
                  'Akses Lokasi Diperlukan',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 10),

                // Pertanyaan izin seperti diminta di prompt
                Text(
                  'Izinkan LokaLuxe mengakses lokasi perangkat ini?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryGreen,
                  ),
                ),
                const SizedBox(height: 10),

                // Penjelasan manfaat
                Text(
                  'LokaLuxe menggunakan lokasi GPS Anda untuk menampilkan peta interaktif, menandai posisi Anda dengan titik biru, serta merekomendasikan tempat wisata, hotel, dan restoran terdekat.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 26),

                // Tombol Aksi
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _onPermissionDeclined();
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          side: const BorderSide(color: AppColors.borderLight),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Nanti Saja',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          await _requestLocationPermission();
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          backgroundColor: AppColors.primaryGreen,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Izinkan Akses',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.pureWhite,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Memanggil runtime permission dari permission_handler & geolocator
  Future<void> _requestLocationPermission() async {
    setState(() => _isLoadingLocation = true);

    try {
      // Minta izin lokasi runtime
      LocationPermission geolocatorPermission =
          await Geolocator.checkPermission();

      if (geolocatorPermission == LocationPermission.denied) {
        geolocatorPermission = await Geolocator.requestPermission();
      }

      if (geolocatorPermission == LocationPermission.always ||
          geolocatorPermission == LocationPermission.whileInUse) {
        setState(() => _hasLocationPermission = true);
        await _detectCurrentLocation();
      } else if (geolocatorPermission == LocationPermission.deniedForever) {
        _showPermissionSettingsDialog();
      } else {
        _onPermissionDeclined();
      }
    } catch (e) {
      debugPrint('[NavigatorScreen] Error requesting permission: $e');
      _onPermissionDeclined();
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  void _onPermissionDeclined() {
    if (!mounted) return;

    setState(() {
      _hasLocationPermission = false;
      _isLoadingLocation = false;
    });

    // Ambil default dari LocationProvider jika ada
    try {
      final locProvider = context.read<LocationProvider>();
      final city = locProvider.currentLocation.city.toLowerCase();
      if (city.contains('bali')) {
        _userLocation = const LatLng(-8.4095, 115.1889);
      } else if (city.contains('surabaya')) {
        _userLocation = const LatLng(-7.2575, 112.7521);
      } else if (city.contains('medan')) {
        _userLocation = const LatLng(3.5952, 98.6722);
      }
    } catch (_) {}

    _centerMapOn(_userLocation, zoom: 13.5);
    _loadPlaces();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Izin lokasi dilewati. Menampilkan lokasi default LokaLuxe.',
            style: GoogleFonts.plusJakartaSans(fontSize: 13),
          ),
          backgroundColor: AppColors.charcoalDark,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Aktifkan',
            textColor: AppColors.accentGold,
            onPressed: _requestLocationPermission,
          ),
        ),
      );
    }
  }

  void _showPermissionSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Izin Lokasi Dinonaktifkan',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Izin lokasi ditolak secara permanen. Silakan buka Pengaturan perangkat untuk mengaktifkan akses lokasi.',
          style: GoogleFonts.plusJakartaSans(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text(
              'Buka Pengaturan',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  /// Mendeteksi koordinat GPS terkini dan berpusat ke lokasi tersebut
  Future<void> _detectCurrentLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Layanan GPS perangkat belum aktif.'),
              backgroundColor: AppColors.errorRed,
            ),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final newCoord = LatLng(position.latitude, position.longitude);

      if (mounted) {
        setState(() {
          _userLocation = newCoord;
          _hasLocationPermission = true;
          _hasCenteredOnUser = true;
        });

        _centerMapOn(newCoord, zoom: 15.0);
        await _loadPlaces();

        if (!mounted) return;

        // Mulai live stream posisi (opsional, jika perangkat bergerak)
        _startLocationStream();

        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.pureWhite,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Peta terpusat ke lokasi Anda sekarang!',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.successGreen,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('[NavigatorScreen] Gagal deteksi lokasi: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mendapatkan koordinat GPS: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  void _startLocationStream() {
    _positionStreamSub?.cancel();
    _positionStreamSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
      ),
    ).listen((pos) {
      if (!mounted) return;
      setState(() {
        _userLocation = LatLng(pos.latitude, pos.longitude);
      });
    });
  }

  // ──────────────────────────────────────────────────────────────────────────
  // DATA LOADING & FILTERING
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _loadPlaces() async {
    setState(() => _isLoadingPlaces = true);
    try {
      final places =
          await MapPlacesService.getPlaces(userLocation: _userLocation);
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
        final matchCat = place.category.labelId.toLowerCase().contains(q);
        final matchTags = place.tags.any((t) => t.toLowerCase().contains(q));
        if (!matchName && !matchCity && !matchCat && !matchTags) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) =>
          a.distanceTo(_userLocation).compareTo(b.distanceTo(_userLocation)));
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

  void _zoomIn() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom + 1);
  }

  void _zoomOut() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom - 1);
  }

  void _toggleFavorite(MapPlace place) {
    setState(() {
      if (_favoritePlaceIds.contains(place.id)) {
        _favoritePlaceIds.remove(place.id);
        place.isFavorite = false;
      } else {
        _favoritePlaceIds.add(place.id);
        place.isFavorite = true;
      }
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          place.isFavorite
              ? '${place.name} ditambahkan ke favorit!'
              : '${place.name} dihapus dari favorit',
          style: GoogleFonts.plusJakartaSans(fontSize: 13),
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Membuka tempat langsung di aplikasi Google Maps fisik
  Future<void> _openPlaceInGoogleMaps(MapPlace place) async {
    final success = await MapPlacesService.openInGoogleMaps(
      place.latitude,
      place.longitude,
    );
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak dapat membuka Google Maps di perangkat ini.'),
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
    final filtered = _filteredPlaces;

    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      body: Stack(
        children: [
          // 1. Interactive Fullscreen Map
          _buildMapLayer(filtered),

          // 2. Top Floating Navigation Controls
          _buildTopFloatingBar(),

          // 3. Right Floating Map Controls (Zoom, My Location)
          _buildRightFloatingControls(),

          // 4. Floating Preview Card (jika ada marker yang dipilih)
          if (_selectedPlace != null)
            _buildFloatingPreviewCard(_selectedPlace!),

          // 5. Draggable Bottom Sheet dengan Filter Kategori & List Tempat
          _buildDraggableBottomSheet(filtered),
        ],
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
        initialZoom: _hasCenteredOnUser ? 15.0 : 13.5,
        minZoom: 3.0,
        maxZoom: 19.0,
        onMapReady: () {
          setState(() => _isMapReady = true);
          if (_hasCenteredOnUser) {
            _centerMapOn(_userLocation, zoom: 15.0);
          }
        },
        onTap: (_, _) {
          if (_selectedPlace != null) {
            setState(() => _selectedPlace = null);
          }
        },
      ),
      children: [
        // Tile Layer bergaya Google Maps / Carto Voyager
        TileLayer(
          urlTemplate: _cartoVoyagerUrl,
          subdomains: _cartoSubdomains,
          userAgentPackageName: 'com.lokaluxe.app',
          maxZoom: 19,
        ),

        // Circle Layer untuk radar radius pengguna jika ada izin
        if (_hasLocationPermission)
          CircleLayer(
            circles: [
              CircleMarker(
                point: _userLocation,
                radius: 120,
                useRadiusInMeter: true,
                color: const Color(0xFF1A73E8).withValues(alpha: 0.12),
                borderColor: const Color(0xFF1A73E8).withValues(alpha: 0.35),
                borderStrokeWidth: 1.5,
              ),
            ],
          ),

        // Marker Layer: Blue Dot GPS + Destinasi / Restoran
        MarkerLayer(
          markers: [
            // Current Location (Blue Dot Marker)
            Marker(
              point: _userLocation,
              width: 60,
              height: 60,
              child: _buildCurrentLocationBlueDot(),
            ),

            // Pin Destinasi / Restoran
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

  /// Indikator titik biru (blue dot marker) ala Google Maps dengan pulsing halo
  Widget _buildCurrentLocationBlueDot() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer Pulsing Glow
            Container(
              width: 44 * _pulseAnimation.value,
              height: 44 * _pulseAnimation.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1A73E8)
                    .withValues(alpha: 0.25 / _pulseAnimation.value),
              ),
            ),
            // White ring
            Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
            // Solid Blue Core
            Container(
              width: 14,
              height: 14,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF1A73E8),
              ),
            ),
          ],
        );
      },
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
            child: Icon(
              icon,
              color: Colors.white,
              size: isSelected ? 24 : 20,
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // FLOATING TOP CONTROLS (Back Button & Menu)
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildTopFloatingBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Tombol Kembali melayang
            _floatingCircularButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Kembali',
              onTap: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  setState(() {
                    _selectedPlace = null;
                    _searchQuery = '';
                    _searchController.clear();
                    _selectedCategory = PlaceCategory.all;
                  });
                }
              },
            ),
            const SizedBox(width: 10),

            // Bar Pencarian & Status Header Pill
            Expanded(
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.pureWhite,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      _hasLocationPermission
                          ? Icons.my_location_rounded
                          : Icons.location_searching_rounded,
                      size: 20,
                      color: _hasLocationPermission
                          ? const Color(0xFF1A73E8)
                          : AppColors.primaryGreen,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'LokaLuxe Navigator',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
                          Text(
                            _hasLocationPermission
                                ? 'GPS Aktif • Koordinat Terkini'
                                : 'Peta Interaktif Indonesia',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10.5,
                              color: _hasLocationPermission
                                  ? AppColors.successGreen
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_isLoadingLocation)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Tombol Menu melayang
            _floatingCircularButton(
              icon: Icons.layers_outlined,
              tooltip: 'Reset Filter',
              onTap: () {
                setState(() {
                  _selectedCategory = PlaceCategory.all;
                  _searchQuery = '';
                  _searchController.clear();
                  _selectedPlace = null;
                });
                _centerMapOn(_userLocation, zoom: 14.5);
              },
            ),
          ],
        ),
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
            tooltip: 'Perbesar Peta',
            onTap: _zoomIn,
          ),
          const SizedBox(height: 8),

          // Tombol Zoom Out
          _floatingMiniButton(
            icon: Icons.remove_rounded,
            tooltip: 'Perkecil Peta',
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
                onTap: () {
                  if (!_hasLocationPermission) {
                    _requestLocationPermission();
                  } else {
                    _detectCurrentLocation();
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    Icons.my_location_rounded,
                    size: 24,
                    color: _hasLocationPermission
                        ? const Color(0xFF1A73E8)
                        : AppColors.primaryGreen,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _floatingCircularButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: AppColors.textDark, size: 22),
        tooltip: tooltip,
        onPressed: onTap,
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

  Widget _buildFloatingPreviewCard(MapPlace place) {
    final currency = context.watch<CurrencyProvider>();
    final formattedDist = place.formattedDistanceTo(_userLocation);
    final isFav = _favoritePlaceIds.contains(place.id) || place.isFavorite;

    return Positioned(
      left: 16,
      right: 16,
      bottom: 270, // Posisi melayang tepat di atas draggable sheet yang menciut
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
                  // Gambar Thumbnail
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          width: 86,
                          height: 86,
                          child: Image.network(
                            place.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              color: AppColors.primaryGreenSubtle,
                              child: Icon(
                                _getCategoryIcon(place.category),
                                color: AppColors.primaryGreen,
                                size: 36,
                              ),
                            ),
                          ),
                        ),
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
                            place.category.labelId,
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
                        // Nama Tempat & Tombol Favorit
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
                            // Tombol Favorit
                            InkWell(
                              onTap: () => _toggleFavorite(place),
                              borderRadius: BorderRadius.circular(20),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  isFav
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  color: isFav
                                      ? const Color(0xFFE63946)
                                      : AppColors.textMuted,
                                  size: 22,
                                ),
                              ),
                            ),
                            // Tombol Tutup Preview (X)
                            InkWell(
                              onTap: () => setState(() => _selectedPlace = null),
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
                              : (place.priceDisplay ?? 'Gratis'),
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
                    'Buka di Google Maps',
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

  // ──────────────────────────────────────────────────────────────────────────
  // DRAGGABLE BOTTOM SHEET
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildDraggableBottomSheet(List<MapPlace> places) {
    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.32,
      minChildSize: 0.14,
      maxChildSize: 0.88,
      snap: true,
      snapSizes: const [0.14, 0.32, 0.65, 0.88],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.pureWhite,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 18,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              // Header Sheet (Drag Handle, Search Box, Kategori Melingkar)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Drag Handle Bar
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: AppColors.borderLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Search Place Input Box
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceCream,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: AppColors.borderInput,
                            width: 1,
                          ),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) {
                            setState(() => _searchQuery = val.trim());
                          },
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            color: AppColors.textDark,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search Place (wisata, resto, hotel...)',
                            hintStyle: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              color: AppColors.textMuted,
                            ),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              color: AppColors.primaryGreen,
                              size: 22,
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                      color: AppColors.textMuted,
                                    ),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Barisan Kategori Melingkar Horizontal (Amusement, Hotel, Park, Restaurants, Pool)
                      _buildCircularCategoryRow(),
                      const SizedBox(height: 16),

                      // Judul & Jumlah Hasil
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _getSectionTitle(),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
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
                              '${places.length} tempat',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),

              // Daftar Kartu Tempat
              if (_isLoadingPlaces)
                const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                )
              else if (places.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 40,
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.location_off_rounded,
                          size: 48,
                          color: AppColors.textMuted.withValues(alpha: 0.6),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Tidak ada tempat ditemukan',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Coba kata kunci lain atau pilih kategori Semua.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 30),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final place = places[index];
                        return _buildPlaceListItemCard(place);
                      },
                      childCount: places.length,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Barisan Kategori Melingkar Horizontal Sesuai Request Prompt:
  /// (Amusement, Hotel, Park, Restaurants, Pool)
  Widget _buildCircularCategoryRow() {
    final categories = [
      (PlaceCategory.amusement, 'Amusement', Icons.attractions_rounded, const Color(0xFF7B2CBF)),
      (PlaceCategory.hotel, 'Hotel', Icons.hotel_rounded, const Color(0xFF2B5B84)),
      (PlaceCategory.park, 'Park', Icons.park_rounded, const Color(0xFF2D6A4F)),
      (PlaceCategory.restaurants, 'Restaurants', Icons.restaurant_rounded, const Color(0xFFE76F51)),
      (PlaceCategory.pool, 'Pool', Icons.pool_rounded, const Color(0xFF0096C7)),
    ];

    return SizedBox(
      height: 94,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final item = categories[index];
          final category = item.$1;
          final label = item.$2;
          final icon = item.$3;
          final color = item.$4;
          final isSelected = _selectedCategory == category;

          return GestureDetector(
            onTap: () {
              setState(() {
                if (_selectedCategory == category) {
                  _selectedCategory = PlaceCategory.all;
                } else {
                  _selectedCategory = category;
                }
                _selectedPlace = null;
              });
            },
            child: SizedBox(
              width: 66,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? color : color.withValues(alpha: 0.12),
                      border: Border.all(
                        color: isSelected ? color : Colors.transparent,
                        width: 2.5,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : [],
                    ),
                    child: Icon(
                      icon,
                      color: isSelected ? Colors.white : color,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight:
                          isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? color : AppColors.textDark,
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

  /// Judul list berdasarkan filter kategori aktif
  String _getSectionTitle() {
    switch (_selectedCategory) {
      case PlaceCategory.restaurants:
        return 'Restoran di Sekitar Anda';
      case PlaceCategory.hotel:
        return 'Hotel & Penginapan Sekitar';
      case PlaceCategory.amusement:
        return 'Wahana Hiburan Terdekat';
      case PlaceCategory.park:
        return 'Taman & Wisata Alam';
      case PlaceCategory.pool:
        return 'Kolam Renang & Waterpark';
      case PlaceCategory.all:
        return 'Destinasi Sekitar Lokasi';
    }
  }

  /// Kartu item tempat di dalam bottom sheet
  Widget _buildPlaceListItemCard(MapPlace place) {
    final currency = context.watch<CurrencyProvider>();
    final formattedDist = place.formattedDistanceTo(_userLocation);
    final isFav = _favoritePlaceIds.contains(place.id) || place.isFavorite;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _onMarkerTap(place),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail Gambar
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 76,
                    height: 76,
                    child: Image.network(
                      place.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: AppColors.primaryGreenSubtle,
                        child: Icon(
                          _getCategoryIcon(place.category),
                          color: AppColors.primaryGreen,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Info Tempat
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nama & Tombol Favorit
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              place.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () => _toggleFavorite(place),
                            child: Icon(
                              isFav
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 19,
                              color: isFav
                                  ? const Color(0xFFE63946)
                                  : AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Rating & Jarak
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 15,
                            color: AppColors.starGold,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            place.rating.toStringAsFixed(1),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '•  $formattedDist',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Alamat / Kota
                      Text(
                        place.address.isNotEmpty ? place.address : place.city,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Harga & Aksi Buka di Google Maps
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            place.price != null && place.price! > 0
                                ? currency.convertAndFormat(place.price!)
                                : (place.priceDisplay ?? 'Gratis'),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                          // Tombol Cepat Google Maps
                          InkWell(
                            onTap: () => _openPlaceInGoogleMaps(place),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryGreenSubtle,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.directions_rounded,
                                    size: 14,
                                    color: AppColors.primaryGreen,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Maps',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primaryGreen,
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
