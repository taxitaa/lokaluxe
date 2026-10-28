import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../../core/services/app_strings.dart';
import '../../core/services/localization_provider.dart';
import '../../core/theme/app_colors.dart';

enum _LocationError {
  serviceDisabled,
  permissionPermanentlyDenied,
  permissionRequired,
  unavailable,
  locationSettingsUnavailable,
  appSettingsUnavailable,
}

double calculateQiblaBearing(LatLng location) {
  const kaabaLatitude = 21.4225;
  const kaabaLongitude = 39.8262;
  final latitude = _degreesToRadians(location.latitude);
  final destinationLatitude = _degreesToRadians(kaabaLatitude);
  final longitudeDifference = _degreesToRadians(
    kaabaLongitude - location.longitude,
  );

  final y = math.sin(longitudeDifference) * math.cos(destinationLatitude);
  final x =
      math.cos(latitude) * math.sin(destinationLatitude) -
      math.sin(latitude) *
          math.cos(destinationLatitude) *
          math.cos(longitudeDifference);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}

double _degreesToRadians(double degrees) => degrees * math.pi / 180;

class QiblaCompassScreen extends StatefulWidget {
  const QiblaCompassScreen({super.key});

  @override
  State<QiblaCompassScreen> createState() => _QiblaCompassScreenState();
}

class _QiblaCompassScreenState extends State<QiblaCompassScreen>
    with WidgetsBindingObserver {
  StreamSubscription<MagnetometerEvent>? _magnetometerSubscription;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<Position>? _locationSubscription;
  MagnetometerEvent? _magneticField;
  AccelerometerEvent? _gravity;
  double? _heading;
  double? _smoothedHeading;
  LatLng? _currentLocation;
  bool _sensorUnavailable = false;
  _LocationError? _locationError;
  bool _isRequestingLocation = false;
  bool _locationServiceDisabled = false;
  bool _permissionPermanentlyDenied = false;

  double? get _qiblaBearing {
    final location = _currentLocation;
    return location == null ? null : calculateQiblaBearing(location);
  }

  String _locationErrorText(AppStrings strings) => switch (_locationError!) {
    _LocationError.serviceDisabled => strings.localized(
      'Layanan lokasi perangkat sedang nonaktif. Aktifkan GPS agar arah kiblat sesuai posisi kamu.',
      'Location services are off. Turn on GPS to find the Qibla direction for your location.',
    ),
    _LocationError.permissionPermanentlyDenied => strings.localized(
      'Izin lokasi ditolak permanen. Aktifkan izin lokasi untuk LokaLuxe melalui Pengaturan aplikasi.',
      'Location permission is permanently denied. Enable location access for LokaLuxe in your app settings.',
    ),
    _LocationError.permissionRequired => strings.localized(
      'Kompas kiblat membutuhkan izin lokasi perangkat. Izinkan akses lokasi saat aplikasi digunakan.',
      'The Qibla compass needs your location. Allow location access while using the app.',
    ),
    _LocationError.unavailable => strings.localized(
      'Lokasi perangkat belum bisa didapatkan. Periksa GPS dan izin lokasi.',
      'Could not get your device location. Check GPS and location permissions.',
    ),
    _LocationError.locationSettingsUnavailable => strings.localized(
      'Pengaturan lokasi tidak dapat dibuka. Aktifkan GPS melalui Pengaturan perangkat.',
      'Could not open location settings. Turn on GPS in your device settings.',
    ),
    _LocationError.appSettingsUnavailable => strings.localized(
      'Pengaturan aplikasi tidak dapat dibuka. Aktifkan izin lokasi LokaLuxe secara manual.',
      'Could not open app settings. Manually enable location access for LokaLuxe.',
    ),
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _magnetometerSubscription = magnetometerEventStream().listen((event) {
      _magneticField = event;
      _updateHeading();
    }, onError: _handleSensorError);
    _accelerometerSubscription = accelerometerEventStream().listen((event) {
      _gravity = event;
      _updateHeading();
    }, onError: _handleSensorError);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startLocationUpdates();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _magnetometerSubscription?.cancel();
    _accelerometerSubscription?.cancel();
    _locationSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _currentLocation == null) {
      _startLocationUpdates(requestPermission: false);
    }
  }

  Future<void> _startLocationUpdates({bool requestPermission = true}) async {
    if (_isRequestingLocation) return;
    setState(() {
      _isRequestingLocation = true;
      _locationError = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _setLocationError(
          _LocationError.serviceDisabled,
          serviceDisabled: true,
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        if (permission == LocationPermission.denied && requestPermission) {
          permission = await Geolocator.requestPermission();
        }

        if (permission == LocationPermission.deniedForever) {
          _setLocationError(
            _LocationError.permissionPermanentlyDenied,
            permanentlyDenied: true,
          );
          return;
        }
        if (permission != LocationPermission.whileInUse &&
            permission != LocationPermission.always) {
          _setLocationError(_LocationError.permissionRequired);
          return;
        }
      }

      final lastKnownPosition = await Geolocator.getLastKnownPosition();
      if (lastKnownPosition != null) _updateLocation(lastKnownPosition);

      await _locationSubscription?.cancel();
      _locationSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen(_updateLocation, onError: _handleLocationError);

      final currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      _updateLocation(currentPosition);
    } catch (error) {
      _handleLocationError(error);
    } finally {
      if (mounted) setState(() => _isRequestingLocation = false);
    }
  }

  void _updateLocation(Position position) {
    if (!mounted) return;
    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
      _locationError = null;
      _locationServiceDisabled = false;
      _permissionPermanentlyDenied = false;
    });
  }

  void _setLocationError(
    _LocationError error, {
    bool serviceDisabled = false,
    bool permanentlyDenied = false,
  }) {
    if (!mounted) return;
    setState(() {
      _locationError = error;
      _locationServiceDisabled = serviceDisabled;
      _permissionPermanentlyDenied = permanentlyDenied;
    });
  }

  void _handleLocationError(Object error) {
    debugPrint('[QiblaCompassScreen] Device location error: $error');
    _setLocationError(_LocationError.unavailable);
  }

  Future<void> _openLocationAction() async {
    if (_locationServiceDisabled) {
      final opened = await Geolocator.openLocationSettings();
      if (!opened && mounted) {
        _setLocationError(
          _LocationError.locationSettingsUnavailable,
          serviceDisabled: true,
        );
      }
      return;
    }
    if (_permissionPermanentlyDenied) {
      final opened = await Geolocator.openAppSettings();
      if (!opened && mounted) {
        _setLocationError(
          _LocationError.appSettingsUnavailable,
          permanentlyDenied: true,
        );
      }
      return;
    }
    await _startLocationUpdates();
  }

  void _handleSensorError(Object error) {
    debugPrint('[QiblaCompassScreen] Compass sensor error: $error');
    if (mounted) {
      setState(() {
        _sensorUnavailable = true;
      });
    }
  }

  void _updateHeading() {
    final magnetic = _magneticField;
    final gravity = _gravity;
    if (magnetic == null || gravity == null) return;

    final gravityLength = math.sqrt(
      gravity.x * gravity.x + gravity.y * gravity.y + gravity.z * gravity.z,
    );
    if (gravityLength == 0) return;

    final gx = gravity.x / gravityLength;
    final gy = gravity.y / gravityLength;
    final gz = gravity.z / gravityLength;

    var hx = magnetic.y * gz - magnetic.z * gy;
    var hy = magnetic.z * gx - magnetic.x * gz;
    var hz = magnetic.x * gy - magnetic.y * gx;
    final horizontalLength = math.sqrt(hx * hx + hy * hy + hz * hz);
    if (horizontalLength < 0.001) return;
    hx /= horizontalLength;
    hy /= horizontalLength;
    hz /= horizontalLength;

    final northY = gz * hx - gx * hz;
    final azimuth = math.atan2(hy, northY);
    final heading = (azimuth * 180 / math.pi + 360) % 360;
    final previousHeading = _smoothedHeading;
    final previousNormalized = previousHeading == null
        ? null
        : (previousHeading % 360 + 360) % 360;
    final angularDifference = previousNormalized == null
        ? 0.0
        : (heading - previousNormalized + 540) % 360 - 180;
    final smoothedHeading = previousHeading == null
        ? heading
        : previousHeading + angularDifference * 0.18;
    final normalizedHeading = (smoothedHeading % 360 + 360) % 360;
    final shouldRebuild =
        previousHeading == null ||
        (smoothedHeading - previousHeading).abs() >= 0.12 ||
        _sensorUnavailable;

    _smoothedHeading = smoothedHeading;
    if (mounted && shouldRebuild) {
      setState(() {
        _heading = normalizedHeading;
        _sensorUnavailable = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocalizationProvider>().strings;
    final heading = _heading;
    final qiblaBearing = _qiblaBearing;
    final smoothedHeading = _smoothedHeading;
    final relativeQibla = smoothedHeading == null || qiblaBearing == null
        ? null
        : qiblaBearing - smoothedHeading;

    return Scaffold(
      backgroundColor: AppColors.warmCream,
      appBar: AppBar(
        backgroundColor: AppColors.pureWhite,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        title: Text(
          strings.localized(
            'Kompas & Arah Kiblat',
            'Compass & Qibla Direction',
          ),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.primaryGreen,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
          child: Column(
            children: [
              Text(
                strings.localized(
                  'Arahkan bagian atas ponsel ke arah kiblat',
                  'Point the top of your phone toward the Qibla',
                ),
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              if (_locationError != null) ...[
                const SizedBox(height: 16),
                _buildLocationPermissionNotice(strings),
              ] else ...[
                const SizedBox(height: 10),
                Text(
                  strings.localized(
                    'Untuk menentukan arah kiblat sesuai posisi, izinkan akses lokasi saat aplikasi meminta izin.',
                    'Allow location access when prompted to find the Qibla direction for your location.',
                  ),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 28),
              Center(
                child: SizedBox(
                  width: 280,
                  height: 280,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.pureWhite,
                          border: Border.all(
                            color: AppColors.borderLight,
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryGreen.withValues(
                                alpha: 0.08,
                              ),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: SizedBox(
                          width: 260,
                          height: 260,
                          child: heading == null
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    color: AppColors.primaryGreen,
                                  ),
                                )
                              : AnimatedRotation(
                                  turns: -(_smoothedHeading ?? heading) / 360,
                                  duration: const Duration(milliseconds: 100),
                                  curve: Curves.easeOutCubic,
                                  child: const CustomPaint(
                                    painter: _CompassDialPainter(),
                                  ),
                                ),
                        ),
                      ),
                      if (relativeQibla != null)
                        AnimatedRotation(
                          turns: relativeQibla / 360,
                          duration: const Duration(milliseconds: 100),
                          curve: Curves.easeOutCubic,
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.navigation_rounded,
                                    size: 38,
                                    color: AppColors.successGreen,
                                  ),
                                  Text(
                                    strings.localized('KIBLAT', 'QIBLA'),
                                    style: const TextStyle(
                                      color: AppColors.primaryGreen,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      Container(
                        width: 14,
                        height: 14,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.accentGold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (_sensorUnavailable)
                Text(
                  strings.localized(
                    'Sensor kompas tidak tersedia di perangkat ini.',
                    'The compass sensor is unavailable on this device.',
                  ),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: AppColors.errorRed,
                  ),
                )
              else
                Text(
                  heading == null
                      ? strings.localized(
                          'Menghubungkan sensor kompas...',
                          'Connecting to compass sensor...',
                        )
                      : strings.localized(
                          'Arah kompas ${heading.round()}°',
                          'Compass heading ${heading.round()}°',
                        ),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  color: AppColors.pureWhite,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(
                  children: [
                    Text(
                      strings.localized('ARAH KIBLAT', 'QIBLA BEARING'),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      qiblaBearing == null ? '--°' : '${qiblaBearing.round()}°',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                    Text(
                      strings.localized('dari utara', 'from north'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                strings.localized(
                  'Kalibrasikan kompas dengan menggerakkan ponsel membentuk angka delapan.',
                  'Calibrate the compass by moving your phone in a figure-eight pattern.',
                ),
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  height: 1.5,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationPermissionNotice(AppStrings strings) {
    final actionLabel = _locationServiceDisabled
        ? strings.localized('Aktifkan GPS', 'Turn on GPS')
        : _permissionPermanentlyDenied
        ? strings.localized('Buka Pengaturan', 'Open Settings')
        : strings.localized('Izinkan Lokasi', 'Allow Location');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.location_on_rounded,
                color: AppColors.primaryGreen,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _locationErrorText(strings),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    height: 1.45,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isRequestingLocation ? null : _openLocationAction,
              icon: _isRequestingLocation
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      _locationServiceDisabled
                          ? Icons.gps_fixed_rounded
                          : _permissionPermanentlyDenied
                          ? Icons.settings_rounded
                          : Icons.my_location_rounded,
                      size: 18,
                    ),
              label: Text(
                _isRequestingLocation
                    ? strings.localized(
                        'Meminta izin...',
                        'Requesting permission...',
                      )
                    : actionLabel,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
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
    );
  }
}

class _CompassDialPainter extends CustomPainter {
  const _CompassDialPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 12;
    final tickPaint = Paint()
      ..color = AppColors.primaryGreen.withValues(alpha: 0.45)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = AppColors.primaryGreen.withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    for (var index = 0; index < 36; index++) {
      final angle = index * math.pi / 18 - math.pi / 2;
      final isCardinal = index % 9 == 0;
      final innerRadius = radius - (isCardinal ? 15 : 8);
      canvas.drawLine(
        Offset(
          center.dx + math.cos(angle) * innerRadius,
          center.dy + math.sin(angle) * innerRadius,
        ),
        Offset(
          center.dx + math.cos(angle) * radius,
          center.dy + math.sin(angle) * radius,
        ),
        tickPaint
          ..strokeWidth = isCardinal ? 2 : 1
          ..color = isCardinal
              ? AppColors.primaryGreen
              : AppColors.primaryGreen.withValues(alpha: 0.35),
      );
    }

    const labels = ['N', 'E', 'S', 'W'];
    for (var index = 0; index < labels.length; index++) {
      final angle = index * math.pi / 2 - math.pi / 2;
      final labelRadius = radius - 28;
      final textPainter = TextPainter(
        text: TextSpan(
          text: labels[index],
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: index == 0 ? AppColors.errorRed : AppColors.textSecondary,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(
          center.dx + math.cos(angle) * labelRadius - textPainter.width / 2,
          center.dy + math.sin(angle) * labelRadius - textPainter.height / 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CompassDialPainter oldDelegate) => false;
}
