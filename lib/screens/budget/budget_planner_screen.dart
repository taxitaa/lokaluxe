import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/database/db_helper.dart';
import '../../core/models/expense_model.dart';
import '../../core/services/currency_provider.dart';
import '../../core/theme/app_colors.dart';

class BudgetPlannerScreen extends StatefulWidget {
  const BudgetPlannerScreen({super.key});

  @override
  State<BudgetPlannerScreen> createState() => _BudgetPlannerScreenState();
}

class _BudgetPlannerScreenState extends State<BudgetPlannerScreen> {
  double _selectedBudget = 5000000;
  double _spent = 0;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isCustom = false;
  final TextEditingController _customController = TextEditingController(text: '5000000');
  final TextEditingController _expenseTitleController = TextEditingController();
  final TextEditingController _expenseAmountController = TextEditingController();

  // Persentase alokasi AI
  final double _transportPercent = 35;
  final double _hotelPercent = 30;
  final double _kulinerPercent = 20;
  final double _wisataPercent = 15;

  @override
  void initState() {
    super.initState();
    _loadBudget();
  }

  @override
  void dispose() {
    _customController.dispose();
    _expenseTitleController.dispose();
    _expenseAmountController.dispose();
    super.dispose();
  }

  Future<void> _loadBudget() async {
    try {
      final trip = await DBHelper.getActiveTrip();
      final spent = await DBHelper.getTotalExpenses();
      if (!mounted) return;
      setState(() {
        if (trip != null) {
          _selectedBudget = trip.targetBudget;
          _customController.text = trip.targetBudget.toStringAsFixed(0);
          _isCustom = ![2500000.0, 5000000.0, 10000000.0]
              .contains(trip.targetBudget);
        }
        _spent = spent;
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('[BudgetPlannerScreen] Could not load budget data: $error');
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to load budget and expenses.')),
      );
    }
  }

  Future<void> _saveBudget(CurrencyProvider currencyProvider) async {
    setState(() => _isSaving = true);
    try {
      await DBHelper.updateActiveTripBudget(
        targetBudget: _selectedBudget,
        transportAllocation: _selectedBudget * (_transportPercent / 100),
        hotelAllocation: _selectedBudget * (_hotelPercent / 100),
        culinaryAllocation: _selectedBudget * (_kulinerPercent / 100),
        activityAllocation: _selectedBudget * (_wisataPercent / 100),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Budget ${currencyProvider.convertAndFormat(_selectedBudget)} saved.',
          ),
        ),
      );
      Navigator.pop(context);
    } catch (error) {
      debugPrint('[BudgetPlannerScreen] Could not save budget: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to save budget. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _recordExpense(CurrencyProvider currencyProvider) async {
    _expenseTitleController.clear();
    _expenseAmountController.clear();
    final expense = await showDialog<ExpenseModel>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Record an expense'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _expenseTitleController,
              decoration: const InputDecoration(labelText: 'Description'),
              textCapitalization: TextCapitalization.sentences,
            ),
            TextField(
              controller: _expenseAmountController,
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: '${currencyProvider.currencySymbol} ',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final title = _expenseTitleController.text.trim();
              final amount =
                  double.tryParse(_expenseAmountController.text.trim());
              if (title.isEmpty ||
                  amount == null ||
                  !amount.isFinite ||
                  amount <= 0) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('Enter a description and a valid amount.'),
                  ),
                );
                return;
              }
              final rate = currencyProvider.convertRaw(1);
              if (currencyProvider.selectedCurrency != 'IDR' &&
                  (rate <= 0 || !rate.isFinite)) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Exchange rate is unavailable. Try again later.',
                    ),
                  ),
                );
                return;
              }
              final amountInIdr = currencyProvider.selectedCurrency == 'IDR'
                  ? amount
                  : amount / rate;
              Navigator.pop(
                dialogContext,
                ExpenseModel(
                  title: title,
                  category: 'Other',
                  amount: amountInIdr,
                  date: DateTime.now().toIso8601String(),
                ),
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (expense == null) return;

    try {
      await DBHelper.insertExpense(expense);
      final spent = await DBHelper.getTotalExpenses();
      if (mounted) setState(() => _spent = spent);
    } catch (error) {
      debugPrint('[BudgetPlannerScreen] Could not record expense: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to record expense.')),
      );
    }
  }

  void _updateBudget(double value, {bool isCustom = false}) {
    setState(() {
      _selectedBudget = value;
      _isCustom = isCustom;
      if (!isCustom) {
        _customController.text = value.toStringAsFixed(0);
      }
    });
  }

  void _showCustomDialog(CurrencyProvider currencyProvider) {
    _customController.text =
        currencyProvider.convertRaw(_selectedBudget).toStringAsFixed(0);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Enter a custom budget', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
          content: TextField(
            controller: _customController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              prefixText: '${currencyProvider.currencySymbol} ',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen),
              onPressed: () {
                setState(() {
                  final amount =
                      double.tryParse(_customController.text) ?? 5000000;
                  final rate = currencyProvider.convertRaw(1);
                  _selectedBudget =
                      currencyProvider.selectedCurrency == 'IDR' || rate <= 0
                          ? amount
                          : amount / rate;
                  _isCustom = true;
                });
                Navigator.pop(context);
              },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyProvider = context.watch<CurrencyProvider>();
    double transportAmount = _selectedBudget * (_transportPercent / 100);
    double hotelAmount = _selectedBudget * (_hotelPercent / 100);
    double kulinerAmount = _selectedBudget * (_kulinerPercent / 100);
    double wisataAmount = _selectedBudget * (_wisataPercent / 100);

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
            Text('LOCALLUXE', style: GoogleFonts.plusJakartaSans(fontSize: 10, letterSpacing: 2, color: AppColors.textMuted, fontWeight: FontWeight.w700)),
            Text('Trip Budget Planner', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark)),
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
                Text('BUDGET LIMIT', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
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
                  BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 6)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Estimated maximum spend', style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 6),
                  Text(
                    currencyProvider.convertAndFormat(_selectedBudget),
                    style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '💡 Smart allocation is enabled for this trip',
                      style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ],
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
                    'BUDGET REMAINING',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isLoading
                        ? 'Loading...'
                        : currencyProvider
                            .convertAndFormat(_selectedBudget - _spent),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Spent: ${currencyProvider.convertAndFormat(_spent)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : () => _recordExpense(currencyProvider),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Record an expense'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Pilihan Chip Budget Cepat
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildBudgetChip(currencyProvider.convertAndFormat(2500000), 2500000),
                _buildBudgetChip(currencyProvider.convertAndFormat(5000000), 5000000),
                _buildBudgetChip(currencyProvider.convertAndFormat(10000000), 10000000),
                GestureDetector(
                  onTap: () => _showCustomDialog(currencyProvider),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _isCustom ? AppColors.primaryGreen : AppColors.pureWhite,
                      border: Border.all(color: _isCustom ? AppColors.primaryGreen : AppColors.borderLight),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text('Custom', style: GoogleFonts.plusJakartaSans(color: _isCustom ? Colors.white : AppColors.textDark, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            Text('SMART BUDGET ALLOCATION', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
            const SizedBox(height: 10),

            // Grid Alokasi
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.35,
              children: [
                _buildAllocationCard('Transport', '🚗', '${_transportPercent.toInt()}%', currencyProvider.convertAndFormat(transportAmount)),
                _buildAllocationCard('Accommodation', '🏨', '${_hotelPercent.toInt()}%', currencyProvider.convertAndFormat(hotelAmount)),
                _buildAllocationCard('Food & cafes', '🍽️', '${_kulinerPercent.toInt()}%', currencyProvider.convertAndFormat(kulinerAmount)),
                _buildAllocationCard('Activities', '🎫', '${_wisataPercent.toInt()}%', currencyProvider.convertAndFormat(wisataAmount)),
              ],
            ),
            const SizedBox(height: 28),

            // Tombol Simpan
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  elevation: 0,
                ),
                onPressed: _isSaving ? null : () => _saveBudget(currencyProvider),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isSaving ? 'Saving...' : 'Save & start trip',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetChip(String label, double value) {
    bool isSelected = _selectedBudget == value && !_isCustom;
    return GestureDetector(
      onTap: () => _updateBudget(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGreen : AppColors.pureWhite,
          border: Border.all(color: isSelected ? AppColors.primaryGreen : AppColors.borderLight),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(label, style: GoogleFonts.plusJakartaSans(color: isSelected ? Colors.white : AppColors.textDark, fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    );
  }

  Widget _buildAllocationCard(String title, String emoji, String percent, String amount) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCream,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(percent, style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
              const SizedBox(height: 2),
              Text(amount, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark)),
            ],
          ),
        ],
      ),
    );
  }
}

extension on double {
  String toStringAsRegExp() {
    return toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.');
  }
}