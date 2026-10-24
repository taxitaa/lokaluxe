import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/database/db_helper.dart';
import '../../core/services/currency_provider.dart';
import '../../core/services/map_places_service.dart';
import '../itinerary/itinerary_screen.dart';

import 'package:google_fonts/google_fonts.dart';

class WisataCatalogScreen extends StatefulWidget {
  // Kalau diisi, dipanggil saat user menekan "Pilih" (misal untuk itinerary/budget)
  final void Function(Map<String, dynamic> wisata)? onSelectWisata;
  final String? initialDestination;

  const WisataCatalogScreen({
    super.key,
    this.onSelectWisata,
    this.initialDestination,
  });

  @override
  State<WisataCatalogScreen> createState() => _WisataCatalogScreenState();
}

class _WisataCatalogScreenState extends State<WisataCatalogScreen> {
  static const Color _green = Color(0xFF1B4332);

  late Future<List<Map<String, dynamic>>> _future;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String? _kategori; // null = semua

  @override
  void initState() {
    super.initState();
    _query = widget.initialDestination ?? '';
    _searchController.text = _query;
    _future = DBHelper.getWisata();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Rapikan teks kategori: "wisata  religi" -> "Wisata Religi"
  String _rapikan(String s) {
    return s
        .trim()
        .split(RegExp(r'\s+'))
        .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  // Estimasi tiket per kategori (cadangan kalau kolom harga_tiket di database masih kosong)
  static const Map<String, int> _hargaKategori = {
    'pantai': 10000,
    'gunung': 20000,
    'air terjun': 15000,
    'bukit': 10000,
    'lembah': 15000,
    'candi': 50000,
    'museum': 15000,
    'kebun binatang': 60000,
    'wahana keluarga': 100000,
    'wisata tematik': 75000,
    'wisata edukasi': 25000,
    'wisata kerajaan': 20000,
    'rumah adat': 10000,
    'monumen': 10000,
    'taman': 5000,
    'wisata alam': 15000,
    'wisata lampion': 30000,
    'wisata religi': 5000,
    'wisata kuliner': 50000,
    'alun-alun': 5000,
    'mall': 20000,
    'cafe view': 50000,
  };

  // Ambil harga dari database; kalau kosong (null) pakai estimasi kategori
  num _nilaiHarga(Map<String, dynamic> w) {
    final dariDb = w['harga_tiket'];
    if (dariDb != null) return dariDb as num;
    final kat = _rapikan((w['kategori'] ?? '').toString()).toLowerCase();
    return _hargaKategori[kat] ?? 10000;
  }

  // Format harga tiket: 0 -> "Gratis", 15000 -> "Rp 15.000"
  String _harga(dynamic value) {
    final n = (value as num?)?.round() ?? 0;
    if (n == 0) return 'Free';
    return context.watch<CurrencyProvider>().convertAndFormat(n.toDouble());
  }

  bool _punyaDeskripsi(dynamic d) {
    final s = (d ?? '').toString().trim();
    return s.isNotEmpty && s != 'Deskripsi tidak ditemukan';
  }

  @override
  Widget build(BuildContext context) {
    context.watch<CurrencyProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          'Indonesian Attractions',
          style: GoogleFonts.playfairDisplay(
            color: Color(0xFF1A1A1A),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1A1A1A)),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _green),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load attractions:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.playfairDisplay(color: Colors.red),
                ),
              ),
            );
          }
          final semua = snapshot.data ?? [];
          if (semua.isEmpty) {
            return const Center(child: Text('No attractions available.'));
          }

          // Daftar kategori unik (sudah dirapikan)
          final kategoriList =
              semua
                  .map((e) => _rapikan((e['kategori'] ?? '').toString()))
                  .where((k) => k.isNotEmpty)
                  .toSet()
                  .toList()
                ..sort();

          // Terapkan filter pencarian + kategori
          final q = _query.trim().toLowerCase();
          final queryTerms = q
              .split(RegExp(r'\s+'))
              .where((term) => term.isNotEmpty);
          final hasil = semua.where((e) {
            final nama = (e['nama_wisata'] ?? '').toString().toLowerCase();
            final kota = (e['kota_kabupaten'] ?? '').toString().toLowerCase();
            final prov = (e['provinsi'] ?? '').toString().toLowerCase();
            final alamat = (e['alamat'] ?? '').toString().toLowerCase();
            final searchableText = '$nama $kota $prov $alamat';
            final cocokCari = queryTerms.every(searchableText.contains);
            final cocokKategori =
                _kategori == null ||
                _rapikan((e['kategori'] ?? '').toString()) == _kategori;
            return cocokCari && cocokKategori;
          }).toList();

          return Column(
            children: [
              // Kolom pencarian
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Search attractions, cities, or provinces',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(99),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              // Chip kategori
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _chip('All', _kategori == null, () {
                      setState(() => _kategori = null);
                    }),
                    for (final k in kategoriList)
                      _chip(k, _kategori == k, () {
                        setState(() => _kategori = k);
                      }),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${hasil.length} attractions',
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                ),
              ),
              Expanded(
                child: hasil.isEmpty
                    ? const Center(child: Text('No matching attractions.'))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        itemCount: hasil.length,
                        itemBuilder: (context, i) => _kartu(hasil[i]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? _green : Colors.white,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : const Color(0xFF1A1A1A),
            ),
          ),
        ),
      ),
    );
  }

  Widget _kartu(Map<String, dynamic> w) {
    final img = (w['image_url'] ?? '').toString();
    final kota = (w['kota_kabupaten'] ?? '').toString();
    final prov = (w['provinsi'] ?? '').toString();
    final lokasi = [kota, prov].where((e) => e.isNotEmpty).join(', ');

    return GestureDetector(
      onTap: () => _detail(w),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 160,
              width: double.infinity,
              child: img.isEmpty
                  ? _fotoKosong()
                  : Image.network(
                      img,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _fotoKosong(),
                      loadingBuilder: (c, child, p) => p == null
                          ? child
                          : Container(
                              color: Colors.grey.shade200,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _green,
                                ),
                              ),
                            ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (w['nama_wisata'] ?? '').toString(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 14,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          lokasi,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      _rapikan((w['kategori'] ?? '').toString()),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _green,
                      ),
                    ),
                  ),
                  if (_punyaDeskripsi(w['deskripsi'])) ...[
                    const SizedBox(height: 8),
                    Text(
                      (w['deskripsi']).toString(),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black87,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const Divider(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Estimasi biaya / orang',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.black45,
                            ),
                          ),
                          Text(
                            _harga(_nilaiHarga(w)),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: _green,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          OutlinedButton(
                            onPressed: () => _detail(w),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            child: const Text(
                              'Detail',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () => _pilih(w),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _green,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                            child: const Text(
                              'Pilih',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openWisataInGoogleMaps(Map<String, dynamic> wisata) async {
    final opened = await MapPlacesService.openPlaceInGoogleMaps(
      placeName: (wisata['nama_wisata'] ?? '').toString(),
      address: (wisata['alamat'] ?? '').toString(),
      latitude: _parseCoordinate(wisata['latitude']),
      longitude: _parseCoordinate(wisata['longitude']),
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak dapat membuka Google Maps di perangkat ini.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  double? _parseCoordinate(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  // Tombol "Pilih"
  void _pilih(Map<String, dynamic> w) {
    final nama = (w['nama_wisata'] ?? '').toString();
    if (widget.onSelectWisata != null) {
      widget.onSelectWisata!(w);
      Navigator.pop(context, {...w, 'selectionPrice': _nilaiHarga(w)});
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: _green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Text(
            '$nama dipilih (${_harga(_nilaiHarga(w))} / orang)',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          action: SnackBarAction(
            label: 'Lihat',
            textColor: Colors.white,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ItineraryScreen(
                    pendingWisata: {...w, 'selectionPrice': _nilaiHarga(w)},
                  ),
                ),
              );
            },
          ),
        ),
      );
  }

  // Tombol "Detail" / tap kartu
  void _detail(Map<String, dynamic> w) {
    final img = (w['image_url'] ?? '').toString();
    final desk = _punyaDeskripsi(w['deskripsi'])
        ? (w['deskripsi']).toString()
        : 'Deskripsi belum tersedia.';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              if (img.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    img,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        SizedBox(height: 200, child: _fotoKosong()),
                  ),
                ),
              const SizedBox(height: 14),
              Text(
                (w['nama_wisata'] ?? '').toString(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                (w['alamat'] ?? '').toString(),
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 12),
              Text(desk, style: const TextStyle(fontSize: 13, height: 1.5)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Estimasi biaya / orang',
                          style: TextStyle(fontSize: 11, color: Colors.black54),
                        ),
                        Text(
                          _harga(_nilaiHarga(w)),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: _green,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _pilih(w);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _green,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: const Text(
                        'Pilih Wisata Ini',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openWisataInGoogleMaps(w),
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: const Text('Lihat di Google Maps'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _green,
                    side: const BorderSide(color: _green),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fotoKosong() => Container(
    color: Colors.grey.shade200,
    child: const Center(
      child: Icon(Icons.landscape, size: 40, color: Colors.grey),
    ),
  );
}
