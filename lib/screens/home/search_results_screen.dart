import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/database/db_helper.dart';
import '../../core/models/hotel_model.dart';
import '../../core/models/transport_model.dart';
import '../../core/theme/app_colors.dart';
import '../hotel/hotel_catalog_screen.dart';
import '../transportasi/transport_catalog_screen.dart';
import '../wisata/wisata_catalog_screen.dart';

class SearchResultsScreen extends StatefulWidget {
  final String query;

  const SearchResultsScreen({super.key, required this.query});

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  late final Future<_SearchResults> _resultsFuture = _loadResults();

  Future<_SearchResults> _loadResults() async {
    final data = await Future.wait<Object>([
      DBHelper.getHotelModels(),
      DBHelper.getTransportModels(),
      DBHelper.getWisata(),
    ]);
    final terms = widget.query
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty);
    bool matches(String text) {
      final normalized = text.toLowerCase();
      return terms.every(normalized.contains);
    }

    final hotels = (data[0] as List<HotelModel>)
        .where(
          (hotel) => matches(
            '${hotel.name} ${hotel.city} ${hotel.province} ${hotel.address}',
          ),
        )
        .toList();
    final transport = (data[1] as List<TransportModel>)
        .where(
          (item) => matches(
            '${item.name} ${item.route} ${item.province} ${item.operatorName} '
            '${item.type} ${item.category} ${item.description}',
          ),
        )
        .toList();
    final attractions = (data[2] as List<Map<String, dynamic>>)
        .where(
          (item) => matches(
            '${item['nama_wisata'] ?? ''} ${item['kota_kabupaten'] ?? ''} '
            '${item['provinsi'] ?? ''} ${item['alamat'] ?? ''}',
          ),
        )
        .toList();

    return _SearchResults(
      hotels: hotels,
      transport: transport,
      attractions: attractions,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmCream,
      appBar: AppBar(
        title: Text(
          'Hasil pencarian',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        backgroundColor: AppColors.warmCream,
        elevation: 0,
      ),
      body: FutureBuilder<_SearchResults>(
        future: _resultsFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Pencarian gagal dimuat:\n${snapshot.error}'),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final results = snapshot.data!;
          final total =
              results.hotels.length +
              results.transport.length +
              results.attractions.length;
          if (total == 0) {
            return Center(
              child: Text(
                'Tidak ada hasil untuk "${widget.query}".',
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.textSecondary,
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Hasil untuk "${widget.query}" · $total item',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              _buildSection(
                context,
                title: 'Hotel',
                icon: Icons.hotel_rounded,
                items: results.hotels
                    .map(
                      (hotel) => _ResultItem(
                        title: hotel.name,
                        subtitle: '${hotel.city}, ${hotel.province}',
                        onTap: () => _open(
                          context,
                          HotelCatalogScreen(initialDestination: widget.query),
                        ),
                      ),
                    )
                    .toList(),
              ),
              _buildSection(
                context,
                title: 'Transportasi',
                icon: Icons.directions_bus_rounded,
                items: results.transport
                    .map(
                      (item) => _ResultItem(
                        title: item.name,
                        subtitle: item.route.isEmpty
                            ? item.province
                            : item.route,
                        onTap: () => _open(
                          context,
                          TransportCatalogScreen(
                            initialDestination: widget.query,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              _buildSection(
                context,
                title: 'Wisata',
                icon: Icons.attractions_rounded,
                items: results.attractions
                    .map(
                      (item) => _ResultItem(
                        title: (item['nama_wisata'] ?? '').toString(),
                        subtitle:
                            '${item['kota_kabupaten'] ?? ''}, ${item['provinsi'] ?? ''}',
                        onTap: () => _open(
                          context,
                          WisataCatalogScreen(initialDestination: widget.query),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<_ResultItem> items,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: Row(
            children: [
              Icon(icon, size: 19, color: AppColors.primaryGreen),
              const SizedBox(width: 8),
              Text(
                '$title (${items.length})',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
        ...items
            .take(12)
            .map(
              (item) => Card(
                color: AppColors.pureWhite,
                child: ListTile(
                  title: Text(
                    item.title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(item.subtitle),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: item.onTap,
                ),
              ),
            ),
        if (items.length > 12)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 4),
            child: Text(
              'Menampilkan 12 dari ${items.length} hasil. Buka kategori untuk melihat lainnya.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

class _SearchResults {
  final List<HotelModel> hotels;
  final List<TransportModel> transport;
  final List<Map<String, dynamic>> attractions;

  const _SearchResults({
    required this.hotels,
    required this.transport,
    required this.attractions,
  });
}

class _ResultItem {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ResultItem({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}
