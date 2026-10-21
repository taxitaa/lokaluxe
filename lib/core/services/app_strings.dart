/// Sistem Lokalisasi LokaLuxe — tanpa flutter_localizations dependency.
///
/// Pendekatan: ARB-style map berbasis Provider untuk menghindari
/// kompleksitas generate kode. Cukup panggil [AppStrings.of(context).key].
///
/// Locale ditentukan otomatis dari [LocationProvider]:
///   - Lokasi Indonesia → Bahasa Indonesia (id)
///   - Lokasi lainnya   → English (en)

// ─── Model Strings ─────────────────────────────────────────────────────────

/// Kelas yang menyimpan semua string UI dalam dua bahasa.
/// Tambahkan field baru di sini dan definisikan di _id / _en di bawah.
class AppStrings {
  final String langCode;

  // ── Navigasi / Umum ────────────────────────────────────────────────────────
  final String appName;
  final String home;
  final String profile;
  final String finance;
  final String miniGame;
  final String settings;
  final String search;
  final String viewAll;
  final String close;
  final String save;
  final String cancel;
  final String loading;
  final String error;
  final String retry;
  final String offline;
  final String play;
  final String restart;
  final String gameOver;

  // ── Beranda ────────────────────────────────────────────────────────────────
  final String currentLocation;
  final String greeting;           // "Hello, {name}! 👋"
  final String tagline;            // "Let's traveling the"
  final String taglineHighlight;   // "Nusantara!"
  final String budgetRemaining;    // "Sisa Budget:"
  final String searchHint;         // "Where are you going?"
  final String categories;
  final String groupTours;
  final String popularIn;          // "Paling Populer di Bali"
  final String topChoice;
  final String perPerson;
  final String perNight;
  final String perDay;

  // ── Lokasi ────────────────────────────────────────────────────────────────
  final String pickLocation;
  final String pickLocationSubtitle;
  final String searchLocation;     // placeholder search modal
  final String locationNotFound;
  final String indonesia;
  final String japan;
  final String eurozone;
  final String otherCountries;

  // ── Mata Uang & Finance ────────────────────────────────────────────────────
  final String currency;
  final String currencyDisplay;
  final String changeCurrency;
  final String selectCurrency;
  final String ratesUpdated;
  final String ratesOffline;
  final String ratesLoading;
  final String quickConverter;
  final String pricesCatalog;
  final String ratesFromIDR;
  final String hotelPrices;
  final String transportPrices;
  final String redeemVoucher;
  final String redeemVoucherSub;
  final String redeem;

  // ── Zona Waktu ────────────────────────────────────────────────────────────
  final String timezone;
  final String activeLocation;
  final String referenceTimezones;
  final String timeDifference;     // "Selisih Waktu (dari WIB)"
  final String activeZone;         // badge "AKTIF"

  // ── Katalog ───────────────────────────────────────────────────────────────
  final String hotels;
  final String transport;
  final String wisata;
  final String allHotels;
  final String allTransport;
  final String allWisata;
  final String noData;
  final String stars;

  // ── Mini Game ─────────────────────────────────────────────────────────────
  final String lokaCatch;
  final String lokaCatchDesc;
  final String gyroscope;
  final String newBadge;
  final String totalCoins;
  final String sessions;
  final String highScore;
  final String rewardCoins;
  final String voucherExchange;
  final String voucherExchangeSub;
  final String gameOverMsg;
  final String finalScore;
  final String catchItems;

  // ── Voucher ───────────────────────────────────────────────────────────────
  final String voucher;
  final String voucherEmpty;
  final String claimVoucher;

  const AppStrings._({
    required this.langCode,
    required this.appName,
    required this.home,
    required this.profile,
    required this.finance,
    required this.miniGame,
    required this.settings,
    required this.search,
    required this.viewAll,
    required this.close,
    required this.save,
    required this.cancel,
    required this.loading,
    required this.error,
    required this.retry,
    required this.offline,
    required this.play,
    required this.restart,
    required this.gameOver,
    required this.currentLocation,
    required this.greeting,
    required this.tagline,
    required this.taglineHighlight,
    required this.budgetRemaining,
    required this.searchHint,
    required this.categories,
    required this.groupTours,
    required this.popularIn,
    required this.topChoice,
    required this.perPerson,
    required this.perNight,
    required this.perDay,
    required this.pickLocation,
    required this.pickLocationSubtitle,
    required this.searchLocation,
    required this.locationNotFound,
    required this.indonesia,
    required this.japan,
    required this.eurozone,
    required this.otherCountries,
    required this.currency,
    required this.currencyDisplay,
    required this.changeCurrency,
    required this.selectCurrency,
    required this.ratesUpdated,
    required this.ratesOffline,
    required this.ratesLoading,
    required this.quickConverter,
    required this.pricesCatalog,
    required this.ratesFromIDR,
    required this.hotelPrices,
    required this.transportPrices,
    required this.redeemVoucher,
    required this.redeemVoucherSub,
    required this.redeem,
    required this.timezone,
    required this.activeLocation,
    required this.referenceTimezones,
    required this.timeDifference,
    required this.activeZone,
    required this.hotels,
    required this.transport,
    required this.wisata,
    required this.allHotels,
    required this.allTransport,
    required this.allWisata,
    required this.noData,
    required this.stars,
    required this.lokaCatch,
    required this.lokaCatchDesc,
    required this.gyroscope,
    required this.newBadge,
    required this.totalCoins,
    required this.sessions,
    required this.highScore,
    required this.rewardCoins,
    required this.voucherExchange,
    required this.voucherExchangeSub,
    required this.gameOverMsg,
    required this.finalScore,
    required this.catchItems,
    required this.voucher,
    required this.voucherEmpty,
    required this.claimVoucher,
  });

  // ─── Bahasa Indonesia ──────────────────────────────────────────────────────
  static const AppStrings id = AppStrings._(
    langCode: 'id',
    appName: 'LokaLuxe',
    home: 'Beranda',
    profile: 'Profil',
    finance: 'Keuangan',
    miniGame: 'Mini Game',
    settings: 'Pengaturan',
    search: 'Cari',
    viewAll: 'Lihat Semua',
    close: 'Tutup',
    save: 'Simpan',
    cancel: 'Batal',
    loading: 'Memuat...',
    error: 'Terjadi Kesalahan',
    retry: 'Coba Lagi',
    offline: 'Mode Offline',
    play: 'Mainkan ▶',
    restart: 'Main Lagi',
    gameOver: 'Game Over!',
    currentLocation: 'LOKASI SAAT INI',
    greeting: 'Halo, {name}! 👋',
    tagline: "Ayo jelajahi",
    taglineHighlight: 'Nusantara!',
    budgetRemaining: 'Sisa Budget:',
    searchHint: 'Mau kemana hari ini?',
    categories: 'Kategori Pilihan',
    groupTours: 'Wisata Grup',
    popularIn: 'Terpopuler di Bali',
    topChoice: 'PILIHAN UTAMA',
    perPerson: '/ orang',
    perNight: '/ malam',
    perDay: '/ hari',
    pickLocation: 'Pilih Lokasi',
    pickLocationSubtitle: 'Mata uang & waktu disesuaikan otomatis',
    searchLocation: 'Cari kota atau negara...',
    locationNotFound: 'Lokasi tidak ditemukan',
    indonesia: 'INDONESIA',
    japan: 'JEPANG',
    eurozone: 'ZONA EURO',
    otherCountries: 'NEGARA LAINNYA',
    currency: 'Mata Uang',
    currencyDisplay: 'Mata Uang Tampilan',
    changeCurrency: 'Ubah',
    selectCurrency: 'Pilih mata uang yang digunakan di seluruh aplikasi',
    ratesUpdated: 'Kurs diperbarui:',
    ratesOffline: 'Gagal memperbarui kurs. Menggunakan data offline.',
    ratesLoading: 'Memperbarui kurs mata uang...',
    quickConverter: 'Konversi Cepat',
    pricesCatalog: 'Harga ditampilkan dalam',
    ratesFromIDR: 'Kurs dari IDR',
    hotelPrices: '🏨 Hotel Pilihan',
    transportPrices: '🚀 Transportasi',
    redeemVoucher: 'Tukar Koin dengan Voucher',
    redeemVoucherSub: 'Kumpulkan koin dari LokaCatch untuk voucher wisata eksklusif!',
    redeem: 'Klaim',
    timezone: 'Zona Waktu',
    activeLocation: 'Lokasi Aktif',
    referenceTimezones: 'Zona Waktu Referensi',
    timeDifference: 'Selisih Waktu (dari WIB)',
    activeZone: 'AKTIF',
    hotels: 'Hotel',
    transport: 'Transportasi',
    wisata: 'Wisata',
    allHotels: 'Semua Hotel',
    allTransport: 'Semua Transportasi',
    allWisata: 'Semua Wisata',
    noData: 'Data tidak tersedia',
    stars: 'bintang',
    lokaCatch: 'LokaCatch',
    lokaCatchDesc:
        'Miringkan HP untuk menangkap 10 bahan kuliner Nusantara. Hindari bom! Menangkan hingga 50 koin.',
    gyroscope: 'GYROSCOPE',
    newBadge: 'BARU',
    totalCoins: 'Total Koin',
    sessions: 'Sesi Main',
    highScore: 'High Score',
    rewardCoins: '+50 Koin',
    voucherExchange: 'Tukar Koin dengan Voucher',
    voucherExchangeSub:
        'Kumpulkan koin dari LokaCatch untuk mendapatkan voucher wisata eksklusif!',
    gameOverMsg: 'Kena Bom! Game Over 💥',
    finalScore: 'Skor Akhir',
    catchItems: 'Tangkap {caught}/{total} item',
    voucher: 'Voucher',
    voucherEmpty: 'Belum ada voucher tersedia',
    claimVoucher: 'Klaim Voucher',
  );

  // ─── English ───────────────────────────────────────────────────────────────
  static const AppStrings en = AppStrings._(
    langCode: 'en',
    appName: 'LokaLuxe',
    home: 'Home',
    profile: 'Profile',
    finance: 'Finance',
    miniGame: 'Mini Game',
    settings: 'Settings',
    search: 'Search',
    viewAll: 'View All',
    close: 'Close',
    save: 'Save',
    cancel: 'Cancel',
    loading: 'Loading...',
    error: 'Something Went Wrong',
    retry: 'Retry',
    offline: 'Offline Mode',
    play: 'Play ▶',
    restart: 'Play Again',
    gameOver: 'Game Over!',
    currentLocation: 'CURRENT LOCATION',
    greeting: 'Hello, {name}! 👋',
    tagline: "Let's explore the",
    taglineHighlight: 'Nusantara!',
    budgetRemaining: 'Budget Left:',
    searchHint: 'Where are you going?',
    categories: 'Categories',
    groupTours: 'Group Tours',
    popularIn: 'Popular in Bali',
    topChoice: 'TOP CHOICE',
    perPerson: '/ person',
    perNight: '/ night',
    perDay: '/ day',
    pickLocation: 'Pick Location',
    pickLocationSubtitle: 'Currency & time will adjust automatically',
    searchLocation: 'Search city or country...',
    locationNotFound: 'No location found',
    indonesia: 'INDONESIA',
    japan: 'JAPAN',
    eurozone: 'EUROZONE',
    otherCountries: 'OTHER COUNTRIES',
    currency: 'Currency',
    currencyDisplay: 'Display Currency',
    changeCurrency: 'Change',
    selectCurrency: 'Select the currency used across the app',
    ratesUpdated: 'Rates updated:',
    ratesOffline: 'Failed to update rates. Using offline data.',
    ratesLoading: 'Updating exchange rates...',
    quickConverter: 'Quick Converter',
    pricesCatalog: 'Prices shown in',
    ratesFromIDR: 'Rates from IDR',
    hotelPrices: '🏨 Featured Hotels',
    transportPrices: '🚀 Transport',
    redeemVoucher: 'Redeem Coins for Voucher',
    redeemVoucherSub: 'Collect LokaCatch coins to get exclusive travel vouchers!',
    redeem: 'Redeem',
    timezone: 'Time Zone',
    activeLocation: 'Active Location',
    referenceTimezones: 'Reference Time Zones',
    timeDifference: 'Time Difference (from WIB)',
    activeZone: 'ACTIVE',
    hotels: 'Hotels',
    transport: 'Transport',
    wisata: 'Attractions',
    allHotels: 'All Hotels',
    allTransport: 'All Transport',
    allWisata: 'All Attractions',
    noData: 'No data available',
    stars: 'stars',
    lokaCatch: 'LokaCatch',
    lokaCatchDesc:
        'Tilt your phone to catch 10 Nusantara culinary ingredients. Avoid bombs! Win up to 50 coins.',
    gyroscope: 'GYROSCOPE',
    newBadge: 'NEW',
    totalCoins: 'Total Coins',
    sessions: 'Sessions',
    highScore: 'High Score',
    rewardCoins: '+50 Coins',
    voucherExchange: 'Redeem Coins for Vouchers',
    voucherExchangeSub:
        'Collect coins from LokaCatch to get exclusive travel vouchers!',
    gameOverMsg: 'Hit a Bomb! Game Over 💥',
    finalScore: 'Final Score',
    catchItems: 'Caught {caught}/{total} items',
    voucher: 'Voucher',
    voucherEmpty: 'No vouchers available yet',
    claimVoucher: 'Claim Voucher',
  );

  /// Mendapatkan string dengan placeholder diganti.
  /// Contoh: s.greeting.fill({'name': 'Amalia'}) → "Halo, Amalia! 👋"
  String fill(Map<String, String> params) {
    String result = toString();
    params.forEach((key, value) {
      result = result.replaceAll('{$key}', value);
    });
    return result;
  }
}

// Ekstensi agar String juga bisa fill (untuk string yang diambil langsung)
extension StringFill on String {
  String fill(Map<String, String> params) {
    String result = this;
    params.forEach((key, value) {
      result = result.replaceAll('{$key}', value);
    });
    return result;
  }
}
