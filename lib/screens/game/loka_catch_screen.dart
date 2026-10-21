import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../core/services/game_coin_service.dart';
import '../../core/theme/app_colors.dart';

// ============================================================
// DATA MODEL: Objek yang jatuh di area permainan
// ============================================================

/// Tipe objek dalam permainan LokaCatch
enum FallingObjectType {
  item,  // Objek kuliner/rempah yang harus ditangkap
  bomb,  // Rintangan bom (game over jika kena)
}

/// Model objek yang jatuh dari atas layar
class FallingObject {
  final String id;          // ID unik objek ini
  final FallingObjectType type;
  final String emoji;       // Representasi visual emoji
  double x;                 // Posisi horizontal (0.0 - 1.0, relatif terhadap lebar layar)
  double y;                 // Posisi vertikal saat ini (dalam pixels)
  double speed;             // Kecepatan jatuh per frame (pixels/tick)

  FallingObject({
    required this.id,
    required this.type,
    required this.emoji,
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
/// - Pemain memiringkan HP untuk menggerakkan keranjang
/// - Tangkap 10 item kuliner untuk menang & mendapat koin
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
  static const int _maxItems = 10;            // Item maks untuk menang
  static const double _basketWidth = 80.0;   // Lebar keranjang (px)
  static const double _basketHeight = 50.0;  // Tinggi keranjang (px)
  static const double _objectSize = 44.0;    // Ukuran objek jatuh (px)
  static const double _gyroSensitivity = 0.008; // Sensitivitas gyroscope
  static const Duration _tickInterval = Duration(milliseconds: 16); // ~60 FPS

  // ---------------------------------------------------
  // DAFTAR OBJEK GAME
  // ---------------------------------------------------
  /// Emoji kuliner & rempah Nusantara yang bisa ditangkap
  static const List<String> _itemEmojis = [
    '🌶️', '🧅', '🧄', '🍋', '🥥',
    '🍛', '🍜', '🥗', '🫚', '🌿',
    '🫛', '🍃', '🌾', '🫙', '🧂',
  ];

  // ---------------------------------------------------
  // STATE GAME
  // ---------------------------------------------------
  List<FallingObject> _objects = [];       // Semua objek aktif di layar
  double _basketX = 0.5;                   // Posisi horizontal keranjang (0-1)
  int _caughtItems = 0;                    // Jumlah item berhasil ditangkap
  bool _isGameOver = false;                // Status game over
  bool _isWon = false;                     // Status menang (10 item tertangkap)
  bool _isPlaying = false;                 // Apakah permainan sedang berjalan
  int _earnedCoins = 0;                    // Koin yang diperoleh sesi ini
  int _totalCoins = 0;                     // Total koin yang dimiliki
  bool _gyroscopeAvailable = true;        // Apakah sensor gyroscope tersedia

  // ---------------------------------------------------
  // CONTROLLERS & STREAMS
  // ---------------------------------------------------
  Timer? _gameTimer;                      // Timer game loop utama
  Timer? _spawnTimer;                     // Timer untuk spawn objek baru
  StreamSubscription<GyroscopeEvent>? _gyroSubscription; // Listener gyroscope

  // Untuk animasi "item tertangkap" feedback
  late AnimationController _catchAnimController;
  late Animation<double> _catchScaleAnim;

  // Dimensi layar game (diisi saat build)
  double _screenWidth = 0;
  double _screenHeight = 0;

  // Random generator
  final Random _random = Random();

  // Counter untuk ID unik objek
  int _objectIdCounter = 0;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadTotalCoins();
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

  /// Memuat total koin dari penyimpanan lokal
  Future<void> _loadTotalCoins() async {
    final coins = await GameCoinService.getTotalCoins();
    if (mounted) setState(() => _totalCoins = coins);
  }

  /// Menginisialisasi sensor gyroscope dengan error handling
  ///
  /// Jika perangkat tidak mendukung gyroscope, fallback ke kontrol tap/drag
  void _initGyroscope() {
    try {
      _gyroSubscription = gyroscopeEventStream(
        samplingPeriod: SensorInterval.gameInterval,
      ).listen(
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

  /// Handler event gyroscope — menggerakkan keranjang berdasarkan kemiringan
  ///
  /// [event.y] positif = miring kanan, negatif = miring kiri
  void _onGyroscopeEvent(GyroscopeEvent event) {
    if (!_isPlaying || _isGameOver || _isWon) return;

    setState(() {
      // Gerakan horizontal berdasarkan sumbu Y gyroscope
      _basketX += event.y * _gyroSensitivity;
      // Clamp agar keranjang tidak keluar layar
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
      _earnedCoins = 0;
    });

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
    final emoji = isBomb
        ? '💣'
        : _itemEmojis[_random.nextInt(_itemEmojis.length)];

    // Kecepatan meningkat seiring progress (semakin banyak item ditangkap)
    final baseSpeed = 2.5 + (_caughtItems * 0.2);
    final speed = baseSpeed + _random.nextDouble() * 1.5;

    _objects.add(FallingObject(
      id: 'obj_${_objectIdCounter++}',
      type: isBomb ? FallingObjectType.bomb : FallingObjectType.item,
      emoji: emoji,
      x: 0.05 + _random.nextDouble() * 0.90, // Hindari spawn di tepi
      y: -_objectSize, // Mulai dari atas layar (di luar tampilan)
      speed: speed,
    ));
  }

  /// Update state game setiap frame (game loop utama)
  void _updateGame() {
    if (!mounted || _isGameOver || _isWon || !_isPlaying) return;

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

        // Cek tabrakan dengan keranjang
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
            _catchAnimController.forward(from: 0);
            HapticFeedback.lightImpact();

            if (_caughtItems >= _maxItems) {
              // === MENANG ===
              _isWon = true;
              _isPlaying = false;
              _stopGame();
              _handleWin();
            }
          }
        }
      }

      // Hapus objek yang sudah tidak diperlukan
      _objects.removeWhere((o) => toRemove.contains(o.id));
    });
  }

  /// Mengecek tabrakan antara objek jatuh dengan keranjang
  ///
  /// Menggunakan AABB (Axis-Aligned Bounding Box) collision detection
  bool _checkCollision(FallingObject obj) {
    if (_screenWidth == 0) return false;

    // Posisi tengah keranjang dalam pixels
    final basketCenterX = _basketX * _screenWidth;
    final basketTopY = _screenHeight - _basketHeight - 40.0; // 40px dari bawah

    // Posisi objek dalam pixels
    final objX = obj.x * _screenWidth;
    final objY = obj.y;

    // AABB collision
    final basketLeft = basketCenterX - _basketWidth / 2;
    final basketRight = basketCenterX + _basketWidth / 2;
    final basketTop = basketTopY;
    final basketBottom = basketTopY + _basketHeight;

    final objLeft = objX - _objectSize / 2;
    final objRight = objX + _objectSize / 2;
    final objTop = objY;
    final objBottom = objY + _objectSize;

    return objRight > basketLeft &&
        objLeft < basketRight &&
        objBottom > basketTop &&
        objTop < basketBottom;
  }

  /// Menangani logika kemenangan: simpan koin & tampilkan dialog
  Future<void> _handleWin() async {
    // Simpan high score
    await GameCoinService.updateHighScore(_caughtItems);

    // Berikan reward koin
    _earnedCoins = await GameCoinService.awardCoinsForCompletion();
    _totalCoins = await GameCoinService.getTotalCoins();

    if (mounted) {
      setState(() {});
      // Beri jeda sebentar sebelum tampilkan dialog kemenangan
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) _showWinDialog();
    }
  }

  // ---------------------------------------------------
  // KONTROL MANUAL (fallback jika gyroscope tidak ada)
  // ---------------------------------------------------

  /// Menggerakkan keranjang ke kiri (kontrol manual)
  void _moveBasketLeft() {
    setState(() {
      _basketX = (_basketX - 0.08).clamp(0.0, 1.0);
    });
  }

  /// Menggerakkan keranjang ke kanan (kontrol manual)
  void _moveBasketRight() {
    setState(() {
      _basketX = (_basketX + 0.08).clamp(0.0, 1.0);
    });
  }

  // ---------------------------------------------------
  // DIALOG
  // ---------------------------------------------------

  /// Menampilkan dialog kemenangan dengan informasi koin
  void _showWinDialog() {
    showDialog(
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.accentGoldLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.accentGold, width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.monetization_on_rounded,
                      color: AppColors.accentGold, size: 28),
                  const SizedBox(width: 10),
                  Text(
                    '+$_earnedCoins Koin',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Total Koin: $_totalCoins',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: AppColors.textSecondary,
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
                        borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    'Main Lagi',
                    style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700),
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

            return Stack(
              children: [
                // === LATAR BELAKANG ===
                _buildBackground(),

                // === OBJEK YANG JATUH ===
                ..._buildFallingObjects(),

                // === KERANJANG PEMAIN ===
                _buildBasket(),

                // === HUD (Heads-Up Display) ===
                _buildHUD(),

                // === OVERLAY: BELUM MULAI ===
                if (!_isPlaying && !_isGameOver && !_isWon)
                  _buildStartOverlay(),

                // === OVERLAY: GAME OVER ===
                if (_isGameOver) _buildGameOverOverlay(),

                // === PERINGATAN GYROSCOPE TIDAK ADA ===
                if (!_gyroscopeAvailable && _isPlaying) _buildManualControls(),
              ],
            );
          },
        ),
      ),
    );
  }

  /// AppBar dengan info koin
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0F1B14),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.chevron_left_rounded,
            color: Colors.white, size: 28),
        onPressed: () => Navigator.of(context).pop(),
      ),
      centerTitle: true,
      title: Text(
        'LokaCatch 🧺',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
      actions: [
        // Tampilan koin
        Container(
          margin: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.accentGoldLight,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.accentGold, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.monetization_on_rounded,
                  size: 14, color: AppColors.accentGold),
              const SizedBox(width: 4),
              Text(
                '$_totalCoins',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
      ],
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
      return Positioned(
        left: obj.x * _screenWidth - _objectSize / 2,
        top: obj.y,
        child: _buildObjectWidget(obj),
      );
    }).toList();
  }

  /// Widget untuk satu objek jatuh
  Widget _buildObjectWidget(FallingObject obj) {
    final isBomb = obj.type == FallingObjectType.bomb;
    return Container(
      width: _objectSize,
      height: _objectSize,
      decoration: isBomb
          ? BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.red.withValues(alpha: 0.15),
              border: Border.all(color: Colors.red.withValues(alpha: 0.5), width: 1.5),
            )
          : null,
      child: Center(
        child: Text(
          obj.emoji,
          style: TextStyle(fontSize: isBomb ? 28 : 30),
        ),
      ),
    );
  }

  /// Widget keranjang penangkap yang dikendalikan gyroscope
  Widget _buildBasket() {
    return Positioned(
      bottom: 40,
      left: _basketX * _screenWidth - _basketWidth / 2,
      child: ScaleTransition(
        scale: _catchScaleAnim,
        child: Container(
          width: _basketWidth,
          height: _basketHeight,
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withValues(alpha: 0.9),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
              bottomLeft: Radius.circular(14),
              bottomRight: Radius.circular(14),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryGreen.withValues(alpha: 0.6),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
            border: Border.all(
              color: AppColors.accentGold.withValues(alpha: 0.8),
              width: 2,
            ),
          ),
          child: const Center(
            child: Text('🧺', style: TextStyle(fontSize: 28)),
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
                '🏆 +50',
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
                const Icon(Icons.screen_rotation_rounded,
                    size: 12, color: Colors.white54),
                const SizedBox(width: 4),
                Text(
                  'Miringkan HP untuk menggerakkan keranjang',
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
              const Text('🧺', style: TextStyle(fontSize: 72)),
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
                'Tangkap 10 bahan kuliner Nusantara!\nHindari 💣 agar tidak Game Over.',
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
                          '📱', 'Miringkan HP ke kiri/kanan untuk bergerak')
                    else
                      _buildHowToRow('👆', 'Gunakan tombol ◀ ▶ untuk bergerak'),
                    const SizedBox(height: 6),
                    _buildHowToRow('🌶️', 'Tangkap rempah & kuliner (+1 item)'),
                    const SizedBox(height: 6),
                    _buildHowToRow('💣', 'Hindari bom! (Game Over seketika)'),
                    const SizedBox(height: 6),
                    _buildHowToRow('🪙', '10 item = +50 koin (pertama kali)'),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Indikator sensor
              if (!_gyroscopeAvailable)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_rounded,
                          color: Colors.orange, size: 16),
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
                      borderRadius: BorderRadius.circular(30)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 48, vertical: 16),
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
              'Keranjangmu kena bom 💣\nItem berhasil ditangkap: $_caughtItems',
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
                    borderRadius: BorderRadius.circular(30)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 40, vertical: 14),
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
                child: const Icon(Icons.arrow_back_ios_rounded,
                    color: Colors.white, size: 22),
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
                child: const Icon(Icons.arrow_forward_ios_rounded,
                    color: Colors.white, size: 22),
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
