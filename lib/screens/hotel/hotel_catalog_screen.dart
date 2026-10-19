import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';

class HotelCatalogScreen extends StatefulWidget {
  const HotelCatalogScreen({Key? key}) : super(key: key);

  @override
  State<HotelCatalogScreen> createState() => _HotelCatalogScreenState();
}

class _HotelCatalogScreenState extends State<HotelCatalogScreen> {
  late Future<List<Map<String, dynamic>>> _hotelList;

  @override
  void initState() {
    super.initState();
    _hotelList = DBHelper.getHotels(); // Mengambil data hotel dari SQLite
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Katalog Hotel Nusantara', 
          style: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.bold)
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1A1A1A)),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _hotelList,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF1B4332)));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Belum ada data hotel tersimpan di database.'));
          }

          final hotels = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: hotels.length,
            itemBuilder: (context, index) {
              final hotel = hotels[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05), 
                      blurRadius: 8, 
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Gambar Hotel dari Unsplash URL
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      child: Image.network(
                        hotel['image_url'],
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 180,
                          color: Colors.grey[200],
                          child: const Icon(Icons.image_not_supported, color: Colors.grey),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  hotel['name'],
                                  style: const TextStyle(
                                    fontSize: 16, 
                                    fontWeight: FontWeight.bold, 
                                    color: Color(0xFF1A1A1A),
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                                  Text(' ${hotel['stars']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${hotel['city']}, ${hotel['province']}',
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Rp ${hotel['price_per_night']} / malam',
                                style: const TextStyle(
                                  fontSize: 15, 
                                  fontWeight: FontWeight.bold, 
                                  color: Color(0xFF1B4332),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  // Aksi ketika hotel dipilih
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1B4332),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text('Pilih', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}