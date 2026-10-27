import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/database/db_helper.dart';
import '../../core/models/hotel_model.dart';
import '../../core/models/transport_model.dart';
import '../../core/services/app_strings.dart';
import '../../core/services/localization_provider.dart';
import '../../core/theme/app_colors.dart';
import '../hotel/hotel_catalog_screen.dart';
import '../itinerary/itinerary_screen.dart';
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
            '${item['provinsi'] ?? ''} ${item['alamat'] ?? ''} '
            '${item['kategori'] ?? ''}',
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
    final strings = context.watch<LocalizationProvider>().strings;
    return Scaffold(
      backgroundColor: AppColors.warmCream,
      appBar: AppBar(
        title: Text(
          strings.localized('Pencarian trip', 'Trip search'),
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
                child: Text(
                  '${strings.localized('Pencarian gagal dimuat:', 'Could not load search results:')}\n${snapshot.error}',
                ),
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
                strings.localized(
                  'Tidak ada hasil untuk "${widget.query}".',
                  'No results for "${widget.query}".',
                ),
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.textSecondary,
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.pureWhite,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: AppColors.primaryGreenSubtle,
                      child: Icon(
                        Icons.search_rounded,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings.localized('Hasil untuk', 'Results for'),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '"${widget.query}" · $total ${strings.localized('item', 'items')}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildSection(
                context,
                strings: strings,
                title: strings.hotels,
                icon: Icons.hotel_rounded,
                items: results.hotels
                    .map(
                      (hotel) => _ResultItem(
                        title: hotel.name,
                        subtitle: '${hotel.city}, ${hotel.province}',
                        imageUrl: hotel.imageUrl,
                        imageIcon: Icons.hotel_rounded,
                        onTap: () => _openHotel(context, hotel),
                      ),
                    )
                    .toList(),
              ),
              _buildSection(
                context,
                strings: strings,
                title: strings.transport,
                icon: Icons.directions_bus_rounded,
                items: results.transport
                    .map(
                      (item) => _ResultItem(
                        title: item.name,
                        subtitle: item.route.isEmpty
                            ? item.province
                            : item.route,
                        imageUrl: item.imageUrl,
                        imageIcon: Icons.directions_bus_rounded,
                        onTap: () => _openTransport(context, item),
                      ),
                    )
                    .toList(),
              ),
              _buildSection(
                context,
                strings: strings,
                title: strings.wisata,
                icon: Icons.attractions_rounded,
                items: results.attractions
                    .map(
                      (item) => _ResultItem(
                        title: (item['nama_wisata'] ?? '').toString(),
                        subtitle:
                            [
                                  item['kategori'],
                                  [item['kota_kabupaten'], item['provinsi']]
                                      .where(
                                        (value) =>
                                            value != null &&
                                            value.toString().isNotEmpty,
                                      )
                                      .join(', '),
                                ]
                                .where(
                                  (value) =>
                                      value != null &&
                                      value.toString().isNotEmpty,
                                )
                                .join(' · '),
                        imageUrl: (item['image_url'] ?? '').toString(),
                        imageIcon: Icons.attractions_rounded,
                        onTap: () => _openWisata(context, item),
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
    required AppStrings strings,
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
        ...items.take(12).map((item) {
          return Card(
            color: AppColors.pureWhite,
            margin: const EdgeInsets.only(bottom: 10),
            elevation: 2,
            shadowColor: Colors.black.withValues(alpha: 0.12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  InkWell(
                    onTap: item.onTap,
                    borderRadius: BorderRadius.circular(12),
                    child: Row(
                      children: [
                        _ResultThumbnail(
                          imageUrl: item.imageUrl,
                          icon: item.imageIcon,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        if (items.length > 12)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 4),
            child: Text(
              strings.localized(
                'Menampilkan 12 dari ${items.length} hasil. Buka kategori untuk melihat lainnya.',
                'Showing 12 of ${items.length} results. Open the category to see more.',
              ),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _openHotel(BuildContext context, HotelModel hotel) async {
    final selectedHotel = await Navigator.of(context).push<HotelModel>(
      MaterialPageRoute(
        builder: (_) => HotelCatalogScreen(
          selectMode: true,
          initialDestination: hotel.name,
          onSelectHotel: (_) {},
        ),
      ),
    );
    if (selectedHotel == null || !context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ItineraryScreen(pendingHotel: selectedHotel),
      ),
    );
  }

  Future<void> _openTransport(
    BuildContext context,
    TransportModel transport,
  ) async {
    final selectedTransport = await Navigator.of(context).push<TransportModel>(
      MaterialPageRoute(
        builder: (_) => TransportCatalogScreen(
          initialDestination: transport.name,
          onSelectTransport: (_) {},
        ),
      ),
    );
    if (selectedTransport == null || !context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ItineraryScreen(pendingTransport: selectedTransport),
      ),
    );
  }

  Future<void> _openWisata(
    BuildContext context,
    Map<String, dynamic> wisata,
  ) async {
    final selectedWisata = await Navigator.of(context)
        .push<Map<String, dynamic>>(
          MaterialPageRoute(
            builder: (_) => WisataCatalogScreen(
              initialDestination: (wisata['nama_wisata'] ?? '').toString(),
              onSelectWisata: (_) {},
            ),
          ),
        );
    if (selectedWisata == null || !context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ItineraryScreen(pendingWisata: selectedWisata),
      ),
    );
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
  final String imageUrl;
  final IconData imageIcon;
  final VoidCallback onTap;

  const _ResultItem({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.imageIcon,
    required this.onTap,
  });
}

class _ResultThumbnail extends StatelessWidget {
  final String imageUrl;
  final IconData icon;

  const _ResultThumbnail({required this.imageUrl, required this.icon});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: AppColors.surfaceCream,
      alignment: Alignment.center,
      child: Icon(icon, size: 30, color: AppColors.primaryGreen),
    );
    final url = imageUrl.trim();

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 82,
        height: 76,
        child: url.isEmpty
            ? fallback
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : Container(
                        color: AppColors.surfaceCream,
                        alignment: Alignment.center,
                        child: const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                      ),
              ),
      ),
    );
  }
}
