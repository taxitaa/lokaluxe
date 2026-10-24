import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../core/theme/app_colors.dart';

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

class _QiblaCompassScreenState extends State<QiblaCompassScreen> {
  StreamSubscription<MagnetometerEvent>? _magnetometerSubscription;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<Position>? _locationSubscription;
  MagnetometerEvent? _magneticField;
  AccelerometerEvent? _gravity;
  double? _heading;
  LatLng? _currentLocation;
  String? _sensorError;
  String? _locationError;

  double? get _qiblaBearing {
    final location = _currentLocation;
    return location == null ? null : calculateQiblaBearing(location);
  }

  @override
  void initState() {
    super.initState();
    _magnetometerSubscription = magnetometerEventStream().listen((event) {
      _magneticField = event;
      _updateHeading();
    }, onError: _handleSensorError);
    _accelerometerSubscription = accelerometerEventStream().listen((event) {
      _gravity = event;
      _updateHeading();
    }, onError: _handleSensorError);
    _startLocationUpdates();
  }

  @override
  void dispose() {
    _magnetometerSubscription?.cancel();
    _accelerometerSubscription?.cancel();
    _locationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startLocationUpdates() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _setLocationError('Aktifkan layanan lokasi untuk menentukan kiblat.');
        return;
      }

      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        _setLocationError(
          'Izin lokasi belum aktif. Aktifkan izin lokasi di pengaturan perangkat.',
        );
        return;
      }

      final lastKnownPosition = await Geolocator.getLastKnownPosition();
      if (lastKnownPosition != null) _updateLocation(lastKnownPosition);

      _locationSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen(
        _updateLocation,
        onError: _handleLocationError,
      );

      final currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      _updateLocation(currentPosition);
    } catch (error) {
      _handleLocationError(error);
    }
  }

  void _updateLocation(Position position) {
    if (!mounted) return;
    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
      _locationError = null;
    });
  }

  void _setLocationError(String message) {
    if (!mounted) return;
    setState(() => _locationError = message);
  }

  void _handleLocationError(Object error) {
    debugPrint('[QiblaCompassScreen] Device location error: $error');
    _setLocationError(
      'Lokasi perangkat belum bisa didapatkan. Periksa GPS dan izin lokasi.',
    );
  }

  void _handleSensorError(Object error) {
    debugPrint('[QiblaCompassScreen] Compass sensor error: $error');
    if (mounted) {
      setState(() {
        _sensorError = 'Sensor kompas tidak tersedia di perangkat ini.';
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

    if (mounted) {
      setState(() {
        _heading = heading;
        _sensorError = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final heading = _heading;
    final qiblaBearing = _qiblaBearing;
    final relativeQibla = heading == null || qiblaBearing == null
        ? null
        : (qiblaBearing - heading + 360) % 360;

    return Scaffold(
      backgroundColor: AppColors.warmCream,
      appBar: AppBar(
        backgroundColor: AppColors.pureWhite,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        title: Text(
          'Kompas & Arah Kiblat',
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
                'Arahkan bagian atas ponsel ke arah kiblat',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
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
                              : Transform.rotate(
                                  angle: -heading * math.pi / 180,
                                  child: const CustomPaint(
                                    painter: _CompassDialPainter(),
                                  ),
                                ),
                        ),
                      ),
                      if (relativeQibla != null)
                        Transform.rotate(
                          angle: relativeQibla * math.pi / 180,
                          child: const Align(
                            alignment: Alignment.topCenter,
                            child: Padding(
                              padding: EdgeInsets.only(top: 12),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.navigation_rounded,
                                    size: 38,
                                    color: AppColors.successGreen,
                                  ),
                                  Text(
                                    'KIBLAT',
                                    style: TextStyle(
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
              if (_locationError != null)
                Text(
                  _locationError!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: AppColors.errorRed,
                  ),
                )
              else if (_sensorError != null)
                Text(
                  _sensorError!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: AppColors.errorRed,
                  ),
                )
              else
                Text(
                  heading == null
                      ? 'Menghubungkan sensor kompas...'
                      : 'Arah kompas ${heading.round()}°',
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
                      'ARAH KIBLAT',
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
                      'dari utara',
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
                'Kalibrasikan kompas dengan menggerakkan ponsel membentuk angka delapan.',
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
