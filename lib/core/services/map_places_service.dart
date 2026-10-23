import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../database/db_helper.dart';
import '../models/map_place_model.dart';

class MapPlacesService {
  static final List<MapPlace> _curatedSeedPlaces = [
    // ─── RESTAURANTS (Kuliner & Makanan) ──────────────────────────────────
    MapPlace(
      id: 'resto_1',
      name: 'Plataran Menteng Heritage Resto',
      category: PlaceCategory.restaurants,
      latitude: -6.1882,
      longitude: 106.8324,
      rating: 4.8,
      reviewCount: 342,
      price: 150000,
      priceDisplay: 'Rp 150.000 / orang',
      address: 'Jl. HOS. Cokroaminoto No.42, Gondangdia, Menteng',
      city: 'Jakarta Pusat',
      imageUrl:
          'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=800',
      description:
          'Restoran masakan Nusantara legendaris dengan arsitektur kolonial mewah dan cita rasa autentik khas Indonesia.',
      openHours: '11:00 - 22:00',
      tags: ['Indonesian', 'Fine Dining', 'Halal', 'Heritage'],
    ),
    MapPlace(
      id: 'resto_2',
      name: 'Bebek Tepi Sawah Restaurant',
      category: PlaceCategory.restaurants,
      latitude: -8.5192,
      longitude: 115.2754,
      rating: 4.7,
      reviewCount: 520,
      price: 95000,
      priceDisplay: 'Rp 95.000 / porsi',
      address: 'Jl. Raya Goa Gajah, Br. Teges, Peliatan',
      city: 'Ubud, Bali',
      imageUrl:
          'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=800',
      description:
          'Nikmati renyahnya bebek goreng khas Ubud di tengah hamparan panorama sawah hijau nan asri.',
      openHours: '10:00 - 22:00',
      tags: ['Crispy Duck', 'Balinese', 'Scenic View'],
    ),
    MapPlace(
      id: 'resto_3',
      name: 'Gubug Makan Mang Engking',
      category: PlaceCategory.restaurants,
      latitude: -7.7492,
      longitude: 110.3341,
      rating: 4.6,
      reviewCount: 418,
      price: 65000,
      priceDisplay: 'Rp 65.000 / porsi',
      address: 'Jl. Soragan No.13, Ngestiharjo, Kasihan',
      city: 'Yogyakarta',
      imageUrl:
          'https://images.unsplash.com/photo-1544025162-d76694265947?w=800',
      description:
          'Nuansa pedesaan dengan gubug di atas kolam ikan dan menu udang bakar madu khas Sunda yang lezat.',
      openHours: '10:00 - 21:00',
      tags: ['Sundanese', 'Seafood', 'Family Friendly'],
    ),
    MapPlace(
      id: 'resto_4',
      name: 'Lara Djonggrang Restaurant',
      category: PlaceCategory.restaurants,
      latitude: -6.1973,
      longitude: 106.8402,
      rating: 4.7,
      reviewCount: 295,
      price: 135000,
      priceDisplay: 'Rp 135.000 / orang',
      address: 'Jl. Teuku Cik Ditiro No.4, Menteng',
      city: 'Jakarta Pusat',
      imageUrl:
          'https://images.unsplash.com/photo-1550966871-3ed3cdb5ed0c?w=800',
      description:
          'Pengalaman bersantap ala kerajaan kuno Indonesia dengan koleksi barang seni tradisional dan resep pusaka.',
      openHours: '11:00 - 23:00',
      tags: ['Royal Cuisine', 'Romantic', 'Authentic'],
    ),
    MapPlace(
      id: 'resto_5',
      name: 'Bunga Rampai Restaurant',
      category: PlaceCategory.restaurants,
      latitude: -6.1994,
      longitude: 106.8427,
      rating: 4.8,
      reviewCount: 388,
      price: 120000,
      priceDisplay: 'Rp 120.000 / orang',
      address: 'Jl. Teuku Cik Ditiro No.35, Menteng',
      city: 'Jakarta Pusat',
      imageUrl:
          'https://images.unsplash.com/photo-1514933651103-005eec06c04b?w=800',
      description:
          'Restoran bergaya kolonial Belanda yang menyajikan hidangan autentik Nusantara dengan pelayanan bintang lima.',
      openHours: '11:00 - 22:00',
      tags: ['Fine Dining', 'Nusantara', 'Instagrammable'],
    ),
    MapPlace(
      id: 'resto_6',
      name: 'Warung Nia Balinese Food & Pork Ribs',
      category: PlaceCategory.restaurants,
      latitude: -8.6853,
      longitude: 115.1542,
      rating: 4.8,
      reviewCount: 610,
      price: 85000,
      priceDisplay: 'Rp 85.000 / porsi',
      address: 'Kayu Aya Square, Jl. Kayu Aya No.19, Seminyak',
      city: 'Badung, Bali',
      imageUrl:
          'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=800',
      description:
          'Sate lilit, iga bakar rempah, dan kuliner khas Bali dengan sambal matah segar favorit wisatawan.',
      openHours: '11:00 - 22:30',
      tags: ['Balinese', 'Satay', 'Seminyak'],
    ),

    // ─── AMUSEMENT (Wahana, Taman Hiburan & Tematik) ────────────────────────
    MapPlace(
      id: 'amuse_1',
      name: 'Dunia Fantasi (Dufan) Ancol',
      category: PlaceCategory.amusement,
      latitude: -6.1253,
      longitude: 106.8335,
      rating: 4.8,
      reviewCount: 1240,
      price: 250000,
      priceDisplay: 'Rp 250.000 / tiket',
      address: 'Jl. Lodan Timur No.7, Ancol, Pademangan',
      city: 'Jakarta Utara',
      imageUrl:
          'https://images.unsplash.com/photo-1513889961551-628c1e5e2ee9?w=800',
      description:
          'Taman hiburan outdoor terbesar dengan beragam wahana atraktif, roller coaster Halilintar, Tornado, dan Bianglala.',
      openHours: '10:00 - 18:00',
      tags: ['Theme Park', 'Roller Coaster', 'Family'],
    ),
    MapPlace(
      id: 'amuse_2',
      name: 'Trans Studio Theme Park Cibubur',
      category: PlaceCategory.amusement,
      latitude: -6.3721,
      longitude: 106.9015,
      rating: 4.7,
      reviewCount: 780,
      price: 275000,
      priceDisplay: 'Rp 275.000 / tiket',
      address: 'Jl. Alternatif Cibubur No.230',
      city: 'Depok / Jakarta Timur',
      imageUrl:
          'https://images.unsplash.com/photo-1579783900882-c0d3dad7b119?w=800',
      description:
          'Indoor theme park kelas dunia dengan wahana berteknologi tinggi seperti Jurassic Island dan Pacific Rim.',
      openHours: '11:00 - 18:00',
      tags: ['Indoor Park', 'VR & 4D', 'Show'],
    ),
    MapPlace(
      id: 'amuse_3',
      name: 'Jatim Park 3 (Dino Park)',
      category: PlaceCategory.amusement,
      latitude: -7.8973,
      longitude: 112.5532,
      rating: 4.8,
      reviewCount: 930,
      price: 110000,
      priceDisplay: 'Rp 110.000 / tiket',
      address: 'Jl. Ir. Soekarno No.144, Beji, Junrejo',
      city: 'Kota Batu, Jawa Timur',
      imageUrl:
          'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=800',
      description:
          'Jelajahi dunia dinosaurus purba dengan animatronik berskala nyata, museum musik dunia, dan wahana seru.',
      openHours: '11:00 - 20:00',
      tags: ['Dinosaur', 'Education', 'Batu'],
    ),

    // ─── HOTEL (Hotel & Resort Mewah) ──────────────────────────────────────
    MapPlace(
      id: 'hotel_1',
      name: 'Hotel Indonesia Kempinski Jakarta',
      category: PlaceCategory.hotel,
      latitude: -6.1953,
      longitude: 106.8231,
      rating: 4.9,
      reviewCount: 890,
      price: 2900000,
      priceDisplay: 'Rp 2.900.000 / malam',
      address: 'Jl. MH Thamrin No.1, Menteng',
      city: 'Jakarta Pusat',
      imageUrl:
          'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=800',
      description:
          'Hotel bintang 5 bersejarah dengan pemandangan Bundaran HI, spa mewah, dan restoran Paulaner Brauhaus.',
      openHours: '24 Jam',
      tags: ['5-Star Luxury', 'Bundaran HI', 'Spa & Pool'],
    ),
    MapPlace(
      id: 'hotel_2',
      name: 'The Phoenix Hotel Yogyakarta',
      category: PlaceCategory.hotel,
      latitude: -7.7827,
      longitude: 110.3671,
      rating: 4.8,
      reviewCount: 654,
      price: 1200000,
      priceDisplay: 'Rp 1.200.000 / malam',
      address: 'Jl. Jend. Sudirman No.9, Cokrodiningratan',
      city: 'Yogyakarta',
      imageUrl:
          'https://images.unsplash.com/photo-1542314831-068cd1dbfeeb?w=800',
      description:
          'Perpaduan gaya kolonial Jawa-Eropa dengan kolam renang terbuka bergaya istana kuno yang memesona.',
      openHours: '24 Jam',
      tags: ['Heritage Hotel', 'Malioboro', 'Fine Dining'],
    ),
    MapPlace(
      id: 'hotel_3',
      name: 'Ayana Resort & Spa Jimbaran',
      category: PlaceCategory.hotel,
      latitude: -8.7672,
      longitude: 115.1483,
      rating: 4.9,
      reviewCount: 1120,
      price: 3800000,
      priceDisplay: 'Rp 3.800.000 / malam',
      address: 'Jl. Karang Mas Sejahtera, Jimbaran',
      city: 'Badung, Bali',
      imageUrl:
          'https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?w=800',
      description:
          'Resor tebing spektakuler di atas Teluk Jimbaran dengan 12 kolam renang, private beach, dan Rock Bar ternama.',
      openHours: '24 Jam',
      tags: ['Oceanfront', 'Rock Bar', 'Sunset'],
    ),

    // ─── PARK (Taman & Wisata Alam) ───────────────────────────────────────
    MapPlace(
      id: 'park_1',
      name: 'Taman Suropati & Menteng',
      category: PlaceCategory.park,
      latitude: -6.1998,
      longitude: 106.8327,
      rating: 4.7,
      reviewCount: 420,
      price: 0,
      priceDisplay: 'Gratis Masuk',
      address: 'Jl. Taman Suropati No.5, Menteng',
      city: 'Jakarta Pusat',
      imageUrl:
          'https://images.unsplash.com/photo-1448375240586-882707db888b?w=800',
      description:
          'Taman asri rindang di jantung kota Jakarta dengan air mancur artistik, monumen ASEAN, dan suasana sejuk.',
      openHours: '06:00 - 21:00',
      tags: ['City Park', 'Jogging Track', 'Nature'],
    ),
    MapPlace(
      id: 'park_2',
      name: 'Kebun Raya Bogor (Bogor Botanical Gardens)',
      category: PlaceCategory.park,
      latitude: -6.5976,
      longitude: 106.7995,
      rating: 4.8,
      reviewCount: 1540,
      price: 25000,
      priceDisplay: 'Rp 25.000 / tiket',
      address: 'Jl. Ir. H. Juanda No.13, Paledang',
      city: 'Bogor, Jawa Barat',
      imageUrl:
          'https://images.unsplash.com/photo-1473448912268-2022ce9509d8?w=800',
      description:
          'Kawasan botani tertua di Asia Tenggara dengan puluhan ribu pohon langka, danau teratai, dan Istana Presiden Bogor.',
      openHours: '08:00 - 17:00',
      tags: ['Botanical', 'Historic', 'Canopy'],
    ),
    MapPlace(
      id: 'park_3',
      name: 'Hutan Kota Gelora Bung Karno (GBK)',
      category: PlaceCategory.park,
      latitude: -6.2215,
      longitude: 106.8086,
      rating: 4.8,
      reviewCount: 790,
      price: 0,
      priceDisplay: 'Gratis Masuk',
      address: 'Jl. Jend. Sudirman Kav 52-53, Gelora, Senayan',
      city: 'Jakarta Pusat',
      imageUrl:
          'https://images.unsplash.com/photo-1519331379826-f10be5486c6f?w=800',
      description:
          'Oase hijau terbuka dengan rumput landai dan latar gedung-gedung pencakar langit SCBD Jakarta.',
      openHours: '06:00 - 18:00',
      tags: ['Skyline View', 'Picnic Spot', 'Urban Park'],
    ),

    // ─── POOL (Kolam Renang & Waterpark) ──────────────────────────────────
    MapPlace(
      id: 'pool_1',
      name: 'Waterbom Bali Waterpark',
      category: PlaceCategory.pool,
      latitude: -8.7289,
      longitude: 115.1692,
      rating: 4.9,
      reviewCount: 1450,
      price: 340000,
      priceDisplay: 'Rp 340.000 / tiket',
      address: 'Jl. Kartika Plaza, Tuban, Kuta',
      city: 'Badung, Bali',
      imageUrl:
          'https://images.unsplash.com/photo-1576013551627-0cc20b96c2a7?w=800',
      description:
          'Waterpark nomor 1 di Asia dengan seluncuran kelas dunia, kolam arus tropis, dan swim-up bar.',
      openHours: '09:00 - 18:00',
      tags: ['Waterslides', 'Lazy River', 'Top Rated'],
    ),
    MapPlace(
      id: 'pool_2',
      name: 'Kolam Renang Stadion Akuatik GBK',
      category: PlaceCategory.pool,
      latitude: -6.2163,
      longitude: 106.8014,
      rating: 4.8,
      reviewCount: 412,
      price: 100000,
      priceDisplay: 'Rp 100.000 / sesi',
      address: 'Jl. Stadion Senayan, Gelora, Tanah Abang',
      city: 'Jakarta Pusat',
      imageUrl:
          'https://images.unsplash.com/photo-1519817650390-64a93db51149?w=800',
      description:
          'Fasilitas akuatik standar Olimpiade internasional dengan kolam tanding 50m, kolam diving, dan air jernih bersuhu terkontrol.',
      openHours: '07:30 - 18:00',
      tags: ['Olympic Pool', 'Aquatic', 'Diving'],
    ),
    MapPlace(
      id: 'pool_3',
      name: 'The Jungle Water Adventure Bogor',
      category: PlaceCategory.pool,
      latitude: -6.6341,
      longitude: 106.7981,
      rating: 4.6,
      reviewCount: 680,
      price: 85000,
      priceDisplay: 'Rp 85.000 / tiket',
      address: 'Kawasan Bogor Nirwana Residence, Jl. Dreded Pahlawan',
      city: 'Bogor, Jawa Barat',
      imageUrl:
          'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800',
      description:
          'Taman rekreasi air bertema alam di kaki Gunung Salak dengan kolam ombak, kolam air hangat, dan seluncuran raksasa.',
      openHours: '09:00 - 17:00',
      tags: ['Wave Pool', 'Thermal Pool', 'Family'],
    ),
  ];

  /// Mengambil semua tempat, menggabungkan database SQLite dan seed terkurasi
  static Future<List<MapPlace>> getPlaces({LatLng? userLocation}) async {
    final List<MapPlace> places = [];
    final Set<String> seenNames = {};

    // 1. Tambahkan curated seed places
    for (final p in _curatedSeedPlaces) {
      if (seenNames.add(p.name.toLowerCase())) {
        places.add(p);
      }
    }

    // 2. Ambil dari database wisata lokal
    try {
      final dbWisata = await DBHelper.getWisata();
      for (final w in dbWisata) {
        final double? lat = (w['latitude'] as num?)?.toDouble();
        final double? lon = (w['longitude'] as num?)?.toDouble();
        if (lat == null || lon == null || lat == 0.0 || lon == 0.0) continue;

        final name = (w['nama_wisata'] ?? '').toString();
        if (name.isEmpty || seenNames.contains(name.toLowerCase())) continue;
        seenNames.add(name.toLowerCase());

        final rawKategori = (w['kategori'] ?? '').toString();
        final category = PlaceCategory.fromString(rawKategori);
        final price = (w['harga_tiket'] as num?)?.toDouble() ?? 0.0;
        final imageUrl = (w['image_url'] ?? '').toString();

        places.add(
          MapPlace(
            id: 'wisata_${w['id']}',
            name: name,
            category: category,
            latitude: lat,
            longitude: lon,
            rating: 4.5 + ((name.hashCode % 5) / 10.0), // 4.5 - 4.9
            reviewCount: 40 + (name.hashCode % 450).abs(),
            price: price,
            priceDisplay: price <= 0 ? 'Gratis' : 'Rp ${price.toInt()} / tiket',
            address: (w['alamat'] ?? '').toString(),
            city: (w['kota_kabupaten'] ?? w['provinsi'] ?? 'Indonesia')
                .toString(),
            imageUrl: imageUrl.isNotEmpty
                ? imageUrl
                : _fallbackImageForCategory(category),
            description: (w['deskripsi'] ?? '').toString(),
            openHours: '08:00 - 17:00',
            tags: [rawKategori, 'Wisata Populer'],
          ),
        );
      }
    } catch (e) {
      debugPrint('[MapPlacesService] SQLite wisata fetch error: $e');
    }

    // 3. Ambil dari database hotels
    try {
      final dbHotels = await DBHelper.getHotels();
      for (final h in dbHotels) {
        final double? lat = (h['latitude'] as num?)?.toDouble();
        final double? lon = (h['longitude'] as num?)?.toDouble();
        if (lat == null || lon == null || lat == 0.0 || lon == 0.0) continue;

        final name = (h['name'] ?? '').toString();
        if (name.isEmpty || seenNames.contains(name.toLowerCase())) continue;
        seenNames.add(name.toLowerCase());

        final price = (h['price_per_night'] as num?)?.toDouble() ?? 750000.0;
        final stars = (h['stars'] as num?)?.toInt() ?? 4;
        final imageUrl = (h['image_url'] ?? '').toString();

        places.add(
          MapPlace(
            id: 'hotel_${h['id']}',
            name: name,
            category: PlaceCategory.hotel,
            latitude: lat,
            longitude: lon,
            rating: 4.0 + (stars * 0.18),
            reviewCount: 100 + (name.hashCode % 500).abs(),
            price: price,
            priceDisplay: 'Rp ${price.toInt()} / malam',
            address: (h['address'] ?? '').toString(),
            city: (h['city'] ?? h['province'] ?? '').toString(),
            imageUrl: imageUrl.isNotEmpty
                ? imageUrl
                : _fallbackImageForCategory(PlaceCategory.hotel),
            openHours: 'Check-in 14:00',
            tags: ['Bintang $stars', 'Resort', 'Wi-Fi'],
          ),
        );
      }
    } catch (e) {
      debugPrint('[MapPlacesService] SQLite hotels fetch error: $e');
    }

    // 4. Jika userLocation diberikan dan tempat di sekitar < 5 km masih sedikit
    // (misalnya user berada di simulator/koordinat khusus), buatkan titik terdekat di sekitar GPS
    if (userLocation != null) {
      final nearbyCount = places
          .where((p) => p.distanceTo(userLocation) <= 8000)
          .length;

      if (nearbyCount < 5) {
        places.addAll(_generateSurroundingPlaces(userLocation));
      }
    }

    return places;
  }

  /// Membuat tempat di sekitar koordinat pengguna agar peta selalu interaktif
  static List<MapPlace> _generateSurroundingPlaces(LatLng userLoc) {
    return [
      MapPlace(
        id: 'nearby_resto_1',
        name: 'Dapur Nusantara Resto & Cafe',
        category: PlaceCategory.restaurants,
        latitude: userLoc.latitude + 0.0035,
        longitude: userLoc.longitude + 0.0042,
        rating: 4.8,
        reviewCount: 215,
        price: 45000,
        priceDisplay: 'Rp 45.000 / porsi',
        address: 'Jl. Boulevard Utama No. 8',
        city: 'Dekat Lokasi Anda',
        imageUrl:
            'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=800',
        description:
            'Menu kuliner khas Nusantara dengan bumbu rempah pilihan, aneka sambal segar, dan es kelapa muda.',
        openHours: '10:00 - 22:00',
        tags: ['Restoran', 'Kuliner Terdekat', 'Dine-In'],
      ),
      MapPlace(
        id: 'nearby_resto_2',
        name: 'Warung Steak & Seafood Bahari',
        category: PlaceCategory.restaurants,
        latitude: userLoc.latitude - 0.0045,
        longitude: userLoc.longitude + 0.0038,
        rating: 4.7,
        reviewCount: 168,
        price: 60000,
        priceDisplay: 'Rp 60.000 / porsi',
        address: 'Jl. Danau Asri No. 15',
        city: 'Dekat Lokasi Anda',
        imageUrl:
            'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=800',
        description:
            'Hidangan laut segar dan tenderloin steak gurih dengan saus blackpepper khas favorit keluarga.',
        openHours: '11:00 - 22:30',
        tags: ['Seafood', 'Steak', 'Resto Terdekat'],
      ),
      MapPlace(
        id: 'nearby_resto_3',
        name: 'Kopi & Resto Senja View',
        category: PlaceCategory.restaurants,
        latitude: userLoc.latitude - 0.0028,
        longitude: userLoc.longitude - 0.0049,
        rating: 4.9,
        reviewCount: 312,
        price: 35000,
        priceDisplay: 'Rp 35.000 / menu',
        address: 'Jl. Panorama Permai No. 22',
        city: 'Dekat Lokasi Anda',
        imageUrl:
            'https://images.unsplash.com/photo-1554118811-1e0d58224f24?w=800',
        description:
            'Tempat santai dengan kopi arabika pilihan, hidangan pasta, nasi goreng istimewa, dan live music.',
        openHours: '09:00 - 23:00',
        tags: ['Cafe & Resto', 'Live Music', 'Outdoor'],
      ),
      MapPlace(
        id: 'nearby_hotel_1',
        name: 'The Grand Luxury Suite & Spa',
        category: PlaceCategory.hotel,
        latitude: userLoc.latitude + 0.0062,
        longitude: userLoc.longitude - 0.0035,
        rating: 4.9,
        reviewCount: 420,
        price: 850000,
        priceDisplay: 'Rp 850.000 / malam',
        address: 'Jl. Kemewahan No. 1',
        city: 'Dekat Lokasi Anda',
        imageUrl:
            'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=800',
        description:
            'Kenyamanan hotel bintang 4 dengan sarapan prasmanan, kolam renang rooftop, dan akses pusat kota.',
        openHours: '24 Jam',
        tags: ['Bintang 4', 'Rooftop Pool', 'Breakfast Included'],
      ),
      MapPlace(
        id: 'nearby_park_1',
        name: 'Taman Kota Hijau Asri',
        category: PlaceCategory.park,
        latitude: userLoc.latitude + 0.0051,
        longitude: userLoc.longitude + 0.0065,
        rating: 4.8,
        reviewCount: 190,
        price: 0,
        priceDisplay: 'Gratis',
        address: 'Jl. Rindang Alam No. 5',
        city: 'Dekat Lokasi Anda',
        imageUrl:
            'https://images.unsplash.com/photo-1448375240586-882707db888b?w=800',
        description:
            'Taman publik dengan pepohonan rindang, jogging track berbatu, dan area bermain ramah anak.',
        openHours: '06:00 - 20:00',
        tags: ['Taman Hijau', 'Jogging', 'Terbuka'],
      ),
      MapPlace(
        id: 'nearby_amuse_1',
        name: 'Wonderland Play & Fun Park',
        category: PlaceCategory.amusement,
        latitude: userLoc.latitude - 0.0065,
        longitude: userLoc.longitude + 0.0058,
        rating: 4.7,
        reviewCount: 340,
        price: 65000,
        priceDisplay: 'Rp 65.000 / tiket',
        address: 'Jl. Rekreasi Ria No. 10',
        city: 'Dekat Lokasi Anda',
        imageUrl:
            'https://images.unsplash.com/photo-1513889961551-628c1e5e2ee9?w=800',
        description:
            'Wahana bermain interaktif, carousel, bumper car, dan arcade game untuk seluruh anggota keluarga.',
        openHours: '10:00 - 21:00',
        tags: ['Wahana', 'Arcade', 'Keluarga'],
      ),
      MapPlace(
        id: 'nearby_pool_1',
        name: 'Aqua Splash Waterpark & Pool',
        category: PlaceCategory.pool,
        latitude: userLoc.latitude + 0.0075,
        longitude: userLoc.longitude + 0.0021,
        rating: 4.8,
        reviewCount: 270,
        price: 50000,
        priceDisplay: 'Rp 50.000 / tiket',
        address: 'Jl. Tirta Kencana No. 7',
        city: 'Dekat Lokasi Anda',
        imageUrl:
            'https://images.unsplash.com/photo-1576013551627-0cc20b96c2a7?w=800',
        description:
            'Kolam renang air jernih dengan ember tumpah raksasa, seluncuran spiral, dan gazebo teduh.',
        openHours: '08:00 - 18:00',
        tags: ['Waterpark', 'Kolam Renang', 'Seluncuran'],
      ),
    ];
  }

  /// Membuka lokasi di aplikasi Google Maps fisik di perangkat pengguna
  /// Menggunakan skema URL: https://www.google.com/maps/search/?api=1&query=Latitude,Longitude
  static Future<bool> openInGoogleMaps(double latitude, double longitude) async {
    final Uri googleMapsUrl = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );

    try {
      final bool launched = await launchUrl(
        googleMapsUrl,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        return await launchUrl(
          googleMapsUrl,
          mode: LaunchMode.platformDefault,
        );
      }
      return true;
    } catch (e) {
      debugPrint('[MapPlacesService] Gagal membuka Google Maps: $e');
      return false;
    }
  }

  static String _fallbackImageForCategory(PlaceCategory category) {
    switch (category) {
      case PlaceCategory.restaurants:
        return 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=800';
      case PlaceCategory.hotel:
        return 'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=800';
      case PlaceCategory.amusement:
        return 'https://images.unsplash.com/photo-1513889961551-628c1e5e2ee9?w=800';
      case PlaceCategory.park:
        return 'https://images.unsplash.com/photo-1448375240586-882707db888b?w=800';
      case PlaceCategory.pool:
        return 'https://images.unsplash.com/photo-1576013551627-0cc20b96c2a7?w=800';
      default:
        return 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800';
    }
  }
}
