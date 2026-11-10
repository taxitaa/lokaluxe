import 'package:intl/intl.dart';

import '../database/db_helper.dart';

class LokaBotReply {
  final String text;
  final bool isRecognized;
  final String? suggestedQuery;

  const LokaBotReply({
    required this.text,
    this.isRecognized = true,
    this.suggestedQuery,
  });
}

class LokaBotService {
  static const String fallbackMessage =
      'Maaf, sebagai **LokaBot (offline)**, saya hanya bisa membantu menjawab '
      'seputar fitur dan panduan aplikasi **LokaLuxe**.\n\n'
      'Untuk rekomendasi destinasi, ide liburan, atau pertanyaan perjalanan '
      'yang lebih lengkap, kamu bisa beralih ke **AI Concierge (Gemini)**.';

  static LokaBotReply getReply(String rawInput) {
    final query = rawInput.trim().toLowerCase();
    if (query.isEmpty) {
      return const LokaBotReply(
        text: 'Silakan ketik pertanyaan seputar fitur aplikasi LokaLuxe.',
        isRecognized: true,
      );
    }

    // 1. Sapaan & Perkenalan
    if (_matches(query, [
      'halo',
      'hai',
      'hei',
      'hi',
      'hello',
      'selamat pagi',
      'selamat siang',
      'selamat sore',
      'selamat malam',
      'siapa kamu',
      'kamu siapa',
      'bisa apa',
      'bantuan',
      'help',
    ])) {
      return const LokaBotReply(
        text:
            'Halo! Saya **LokaBot**, asisten offline resmi aplikasi **LokaLuxe**.\n\n'
            'Saya siap memandumu menggunakan fitur-fitur LokaLuxe tanpa perlu internet:\n'
            '• **Budget Trip**: Perencanaan anggaran liburan\n'
            '• **Itinerary**: Penyusunan jadwal harian & pengingat trip\n'
            '• **Mini Game (LokaCatch)**: Permainan seru tangkap kuliner\n'
            '• **Voucher**: Kupon diskon wisata & penginapan\n'
            '• **Currency & Time Converter**: Konversi kurs valuta & zona waktu\n'
            '• **Navigator**: Peta interaktif destinasi nusantara\n\n'
            'Ketik nama fitur yang ingin kamu pelajari!',
        isRecognized: true,
      );
    }

    // 2. Budget Trip / Budget Planner
    if (_matches(query, [
      'budget',
      'anggaran',
      'uang',
      'biaya',
      'pengeluaran',
      'planner',
      'atur budget',
      'catat biaya',
    ])) {
      return const LokaBotReply(
        text:
            '**Fitur Budget Trip LokaLuxe**\n\n'
            'Fitur ini membantumu merencanakan dan mengontrol keuangan liburan:\n'
            '1. **Atur Target Budget**: Tetapkan total dana perjalananmu.\n'
            '2. **Alokasi 4 Pos Utama**: Bagikan budget untuk Transportasi, Hotel, Kuliner, dan Aktivitas Wisata.\n'
            '3. **Pencatatan Pengeluaran**: Catat setiap pengeluaran riil untuk melihat sisa dana secara real-time.\n'
            '4. **Terintegrasi**: Terhubung langsung dengan fitur Itinerary dan konverter mata uang.\n\n'
            '💡 **Cara Akses**: Ketuk banner *Budget Trip* di bagian atas Beranda atau kartu pintasan di dashboard.',
        isRecognized: true,
      );
    }

    // 3. Itinerary / Rencana Perjalanan
    if (_matches(query, [
      'itinerary',
      'itinerari',
      'jadwal',
      'rencana',
      'rundown',
      'pengingat',
      'reminder',
      'agenda',
    ])) {
      return const LokaBotReply(
        text:
            '**Fitur Itinerary LokaLuxe**\n\n'
            'Dengan Itinerary, liburanmu akan tertata rapi dan terjadwal:\n'
            '1. **Jadwal Harian**: Kelola destinasi dan agenda hari demi hari (Hari 1, Hari 2, dst).\n'
            '2. **Pengingat Otomatis**: Aplikasi mengirim notifikasi pengingat pada H-7, H-5, H-3, dan Hari-H pukul 09.00.\n'
            '3. **Simpan dari Katalog**: Kamu bisa langsung menambahkan destinasi wisata favorit ke itinerary aktif.\n'
            '4. **Pembuatan Otomatis**: AI Concierge (Gemini) juga bisa menyusunkan rencana perjalanan lengkap secara otomatis!\n\n'
            '💡 **Cara Akses**: Ketuk ikon *Itinerary* di Beranda atau beralih ke mode AI Concierge untuk membuat rencana otomatis.',
        isRecognized: true,
      );
    }

    // 4. Mini Game LokaCatch
    if (_matches(query, [
      'game',
      'mini game',
      'lokacatch',
      'main',
      'skor',
      'komodo',
      'bom',
      'makanan',
    ])) {
      return const LokaBotReply(
        text:
            '**Mini Game: LokaCatch** 🎮\n\n'
            'LokaCatch adalah permainan santai bertema kuliner nusantara:\n'
            '1. **Cara Main**: Gerakkan karakter komodo ke kiri dan kanan untuk menangkap makanan khas Nusantara (sate, tumpeng, lemper, dll).\n'
            '2. **Poin**: Setiap makanan yang tertangkap akan menambah skormu.\n'
            '3. **Hati-hati Bom**: Hindari bom yang jatuh, jika tertangkap nyawamu akan berkurang!\n'
            '4. **Tantangan Harian**: Kumpulkan skor tertinggi dan bagikan dengan teman perjalananmu.\n\n'
            '💡 **Cara Akses**: Ketuk menu *Mini Game* berikon joystick di dashboard Beranda.',
        isRecognized: true,
      );
    }

    // 5. Voucher & Promo
    if (_matches(query, [
      'voucher',
      'kupon',
      'promo',
      'diskon',
      'potongan',
      'hemat',
      'klaim',
    ])) {
      return const LokaBotReply(
        text:
            '**Fitur Voucher & Promo LokaLuxe** 🎟️\n\n'
            'Dapatkan penawaran istimewa untuk liburan hemat:\n'
            '1. **Voucher Tiket Wisata**: Diskon tiket masuk destinasi nusantara.\n'
            '2. **Voucher Penginapan**: Potongan harga hotel dan resort mitra.\n'
            '3. **Voucher Transportasi**: Diskon sewa kendaraan dan tiket perjalanan.\n'
            '4. **Mudah Digunakan**: Salin kode voucher dan gunakan saat melakukan pemesanan.\n\n'
            '💡 **Cara Akses**: Ketuk ikon *Voucher* berbentuk kado di Beranda.',
        isRecognized: true,
      );
    }

    // 6. Currency / Konversi Mata Uang
    if (_matches(query, [
      'currency',
      'mata uang',
      'kurs',
      'valuta',
      'dollar',
      'usd',
      'idr',
      'rupiah',
      'konversi uang',
    ])) {
      return const LokaBotReply(
        text:
            '**Fitur Konversi Mata Uang (Currency Converter)** 💱\n\n'
            'Memudahkan perhitungan biaya bagi wisatawan mancanegara maupun domestik:\n'
            '• Mengonversi mata uang populer dunia (USD, EUR, SGD, JPY, MYR, AUD, GBP, dll) ke Rupiah (IDR).\n'
            '• Mengupdate kurs acuan secara akurat saat terhubung internet dan menyimpannya untuk penggunaan offline.\n'
            '• Terintegrasi ke tampilan harga wisata di katalog.\n\n'
            '💡 **Cara Akses**: Ketuk kartu *Currency* di Beranda atau buka melalui menu Keuangan.',
        isRecognized: true,
      );
    }

    // 7. Time / Zona Waktu
    if (_matches(query, [
      'time',
      'waktu',
      'jam',
      'zona waktu',
      'wib',
      'wita',
      'wit',
      'selisih waktu',
    ])) {
      return const LokaBotReply(
        text:
            '**Fitur Penunjuk Zona Waktu (Time Converter)** ⏰\n\n'
            'Indonesia memiliki 3 zona waktu yang berbeda:\n'
            '• **WIB** (Waktu Indonesia Barat): Sumatra, Jawa, Kalimantan Barat & Tengah.\n'
            '• **WITA** (Waktu Indonesia Tengah): Bali, NTB, NTT, Kalimantan Selatan, Timur & Utara, Sulawesi (+1 jam dari WIB).\n'
            '• **WIT** (Waktu Indonesia Timur): Maluku & Papua (+2 jam dari WIB).\n\n'
            'Aplikasi LokaLuxe menampilkan waktu tujuan secara langsung agar kamu tidak ketinggalan jadwal penerbangan atau tur!\n\n'
            '💡 **Cara Akses**: Ketuk kartu *Time* di Beranda.',
        isRecognized: true,
      );
    }

    // 8. Navigator / Peta & Lokasi
    if (_matches(query, [
      'navigator',
      'navigasi',
      'peta',
      'map',
      'rute',
      'arah',
      'gps',
      'lokasi',
      'koordinat',
    ])) {
      return const LokaBotReply(
        text:
            '**Fitur Navigasi & Peta Wisata (Navigator)** 🧭\n\n'
            'Jelajahi keindahan Indonesia dengan panduan lokasi akurat:\n'
            '1. **Peta Interaktif**: Menampilkan titik-titik tempat wisata terpopuler.\n'
            '2. **Lokasi Saat Ini**: Deteksi lokasimu dan temukan destinasi menarik terdekat.\n'
            '3. **Rute & Arah**: Dapatkan rute tercepat menuju tempat wisata impian.\n'
            '4. **Info Lengkap**: Klik pin lokasi untuk melihat alamat dan tiket masuk.\n\n'
            '💡 **Cara Akses**: Pilih tab *Navigasi* di bottom navigation bar.',
        isRecognized: true,
      );
    }

    // 9. Katalog Wisata & Rekomendasi
    if (_matches(query, [
      'katalog',
      'wisata populer',
      'destinasi',
      'daftar wisata',
      'hotel',
      'penginapan',
      'transportasi',
      'kategori',
    ])) {
      return const LokaBotReply(
        text:
            '**Katalog Wisata & Layanan LokaLuxe** 🏖️\n\n'
            'LokaLuxe menyediakan database lengkap destinasi di 38 provinsi Indonesia:\n'
            '• **Wisata**: Alam, budaya, sejarah, bahari, dan edukasi.\n'
            '• **Hotel**: Rekomendasi penginapan nyaman sesuai budget liburan.\n'
            '• **Transportasi**: Pilihan sewa kendaraan dan rute perjalanan.\n\n'
            'Gunakan kolom pencarian di Beranda atau tombol *Lihat Semua* pada Wisata Populer untuk menjelajahi katalog.',
        isRecognized: true,
      );
    }

    // 10. Profil & Bahasa
    if (_matches(query, [
      'profil',
      'profile',
      'akun',
      'bahasa',
      'ganti foto',
      'ubah profil',
      'setting',
      'pengaturan',
    ])) {
      return const LokaBotReply(
        text:
            '**Pengaturan Akun & Profil** 👤\n\n'
            'Di menu Profil kamu dapat:\n'
            '• Mengubah nama pengguna dan foto profil avatar.\n'
            '• Mengganti bahasa aplikasi (Bahasa Indonesia / English).\n'
            '• Melihat riwayat perjalanan dan status akun.\n\n'
            '💡 **Cara Akses**: Pilih tab *Profil* di pojok kanan bawah navigation bar.',
        isRecognized: true,
      );
    }

    // 11. Unrecognized query -> Fallback to Gemini
    return LokaBotReply(
      text: fallbackMessage,
      isRecognized: false,
      suggestedQuery: rawInput.trim(),
    );
  }

  static Future<LokaBotReply> answer(String rawInput) async {
    final query = rawInput.trim().toLowerCase();
    if (query.isEmpty) {
      return const LokaBotReply(
        text:
            'Silakan ketik pertanyaan seputar perjalanan atau fitur LokaLuxe.',
      );
    }

    if (_isClearlyOutOfScope(query)) {
      return const LokaBotReply(
        text: 'Maaf, saya hanya bisa membantu seputar perjalanan dan fitur LokaLuxe.',
      );
    }

    final helpReply = _featureHelp(query);
    if (helpReply != null) return helpReply;

    if (_isBudgetQuestion(query)) return _remainingBudgetReply(query);
    if (query.contains('hotel')) return _hotelReply(query);
    if (query.contains('tiket') ||
        query.contains('transportasi') ||
        query.contains('pesawat') ||
        query.contains('kereta')) {
      return _transportReply(query);
    }
    if (_isTourismQuestion(query)) return _wisataReply(query);

    final existingReply = getReply(rawInput);
    if (existingReply.isRecognized) return existingReply;

    if (_isTravelQuestion(query)) {
      return LokaBotReply(
        text:
            'Saya bisa membantu mencari wisata, hotel, transportasi, atau sisa anggaran dari data lokal. '
            'Coba sebutkan kota, jenis layanan, atau pertanyaan fitur yang kamu maksud.',
        isRecognized: false,
        suggestedQuery: rawInput.trim(),
      );
    }

    return LokaBotReply(
      text: 'Saya belum yakin memahami pertanyaan itu. Coba tanyakan tentang wisata, hotel, transportasi, anggaran, atau fitur LokaLuxe.',
      isRecognized: false,
      suggestedQuery: rawInput.trim(),
    );
  }

  static bool _isClearlyOutOfScope(String query) {
    const topics = [
      'politik',
      'pemilu',
      'partai',
      'coding',
      'pemrograman',
      'programming',
      'resep',
      'memasak',
      'masak ',
    ];
    return topics.any(query.contains) &&
        !_isTravelQuestion(query) &&
        !_featureHelpKeywords.any(query.contains);
  }

  static const _featureHelpKeywords = [
    'trip',
    'budget',
    'itinerary',
    'kiblat',
    'voucher',
    'konversi',
    'currency',
    'mata uang',
    'peta',
    'navigator',
    'navigasi',
  ];

  static LokaBotReply? _featureHelp(String query) {
    final isHowTo = _matches(query, [
      'cara',
      'bagaimana',
      'gimana',
      'tutorial',
      'bantu',
      'petunjuk',
    ]);
    if (!isHowTo) return null;

    if (_matches(query, ['trip', 'budget', 'anggaran'])) {
      return const LokaBotReply(
        text: 'Untuk membuat Budget Trip, ketuk **Budget Trip** di Beranda. Isi target anggaran dan alokasi biaya perjalanan, lalu simpan. Kamu bisa mencatat pengeluaran pada menu Keuangan untuk melihat sisa anggaran.',
      );
    }
    if (_matches(query, ['kiblat', 'qibla'])) {
      return const LokaBotReply(
        text: 'Buka tab **Navigasi**, lalu pilih **Kompas dan arah kiblat**. Izinkan akses lokasi dan sensor kompas agar arah kiblat dapat ditampilkan sesuai lokasimu.',
      );
    }
    if (query.contains('voucher')) {
      return const LokaBotReply(
        text: 'Buka **Voucher** dari menu pintasan di Beranda untuk melihat voucher aktif. Fitur voucher memerlukan sesi akun dan koneksi untuk memuat atau menggunakan voucher; ketuk tombol pada kartu voucher untuk menyalin dan menggunakannya.',
      );
    }
    if (_matches(query, ['konversi', 'currency', 'mata uang', 'kurs'])) {
      return const LokaBotReply(
        text: 'Untuk konversi mata uang, ketuk kartu **Currency** di Beranda atau buka menu Keuangan, lalu pilih mata uang asal dan tujuan serta masukkan nominal.',
      );
    }
    if (_matches(query, ['peta', 'navigator', 'navigasi', 'lokasi'])) {
      return const LokaBotReply(
        text: 'Buka tab **Navigasi** pada bagian bawah aplikasi untuk melihat peta. Izinkan akses lokasi bila ingin melihat posisi dan tempat di sekitar.',
      );
    }

    return const LokaBotReply(
      text: 'Untuk membuat itinerary, ketuk pintasan **Itinerary** di Beranda. Kamu juga bisa membuka **AI Concierge** untuk meminta pembuatan itinerary otomatis.',
    );
  }

  static bool _isBudgetQuestion(String query) => _matches(query, [
    'sisa anggaran',
    'sisa budget',
    'sisa uang',
    'uang saku harian',
    'anggaran tersisa',
    'budget tersisa',
  ]);

  static Future<LokaBotReply> _remainingBudgetReply(String query) async {
    final trip = await DBHelper.getActiveTrip();
    if (trip == null) {
      return const LokaBotReply(
        text: 'Belum ada trip aktif untuk dihitung. Buat Budget Trip terlebih dahulu dari Beranda.',
      );
    }

    final remaining = await DBHelper.getRemainingBudget();
    final currency = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    if (query.contains('harian') && trip.durationDays != null) {
      final days = trip.durationDays!;
      if (days > 0) {
        return LokaBotReply(
          text:
              'Trip aktif ke ${trip.destinationTitle.isEmpty ? trip.destination : trip.destinationTitle} memiliki sisa anggaran ${currency.format(remaining)}. Rata-rata uang saku dari sisa anggaran: ${currency.format(remaining / days)} per hari untuk $days hari perjalanan.',
        );
      }
    }
    if (query.contains('harian')) {
      return LokaBotReply(
        text:
            'Sisa anggaran trip aktif adalah ${currency.format(remaining)}, tetapi durasi trip belum tersedia sehingga uang saku harian belum bisa dihitung.',
      );
    }
    return LokaBotReply(
      text:
          'Sisa anggaran trip aktif${trip.destinationTitle.isEmpty ? '' : ' ke ${trip.destinationTitle}'} adalah ${currency.format(remaining)}.',
    );
  }

  static Future<LokaBotReply> _wisataReply(String query) async {
    final city = _extractPlace(
      query,
      r'(?:wisata|destinasi|liburan)\s+(?:di|ke)\s+',
    );
    if (city == null || city.isEmpty) {
      return const LokaBotReply(
        text: 'Kota mana yang ingin kamu cari wisatanya? Sebutkan nama kota, misalnya “wisata di Yogyakarta”.',
      );
    }

    final allWisata = await DBHelper.getWisata();
    final normalizedCity = city.toLowerCase();
    final matches = allWisata
        .where((item) {
          final searchable = [
            item['kota_kabupaten'],
            item['alamat'],
            item['nama_wisata'],
            item['nama_lengkap'],
          ].whereType<Object>().join(' ').toLowerCase();
          return searchable.contains(normalizedCity);
        })
        .take(5)
        .toList(growable: false);

    if (matches.isEmpty) {
      final cities = allWisata
          .map((item) => (item['kota_kabupaten'] ?? '').toString().trim())
          .where((name) => name.isNotEmpty)
          .toSet()
          .take(5)
          .join(', ');
      return LokaBotReply(
        text: cities.isEmpty
            ? 'Belum ada data wisata untuk $city di katalog lokal, dan katalog belum memuat kota lain.'
            : 'Belum ada data wisata untuk $city di katalog. Kota yang tersedia antara lain: $cities.',
      );
    }

    final currency = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final lines = matches
        .map((item) {
          final name =
              (item['nama_wisata'] ?? item['nama_lengkap'] ?? 'Destinasi')
                  .toString();
          final category = (item['kategori'] ?? 'Kategori tidak tersedia')
              .toString();
          final price = item['harga_tiket'];
          final estimatedPrice = price is num
              ? currency.format(price)
              : 'harga belum tersedia';
          return '• $name — $category — estimasi $estimatedPrice';
        })
        .join('\n');
    return LokaBotReply(text: 'Destinasi wisata di $city:\n$lines');
  }

  static Future<LokaBotReply> _hotelReply(String query) async {
    final maxPrice = _extractPriceLimit(query);
    final city = _extractPlace(query, r'hotel\s+(?:di|ke)\s+');
    final allHotels = await DBHelper.getHotels();
    final hotels = allHotels
        .where((hotel) {
          final price = hotel['price_per_night'];
          if (price is! num || (maxPrice != null && price > maxPrice))
            return false;
          if (city == null) return true;
          return [
                hotel['city'],
                hotel['province'],
                hotel['name'],
                hotel['address'],
              ]
              .whereType<Object>()
              .join(' ')
              .toLowerCase()
              .contains(city.toLowerCase());
        })
        .take(5)
        .toList(growable: false);

    if (hotels.isEmpty) {
      final condition = maxPrice == null
          ? (city == null ? '' : ' di $city')
          : ' dengan harga maksimal ${_formatCurrency(maxPrice)} per malam';
      return LokaBotReply(
        text: 'Belum ada data hotel$condition di katalog lokal.',
      );
    }

    final lines = hotels
        .map((hotel) {
          final name = (hotel['name'] ?? 'Hotel').toString();
          final location = (hotel['city'] ?? '').toString();
          final price = (hotel['price_per_night'] as num).toDouble();
          return '• $name${location.isEmpty ? '' : ' — $location'} — ${_formatCurrency(price)}/malam';
        })
        .join('\n');
    return LokaBotReply(text: 'Hotel yang cocok:\n$lines');
  }

  static Future<LokaBotReply> _transportReply(String query) async {
    final wantsPlane = query.contains('pesawat');
    final wantsTrain = query.contains('kereta');
    final allTransports = await DBHelper.getTransports();
    final transports = allTransports
        .where((item) {
          final searchable = [
            item['type'],
            item['name'],
            item['category'],
            item['route'],
          ].whereType<Object>().join(' ').toLowerCase();
          if (wantsPlane && wantsTrain) {
            return searchable.contains('pesawat') ||
                searchable.contains('kereta');
          }
          if (wantsPlane && !searchable.contains('pesawat')) return false;
          if (wantsTrain && !searchable.contains('kereta')) return false;
          return true;
        })
        .take(5)
        .toList(growable: false);

    if (transports.isEmpty) {
      return const LokaBotReply(
        text: 'Belum ada data tiket transportasi yang sesuai di katalog lokal.',
      );
    }
    final lines = transports
        .map((item) {
          final name = (item['name'] ?? 'Transportasi').toString();
          final type = (item['type'] ?? '').toString();
          final route = (item['route'] ?? '').toString();
          final price = (item['price'] as num?)?.toDouble() ?? 0;
          return '• ${type.isEmpty ? name : '$type — $name'}${route.isEmpty ? '' : ' — $route'} — ${_formatCurrency(price)}';
        })
        .join('\n');
    return LokaBotReply(text: 'Pilihan transportasi dari katalog:\n$lines');
  }

  static String? _extractPlace(String query, String prefixPattern) {
    final match = RegExp(
      '$prefixPattern(.+)',
      caseSensitive: false,
    ).firstMatch(query);
    if (match == null) return null;
    final place = match
        .group(1)!
        .replaceAll(RegExp(r'\b(?:dong|ya|tolong|please)\b.*$'), '')
        .replaceAll(RegExp(r'[?!.,]+$'), '')
        .trim();
    if (place.isEmpty ||
        _matches(place, ['bawah', 'di bawah', 'kurang dari', 'maksimal'])) {
      return null;
    }
    return place;
  }

  static double? _extractPriceLimit(String query) {
    final match = RegExp(
      r'(?:di bawah|dibawah|kurang dari|maksimal|max(?:imum)?|under)\s+(?:rp\s*)?(\d[\d.,]*)\s*(juta|jt|ribu|rb|k)?',
    ).firstMatch(query);
    if (match == null) return null;
    final rawAmount = match.group(1)!;
    final suffix = match.group(2);
    final amount = rawAmount.contains(RegExp(r'[.,]\d{3}$'))
        ? double.parse(rawAmount.replaceAll(RegExp(r'[.,]'), ''))
        : double.parse(rawAmount.replaceAll(',', '.'));
    if (suffix == 'juta' || suffix == 'jt') return amount * 1000000;
    if (suffix == 'ribu' || suffix == 'rb' || suffix == 'k') {
      return amount * 1000;
    }
    return amount;
  }

  static String _formatCurrency(num value) => NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  ).format(value);

  static bool _isTourismQuestion(String query) =>
      _matches(query, ['wisata', 'destinasi', 'tempat liburan']);

  static bool _isTravelQuestion(String query) => _matches(query, [
    'wisata',
    'destinasi',
    'hotel',
    'penginapan',
    'transportasi',
    'pesawat',
    'kereta',
    'tiket',
    'trip',
    'perjalanan',
    'liburan',
    'anggaran',
    'budget',
    'uang saku',
  ]);

  static bool _matches(String query, List<String> keywords) {
    for (final kw in keywords) {
      if (query.contains(kw)) return true;
    }
    return false;
  }
}

Future<LokaBotReply> jawabLokaBot(String input) => LokaBotService.answer(input);
