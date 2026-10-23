import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/database/db_helper.dart';
import '../../core/models/hotel_model.dart';
import '../../core/models/transport_model.dart';
import '../../core/models/trip_model.dart';
import '../../core/services/currency_provider.dart';
import '../../core/theme/app_colors.dart';
import '../budget/budget_planner_screen.dart';
import '../hotel/hotel_catalog_screen.dart';
import '../transportasi/transport_catalog_screen.dart';
import '../wisata/wisata_catalog_screen.dart';

class ItineraryScreen extends StatefulWidget {
  final Map<String, dynamic>? pendingWisata;

  const ItineraryScreen({super.key, this.pendingWisata});

  @override
  State<ItineraryScreen> createState() => _ItineraryScreenState();
}

class _ItineraryScreenState extends State<ItineraryScreen> {
  final TextEditingController _destinationController = TextEditingController();
  final TextEditingController _travelerController = TextEditingController();
  TripModel? _trip;
  List<Map<String, dynamic>> _items = [];
  double _spent = 0;
  DateTime? _startDate;
  int? _durationDays;
  int _selectedDay = 0;
  bool _isLoading = true;
  bool _isSavingDetails = false;
  bool _isOpeningCatalog = false;
  bool _isSavingPendingWisata = false;
  bool _pendingWisataHandled = false;

  @override
  void initState() {
    super.initState();
    _loadTrip();
  }

  @override
  void dispose() {
    _destinationController.dispose();
    _travelerController.dispose();
    super.dispose();
  }

  Future<void> _loadTrip() async {
    try {
      final trip = await DBHelper.getActiveTrip();
      final items = await DBHelper.getActiveTripItems();
      final spent = await DBHelper.getTotalExpenses();
      if (!mounted) return;
      setState(() {
        _trip = trip;
        _items = items;
        _spent = spent;
        _destinationController.text = trip?.destination ?? '';
        _startDate = DateTime.tryParse(trip?.dates ?? '');
        _durationDays = trip?.durationDays;
        _travelerController.text = trip?.travelerCount?.toString() ?? '';
        _selectedDay = _selectedDay
            .clamp(0, ((trip?.durationDays ?? 1) - 1).clamp(0, 365))
            .toInt();
        _isLoading = false;
      });
      _savePendingWisataIfReady();
    } catch (error) {
      debugPrint('[ItineraryScreen] Could not load trip: $error');
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage('Gagal memuat itinerary trip.');
    }
  }

  bool get _hasSavedTripDetails {
    final trip = _trip;
    return trip != null &&
        trip.destination.trim().isNotEmpty &&
        DateTime.tryParse(trip.dates) != null &&
        (trip.durationDays ?? 0) > 0 &&
        (trip.travelerCount ?? 0) > 0;
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError
              ? AppColors.errorRed
              : AppColors.primaryGreen,
        ),
      );
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
    );
    if (selected != null && mounted) setState(() => _startDate = selected);
  }

  Future<void> _saveTripDetails() async {
    final destination = _destinationController.text.trim();
    final travelers = int.tryParse(_travelerController.text.trim());
    final startDate = _startDate;
    final durationDays = _durationDays;
    if (destination.isEmpty ||
        startDate == null ||
        durationDays == null ||
        travelers == null ||
        travelers < 1) {
      _showMessage(
        'Isi tujuan, tanggal, durasi, dan jumlah orang terlebih dahulu.',
        isError: true,
      );
      return;
    }

    setState(() => _isSavingDetails = true);
    try {
      await DBHelper.updateActiveTripDetails(
        destination: destination,
        startDate: startDate,
        durationDays: durationDays,
        travelerCount: travelers,
      );
      await _loadTrip();
      _showMessage('Detail perjalanan berhasil disimpan.');
    } catch (error) {
      debugPrint('[ItineraryScreen] Could not save trip details: $error');
      _showMessage('Gagal menyimpan detail perjalanan.', isError: true);
    } finally {
      if (mounted) setState(() => _isSavingDetails = false);
    }
  }

  Future<void> _savePendingWisataIfReady() async {
    final wisata = widget.pendingWisata;
    final trip = _trip;
    final startDate = _startDate;
    if (wisata == null ||
        _pendingWisataHandled ||
        _isSavingPendingWisata ||
        trip == null ||
        !_hasSavedTripDetails ||
        startDate == null) {
      return;
    }

    _isSavingPendingWisata = true;
    final plannedDate = DateTime(
      startDate.year,
      startDate.month,
      startDate.day + _selectedDay,
    );
    try {
      final title = (wisata['nama_wisata'] ?? '').toString().trim();
      if (title.isEmpty) {
        _pendingWisataHandled = true;
        _showMessage(
          'Pilihan wisata tidak memiliki nama yang valid.',
          isError: true,
        );
        return;
      }

      final location = [
        wisata['kota_kabupaten'],
        wisata['provinsi'],
      ].where((value) => value != null && value.toString().trim().isNotEmpty)
          .join(', ');
      final unitPrice =
          (wisata['selectionPrice'] as num?)?.toDouble() ??
          (wisata['harga_tiket'] as num?)?.toDouble() ??
          0;
      final result = await DBHelper.insertActiveTripItem(
        title: title,
        category: 'Wisata',
        location: location,
        unitPrice: unitPrice,
        quantity: trip.travelerCount ?? 1,
        plannedDate: plannedDate,
      );
      if (!mounted) return;

      _pendingWisataHandled = true;
      switch (result) {
        case TripItemSaveResult.saved:
          await _loadTrip();
          _showMessage('$title ditambahkan ke itinerary dan budget.');
          break;
        case TripItemSaveResult.budgetExceeded:
          _showMessage(
            'Budget trip tidak cukup untuk menambahkan $title.',
            isError: true,
          );
          break;
        case TripItemSaveResult.duplicate:
          _showMessage('$title sudah ada di itinerary hari ini.');
          break;
        case TripItemSaveResult.noActiveTrip:
          _showMessage(
            'Buat budget trip terlebih dahulu sebelum memilih wisata.',
            isError: true,
          );
          break;
      }
    } catch (error, stackTrace) {
      debugPrint('[ItineraryScreen] Could not save selected attraction: $error');
      debugPrintStack(stackTrace: stackTrace);
      _pendingWisataHandled = true;
      _showMessage('Gagal menyimpan wisata ke itinerary.', isError: true);
    } finally {
      _isSavingPendingWisata = false;
    }
  }

  Future<void> _openCatalogChooser() async {
    if (!_hasSavedTripDetails) {
      _showMessage(
        'Simpan tujuan dan jadwal perjalanan terlebih dahulu.',
        isError: true,
      );
      return;
    }
    if (_isOpeningCatalog) return;
    setState(() => _isOpeningCatalog = true);
    try {
      final category = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: AppColors.pureWhite,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Tambahkan ke itinerary',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 12),
                _catalogOption(
                  context,
                  'Hotel',
                  'Di ${_trip!.destination} · kapasitas 2 orang per kamar',
                  Icons.hotel_rounded,
                  'hotel',
                ),
                _catalogOption(
                  context,
                  'Transportasi',
                  'Pilih kendaraan atau perjalanan',
                  Icons.directions_car_rounded,
                  'transport',
                ),
                _catalogOption(
                  context,
                  'Wisata',
                  'Pilih tempat wisata dan aktivitas',
                  Icons.attractions_rounded,
                  'wisata',
                ),
              ],
            ),
          ),
        ),
      );
      if (category != null && mounted) await _pickFromCatalog(category);
    } finally {
      if (mounted) setState(() => _isOpeningCatalog = false);
    }
  }

  Widget _catalogOption(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    String value,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: AppColors.primaryGreenSubtle,
        child: Icon(icon, color: AppColors.primaryGreen),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => Navigator.pop(context, value),
    );
  }

  Future<void> _pickFromCatalog(String category) async {
    var title = '';
    var itemCategory = '';
    var location = '';
    var unitPrice = 0.0;
    var quantity = 1;
    final trip = _trip!;

    if (category == 'hotel') {
      final hotel = await Navigator.of(context).push<HotelModel>(
        MaterialPageRoute(
          builder: (_) => HotelCatalogScreen(
            selectMode: true,
            initialDestination: trip.destination,
            onSelectHotel: (_) {},
          ),
        ),
      );
      if (hotel == null || !mounted) return;
      final nights = ((trip.durationDays ?? 1) - 1).clamp(0, 365).toInt();
      if (nights < 1) {
        _showMessage(
          'Untuk memilih hotel, durasi trip harus minimal 2 hari.',
          isError: true,
        );
        return;
      }
      title = hotel.name;
      itemCategory = 'Hotel';
      location = hotel.locationDescription;
      quantity = (trip.travelerCount! + 1) ~/ 2;
      unitPrice = hotel.pricePerNight * nights;
    } else if (category == 'transport') {
      final transport = await Navigator.of(context).push<TransportModel>(
        MaterialPageRoute(
          builder: (_) => TransportCatalogScreen(
            initialDestination: trip.destination,
            onSelectTransport: (_) {},
          ),
        ),
      );
      if (transport == null || !mounted) return;
      title = transport.name;
      final isDailyRental =
          transport.type == 'Sewa Mobil' || transport.type == 'Sewa Motor';
      itemCategory = isDailyRental
          ? 'Transportasi sewa harian'
          : 'Transportasi';
      location = transport.route;
      unitPrice = transport.price;
      quantity = isDailyRental ? trip.durationDays! : trip.travelerCount!;
    } else {
      final wisata = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(
          builder: (_) => WisataCatalogScreen(
            initialDestination: trip.destination,
            onSelectWisata: (_) {},
          ),
        ),
      );
      if (wisata == null || !mounted) return;
      title = (wisata['nama_wisata'] ?? '').toString();
      itemCategory = 'Wisata';
      location =
          (wisata['alamat'] ??
                  wisata['kota_kabupaten'] ??
                  wisata['provinsi'] ??
                  '')
              .toString();
      unitPrice =
          (wisata['selectionPrice'] as num?)?.toDouble() ??
          (wisata['harga_tiket'] as num?)?.toDouble() ??
          0;
      quantity = trip.travelerCount!;
    }

    final plannedDate = DateTime(
      _startDate!.year,
      _startDate!.month,
      _startDate!.day + _selectedDay,
    );
    try {
      final result = await DBHelper.insertActiveTripItem(
        title: title,
        category: itemCategory,
        location: location,
        unitPrice: unitPrice,
        quantity: quantity,
        plannedDate: plannedDate,
      );
      if (!mounted) return;
      switch (result) {
        case TripItemSaveResult.saved:
          await _loadTrip();
          _showMessage('$title ditambahkan ke itinerary.');
          break;
        case TripItemSaveResult.budgetExceeded:
          _showMessage('Pilihan ini melebihi sisa budget trip.', isError: true);
          break;
        case TripItemSaveResult.duplicate:
          _showMessage(
            'Pilihan ini sudah ada pada hari yang dipilih.',
            isError: true,
          );
          break;
        case TripItemSaveResult.noActiveTrip:
          _showMessage('Buat budget trip terlebih dahulu.', isError: true);
          break;
      }
    } catch (error) {
      debugPrint('[ItineraryScreen] Could not add itinerary item: $error');
      _showMessage('Gagal menambahkan pilihan ke itinerary.', isError: true);
    }
  }

  Future<void> _openItemInMaps(Map<String, dynamic> item) async {
    final location = item['location'].toString().trim();
    final query = location.isEmpty ? item['title'].toString() : location;
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': query,
    });
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) {
        _showMessage('Tidak dapat membuka aplikasi peta.', isError: true);
      }
    } catch (error) {
      debugPrint('[ItineraryScreen] Could not open map: $error');
      _showMessage('Tidak dapat membuka aplikasi peta.', isError: true);
    }
  }

  Future<void> _deleteItem(Map<String, dynamic> item) async {
    final itemId = (item['id'] as num?)?.toInt();
    if (itemId == null) {
      _showMessage(
        'Pilihan itinerary tidak memiliki ID yang valid.',
        isError: true,
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus pilihan?'),
        content: Text('Hapus ${item['title']} dari itinerary?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await DBHelper.deleteActiveTripItem(itemId);
      await _loadTrip();
      _showMessage('Pilihan dihapus dan sisa budget diperbarui.');
    } catch (error) {
      debugPrint('[ItineraryScreen] Could not delete itinerary item: $error');
      _showMessage('Gagal menghapus pilihan itinerary.', isError: true);
    }
  }

  String _dateLabel(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<CurrencyProvider>();
    final trip = _trip;
    final selectedDate = _startDate == null
        ? null
        : DateTime(
            _startDate!.year,
            _startDate!.month,
            _startDate!.day + _selectedDay,
          );
    final dayItems = selectedDate == null
        ? <Map<String, dynamic>>[]
        : _items
              .where(
                (item) => item['plannedDate'] == selectedDate.toIso8601String(),
              )
              .toList();

    return Scaffold(
      backgroundColor: AppColors.warmCream,
      appBar: AppBar(
        backgroundColor: AppColors.warmCream,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.chevron_left_rounded,
            color: AppColors.textDark,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: Text(
          'Trip itinerary',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : trip == null
          ? _buildNoBudgetState()
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    children: [
                      _buildTripDetailsForm(),
                      if (widget.pendingWisata != null &&
                          !_pendingWisataHandled &&
                          !_hasSavedTripDetails) ...[
                        const SizedBox(height: 12),
                        _buildPendingWisataNotice(),
                      ],
                      const SizedBox(height: 20),
                      _buildRemainingBudget(currency),
                      if (_hasSavedTripDetails) ...[
                        const SizedBox(height: 16),
                        _buildDaySelector(),
                        const SizedBox(height: 12),
                        if (dayItems.isEmpty)
                          _buildEmptyDay()
                        else
                          ...dayItems.map(
                            (item) => _buildItemCard(item, currency),
                          ),
                      ],
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _isOpeningCatalog
                            ? null
                            : _openCatalogChooser,
                        icon: const Icon(Icons.add_rounded),
                        label: Text(
                          _isOpeningCatalog
                              ? 'Membuka katalog...'
                              : 'Cari hotel, transportasi, atau wisata',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: AppColors.pureWhite,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildNoBudgetState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.account_balance_wallet_outlined,
              size: 52,
              color: AppColors.primaryGreen,
            ),
            const SizedBox(height: 14),
            Text(
              'Tentukan budget trip terlebih dahulu',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Setelah budget disimpan, kamu bisa mengisi tujuan dan menyusun itinerary.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const BudgetPlannerScreen(),
                  ),
                );
                await _loadTrip();
              },
              child: const Text('Buat budget trip'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingWisataNotice() {
    final title = (widget.pendingWisata?['nama_wisata'] ?? '').toString();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accentGoldLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.4)),
      ),
      child: Text(
        '$title sudah dipilih. Lengkapi dan simpan detail trip untuk '
        'menambahkannya ke itinerary dan budget.',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          color: AppColors.textDark,
        ),
      ),
    );
  }

  Widget _buildRemainingBudget(CurrencyProvider currency) {
    final remaining = (_trip?.targetBudget ?? 0) - _spent;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accentGoldLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SISA BUDGET TRIP',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            currency.convertAndFormat(remaining),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 23,
              fontWeight: FontWeight.w800,
              color: remaining < 0 ? AppColors.errorRed : AppColors.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Terpakai ${currency.convertAndFormat(_spent)} dari ${currency.convertAndFormat(_trip?.targetBudget ?? 0)}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripDetailsForm() {
    final dateText = _startDate == null
        ? 'Pilih tanggal mulai'
        : _dateLabel(_startDate!);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Detail perjalanan',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _destinationController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Mau ke mana?',
              prefixIcon: Icon(Icons.location_on_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickStartDate,
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text(dateText),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _durationDays,
            decoration: const InputDecoration(
              labelText: 'Durasi perjalanan',
              border: OutlineInputBorder(),
            ),
            items: List.generate(
              30,
              (index) => DropdownMenuItem(
                value: index + 1,
                child: Text('${index + 1} hari'),
              ),
            ),
            onChanged: (value) => setState(() => _durationDays = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _travelerController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Jumlah orang',
              prefixIcon: Icon(Icons.people_outline_rounded),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textDark,
                backgroundColor: AppColors.accentGoldLight,
                side: BorderSide(
                  color: AppColors.accentGold.withValues(alpha: 0.6),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _isSavingDetails ? null : _saveTripDetails,
              child: _isSavingDetails
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      _hasSavedTripDetails
                          ? 'Simpan perubahan trip'
                          : 'Simpan detail trip',
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaySelector() {
    final duration = _trip?.durationDays ?? 0;
    if (duration < 1) return const SizedBox.shrink();
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: duration,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected = index == _selectedDay;
          return ChoiceChip(
            label: Text('Hari ${index + 1}'),
            selected: selected,
            onSelected: (_) => setState(() => _selectedDay = index),
            selectedColor: AppColors.primaryGreen,
            labelStyle: TextStyle(
              color: selected ? Colors.white : AppColors.textDark,
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyDay() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          const Icon(
            Icons.route_outlined,
            size: 42,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 8),
          Text(
            'Belum ada pilihan untuk hari ini',
            style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item, CurrencyProvider currency) {
    final quantity = (item['quantity'] as num).toInt();
    final unitPrice = (item['unitPrice'] as num).toDouble();
    final total = (item['totalCost'] as num).toDouble();
    final category = item['category'] as String;
    final countLabel = switch (category) {
      'Hotel' => '$quantity kamar (maks. 2 orang/kamar)',
      'Transportasi sewa harian' => '$quantity hari',
      'Transportasi' => '$quantity orang',
      _ => '$quantity orang',
    };
    final icon = switch (category) {
      'Hotel' => Icons.hotel_rounded,
      'Transportasi' ||
      'Transportasi sewa harian' => Icons.directions_car_rounded,
      _ => Icons.attractions_rounded,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primaryGreenSubtle,
            child: Icon(icon, color: AppColors.primaryGreen, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['title'] as String,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                if ((item['location'] as String).isNotEmpty)
                  Text(
                    item['location'] as String,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                Text(
                  '$category · $countLabel · ${currency.convertAndFormat(unitPrice)} per unit',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            currency.convertAndFormat(total),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryGreen,
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Aksi itinerary',
            onSelected: (action) {
              if (action == 'map') {
                _openItemInMaps(item);
              } else if (action == 'delete') {
                _deleteItem(item);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'map',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.map_outlined),
                  title: Text('Buka di Maps'),
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.delete_outline,
                    color: AppColors.errorRed,
                  ),
                  title: Text('Hapus dari itinerary'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
