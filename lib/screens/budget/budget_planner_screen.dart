import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';

class BudgetPlannerScreen extends StatefulWidget {
  const BudgetPlannerScreen({super.key});

  @override
  State<BudgetPlannerScreen> createState() => _BudgetPlannerScreenState();
}

class _BudgetPlannerScreenState extends State<BudgetPlannerScreen> {
  double _selectedBudget = 5000000;
  String _selectedCurrency = 'Rp (IDR)';
  bool _isCustom = false;
  final TextEditingController _customController = TextEditingController(text: '5000000');

  // Persentase alokasi AI
  final double _transportPercent = 35;
  final double _hotelPercent = 30;
  final double _kulinerPercent = 20;
  final double _wisataPercent = 15;

  void _updateBudget(double value, {bool isCustom = false}) {
    setState(() {
      _selectedBudget = value;
      _isCustom = isCustom;
      if (!isCustom) {
        _customController.text = value.toStringAsFixed(0);
      }
    });
  }

  void _showCustomDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Masukkan Budget Custom', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
          content: TextField(
            controller: _customController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              prefixText: 'Rp ',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen),
              onPressed: () {
                setState(() {
                  _selectedBudget = double.tryParse(_customController.text) ?? 5000000;
                  _isCustom = true;
                });
                Navigator.pop(context);
              },
              child: const Text('Simpan', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
            Text('Input Budget & Trip', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark)),
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
                Text('TARGET BATAS ANGGARAN', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                ToggleButtons(
                  isSelected: [_selectedCurrency == 'Rp (IDR)', _selectedCurrency == ' (USD)'],
                  onPressed: (index) {
                    setState(() {
                      _selectedCurrency = index == 0 ? 'Rp (IDR)' : ' (USD)';
                    });
                  },
                  borderRadius: BorderRadius.circular(16),
                  color: AppColors.textDark,
                  selectedColor: Colors.white,
                  fillColor: AppColors.primaryGreen,
                  constraints: const BoxConstraints(minHeight: 32, minWidth: 65),
                  children: const [Text('Rp', style: TextStyle(fontSize: 11)), Text('\$', style: TextStyle(fontSize: 11))],
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
                  BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 6)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Maksimal Pengeluaran (Estimasi)', style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 6),
                  Text(
                    '${_selectedCurrency.contains('Rp') ? 'Rp ' : '\$ '}${_selectedBudget.toStringAsRegExp()}',
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
                      '💡 Alokasi otomatis pintar aktif untuk trip ini',
                      style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Pilihan Chip Budget Cepat
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildBudgetChip('Rp 2.5 Jt', 2500000),
                _buildBudgetChip('Rp 5 Jt', 5000000),
                _buildBudgetChip('Rp 10 Jt', 10000000),
                GestureDetector(
                  onTap: _showCustomDialog,
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

            Text('ALOKASI OTOMATIS AI', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
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
                _buildAllocationCard('Transportasi', '🚗', '${_transportPercent.toInt()}%', transportAmount),
                _buildAllocationCard('Penginapan', '🏨', '${_hotelPercent.toInt()}%', hotelAmount),
                _buildAllocationCard('Kuliner & Cafe', '🍽️', '${_kulinerPercent.toInt()}%', kulinerAmount),
                _buildAllocationCard('Aktivitas & Wisata', '🎫', '${_wisataPercent.toInt()}%', wisataAmount),
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
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Budget Rp ${_selectedBudget.toStringAsRegExp()} berhasil disimpan!')),
                  );
                  Navigator.pop(context);
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Simpan & Mulai Trip', style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)),
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

  Widget _buildAllocationCard(String title, String emoji, String percent, double amount) {
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
              Text('Rp ${amount.toStringAsRegExp()}', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark)),
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