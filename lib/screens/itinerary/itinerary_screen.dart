import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../map/navigator_map_screen.dart';

class ItineraryScreen extends StatefulWidget {
  const ItineraryScreen({super.key});

  @override
  State<ItineraryScreen> createState() => _ItineraryScreenState();
}

class _ItineraryScreenState extends State<ItineraryScreen> {
  int _selectedDay = 0;

  final List<String> _days = ['Hari 1', 'Hari 2', 'Hari 3', 'Hari 4', 'Hari 5'];

  final List<List<Map<String, dynamic>>> _activitiesByDay = [
    [
      {
        'time': '08:30',
        'title': 'Tiba di Bandara & Check-in Hotel',
        'location': 'The Phoenix Hotel Yogyakarta',
        'cost': 'Rp 850.000',
        'category': 'Penginapan',
        'icon': Icons.hotel_rounded,
      },
      {
        'time': '11:00',
        'title': 'Kraton Ngayogyakarta Hadiningrat',
        'location': 'Pusat Kota Yogyakarta',
        'cost': 'Rp 25.000',
        'category': 'Wisata Budaya',
        'icon': Icons.account_balance_rounded,
      },
      {
        'time': '13:30',
        'title': 'Makan Siang Gudeg Yu Djum Wijilan',
        'location': 'Jl. Wijilan, Panembahan',
        'cost': 'Rp 65.000',
        'category': 'Kuliner',
        'icon': Icons.restaurant_rounded,
      },
      {
        'time': '16:30',
        'title': 'Sunset di Candi Ratu Boko',
        'location': 'Bokoharjo, Prambanan',
        'cost': 'Rp 85.000',
        'category': 'Sunset View',
        'icon': Icons.wb_sunny_rounded,
      },
    ],
    [
      {
        'time': '04:30',
        'title': 'Sunrise Tour Candi Borobudur',
        'location': 'Magelang, Jawa Tengah',
        'cost': 'Rp 150.000',
        'category': 'Wisata Candi',
        'icon': Icons.temple_buddhist_rounded,
      },
      {
        'time': '09:30',
        'title': 'Sarapan Tradisional Pawon Luwak Coffee',
        'location': 'Borobudur, Magelang',
        'cost': 'Rp 75.000',
        'category': 'Kuliner',
        'icon': Icons.coffee_rounded,
      },
      {
        'time': '14:00',
        'title': 'Jeep Tour Merapi Lava Tour',
        'location': 'Kaliurang, Sleman',
        'cost': 'Rp 450.000',
        'category': 'Petualangan',
        'icon': Icons.terrain_rounded,
      },
    ],
    [
      {
        'time': '09:00',
        'title': 'Pantai Timang & Gondola Tradisional',
        'location': 'Tepus, Gunungkidul',
        'cost': 'Rp 350.000',
        'category': 'Pantai & Bahari',
        'icon': Icons.waves_rounded,
      },
      {
        'time': '14:30',
        'title': 'Goa Pindul Cave Tubing',
        'location': 'Karangmojo, Gunungkidul',
        'cost': 'Rp 120.000',
        'category': 'Air & Goa',
        'icon': Icons.kayaking_rounded,
      },
    ],
    [
      {
        'time': '10:00',
        'title': 'Belanja Kerajinan Perak Kotagede',
        'location': 'Kotagede, Yogyakarta',
        'cost': 'Rp 300.000',
        'category': 'Oleh-oleh',
        'icon': Icons.shopping_bag_rounded,
      },
    ],
    [
      {
        'time': '11:00',
        'title': 'Jalan Santai Malioboro & Titik Nol',
        'location': 'Jl. Malioboro',
        'cost': 'Rp 100.000',
        'category': 'City Walk',
        'icon': Icons.directions_walk_rounded,
      },
      {
        'time': '16:00',
        'title': 'Perjalanan Menuju Bandara YIA',
        'location': 'Kulon Progo',
        'cost': 'Rp 50.000',
        'category': 'Transportasi',
        'icon': Icons.flight_takeoff_rounded,
      },
    ],
  ];

  @override
  Widget build(BuildContext context) {
    final activities = _activitiesByDay[_selectedDay];

    return Scaffold(
      backgroundColor: AppColors.warmCream,
      appBar: AppBar(
        backgroundColor: AppColors.warmCream,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.chevron_left_rounded,
            size: 28,
            color: AppColors.textDark,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: Text(
          'Itinerary Perjalanan',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.share_outlined,
              size: 20,
              color: AppColors.textSecondary,
            ),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header Trip Info Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryGreen.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Yogyakarta Heritage Tour',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '5 Hari • 12 Destinasi Wisata',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Budget OK',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accentGold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Day Selector Tabs
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                physics: const BouncingScrollPhysics(),
                itemCount: _days.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final isSelected = _selectedDay == index;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedDay = index;
                      });
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primaryGreen
                            : AppColors.pureWhite,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primaryGreen
                              : AppColors.borderLight,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        _days[index],
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : AppColors.textDark,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            // Timeline List of Activities
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                physics: const BouncingScrollPhysics(),
                itemCount: activities.length,
                itemBuilder: (context, index) {
                  final item = activities[index];
                  final isLast = index == activities.length - 1;

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Timeline indicator
                      Column(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreenSubtle,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.primaryGreen,
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              item['icon'] as IconData,
                              size: 15,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                          if (!isLast)
                            Container(
                              width: 2,
                              height: 60,
                              color: AppColors.borderLight,
                            ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      // Activity Card
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.pureWhite,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.borderLight,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    item['time'],
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primaryGreen,
                                    ),
                                  ),
                                  Text(
                                    item['cost'],
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item['title'],
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.location_on_rounded,
                                    size: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 3),
                                  Expanded(
                                    child: Text(
                                      item['location'],
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // Bottom CTA: Buka Navigasi Peta
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const NavigatorMapScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.map_rounded, size: 18),
                  label: Text(
                    'Buka Peta Navigasi',
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
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
