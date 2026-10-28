import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';

import '../../core/database/db_helper.dart';
import '../../core/models/trip_model.dart';
import '../../core/services/currency_provider.dart';
import '../../core/services/currency_service.dart';
import '../../core/services/localization_provider.dart';
import '../../core/theme/app_colors.dart';

const _plannerAnchorApi = String.fromEnvironment('PLANNER_ANCHOR_API');

class BudgetPlannerScreen extends StatefulWidget {
  const BudgetPlannerScreen({super.key});

  @override
  State<BudgetPlannerScreen> createState() => _BudgetPlannerScreenState();
}

class _BudgetPlannerScreenState extends State<BudgetPlannerScreen> {
  String _tr(String indonesian, String english) => context
      .read<LocalizationProvider>()
      .strings
      .localized(indonesian, english);

  String _categoryLabel(String category) => switch (category) {
    'Transportasi sewa harian' => _tr('Sewa harian', 'Daily rental'),
    'Transportasi' => _tr('Transportasi', 'Transportation'),
    'Wisata' => _tr('Wisata', 'Attraction'),
    _ => category,
  };

  double _selectedBudget = 0;
  String? _inputCurrency;
  double _spent = 0;
  bool _isLoading = true;
  bool _isSaving = false;
  TripModel? _trip;
  List<Map<String, dynamic>> _tripItems = [];
  final TextEditingController _customController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBudget();
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  Future<void> _loadBudget() async {
    try {
      final trip = await DBHelper.getActiveTrip();
      final spent = await DBHelper.getTotalExpenses();
      final items = await DBHelper.getActiveTripItems();
      if (!mounted) return;
      setState(() {
        _trip = trip;
        _tripItems = items;
        if (trip != null) {
          _selectedBudget = trip.targetBudget;
          final currencyProvider = context.read<CurrencyProvider>();
          final inputCurrency = _effectiveInputCurrency(currencyProvider);
          _customController.text = _formatInputAmount(
            currencyProvider.convertBetween(
              amount: trip.targetBudget,
              sourceCurrency: 'IDR',
              targetCurrency: inputCurrency,
            ),
            inputCurrency,
          );
        } else {
          _selectedBudget = 0;
          _customController.clear();
        }
        _spent = spent;
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('[BudgetPlannerScreen] Could not load budget data: $error');
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'Gagal memuat budget dan pengeluaran.',
              'Unable to load budget and expenses.',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _saveBudget(CurrencyProvider currencyProvider) async {
    if (_selectedBudget <= 0 || !(_selectedBudget.isFinite)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'Masukkan budget yang valid terlebih dahulu.',
              'Enter a valid budget first.',
            ),
          ),
        ),
      );
      return;
    }
    if (_selectedBudget < _spent) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'Budget tidak boleh lebih kecil dari total pengeluaran trip.',
              'The budget cannot be less than the trip expenses.',
            ),
          ),
        ),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      await DBHelper.updateActiveTripBudget(
        targetBudget: _selectedBudget,
        transportAllocation: 0,
        hotelAllocation: 0,
        culinaryAllocation: 0,
        activityAllocation: 0,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'Budget ${currencyProvider.convertAndFormat(_selectedBudget)} berhasil disimpan.',
              'Budget ${currencyProvider.convertAndFormat(_selectedBudget)} saved.',
            ),
          ),
        ),
      );
      Navigator.pop(context);
    } catch (error) {
      debugPrint('[BudgetPlannerScreen] Could not save budget: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'Gagal menyimpan budget. Silakan coba lagi.',
              'Unable to save budget. Please try again.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _updateBudget(double value, CurrencyProvider currencyProvider) {
    setState(() {
      _selectedBudget = currencyProvider.convertBetween(
        amount: value,
        sourceCurrency: _effectiveInputCurrency(currencyProvider),
        targetCurrency: 'IDR',
      );
    });
  }

  String _effectiveInputCurrency(CurrencyProvider currencyProvider) =>
      _inputCurrency ?? currencyProvider.selectedCurrency;

  String _formatInputAmount(double amount, String currency) =>
      switch (currency) {
        'USD' || 'EUR' => amount.toStringAsFixed(2),
        _ => amount.round().toString(),
      };

  String? _budgetComparison(CurrencyProvider currencyProvider) {
    if (_selectedBudget <= 0 || !_selectedBudget.isFinite) return null;

    final inputCurrency = _effectiveInputCurrency(currencyProvider);
    final preferredCurrency = currencyProvider.selectedCurrency;
    final comparisonCurrency = inputCurrency == preferredCurrency
        ? (inputCurrency == 'IDR' ? null : 'IDR')
        : preferredCurrency;
    if (comparisonCurrency == null) return null;

    final converted = currencyProvider.convertBetween(
      amount: _selectedBudget,
      sourceCurrency: 'IDR',
      targetCurrency: comparisonCurrency,
    );
    final formatted = CurrencyService.formatAmount(
      converted,
      comparisonCurrency,
    );
    return '${_tr("Perkiraan setara", "Approx. equivalent")}: $formatted';
  }

  void _changeInputCurrency(String currency, CurrencyProvider provider) {
    final currentAmount = _customController.text.trim().isEmpty
        ? null
        : double.tryParse(_customController.text.trim());
    final amountIDR = currentAmount == null
        ? _selectedBudget
        : provider.convertBetween(
            amount: currentAmount,
            sourceCurrency: _effectiveInputCurrency(provider),
            targetCurrency: 'IDR',
          );
    setState(() {
      _inputCurrency = currency;
      _selectedBudget = amountIDR;
      _customController.text = _formatInputAmount(
        provider.convertBetween(
          amount: amountIDR,
          sourceCurrency: 'IDR',
          targetCurrency: currency,
        ),
        currency,
      );
    });
  }

  Future<String?> _anchorPlannerHash(String hash) async {
    if (_plannerAnchorApi.trim().isEmpty) return null;

    final endpoint = Uri.tryParse(_plannerAnchorApi);
    if (endpoint == null || !endpoint.hasScheme || endpoint.scheme != 'https') {
      throw const FormatException('PLANNER_ANCHOR_API must be an HTTPS URL.');
    }

    final response = await http.post(
      endpoint,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'network': 'ethereum-sepolia',
        'chainId': 11155111,
        'contentHash': hash,
        'idempotencyKey': hash,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Backend Sepolia returned HTTP ${response.statusCode}.');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> ||
        decoded['chainId'] != 11155111 ||
        decoded['contentHash'] != hash ||
        decoded['confirmed'] != true ||
        decoded['transactionHash'] is! String ||
        !RegExp(r'^0x[0-9a-fA-F]{64}$')
            .hasMatch(decoded['transactionHash'] as String)) {
      throw const FormatException(
        'Backend response must confirm the matching hash on Sepolia.',
      );
    }
    return decoded['transactionHash'] as String;
  }

  Future<void> _exportPlannerPdf(CurrencyProvider currencyProvider) async {
    setState(() => _isSaving = true);
    try {
      final trip = await DBHelper.getActiveTrip();
      if (!mounted) return;
      if (trip == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _tr(
                'Buat budget trip sebelum menyimpan planner.',
                'Create a trip budget before saving the planner.',
              ),
            ),
          ),
        );
        return;
      }
      if (_selectedBudget != trip.targetBudget) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _tr(
                'Simpan perubahan budget sebelum mengekspor planner.',
                'Save your budget changes before exporting the planner.',
              ),
            ),
          ),
        );
        return;
      }

      final spent = await DBHelper.getTotalExpenses();
      final items = await DBHelper.getActiveTripItems();
      if (!mounted) return;
      setState(() {
        _trip = trip;
        _spent = spent;
        _tripItems = items;
      });
      final plannerSnapshot = <String, Object?>{
        'schemaVersion': 1,
        'network': 'ethereum-sepolia',
        'tripId': trip.id,
        'destination': trip.destination,
        'startDate': trip.dates,
        'durationDays': trip.durationDays,
        'travelerCount': trip.travelerCount,
        'budgetIdr': trip.targetBudget,
        'spentIdr': spent,
        'items': items
            .map(
              (item) => <String, Object?>{
                'title': item['title'],
                'category': item['category'],
                'location': item['location'],
                'unitPriceIdr': item['unitPrice'],
                'quantity': item['quantity'],
                'totalCostIdr': item['totalCost'],
                'plannedDate': item['plannedDate'],
              },
            )
            .toList(),
      };
      final hash = sha256
          .convert(utf8.encode(jsonEncode(plannerSnapshot)))
          .toString();
      final transactionHash = await _anchorPlannerHash(hash);
      final document = pw.Document();
      document.addPage(
        pw.MultiPage(
          build: (context) => [
            pw.Text(
              'LokaLuxe Trip Planner',
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 18),
            pw.Text(
              '${_tr("Tujuan", "Destination")}: ${trip.destination.isEmpty ? "-" : trip.destination}',
            ),
            pw.Text(
              '${_tr("Tanggal mulai", "Start date")}: ${trip.dates.isEmpty ? "-" : trip.dates}',
            ),
            pw.Text(
              '${_tr("Durasi", "Duration")}: ${trip.durationDays ?? "-"} ${_tr("hari", "days")}',
            ),
            pw.Text(
              '${_tr("Jumlah orang", "Travelers")}: ${trip.travelerCount ?? "-"}',
            ),
            pw.SizedBox(height: 12),
            pw.Text(
              '${_tr("Budget", "Budget")}: ${currencyProvider.convertAndFormat(trip.targetBudget)}',
            ),
            pw.Text(
              '${_tr("Terpakai", "Spent")}: ${currencyProvider.convertAndFormat(spent)}',
            ),
            pw.Text(
              '${_tr("Sisa", "Remaining")}: ${currencyProvider.convertAndFormat(trip.targetBudget - spent)}',
            ),
            pw.SizedBox(height: 18),
            pw.Text(
              _tr('Rencana perjalanan', 'Trip itinerary'),
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            if (items.isEmpty)
              pw.Text(
                _tr('Belum ada pilihan itinerary.', 'No itinerary items yet.'),
              ),
            ...items.map(
              (item) => pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 8),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.grey300),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '${item['title']} (${_categoryLabel(item['category'] as String)})',
                    ),
                    pw.Text(
                      '${item['plannedDate']} · ${item['location']} · '
                      '${currencyProvider.convertAndFormat((item['totalCost'] as num).toDouble())}',
                    ),
                  ],
                ),
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              _tr('Integritas planner', 'Planner integrity'),
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text('SHA-256: $hash'),
            pw.Text(
              transactionHash == null
                  ? _tr(
                      'Status Sepolia: belum dicatat on-chain. Backend anchor belum dikonfigurasi.',
                      'Sepolia status: not recorded on-chain. The backend anchor is not configured.',
                    )
                  : 'Jaringan: Ethereum Sepolia (chain ID 11155111)',
            ),
            if (transactionHash != null)
              pw.Text('Transaction hash: $transactionHash'),
          ],
        ),
      );

      await Printing.sharePdf(
        bytes: await document.save(),
        filename: 'lokaluxe-trip-planner-${trip.id ?? 'draft'}.pdf',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            transactionHash == null
                ? _tr(
                    'PDF tersimpan/dibagikan. Hash belum dicatat di Sepolia karena backend belum dikonfigurasi.',
                    'The PDF was saved/shared. The hash was not recorded on Sepolia because the backend is not configured.',
                  )
                : _tr(
                    'PDF planner dibuat dan hash berhasil dicatat di Sepolia.',
                    'The planner PDF was created and its hash was recorded on Sepolia.',
                  ),
          ),
        ),
      );
    } catch (error) {
      debugPrint('[BudgetPlannerScreen] Could not export planner PDF: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_tr("Gagal membuat PDF planner", "Could not create the planner PDF")}: $error',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyProvider = context.watch<CurrencyProvider>();
    final strings = context.watch<LocalizationProvider>().strings;
    return Scaffold(
      backgroundColor: AppColors.warmCream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text(
              'LOCALLUXE',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                letterSpacing: 2,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              strings.budgetPlanner,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  strings.budgetLimit,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Kartu Utama Total Budget
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.estimatedSpend,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _selectedBudget > 0
                        ? currencyProvider.convertAndFormat(_selectedBudget)
                        : _tr('Belum ditentukan', 'Not set'),
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _customController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (value) {
                final amount = double.tryParse(value.trim());
                if (amount != null && amount.isFinite && amount > 0) {
                  _updateBudget(amount, currencyProvider);
                } else {
                  setState(() => _selectedBudget = 0);
                }
              },
              decoration: InputDecoration(
                labelText: _tr('Masukkan budget trip', 'Enter trip budget'),
                prefixText:
                    '${CurrencyService.currencySymbols[_effectiveInputCurrency(currencyProvider)] ?? ''} ',
                suffixIcon: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _effectiveInputCurrency(currencyProvider),
                      items: CurrencyService.currencySymbols.keys
                          .map(
                            (currency) => DropdownMenuItem(
                              value: currency,
                              child: Text(currency),
                            ),
                          )
                          .toList(),
                      onChanged: _isSaving
                          ? null
                          : (currency) {
                              if (currency != null) {
                                _changeInputCurrency(
                                  currency,
                                  currencyProvider,
                                );
                              }
                            },
                    ),
                  ),
                ),
                filled: true,
                fillColor: AppColors.pureWhite,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            if (_budgetComparison(currencyProvider) case final comparison?)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                child: Text(
                  comparison,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
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
                    _tr('SISA BUDGET', 'BUDGET REMAINING'),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isLoading
                        ? _tr('Memuat...', 'Loading...')
                        : currencyProvider.convertAndFormat(
                            (_selectedBudget - _spent).clamp(
                              0,
                              double.infinity,
                            ),
                          ),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_tr("Terpakai", "Spent")}: ${currencyProvider.convertAndFormat(_spent)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (_tripItems.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                _tr('DETAIL PENGELUARAN TRIP', 'TRIP EXPENSE DETAILS'),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              ..._tripItems.map(
                (item) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.pureWhite,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['title'].toString(),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                              ),
                            ),
                            Text(
                              item['category'] == 'Hotel'
                                  ? _tr(
                                      'Hotel · ${item['quantity']} kamar · maks. 2 orang/kamar',
                                      'Hotel · ${item['quantity']} rooms · max. 2 people/room',
                                    )
                                  : '${_categoryLabel(item['category'] as String)} · ${_tr("Jumlah", "Qty")} ${item['quantity']}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        currencyProvider.convertAndFormat(
                          (item['totalCost'] as num).toDouble(),
                        ),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 28),

            // Tombol Simpan
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  elevation: 0,
                ),
                onPressed: _isSaving
                    ? null
                    : () => _saveBudget(currencyProvider),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isSaving
                          ? _tr('Menyimpan...', 'Saving...')
                          : _tr(
                              'Simpan & mulai perjalanan',
                              'Save & start trip',
                            ),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _isLoading || _isSaving || _trip == null
                    ? null
                    : () => _exportPlannerPdf(currencyProvider),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: Text(
                  _tr('Simpan planner sebagai PDF', 'Save planner as PDF'),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textDark,
                  side: BorderSide(
                    color: AppColors.accentGold.withValues(alpha: 0.7),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _plannerAnchorApi.trim().isEmpty
                  ? _tr(
                      'Hash SHA-256 dicantumkan di PDF. Pencatatan Sepolia menunggu backend.',
                      'The SHA-256 hash is included in the PDF. Sepolia recording is pending backend configuration.',
                    )
                  : _tr(
                      'Hash planner akan dikirim ke backend untuk dicatat di Sepolia.',
                      'The planner hash will be sent to the backend for recording on Sepolia.',
                    ),
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
