/// Kamus UI LokaLuxe untuk Bahasa Indonesia dan Bahasa Inggris.
///
/// Pilihan locale dikelola dan disimpan oleh [LocalizationProvider].

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
  final String changeLanguage;
  final String selectLanguage;
  final String indonesianLanguage;
  final String englishLanguage;
  final String explore;
  final String navigator;
  final String concierge;
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
  final String greeting; // "Hello, {name}! 👋"
  final String tagline; // "Let's traveling the"
  final String taglineHighlight; // "Nusantara!"
  final String budgetRemaining; // "Sisa Budget:"
  final String searchHint; // "Where are you going?"
  final String categories;
  final String groupTours;
  final String popularIn;
  final String topChoice;
  final String perPerson;
  final String perNight;
  final String perDay;

  // ── Lokasi ────────────────────────────────────────────────────────────────
  final String pickLocation;
  final String pickLocationSubtitle;
  final String searchLocation; // placeholder search modal
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
  final String redeem;

  // ── Zona Waktu ────────────────────────────────────────────────────────────
  final String timezone;
  final String activeLocation;
  final String referenceTimezones;
  final String timeDifference; // "Selisih Waktu (dari WIB)"
  final String activeZone; // badge "AKTIF"

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
  final String voucherExchange;
  final String voucherExchangeSub;
  final String gameOverMsg;
  final String finalScore;
  final String catchItems;

  // ── Voucher ───────────────────────────────────────────────────────────────
  final String voucher;
  final String voucherEmpty;
  final String claimVoucher;

  // ── Profil & Pengaturan ──────────────────────────────────────────────────
  final String accountPreferences;
  final String editProfile;
  final String profilePhotoSubtitle;
  final String securityBiometrics;
  final String securitySubtitle;
  final String feedback;
  final String feedbackSubtitle;
  final String tripsCompleted;
  final String activeVouchers;
  final String languageSetting;
  final String localMember;
  final String feedbackTitle;
  final String feedbackDescription;
  final String feedbackHint;
  final String submitFeedback;
  final String logout;
  final String gameInstructions;
  final String tiltToMove;
  final String swipeOrButtons;
  final String catchFood;
  final String avoidBomb;
  final String catchTenForVoucher;
  final String gyroUnavailable;
  final String manualControls;
  final String startPlaying;
  final String caughtSummary;
  final String caughtCount;
  final String greatJob;
  final String rewardPrefix;
  final String voucherCode;
  final String reference;
  final String notificationFailure;
  final String notificationUnavailable;
  final String rewardDataUnavailable;
  final String voucherSaveFailure;
  final String loginTitle;
  final String loginSubtitle;
  final String emailHint;
  final String passwordHint;
  final String signIn;
  final String quickSignIn;
  final String noAccount;
  final String hasAccount;
  final String createAccount;
  final String registerTitle;
  final String registerSubtitle;
  final String nameHint;
  final String termsText;
  final String acceptTermsError;
  final String startAdventure;
  final String loginRequired;
  final String itineraryTitle;
  final String tripDetails;
  final String destinationHint;
  final String tripDuration;
  final String travelerCount;
  final String saveTripDetails;
  final String saveTripChanges;
  final String day;
  final String hotelCatalogTitle;
  final String hotelCatalogSubtitle;
  final String transportCatalogTitle;
  final String transportCatalogSubtitle;
  final String attractionCatalogTitle;
  final String searchAttractions;
  final String searchHotels;
  final String searchTransport;
  final String budgetPlanner;
  final String budgetLimit;
  final String estimatedSpend;
  final String amountHint;
  final String searchPlaces;
  final String askTravel;
  final String travelAssistant;
  final String conciergePromptItinerary;
  final String conciergePromptBudget;
  final String conciergePromptAttractions;
  final String swapCurrencies;
  final String hoursFromWib;

  const AppStrings._({
    required this.langCode,
    required this.appName,
    required this.home,
    required this.profile,
    required this.finance,
    required this.miniGame,
    required this.settings,
    required this.changeLanguage,
    required this.selectLanguage,
    required this.indonesianLanguage,
    required this.englishLanguage,
    required this.explore,
    required this.navigator,
    required this.concierge,
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
    required this.voucherExchange,
    required this.voucherExchangeSub,
    required this.gameOverMsg,
    required this.finalScore,
    required this.catchItems,
    required this.voucher,
    required this.voucherEmpty,
    required this.claimVoucher,
    required this.accountPreferences,
    required this.editProfile,
    required this.profilePhotoSubtitle,
    required this.securityBiometrics,
    required this.securitySubtitle,
    required this.feedback,
    required this.feedbackSubtitle,
    required this.tripsCompleted,
    required this.activeVouchers,
    required this.languageSetting,
    required this.localMember,
    required this.feedbackTitle,
    required this.feedbackDescription,
    required this.feedbackHint,
    required this.submitFeedback,
    required this.logout,
    required this.gameInstructions,
    required this.tiltToMove,
    required this.swipeOrButtons,
    required this.catchFood,
    required this.avoidBomb,
    required this.catchTenForVoucher,
    required this.gyroUnavailable,
    required this.manualControls,
    required this.startPlaying,
    required this.caughtSummary,
    required this.caughtCount,
    required this.greatJob,
    required this.rewardPrefix,
    required this.voucherCode,
    required this.reference,
    required this.notificationFailure,
    required this.notificationUnavailable,
    required this.rewardDataUnavailable,
    required this.voucherSaveFailure,
    required this.loginTitle,
    required this.loginSubtitle,
    required this.emailHint,
    required this.passwordHint,
    required this.signIn,
    required this.quickSignIn,
    required this.noAccount,
    required this.hasAccount,
    required this.createAccount,
    required this.registerTitle,
    required this.registerSubtitle,
    required this.nameHint,
    required this.termsText,
    required this.acceptTermsError,
    required this.startAdventure,
    required this.loginRequired,
    required this.itineraryTitle,
    required this.tripDetails,
    required this.destinationHint,
    required this.tripDuration,
    required this.travelerCount,
    required this.saveTripDetails,
    required this.saveTripChanges,
    required this.day,
    required this.hotelCatalogTitle,
    required this.hotelCatalogSubtitle,
    required this.transportCatalogTitle,
    required this.transportCatalogSubtitle,
    required this.attractionCatalogTitle,
    required this.searchAttractions,
    required this.searchHotels,
    required this.searchTransport,
    required this.budgetPlanner,
    required this.budgetLimit,
    required this.estimatedSpend,
    required this.amountHint,
    required this.searchPlaces,
    required this.askTravel,
    required this.travelAssistant,
    required this.conciergePromptItinerary,
    required this.conciergePromptBudget,
    required this.conciergePromptAttractions,
    required this.swapCurrencies,
    required this.hoursFromWib,
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
    changeLanguage: 'Pilih Bahasa',
    selectLanguage: 'Pilih bahasa aplikasi',
    indonesianLanguage: 'Bahasa Indonesia',
    englishLanguage: 'Bahasa Inggris',
    explore: 'Jelajah',
    navigator: 'Navigasi',
    concierge: 'Concierge',
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
    popularIn: 'Wisata Populer',
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
    lokaCatchDesc: 'Miringkan HP atau geser layar untuk menangkap 10 hidangan khas Indonesia. Hindari bom dan menangkan voucher!',
    gyroscope: 'GYROSCOPE',
    newBadge: 'BARU',
    voucherExchange: 'Hadiah Voucher LokaCatch',
    voucherExchangeSub:
        'Menangkan permainan LokaCatch untuk mendapatkan voucher diskon.',
    gameOverMsg: 'Kena Bom! Game Over 💥',
    finalScore: 'Skor Akhir',
    catchItems: 'Tangkap {caught}/{total} item',
    voucher: 'Voucher',
    voucherEmpty: 'Belum ada voucher tersedia',
    claimVoucher: 'Klaim Voucher',
    accountPreferences: 'Akun & preferensi',
    editProfile: 'Ubah profil',
    profilePhotoSubtitle: 'Tambah atau ubah foto profil',
    securityBiometrics: 'Keamanan & biometrik',
    securitySubtitle: 'PIN, sidik jari, dan Face ID',
    feedback: 'Kritik & saran',
    feedbackSubtitle: 'Pemrograman Aplikasi Mobile',
    tripsCompleted: 'Perjalanan selesai',
    activeVouchers: 'Voucher aktif',
    languageSetting: 'Bahasa',
    localMember: 'Anggota LokaLuxe',
    feedbackTitle: 'Kritik dan saran',
    feedbackDescription: 'Bagikan kritik atau saran untuk aplikasi ini.',
    feedbackHint: 'Tulis kritik dan saran di sini...',
    submitFeedback: 'Kirim masukan',
    logout: 'Keluar Akun',
    gameInstructions:
        'Tangkap 10 hidangan khas Indonesia!\nHindari 💣 agar tidak Game Over.',
    tiltToMove: 'Miringkan HP untuk menggerakkan komodo',
    swipeOrButtons: 'Geser layar atau gunakan tombol ◀ ▶',
    catchFood: 'Tangkap hidangan Indonesia (+1 item)',
    avoidBomb: 'Hindari bom! (Game Over seketika)',
    catchTenForVoucher: 'Tangkap 10 item untuk mendapatkan voucher!',
    gyroUnavailable: 'Gyroscope tidak tersedia.\nMode kontrol manual aktif.',
    manualControls: 'KONTROL MANUAL',
    startPlaying: 'Mulai Bermain!',
    caughtSummary: 'Kamu berhasil menangkap {count} item kuliner Nusantara!',
    caughtCount: 'Item berhasil ditangkap: {count}',
    greatJob: 'Luar Biasa!',
    rewardPrefix: '🎫 Selamat! Kamu mendapatkan {discount}',
    voucherCode: 'Kode voucher: {code}',
    reference: 'Ref: {reference}',
    notificationFailure: 'Notifikasi hadiah gagal ditampilkan.',
    notificationUnavailable:
        'Notifikasi hadiah tidak tersedia di perangkat ini.',
    rewardDataUnavailable:
        'Data hadiah hotel/pesawat tidak tersedia. Muat ulang katalog hotel dan pesawat, lalu coba lagi.',
    voucherSaveFailure:
        'Voucher belum berhasil disimpan. Periksa koneksi dan akun online, lalu hubungi dukungan jika masalah berlanjut.',
    loginTitle: 'Masuk ke LokaLuxe',
    loginSubtitle: 'Kelola anggaran dan rute perjalanan mewahmu dengan mudah.',
    emailHint: 'Masukkan email Anda',
    passwordHint: 'Masukkan kata sandi Anda',
    signIn: 'Masuk',
    quickSignIn: 'atau masuk cepat',
    noAccount: 'Belum punya akun? ',
    hasAccount: 'Sudah punya akun? ',
    createAccount: 'Buat akun',
    registerTitle: 'Buat akun Anda',
    registerSubtitle: 'Mulai rencanakan perjalanan berkesan bersama kami.',
    nameHint: 'Masukkan nama lengkap Anda',
    termsText:
        'Saya menyetujui Syarat Layanan dan Kebijakan Privasi LokaLuxe.',
    acceptTermsError:
        'Anda harus menyetujui Syarat Layanan dan Kebijakan Privasi.',
    startAdventure: 'Mulai petualanganmu bersama kami',
    loginRequired: 'Email dan kata sandi wajib diisi.',
    itineraryTitle: 'Itinerary Perjalanan',
    tripDetails: 'Detail perjalanan',
    destinationHint: 'Mau ke mana?',
    tripDuration: 'Durasi perjalanan',
    travelerCount: 'Jumlah orang',
    saveTripDetails: 'Simpan detail trip',
    saveTripChanges: 'Simpan perubahan trip',
    day: 'Hari',
    hotelCatalogTitle: 'Katalog Hotel Nusantara',
    hotelCatalogSubtitle: 'Pilihan hotel di seluruh Indonesia',
    transportCatalogTitle: 'Transportasi Nusantara',
    transportCatalogSubtitle: 'Pesawat, kereta, bus, kapal, dan kendaraan sewa',
    attractionCatalogTitle: 'Destinasi Wisata Indonesia',
    searchAttractions: 'Cari wisata, kota, atau provinsi',
    searchHotels: 'Cari nama hotel, kota, atau provinsi',
    searchTransport: 'Cari nama, rute, operator, atau provinsi',
    budgetPlanner: 'Perencana Budget Perjalanan',
    budgetLimit: 'BATAS BUDGET',
    estimatedSpend: 'Estimasi pengeluaran maksimum',
    amountHint: 'Masukkan jumlah',
    searchPlaces: 'Cari tempat, wisata, atau kuliner',
    askTravel: 'Tanyakan seputar perjalanan...',
    travelAssistant: 'Asisten perjalanan LokaLuxe',
    conciergePromptItinerary: 'Buat itinerary 3 hari di Bali',
    conciergePromptBudget: 'Bagaimana mengatur budget trip?',
    conciergePromptAttractions: 'Rekomendasikan wisata di Yogyakarta',
    swapCurrencies: 'Tukar mata uang',
    hoursFromWib: '{hours} jam dari WIB',
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
    changeLanguage: 'Change Language',
    selectLanguage: 'Choose app language',
    indonesianLanguage: 'Indonesian',
    englishLanguage: 'English',
    explore: 'Explore',
    navigator: 'Navigator',
    concierge: 'Concierge',
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
    popularIn: 'Popular Attractions',
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
    lokaCatchDesc: 'Tilt your phone or swipe to catch 10 Indonesian dishes. Avoid bombs and win a voucher!',
    gyroscope: 'GYROSCOPE',
    newBadge: 'NEW',
    voucherExchange: 'LokaCatch Voucher Reward',
    voucherExchangeSub: 'Win LokaCatch to receive a discount voucher.',
    gameOverMsg: 'Hit a Bomb! Game Over 💥',
    finalScore: 'Final Score',
    catchItems: 'Caught {caught}/{total} items',
    voucher: 'Voucher',
    voucherEmpty: 'No vouchers available yet',
    claimVoucher: 'Claim Voucher',
    accountPreferences: 'Account & preferences',
    editProfile: 'Edit personal profile',
    profilePhotoSubtitle: 'Add or change your profile photo',
    securityBiometrics: 'Security & biometrics',
    securitySubtitle: 'PIN, fingerprint and Face ID',
    feedback: 'Feedback',
    feedbackSubtitle: 'Mobile Application Programming',
    tripsCompleted: 'Trips completed',
    activeVouchers: 'Active vouchers',
    languageSetting: 'Language',
    localMember: 'LokaLuxe Member',
    feedbackTitle: 'Feedback',
    feedbackDescription: 'Share feedback or suggestions about the app.',
    feedbackHint: 'Write your feedback here...',
    submitFeedback: 'Send feedback',
    logout: 'Log out',
    gameInstructions:
        'Catch 10 Indonesian dishes!\nAvoid 💣 to prevent Game Over.',
    tiltToMove: 'Tilt your phone to move the komodo',
    swipeOrButtons: 'Swipe the screen or use the ◀ ▶ buttons',
    catchFood: 'Catch Indonesian dishes (+1 item)',
    avoidBomb: 'Avoid bombs! (Instant Game Over)',
    catchTenForVoucher: 'Catch 10 items to earn a voucher!',
    gyroUnavailable: 'Gyroscope unavailable.\nManual controls are enabled.',
    manualControls: 'MANUAL CONTROLS',
    startPlaying: 'Start Playing!',
    caughtSummary: 'You caught {count} Nusantara food items!',
    caughtCount: 'Items caught: {count}',
    greatJob: 'Great job!',
    rewardPrefix: '🎫 Congratulations! You earned {discount}',
    voucherCode: 'Voucher code: {code}',
    reference: 'Ref: {reference}',
    notificationFailure: 'Could not display the reward notification.',
    notificationUnavailable: 'Reward notifications are unavailable on this device.',
    rewardDataUnavailable:
        'Hotel/flight reward data is unavailable. Refresh the hotel and flight catalogs and try again.',
    voucherSaveFailure:
        'Could not save the voucher. Check your connection and online account, then contact support if the issue continues.',
    loginTitle: 'Sign in to LokaLuxe',
    loginSubtitle: 'Easily manage your budget and luxury travel routes.',
    emailHint: 'Enter your email',
    passwordHint: 'Enter your password',
    signIn: 'Sign in',
    quickSignIn: 'or sign in quickly',
    noAccount: "Don't have an account? ",
    hasAccount: 'Already have an account? ',
    createAccount: 'Create an account',
    registerTitle: 'Create your account',
    registerSubtitle: 'Start planning thoughtful trips with us.',
    nameHint: 'Enter your full name',
    termsText:
        'I agree to the LokaLuxe Terms of Service and Privacy Policy.',
    acceptTermsError:
        'You must accept the Terms of Service and Privacy Policy.',
    startAdventure: 'Start your adventure with us',
    loginRequired: 'Email and password are required.',
    itineraryTitle: 'Trip itinerary',
    tripDetails: 'Trip details',
    destinationHint: 'Where are you going?',
    tripDuration: 'Trip duration',
    travelerCount: 'Number of travelers',
    saveTripDetails: 'Save trip details',
    saveTripChanges: 'Save trip changes',
    day: 'Day',
    hotelCatalogTitle: 'Indonesian Hotel Catalog',
    hotelCatalogSubtitle: 'Hotel stays across Indonesia',
    transportCatalogTitle: 'Indonesian Transport',
    transportCatalogSubtitle: 'Flights, trains, buses, boats and rentals',
    attractionCatalogTitle: 'Indonesian Attractions',
    searchAttractions: 'Search attractions, cities, or provinces',
    searchHotels: 'Search hotels, cities, or provinces',
    searchTransport: 'Search names, routes, operators, or provinces',
    budgetPlanner: 'Trip Budget Planner',
    budgetLimit: 'BUDGET LIMIT',
    estimatedSpend: 'Estimated maximum spend',
    amountHint: 'Enter amount',
    searchPlaces: 'Search places, attractions, or food',
    askTravel: 'Ask about your trip...',
    travelAssistant: 'LokaLuxe travel assistant',
    conciergePromptItinerary: 'Plan a 3-day Bali itinerary',
    conciergePromptBudget: 'How do I manage my trip budget?',
    conciergePromptAttractions: 'Recommend attractions in Yogyakarta',
    swapCurrencies: 'Swap currencies',
    hoursFromWib: '{hours} hours from WIB',
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

  String localized(String indonesian, String english) =>
      langCode == 'en' ? english : indonesian;
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
