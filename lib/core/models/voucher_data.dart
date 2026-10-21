class VoucherData {
  final String discount;
  final String title;
  final String merchant;
  final String expiry;
  final String reference;
  final bool isUsed;

  const VoucherData({
    required this.discount,
    required this.title,
    required this.merchant,
    required this.expiry,
    required this.reference,
    required this.isUsed,
  });
}

const voucherCatalog = <VoucherData>[
  VoucherData(
    discount: 'POTONGAN RP 250.000',
    title: 'Tur Candi Borobudur & Kuliner Pawon',
    merchant: 'Mitra Resmi Borobudur Sunrise',
    expiry: 'Berlaku s/d 30 Nov 2026',
    reference: '0x8A4B...99F2 (Ledger Verified)',
    isUsed: false,
  ),
  VoucherData(
    discount: 'DISKON 20% RESORT',
    title: 'Luxury Villa & Spa Seminyak Bali',
    merchant: 'The Royal Seminyak Retreat',
    expiry: 'Berlaku s/d 15 Des 2026',
    reference: '0x3E1C...41D0 (Ledger Verified)',
    isUsed: false,
  ),
  VoucherData(
    discount: 'FREE SPEEDBOAT TICKET',
    title: 'Penyeberangan Sanur - Nusa Penida',
    merchant: 'Fast Boat Nusantara Line',
    expiry: 'Sudah Digunakan',
    reference: '0x992D...88A1 (Redeemed)',
    isUsed: true,
  ),
];

List<VoucherData> get availableVouchers =>
    voucherCatalog.where((voucher) => !voucher.isUsed).toList(growable: false);
