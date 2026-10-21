import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/services/currency_provider.dart';
import '../../core/theme/app_colors.dart';

class NavigatorMapScreen extends StatefulWidget {
  const NavigatorMapScreen({super.key});

  @override
  State<NavigatorMapScreen> createState() => _NavigatorMapScreenState();
}

class _NavigatorMapScreenState extends State<NavigatorMapScreen> {
  int _selectedPinIndex = 0;

  final List<Map<String, dynamic>> _pins = [
    {
      'title': 'Candi Borobudur',
      'category': 'Wisata Candi',
      'distance': '18 km • 35 mnt',
      'price': 750000,
      'rating': '4.8',
      'image': 'assets/images/dest_borobudur.jpg',
      'x': 0.45,
      'y': 0.35,
    },
    {
      'title': 'Tanah Lot & Pantai',
      'category': 'Pesisir Pantai',
      'distance': '24 km • 45 mnt',
      'price': 1250000,
      'rating': '4.9',
      'image': 'assets/images/dest_tanahlot.jpg',
      'x': 0.70,
      'y': 0.55,
    },
    {
      'title': 'Nusa Penida Coastal',
      'category': 'Pulau & Laut',
      'distance': '38 km • Speedboat',
      'price': 650000,
      'rating': '4.9',
      'image': 'assets/images/dest_nusapenida.jpg',
      'x': 0.30,
      'y': 0.65,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final currencyProvider = context.watch<CurrencyProvider>();
    final selectedPin = _pins[_selectedPinIndex];

    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      body: Stack(
        children: [
          // Simulated Stylized Luxury Map Canvas
          Positioned.fill(
            child: CustomPaint(
              painter: _MapCanvasPainter(),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: List.generate(_pins.length, (index) {
                      final pin = _pins[index];
                      final isSelected = _selectedPinIndex == index;
                      final left = constraints.maxWidth * (pin['x'] as double);
                      final top = constraints.maxHeight * (pin['y'] as double);

                      return Positioned(
                        left: left - 20,
                        top: top - 40,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedPinIndex = index;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primaryGreen
                                        : AppColors.pureWhite,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.1),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    pin['title'],
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected
                                          ? Colors.white
                                          : AppColors.textDark,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.location_on_rounded,
                                  size: isSelected ? 34 : 26,
                                  color: isSelected
                                      ? AppColors.primaryGreen
                                      : AppColors.accentGold,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
            ),
          ),

          // Top Header & Search Bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Back Button
                      CircleAvatar(
                        backgroundColor: AppColors.pureWhite,
                        child: IconButton(
                          icon: const Icon(
                            Icons.chevron_left_rounded,
                            color: AppColors.textDark,
                            size: 26,
                          ),
                          onPressed: () {
                            if (Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Search Input
                      Expanded(
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.pureWhite,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextField(
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              color: AppColors.textDark,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Cari rute atau destinasi...',
                              hintStyle: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                color: AppColors.textMuted,
                              ),
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                size: 20,
                                color: AppColors.primaryGreen,
                              ),
                              border: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 13),
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

          // Right Map Controls
          Positioned(
            right: 20,
            bottom: 230,
            child: Column(
              children: [
                _buildMapControl(
                  icon: Icons.my_location_rounded,
                  onTap: () {},
                ),
                const SizedBox(height: 10),
                _buildMapControl(
                  icon: Icons.layers_outlined,
                  onTap: () {},
                ),
              ],
            ),
          ),

          // White Bottom Sheet
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              decoration: const BoxDecoration(
                color: AppColors.pureWhite,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 20,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Sheet Handle
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.borderLight,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Destination Card Detail
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: SizedBox(
                            width: 72,
                            height: 72,
                            child: Image.asset(
                              selectedPin['image'],
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedPin['title'],
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                selectedPin['category'],
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.directions_car_rounded,
                                    size: 13,
                                    color: AppColors.primaryGreen,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    selectedPin['distance'],
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primaryGreen,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              currencyProvider.convertAndFormat(
                                (selectedPin['price'] as num).toDouble(),
                              ),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryGreen,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  size: 13,
                                  color: AppColors.starGold,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  selectedPin['rating'],
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textDark,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Primary Button: Mulai Navigasi
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Navigasi rute ke ${selectedPin['title']} dimulai!',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                ),
                              ),
                              backgroundColor: AppColors.primaryGreen,
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.navigation_rounded,
                          size: 18,
                          color: AppColors.pureWhite,
                        ),
                        label: Text(
                          'Mulai Navigasi Rute',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: AppColors.pureWhite,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapControl({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.pureWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderLight, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: AppColors.primaryGreen),
      ),
    );
  }
}

class _MapCanvasPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFFF3ECE0);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final waterPaint = Paint()
      ..color = const Color(0xFFDFE9E4)
      ..style = PaintingStyle.fill;

    // Scenic river / coastline curve
    final riverPath = Path()
      ..moveTo(0, size.height * 0.4)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.45,
        size.width,
        size.height * 0.35,
      )
      ..lineTo(size.width, size.height * 0.5)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.6,
        0,
        size.height * 0.55,
      )
      ..close();
    canvas.drawPath(riverPath, waterPaint);

    // Subtle Road Grid Lines
    final roadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(size.width * 0.1, 0),
      Offset(size.width * 0.7, size.height),
      roadPaint,
    );
    canvas.drawLine(
      Offset(0, size.height * 0.6),
      Offset(size.width, size.height * 0.5),
      roadPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.8, 0),
      Offset(size.width * 0.3, size.height),
      roadPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
