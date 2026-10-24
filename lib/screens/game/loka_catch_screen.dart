import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../core/models/voucher_data.dart';
import '../../core/services/game_notification_service.dart';
import '../../core/theme/app_colors.dart';

// ============================================================
// DATA MODEL: Objek yang jatuh di area permainan
// ============================================================

/// Tipe objek dalam permainan LokaCatch
enum FallingObjectType {
  item, // Hidangan khas Indonesia yang harus ditangkap
  bomb, // Rintangan bom (game over jika kena)
}

/// Model objek yang jatuh dari atas layar
class FallingObject {
  final String id; // ID unik objek ini
  final FallingObjectType type;
  final String assetPath;
  double x; // Posisi horizontal (0.0 - 1.0, relatif terhadap lebar layar)
  double y; // Posisi vertikal saat ini (dalam pixels)
  double speed; // Kecepatan jatuh per frame (pixels/tick)

  FallingObject({
    required this.id,
    required this.type,
    required this.assetPath,
    required this.x,
    required this.y,
    required this.speed,
  });
}

// ============================================================
// SCREEN: LokaCatch Mini Game
// ============================================================

/// Layar mini game LokaCatch dengan kendali gyroscope
///
/// Mekanisme:
/// - Pemain memiringkan HP untuk menggerakkan komodo
/// - Tangkap 10 item kuliner untuk menang dan mendapatkan voucher
/// - Hindari bom — jika kena langsung Game Over
class LokaCatchScreen extends StatefulWidget {
  const LokaCatchScreen({super.key});

  @override
  State<LokaCatchScreen> createState() => _LokaCatchScreenState();
}

class _LokaCatchScreenState extends State<LokaCatchScreen>
    with TickerProviderStateMixin {
  // ---------------------------------------------------
  // KONSTANTA GAME
  // ---------------------------------------------------
  static const int _maxItems = 10; // Item maks untuk menang
  static const double _komodoWidth = 128.0;
  static const double _komodoHeight = 156.0;
  static const String _komodoOpenAsset =
      'assets/images/lokacatch_komodo_open.png';
  static const String _komodoClosedAsset =
      'assets/images/lokacatch_komodo_closed.png';
  static const String _bombAsset = 'assets/images/lokacatch_bomb.png';
  static const double _objectSize = 44.0; // Ukuran area tabrakan objek (px)
  static const double _bombDisplaySize = 56.0;
  static const double _gyroSensitivity = 0.02; // Sensitivitas gyroscope
  static const double _manualMoveStep = 0.14;
  static const Duration _tickInterval = Duration(milliseconds: 16); // ~60 FPS

  // ---------------------------------------------------
  // DAFTAR OBJEK GAME
  // ---------------------------------------------------
  /// Aset hidangan khas Indonesia yang bisa ditangkap
  static const List<String> _itemAssets = [
    'assets/images/lokacatch_food_tofu.png',
    'assets/images/lokacatch_food_dumplings.png',
    'assets/images/lokacatch_food_sushi.png',
    'assets/images/lokacatch_food_satay.png',
    'assets/images/lokacatch_food_chicken_rice.png',
    'assets/images/lokacatch_food_steamed_cake.png',
    'assets/images/lokacatch_food_rice_cakes.png',
    'assets/images/lokacatch_food_tumpeng.png',
    'assets/images/lokacatch_food_rice_bowl.png',
  ];

  // ---------------------------------------------------
  // STATE GAME
  // ---------------------------------------------------
  List<FallingObject> _objects = []; // Semua objek aktif di layar
  double _basketX = 0.5; // Posisi horizontal komodo (0-1)
  int _caughtItems = 0; // Jumlah item berhasil ditangkap
  bool _isGameOver = false; // Status game over
  bool _isWon = false; // Status menang (10 item tertangkap)
  bool _isPlaying = false; // Apakah permainan sedang berjalan
  bool _gyroscopeAvailable = true; // Apakah sensor gyroscope tersedia
  bool _komodoHasFood = false;
  String? _lastCaughtFoodAsset;

  double get _komodoLeft {
    if (_screenWidth <= 0) return 0;
    final mouthOffset = _komodoWidth * 0.64;
    return (_basketX * _screenWidth - mouthOffset).clamp(
      -mouthOffset,
      _screenWidth - mouthOffset,
    );
  }

  // ---------------------------------------------------
  // CONTROLLERS & STREAMS
  // ---------------------------------------------------
  Timer? _gameTimer; // Timer game loop utama
  Timer? _spawnTimer; // Timer untuk spawn objek baru
  Timer? _komodoMouthTimer;
  StreamSubscription<GyroscopeEvent>? _gyroSubscription; // Listener gyroscope

  // Untuk animasi "item tertangkap" feedback
  late AnimationController _catchAnimController;
  late Animation<double> _catchScaleAnim;

  // Dimensi layar game (diisi saat build)
  double _screenWidth = 0;
  double _screenHeight = 0;

  // Random generator
  final Random _random = Random();

  VoucherData get _gameRewardVoucher => availableVouchers.first;

  // Counter untuk ID unik objek
  int _objectIdCounter = 0;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initGyroscope();
  }

  /// Inisialisasi animasi feedback "catch"
  void _initAnimations() {
    _catchAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _catchScaleAnim = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _catchAnimController, curve: Curves.elasticOut),
    );
  }

  /// Menginisialisasi sensor gyroscope dengan error handling
  ///
  /// Jika perangkat tidak mendukung gyroscope, fallback ke kontrol tap/drag
  void _initGyroscope() {
    try {
      _gyroSubscription =
          gyroscopeEventStream(samplingPeriod: SensorInterval.gameInterval)
              .listen(
                _onGyroscopeEvent,
                onError: (error) {
                  debugPrint('[LokaCatch] Gyroscope error: $error');
                  _setGyroscopeUnavailable();
                },
              );
    } catch (e) {
      debugPrint('[LokaCatch] Gyroscope tidak tersedia: $e');
      _setGyroscopeUnavailable();
    }
  }

  /// Dipanggil jika gyroscope tidak tersedia di perangkat ini
  void _setGyroscopeUnavailable() {
    if (mounted) {
      setState(() => _gyroscopeAvailable = false);
    }
  }

  /// Handler event gyroscope — menggerakkan komodo berdasarkan kemiringan.
  ///
  /// [event.y] positif = miring kanan, negatif = miring kiri
  void _onGyroscopeEvent(GyroscopeEvent event) {
    if (!_isPlaying || _isGameOver || _isWon) return;

    setState(() {
      // Gerakan horizontal berdasarkan sumbu Y gyroscope
      _basketX += event.y * _gyroSensitivity;
      // Clamp agar komodo tidak keluar layar.
      _basketX = _basketX.clamp(0.0, 1.0);
    });
  }

  // ---------------------------------------------------
  // GAME LIFECYCLE
  // ---------------------------------------------------

  /// Memulai permainan baru / restart
  void _startGame() {
    setState(() {
      _objects = [];
      _basketX = 0.5;
      _caughtItems = 0;
      _isGameOver = false;
      _isWon = false;
      _isPlaying = true;
      _komodoHasFood = false;
      _lastCaughtFoodAsset = null;
    });
    _komodoMouthTimer?.cancel();

    // Game loop: update posisi objek & deteksi tabrakan setiap ~16ms
    _gameTimer = Timer.periodic(_tickInterval, (_) => _updateGame());

    // Spawn objek baru setiap 1.2 detik
    _spawnTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) {
      if (_isPlaying && !_isGameOver && !_isWon) {
        _spawnObject();
      }
    });
  }

  /// Menghentikan semua timer game
  void _stopGame() {
    _gameTimer?.cancel();
    _spawnTimer?.cancel();
    _gameTimer = null;
    _spawnTimer = null;
  }

  /// Spawn satu objek baru di posisi acak bagian atas layar
  void _spawnObject() {
    final isBomb = _random.nextDouble() < 0.20; // 20% kemungkinan bom
    final assetPath = isBomb
        ? _bombAsset
        : _itemAssets[_random.nextInt(_itemAssets.length)];

    // Kecepatan meningkat seiring progress (semakin banyak item ditangkap)
    final baseSpeed = 2.5 + (_caughtItems * 0.2);
    final speed = baseSpeed + _random.nextDouble() * 1.5;

    _objects.add(
      FallingObject(
        id: 'obj_${_objectIdCounter++}',
        type: isBomb ? FallingObjectType.bomb : FallingObjectType.item,
        assetPath: assetPath,
        x: 0.05 + _random.nextDouble() * 0.90, // Hindari spawn di tepi
        y: -_objectSize, // Mulai dari atas layar (di luar tampilan)
        speed: speed,
      ),
    );
  }

  /// Update state game setiap frame (game loop utama)
  void _updateGame() {
    if (!mounted || _isGameOver || _isWon || !_isPlaying) return;

    var didWin = false;
    setState(() {
      final toRemove = <String>[];

      for (final obj in _objects) {
        // Gerakkan objek ke bawah
        obj.y += obj.speed;

        // Cek apakah objek sudah melewati bawah layar
        if (obj.y > _screenHeight) {
          toRemove.add(obj.id);
          continue;
        }

        // Cek tabrakan objek dengan komodo.
        if (_checkCollision(obj)) {
          toRemove.add(obj.id);

          if (obj.type == FallingObjectType.bomb) {
            // === GAME OVER ===
            _isGameOver = true;
            _isPlaying = false;
            _stopGame();
            HapticFeedback.heavyImpact();
          } else {
            // === ITEM TERTANGKAP ===
            _caughtItems++;
            _komodoHasFood = true;
            _lastCaughtFoodAsset = obj.assetPath;
            _komodoMouthTimer?.cancel();
            _komodoMouthTimer = Timer(const Duration(milliseconds: 700), () {
              if (mounted && !_isWon) {
                setState(() => _komodoHasFood = false);
              }
            });
            _catchAnimController.forward(from: 0);
            HapticFeedback.lightImpact();

            if (_caughtItems >= _maxItems) {
              // === MENANG ===
              _isWon = true;
              _isPlaying = false;
              _stopGame();
              didWin = true;
            }
          }
        }
      }

      // Hapus objek yang sudah tidak diperlukan
      _objects.removeWhere((o) => toRemove.contains(o.id));
    });
    if (didWin) _handleWin();
  }

  /// Makanan hanya tertangkap saat menyentuh mulut komodo yang terbuka.
  ///
  /// Menggunakan AABB (Axis-Aligned Bounding Box) collision detection
  bool _checkCollision(FallingObject obj) {
    if (_screenWidth == 0) return false;

    final komodoTop = _screenHeight - _komodoHeight - 18;
    final objX = obj.x * _screenWidth;
    final objY = obj.y;

    final objLeft = objX - _objectSize / 2;
    final objRight = objX + _objectSize / 2;
    final objTop = objY;
    final objBottom = objY + _objectSize;

    if (obj.type == FallingObjectType.item) {
      if (_komodoHasFood) return false;
      final mouthCenterX = _komodoLeft + _komodoWidth * 0.64;
      final mouthCenterY = komodoTop + _komodoHeight * 0.4;
      final mouthHalfWidth = _komodoWidth * 0.24;
      final mouthLeft = mouthCenterX - mouthHalfWidth;
      final mouthRight = mouthCenterX + mouthHalfWidth;
      final mouthTop = mouthCenterY - _komodoHeight * 0.105;
      final mouthBottom = mouthCenterY + _komodoHeight * 0.126;
      return objRight > mouthLeft &&
          objLeft < mouthRight &&
          objBottom > mouthTop &&
          objTop < mouthBottom;
    }

    final bodyLeft = _komodoLeft + _komodoWidth * 0.2;
    final bodyRight = _komodoLeft + _komodoWidth * 0.8;
    final bodyTop = komodoTop + _komodoHeight * 0.62;
    final bodyBottom = komodoTop + _komodoHeight;
    return objRight > bodyLeft &&
        objLeft < bodyRight &&
        objBottom > bodyTop &&
        objTop < bodyBottom;
  }

  /// Menangani logika kemenangan dan menampilkan voucher
  Future<void> _handleWin() async {
    try {
      final notificationResult =
          await GameNotificationService.showVoucherReward(_gameRewardVoucher);
      if (notificationResult == VoucherNotificationResult.unsupported &&
          mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Selamat! Kamu mendapatkan ${_gameRewardVoucher.discount}: '
              '${_gameRewardVoucher.title}',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on PlatformException catch (error, stackTrace) {
      debugPrint('[LokaCatch] Gagal menampilkan notifikasi voucher: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notifikasi hadiah gagal ditampilkan.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on MissingPluginException catch (error, stackTrace) {
      debugPrint('[LokaCatch] Channel notifikasi tidak tersedia: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notifikasi hadiah tidak tersedia di perangkat ini.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on StateError catch (error, stackTrace) {
      debugPrint('[LokaCatch] Status notifikasi tidak valid: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    if (mounted) {
      // Beri jeda sebentar sebelum tampilkan dialog kemenangan
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) await _showWinDialog();
    }
  }

  // ---------------------------------------------------
  // KONTROL MANUAL (fallback jika gyroscope tidak ada)
  // ---------------------------------------------------

  /// Menggerakkan keranjang ke kiri (kontrol manual)
  void _moveBasketLeft() {
    setState(() {
      _basketX = (_basketX - _manualMoveStep).clamp(0.0, 1.0);
    });
  }

  /// Menggerakkan keranjang ke kanan (kontrol manual)
  void _moveBasketRight() {
    setState(() {
      _basketX = (_basketX + _manualMoveStep).clamp(0.0, 1.0);
    });
  }

  void _moveBasketByDrag(double deltaX) {
    if (!_isPlaying || _screenWidth == 0) return;
    setState(() {
      _basketX = (_basketX + deltaX / _screenWidth).clamp(0.0, 1.0);
    });
  }

  // ---------------------------------------------------
  // DIALOG
  // ---------------------------------------------------

  /// Menampilkan dialog kemenangan dengan hadiah voucher
  Future<void> _showWinDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.pureWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Column(
          children: [
            const Text('🎉', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 8),
            Text(
              'Luar Biasa!',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryGreen,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Kamu berhasil menangkap $_caughtItems item kuliner Nusantara!',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.accentGoldLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.accentGold, width: 1.5),
              ),
              child: Column(
                children: [
                  Text(
                    '🎫 Selamat! Kamu mendapatkan ${_gameRewardVoucher.discount}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _gameRewardVoucher.title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryGreen,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _gameRewardVoucher.merchant,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ref: ${_gameRewardVoucher.reference}',
                    style: const TextStyle(
                      fontSize: 9,
                      fontFamily: 'monospace',
                      color: AppColors.accentGold,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _startGame();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    'Main Lagi',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Kembali ke Menu',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _stopGame();
    _komodoMouthTimer?.cancel();
    _gyroSubscription?.cancel();
    _catchAnimController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------
  // BUILD
  // ---------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1B14), // Dark game background
      appBar: _buildAppBar(),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Simpan dimensi layar untuk kalkulasi game
            _screenWidth = constraints.maxWidth;
            _screenHeight = constraints.maxHeight;

            return GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragUpdate: (details) =>
                  _moveBasketByDrag(details.delta.dx),
              child: Stack(
                children: [
                  // === LATAR BELAKANG ===
                  _buildBackground(),

                  // === OBJEK YANG JATUH ===
                  ..._buildFallingObjects(),

                  // === KOMODO PEMAIN ===
                  _buildKomodo(),

                  // === HUD (Heads-Up Display) ===
                  _buildHUD(),

                  // === OVERLAY: BELUM MULAI ===
                  if (!_isPlaying && !_isGameOver && !_isWon)
                    _buildStartOverlay(),

                  // === OVERLAY: GAME OVER ===
                  if (_isGameOver) _buildGameOverOverlay(),

                  // === PERINGATAN GYROSCOPE TIDAK ADA ===
                  if (!_gyroscopeAvailable && _isPlaying)
                    _buildManualControls(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// AppBar game
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0F1B14),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.chevron_left_rounded,
          color: Colors.white,
          size: 28,
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      centerTitle: true,
      title: Text(
        'LokaCatch 🦎',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }

  /// Latar belakang permainan bergaya malam hari
  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0F1B14), // Hijau gelap tua
            Color(0xFF1A2D1F), // Hijau gelap medium
            Color(0xFF0D1A12), // Hijau gelap bawah
          ],
        ),
      ),
      child: CustomPaint(
        painter: _StarfieldPainter(),
        size: Size(_screenWidth, _screenHeight),
      ),
    );
  }

  /// Render semua objek yang sedang jatuh
  List<Widget> _buildFallingObjects() {
    return _objects.map((obj) {
      final displaySize = obj.type == FallingObjectType.bomb
          ? _bombDisplaySize
          : _objectSize;
      return Positioned(
        left: obj.x * _screenWidth - displaySize / 2,
        top: obj.y,
        child: _buildObjectWidget(obj),
      );
    }).toList();
  }

  /// Widget untuk satu objek jatuh
  Widget _buildObjectWidget(FallingObject obj) {
    final isBomb = obj.type == FallingObjectType.bomb;
    return SizedBox(
      width: isBomb ? _bombDisplaySize : _objectSize,
      height: isBomb ? _bombDisplaySize : _objectSize,
      child: isBomb
          ? Image.asset(_bombAsset, fit: BoxFit.contain)
          : Image.asset(obj.assetPath, fit: BoxFit.contain),
    );
  }

  /// Komodo membuka mulut untuk menangkap makanan lalu menutupnya saat makan.
  Widget _buildKomodo() {
    return Positioned(
      bottom: 18,
      left: _komodoLeft,
      child: ScaleTransition(
        scale: _catchScaleAnim,
        child: SizedBox(
          width: _komodoWidth,
          height: _komodoHeight,
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Image.asset(
                    _komodoHasFood ? _komodoClosedAsset : _komodoOpenAsset,
                    key: ValueKey(_komodoHasFood),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              if (_komodoHasFood && _lastCaughtFoodAsset != null)
                Positioned(
                  left: _komodoWidth * 0.48,
                  top: _komodoHeight * 0.39,
                  child: Image.asset(
                    _lastCaughtFoodAsset!,
                    width: 34,
                    height: 34,
                    fit: BoxFit.contain,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// HUD: menampilkan progress item yang ditangkap
  Widget _buildHUD() {
    return Positioned(
      top: 8,
      left: 16,
      right: 16,
      child: Column(
        children: [
          // Progress bar item
          Row(
            children: [
              Text(
                '$_caughtItems / $_maxItems',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _caughtItems / _maxItems,
                    minHeight: 8,
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.accentGold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '🎫 VOUCHER',
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.accentGold,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),

          // Keterangan gyroscope
          if (_gyroscopeAvailable && _isPlaying) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.screen_rotation_rounded,
                  size: 12,
                  color: Colors.white54,
                ),
                const SizedBox(width: 4),
                Text(
                  'Miringkan HP untuk menggerakkan komodo',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Overlay layar awal sebelum game dimulai
  Widget _buildStartOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.75),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Image(
                image: AssetImage(_komodoOpenAsset),
                width: 140,
                height: 120,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 16),
              Text(
                'LokaCatch',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tangkap 10 hidangan khas Indonesia!\nHindari 💣 agar tidak Game Over.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: Colors.white70,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Cara bermain
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24),
                ),
                child: Column(
                  children: [
                    if (_gyroscopeAvailable)
                      _buildHowToRow(
                        '📱',
                        'Miringkan HP atau geser layar untuk bergerak',
                      )
                    else
                      _buildHowToRow(
                        '👆',
                        'Geser layar atau gunakan tombol ◀ ▶',
                      ),
                    const SizedBox(height: 6),
                    _buildHowToRow(
                      '🍛',
                      'Tangkap hidangan Indonesia (+1 item)',
                    ),
                    const SizedBox(height: 6),
                    _buildHowToRow('💣', 'Hindari bom! (Game Over seketika)'),
                    const SizedBox(height: 6),
                    _buildHowToRow(
                      '🎫',
                      'Tangkap 10 item untuk mendapatkan voucher!',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Indikator sensor
              if (!_gyroscopeAvailable)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.warning_rounded,
                        color: Colors.orange,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Gyroscope tidak tersedia.\nMode kontrol manual aktif.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: Colors.orange,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

              ElevatedButton(
                onPressed: _startGame,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 16,
                  ),
                  elevation: 8,
                  shadowColor: AppColors.primaryGreen.withValues(alpha: 0.5),
                ),
                child: Text(
                  'Mulai Bermain!',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Overlay game over
  Widget _buildGameOverOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('💥', style: TextStyle(fontSize: 80)),
            const SizedBox(height: 16),
            Text(
              'Game Over!',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Komodomu kena bom 💣\nItem berhasil ditangkap: $_caughtItems',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: Colors.white70,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _startGame,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(
                'Coba Lagi',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Keluar',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Kontrol manual (tombol) untuk perangkat tanpa gyroscope
  Widget _buildManualControls() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        color: Colors.black26,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Tombol kiri
            GestureDetector(
              onTapDown: (_) => _moveBasketLeft(),
              child: Container(
                width: 64,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
            Text(
              'KONTROL MANUAL',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                color: Colors.white38,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
            // Tombol kanan
            GestureDetector(
              onTapDown: (_) => _moveBasketRight(),
              child: Container(
                width: 64,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Baris keterangan cara bermain
  Widget _buildHowToRow(String emoji, String text) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: Colors.white70,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// CUSTOM PAINTER: Latar bintang untuk nuansa game
// ============================================================

/// Painter untuk menggambar bintang-bintang sebagai background dekoratif
class _StarfieldPainter extends CustomPainter {
  // Posisi bintang statis (agar tidak berubah setiap rebuild)
  static final List<Offset> _stars = _generateStars();

  static List<Offset> _generateStars() {
    final random = Random(42); // Seed tetap agar konsisten
    return List.generate(
      60,
      (_) => Offset(random.nextDouble(), random.nextDouble()),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    for (final star in _stars) {
      canvas.drawCircle(
        Offset(star.dx * size.width, star.dy * size.height),
        1.0,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
