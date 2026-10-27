import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/database/db_helper.dart';
import '../../core/services/currency_provider.dart';
import '../../core/services/localization_provider.dart';
import '../../core/services/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../itinerary/itinerary_screen.dart';
import '../wisata/wisata_catalog_screen.dart';

class PopularWisataScreen extends StatefulWidget {
  const PopularWisataScreen({super.key});

  @override
  State<PopularWisataScreen> createState() => _PopularWisataScreenState();
}

class _PopularWisataScreenState extends State<PopularWisataScreen> {
  static const _maxWisataPerRegion = 5;

  late final Future<List<Map<String, dynamic>>> _wisataFuture =
      DBHelper.getWisata();

  @override
  Widget build(BuildContext context) {
    final currencyProvider = context.watch<CurrencyProvider>();
    final strings = context.watch<LocalizationProvider>().strings;

    return Scaffold(
      backgroundColor: AppColors.warmCream,
      appBar: AppBar(
        title: Text(
          strings.popularIn,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        backgroundColor: AppColors.warmCream,
        elevation: 0,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _wisataFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '${strings.localized('Gagal memuat data wisata:', 'Could not load attractions:')}\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(color: AppColors.errorRed),
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final grouped = _groupByRegion(snapshot.data!);
          if (grouped.isEmpty) {
            return Center(
              child: Text(strings.localized('Belum ada data wisata.', 'No attractions available.')),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              for (final entry in grouped.entries) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 20, bottom: 8),
                  child: Text(
                    '${entry.key} (${entry.value.length})',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                for (final wisata in entry.value)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _PopularWisataCard(
                      wisata: wisata,
                      price: _formatPrice(
                        wisata['harga_tiket'],
                        currencyProvider,
                        strings,
                      ),
                      onTap: () => _openWisata(context, wisata),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  Map<String, List<Map<String, dynamic>>> _groupByRegion(
    List<Map<String, dynamic>> wisataList,
  ) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final wisata in wisataList) {
      final region = (wisata['provinsi'] ?? '').toString().trim();
      final key = region.isEmpty ? 'Daerah lainnya' : region;
      final items = grouped.putIfAbsent(key, () => []);
      if (items.length < _maxWisataPerRegion) {
        items.add(wisata);
      }
    }
    return grouped;
  }

  String _formatPrice(
    dynamic value,
    CurrencyProvider currencyProvider,
    AppStrings strings,
  ) {
    final price = (value as num?)?.toDouble();
    if (price == null) return '';
    if (price == 0) return strings.localized('Gratis', 'Free');
    return currencyProvider.convertAndFormat(price);
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

class _PopularWisataCard extends StatelessWidget {
  final Map<String, dynamic> wisata;
  final String price;
  final VoidCallback onTap;

  const _PopularWisataCard({
    required this.wisata,
    required this.price,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocalizationProvider>().strings;
    final imageUrl = (wisata['image_url'] ?? '').toString().trim();
    final city = (wisata['kota_kabupaten'] ?? '').toString().trim();
    final province = (wisata['provinsi'] ?? '').toString().trim();
    final location = [
      city,
      province,
    ].where((part) => part.isNotEmpty).join(', ');

    return Card(
      color: AppColors.pureWhite,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              _WisataImage(imageUrl: imageUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${strings.popularIn.toUpperCase()} ${strings.localized('DI', 'IN')} ${province.isEmpty ? strings.indonesia : province.toUpperCase()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppColors.accentGold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      (wisata['nama_wisata'] ?? '').toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (price.isNotEmpty) ...[
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      price,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      '/ tiket',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _WisataImage extends StatelessWidget {
  final String imageUrl;

  const _WisataImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: 104,
      height: 104,
      color: AppColors.surfaceCream,
      alignment: Alignment.center,
      child: const Icon(
        Icons.attractions_rounded,
        size: 32,
        color: AppColors.primaryGreen,
      ),
    );
    if (imageUrl.isEmpty)
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: fallback,
      );

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.network(
        imageUrl,
        width: 104,
        height: 104,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}
