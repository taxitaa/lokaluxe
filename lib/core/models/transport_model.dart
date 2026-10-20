class TransportModel {
  final int? id;
  final String name;
  final String type; // Pesawat, Kereta, Bus, Kapal, Sewa Mobil, Sewa Motor
  final String category; // Antar Kota / Dalam Kota
  final String operatorName;
  final String province;
  final String route;
  final double price;
  final String description;
  final String imageUrl;

  const TransportModel({
    this.id,
    required this.name,
    required this.type,
    required this.category,
    required this.operatorName,
    required this.province,
    required this.route,
    required this.price,
    required this.description,
    required this.imageUrl,
  });

  factory TransportModel.fromMap(Map<String, dynamic> map) {
    return TransportModel(
      id: map['id'] as int?,
      name: (map['name'] ?? '') as String,
      type: (map['type'] ?? '') as String,
      category: (map['category'] ?? '') as String,
      operatorName: (map['operator_name'] ?? '') as String,
      province: (map['province'] ?? '') as String,
      route: (map['route'] ?? '') as String,
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      description: (map['description'] ?? '') as String,
      imageUrl: (map['image_url'] ?? '') as String,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'type': type,
        'category': category,
        'operator_name': operatorName,
        'province': province,
        'route': route,
        'price': price,
        'description': description,
        'image_url': imageUrl,
      };

  // Contoh: 1200000 -> "Rp 1.200.000"
  String get formattedPrice {
    final str = price.round().toString();
    final buf = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write('.');
      buf.write(str[i]);
    }
    return 'Rp $buf';
  }

  // Sewa dihitung per hari, selebihnya per orang
  String get priceUnit =>
      (type == 'Sewa Mobil' || type == 'Sewa Motor') ? '/ hari' : '/ orang';
}