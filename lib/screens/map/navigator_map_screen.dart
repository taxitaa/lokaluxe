import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/database/db_helper.dart';
import '../../core/services/currency_provider.dart';
import '../../core/theme/app_colors.dart';

class NavigatorMapScreen extends StatefulWidget {
  const NavigatorMapScreen({super.key});

  @override
  State<NavigatorMapScreen> createState() => _NavigatorMapScreenState();
}

class _NavigatorMapScreenState extends State<NavigatorMapScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  Map<String, dynamic>? _selectedDestination;
  bool _isSearching = false;
  bool _hasSearched = false;
  String? _searchError;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchDestinations() async {
    final query = _searchController.text.trim();
    if (query.isEmpty || _isSearching) return;

    setState(() {
      _isSearching = true;
      _hasSearched = true;
      _selectedDestination = null;
      _searchError = null;
      _searchResults = [];
    });

    try {
      final destinations = await DBHelper.getWisata();
      final terms = query.toLowerCase().split(RegExp(r'\s+'));
      final results = destinations
          .where((destination) {
            final searchableText = [
              destination['nama_wisata'],
              destination['kategori'],
              destination['alamat'],
              destination['kota_kabupaten'],
              destination['provinsi'],
            ].whereType<Object>().join(' ').toLowerCase();
            return terms.every(searchableText.contains);
          })
          .take(20)
          .toList();

      if (!mounted) return;
      setState(() => _searchResults = results);
    } catch (error, stackTrace) {
      debugPrint('[NavigatorMapScreen] Could not search destinations: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => _searchError = 'Tujuan gagal dimuat. Coba cari lagi.');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _openGoogleMaps(Map<String, dynamic> destination) async {
    final destinationName = (destination['nama_wisata'] ?? '').toString();
    final location =
        [
              destination['alamat'],
              destination['kota_kabupaten'],
              destination['provinsi'],
            ]
            .where(
              (value) => value != null && value.toString().trim().isNotEmpty,
            )
            .map((value) => value.toString().trim())
            .toSet()
            .join(', ');
    final query = [
      destinationName,
      location,
    ].where((part) => part.isNotEmpty).join(', ');
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': query,
      'travelmode': 'driving',
    });

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) _showNavigationError();
    } catch (error, stackTrace) {
      debugPrint('[NavigatorMapScreen] Could not open Google Maps: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) _showNavigationError();
    }
  }

  void _showNavigationError() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Google Maps tidak dapat dibuka. Coba lagi nanti.'),
          backgroundColor: AppColors.errorRed,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<CurrencyProvider>();
    final selectedDestination = _selectedDestination;

    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceCream,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.chevron_left_rounded,
            color: AppColors.textDark,
            size: 28,
          ),
          onPressed: () {
            if (Navigator.of(context).canPop()) Navigator.of(context).pop();
          },
        ),
        title: Text(
          'Cari Tujuan',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mau pergi ke mana?',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Cari tempat wisata, kota, atau daerah tujuanmu.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.pureWhite,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _searchDestinations(),
                      onChanged: (_) {
                        if (_hasSearched || _selectedDestination != null) {
                          setState(() {
                            _hasSearched = false;
                            _selectedDestination = null;
                            _searchResults = [];
                            _searchError = null;
                          });
                        }
                      },
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: AppColors.textDark,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Contoh: Candi Borobudur',
                        hintStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: AppColors.primaryGreen,
                        ),
                        suffixIcon: IconButton(
                          onPressed: _isSearching ? null : _searchDestinations,
                          icon: _isSearching
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primaryGreen,
                                  ),
                                )
                              : const Icon(
                                  Icons.arrow_forward_rounded,
                                  color: AppColors.primaryGreen,
                                ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: selectedDestination != null
                  ? _buildDestinationDetail(selectedDestination, currency)
                  : _buildSearchContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchContent() {
    if (_searchError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _searchError!,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: AppColors.errorRed,
            ),
          ),
        ),
      );
    }

    if (!_hasSearched) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Cari tempat terdekat',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _openNearbyInGoogleMaps('places'),
                child: Text(
                  'Lihat semua',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          Text(
            'Pilih kategori untuk melihat rekomendasi di sekitar lokasimu.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 16,
            children: [
              _nearbyCategory(
                label: 'Hotel',
                query: 'hotels',
                icon: Icons.hotel_rounded,
                color: const Color(0xFFD96575),
              ),
              _nearbyCategory(
                label: 'Restoran',
                query: 'restaurants',
                icon: Icons.restaurant_rounded,
                color: const Color(0xFF8060C8),
              ),
              _nearbyCategory(
                label: 'Kafe',
                query: 'cafes',
                icon: Icons.local_cafe_rounded,
                color: const Color(0xFFE88F53),
              ),
              _nearbyCategory(
                label: 'Taman',
                query: 'parks',
                icon: Icons.park_rounded,
                color: const Color(0xFF4D9F79),
              ),
              _nearbyCategory(
                label: 'Kolam',
                query: 'swimming pools',
                icon: Icons.pool_rounded,
                color: const Color(0xFF4568D7),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryGreenSubtle,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.location_searching_rounded,
                  color: AppColors.primaryGreen,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Hasil rekomendasi dibuka di Google Maps dan mengikuti lokasi perangkatmu.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      height: 1.45,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Tujuan tidak ditemukan. Coba nama tempat atau daerah lain.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Text(
          'Pilih tujuan',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 10),
        ..._searchResults.map(_buildDestinationResult),
      ],
    );
  }

  Widget _nearbyCategory({
    required String label,
    required String query,
    required IconData icon,
    required Color color,
  }) {
    return SizedBox(
      width: 64,
      child: InkWell(
        onTap: () => _openNearbyInGoogleMaps(query),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(icon, color: AppColors.pureWhite, size: 23),
            ),
            const SizedBox(height: 7),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openNearbyInGoogleMaps(String category) async {
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': '$category near me',
    });
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) _showNavigationError();
    } catch (error, stackTrace) {
      debugPrint('[NavigatorMapScreen] Could not open nearby places: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) _showNavigationError();
    }
  }

  Widget _buildDestinationResult(Map<String, dynamic> destination) {
    final imageUrl = (destination['image_url'] ?? '').toString().trim();
    final location = _destinationLocation(destination);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: AppColors.pureWhite,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.borderLight),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: () => setState(() => _selectedDestination = destination),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 56,
            height: 56,
            child: imageUrl.isEmpty
                ? _destinationImageFallback()
                : Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _destinationImageFallback(),
                  ),
          ),
        ),
        title: Text(
          (destination['nama_wisata'] ?? 'Tujuan wisata').toString(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            location.isEmpty
                ? (destination['kategori'] ?? '').toString()
                : location,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: AppColors.primaryGreen,
        ),
      ),
    );
  }

  Widget _buildDestinationDetail(
    Map<String, dynamic> destination,
    CurrencyProvider currency,
  ) {
    final imageUrl = (destination['image_url'] ?? '').toString().trim();
    final location = _destinationLocation(destination);
    final price = (destination['harga_tiket'] as num?)?.toDouble();
    final description = (destination['deskripsi'] ?? '').toString().trim();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => setState(() => _selectedDestination = null),
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: AppColors.primaryGreen,
              ),
              tooltip: 'Kembali ke hasil pencarian',
            ),
            Text(
              'Detail tujuan',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            height: 210,
            width: double.infinity,
            child: imageUrl.isEmpty
                ? _destinationImageFallback()
                : Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _destinationImageFallback(),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          (destination['nama_wisata'] ?? 'Tujuan wisata').toString(),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 8),
        if (location.isNotEmpty)
          _detailLine(Icons.location_on_outlined, location),
        if ((destination['kategori'] ?? '').toString().trim().isNotEmpty)
          _detailLine(
            Icons.local_offer_outlined,
            (destination['kategori']).toString(),
          ),
        if (price != null)
          _detailLine(
            Icons.confirmation_number_outlined,
            price <= 0 ? 'Gratis' : currency.convertAndFormat(price),
          ),
        if (description.isNotEmpty &&
            description != 'Deskripsi tidak ditemukan') ...[
          const SizedBox(height: 12),
          Text(
            description,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: 22),
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () => _openGoogleMaps(destination),
            icon: const Icon(Icons.navigation_rounded, size: 19),
            label: Text(
              'Lihat Rute di Google Maps',
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
      ],
    );
  }

  Widget _detailLine(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.primaryGreen),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _destinationLocation(Map<String, dynamic> destination) {
    return [
          destination['alamat'],
          destination['kota_kabupaten'],
          destination['provinsi'],
        ]
        .where((value) => value != null && value.toString().trim().isNotEmpty)
        .map((value) => value.toString().trim())
        .toSet()
        .join(', ');
  }

  Widget _destinationImageFallback() {
    return Container(
      color: AppColors.primaryGreenSubtle,
      alignment: Alignment.center,
      child: const Icon(
        Icons.landscape_rounded,
        size: 30,
        color: AppColors.primaryGreen,
      ),
    );
  }
}
