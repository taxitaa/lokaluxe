class SupabaseVoucher {
  final int id;
  final String code;
  final String title;
  final String discount;
  final bool isUsed;

  const SupabaseVoucher({
    required this.id,
    required this.code,
    required this.title,
    required this.discount,
    required this.isUsed,
  });

  factory SupabaseVoucher.fromMap(Map<String, dynamic> map) {
    final id = map['id'];
    if (id is! num ||
        map['code'] is! String ||
        map['title'] is! String ||
        map['discount'] is! String ||
        map['is_used'] is! bool) {
      throw const FormatException('Format data voucher Supabase tidak valid.');
    }
    return SupabaseVoucher(
      id: id.toInt(),
      code: map['code'] as String,
      title: map['title'] as String,
      discount: map['discount'] as String,
      isUsed: map['is_used'] as bool,
    );
  }
}
