class HotelModel {
  final int? id;
  final String name;
  final String province;
  final String city;
  final int stars;
  final double pricePerNight;
  final double? latitude;
  final double? longitude;
  final String address;
  final String imageUrl;

  const HotelModel({
    this.id,
    required this.name,
    required this.province,
    required this.city,
    required this.stars,
    required this.pricePerNight,
    this.latitude,
    this.longitude,
    required this.address,
    required this.imageUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'province': province,
      'city': city,
      'stars': stars,
      'price_per_night': pricePerNight,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'image_url': imageUrl,
    };
  }

  factory HotelModel.fromMap(Map<String, dynamic> map) {
    return HotelModel(
      id: map['id'] as int?,
      name: (map['name'] ?? '') as String,
      province: (map['province'] ?? '') as String,
      city: (map['city'] ?? '') as String,
      stars: (map['stars'] as num?)?.toInt() ?? 0,
      pricePerNight: (map['price_per_night'] as num?)?.toDouble() ?? 0.0,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      address: (map['address'] ?? '') as String,
      imageUrl: (map['image_url'] ?? '') as String,
    );
  }

  String get formattedPrice {
    final n = pricePerNight.round();
    final str = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write('.');
      buf.write(str[i]);
    }
    return 'Rp $buf';
  }

  String get locationDescription => '$city, $province';
}
