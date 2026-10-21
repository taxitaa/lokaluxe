import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/database/db_helper.dart';
import '../../core/models/transport_model.dart';
import '../../core/services/currency_provider.dart';
import '../../core/theme/app_colors.dart';

class TransportCatalogScreen extends StatefulWidget {
  // Kalau diisi, dipanggil saat user menekan "Pilih" (misal untuk itinerary/budget)
  final void Function(TransportModel transport)? onSelectTransport;

  const TransportCatalogScreen({super.key, this.onSelectTransport});

  @override
  State<TransportCatalogScreen> createState() => _TransportCatalogScreenState();
}

class _TransportCatalogScreenState extends State<TransportCatalogScreen> {
  static const List<String> _types = [
    'Semua',
    'Pesawat',
    'Kereta',
    'Bus',
    'Kapal',
    'Sewa Mobil',
    'Sewa Motor',
  ];

  late Future<List<TransportModel>> _future;
  List<TransportModel> _all = [];
  List<TransportModel> _filtered = [];

  final TextEditingController _searchController = TextEditingController();
  String _selectedType = 'Semua';
  String _sortBy = 'default'; // default, price_asc, price_desc, name_asc

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<TransportModel>> _load() async {
    _all = await DBHelper.getTransportModels();
    _filtered = _hitungFilter();
    return _all;
  }

  Future<void> _refresh() {
    setState(() {
      _future = _load();
    });
    return _future;
  }

  void _terapkan() {
    setState(() {
      _filtered = _hitungFilter();
    });
  }

  List<TransportModel> _hitungFilter() {
    final q = _searchController.text.trim().toLowerCase();
    final hasil = _all.where((t) {
      if (_selectedType != 'Semua' && t.type != _selectedType) return false;
      if (q.isNotEmpty) {
        final cocok = t.name.toLowerCase().contains(q) ||
            t.route.toLowerCase().contains(q) ||
            t.province.toLowerCase().contains(q) ||
            t.operatorName.toLowerCase().contains(q);
        if (!cocok) return false;
      }
      return true;
    }).toList();

    switch (_sortBy) {
      case 'price_asc':
        hasil.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'price_desc':
        hasil.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'name_asc':
        hasil.sort((a, b) => a.name.compareTo(b.name));
        break;
      default:
        break;
    }
    return hasil;
  }

  IconData _icon(String type) {
    switch (type) {
      case 'Pesawat':
        return Icons.flight_rounded;
      case 'Kereta':
        return Icons.train_rounded;
      case 'Bus':
        return Icons.directions_bus_rounded;
      case 'Kapal':
        return Icons.directions_boat_rounded;
      case 'Sewa Mobil':
        return Icons.directions_car_rounded;
      case 'Sewa Motor':
        return Icons.two_wheeler_rounded;
      default:
        return Icons.commute_rounded;
    }
  }

  Widget _kotakIkon(TransportModel t, double tinggi) {
    return Container(
      height: tinggi,
      width: double.infinity,
      color: AppColors.surfaceCream,
      child: Center(
        child: Icon(_icon(t.type), size: 52, color: AppColors.primaryGreen),
      ),
    );
  }

  Widget _gambar(TransportModel t, double tinggi) {
    if (t.imageUrl.isEmpty) return _kotakIkon(t, tinggi);
    return Image.network(
      t.imageUrl,
      height: tinggi,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _kotakIkon(t, tinggi),
    );
  }

  void _pilih(TransportModel t) {
    if (widget.onSelectTransport != null) {
      widget.onSelectTransport!(t);
      Navigator.pop(context, t);
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: AppColors.primaryGreen,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${t.name} selected (${context.read<CurrencyProvider>().convertAndFormat(t.price)} ${t.priceUnit})',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  void _detail(TransportModel t) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
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
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _gambar(t, 190),
              ),
              const SizedBox(height: 14),
              Text(
                t.name,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 6),
              _barisInfo(Icons.business_rounded, t.operatorName),
              _barisInfo(Icons.route_rounded, t.route),
              _barisInfo(Icons.location_on, '${t.province}  •  ${t.category}'),
              const SizedBox(height: 10),
              Text(
                t.description,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, height: 1.5, color: AppColors.textDark),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCream,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Estimasi harga',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                        Text(
                          '${context.watch<CurrencyProvider>().convertAndFormat(t.price)} ${t.priceUnit}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _pilih(t);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 22, vertical: 12),
                      ),
                      child: Text(
                        'Pilih',
                        style: GoogleFonts.plusJakartaSans(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _barisInfo(IconData icon, String teks) {
    if (teks.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: AppColors.primaryGreen),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              teks,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmCream,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Transportasi Nusantara',
              style: GoogleFonts.playfairDisplay(
                color: AppColors.textDark,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              'Pesawat, kereta, bus, kapal, dan sewa kendaraan',
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.pureWhite,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textDark),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort_rounded, color: AppColors.textDark),
            tooltip: 'Urutkan',
            initialValue: _sortBy,
            onSelected: (v) {
              _sortBy = v;
              _terapkan();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'default', child: Text('Berdasarkan jenis')),
              PopupMenuItem(
                  value: 'price_asc', child: Text('Harga: Termurah')),
              PopupMenuItem(
                  value: 'price_desc', child: Text('Harga: Termahal')),
              PopupMenuItem(value: 'name_asc', child: Text('Nama (A - Z)')),
            ],
          ),
        ],
      ),
      body: FutureBuilder<List<TransportModel>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Gagal memuat data transportasi:\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                          color: AppColors.errorRed),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _refresh,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen),
                      child: const Text('Coba Lagi',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              // Pencarian
              Container(
                color: AppColors.pureWhite,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.warmCream,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => _terapkan(),
                    style: GoogleFonts.plusJakartaSans(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Cari nama, rute, operator, atau provinsi...',
                      hintStyle: GoogleFonts.plusJakartaSans(
                          color: AppColors.textMuted, fontSize: 13),
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: AppColors.primaryGreen),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _terapkan();
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                  ),
                ),
              ),
              // Chip jenis
              Container(
                color: AppColors.pureWhite,
                padding: const EdgeInsets.only(bottom: 10),
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: _types.map((jenis) {
                    final dipilih = _selectedType == jenis;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(jenis),
                        selected: dipilih,
                        onSelected: (_) {
                          _selectedType = jenis;
                          _terapkan();
                        },
                        backgroundColor: AppColors.warmCream,
                        selectedColor: AppColors.primaryGreen,
                        showCheckmark: false,
                        labelStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight:
                              dipilih ? FontWeight.bold : FontWeight.w500,
                          color: dipilih ? Colors.white : AppColors.textDark,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: dipilih
                                ? AppColors.primaryGreen
                                : AppColors.borderLight,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Menampilkan ${_filtered.length} pilihan transportasi',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _filtered.isEmpty
                    ? Center(
                        child: Text(
                          'Transportasi tidak ditemukan.',
                          style: GoogleFonts.plusJakartaSans(
                              color: AppColors.textSecondary),
                        ),
                      )
                    : RefreshIndicator(
                        color: AppColors.primaryGreen,
                        onRefresh: _refresh,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: _filtered.length,
                          itemBuilder: (context, i) => _kartu(_filtered[i]),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _kartu(TransportModel t) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _detail(t),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(18)),
                    child: _gambar(t, 150),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_icon(t.type), size: 13, color: Colors.white),
                          const SizedBox(width: 5),
                          Text(
                            t.type,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        t.category,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _barisInfo(Icons.route_rounded, t.route),
                    _barisInfo(Icons.location_on, t.province),
                    const Divider(height: 20, color: AppColors.borderLight),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Estimasi harga',
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10, color: AppColors.textMuted),
                            ),
                            Text(
                              '${context.watch<CurrencyProvider>().convertAndFormat(t.price)} ${t.priceUnit}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryGreen,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            OutlinedButton(
                              onPressed: () => _detail(t),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                    color: AppColors.borderLight),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                              ),
                              child: Text(
                                'Detail',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textDark,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () => _pilih(t),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryGreen,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                              ),
                              child: Text(
                                'Pilih',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
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
      ),
    );
  }
}