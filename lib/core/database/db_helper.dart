import 'package:flutter/foundation.dart';
import 'database_initializer.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/expense_model.dart';
import '../models/hotel_model.dart';
import '../models/transport_model.dart';
import '../models/trip_model.dart';
import '../models/trip_itinerary_day_model.dart';
import '../models/user_model.dart';
import '../security/password_hasher.dart';
import 'hotel_seed_data.dart';
import 'transport_seed_data.dart';

enum TripItemSaveResult { saved, budgetExceeded, duplicate, noActiveTrip }

class DBHelper {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  static Future<Database> _initDB() async {
    initializeDatabase();

    final String path;
    if (kIsWeb) {
      path = 'lokaluxe_local.db';
    } else {
      final dbPath = await getDatabasesPath();
      path = join(dbPath, 'lokaluxe_local.db');
    }

    final db = await openDatabase(
      path,
      version: 7,
      onCreate: (db, version) async {
        // 1. Table Users dengan Enkripsi PBKDF2 / SHA-256 & Salt
        await _createUsersTable(db);
        await _seedDefaultUser(db);

        // 2. Table Trips (Budget Planner)
        await db.execute('''
          CREATE TABLE trips (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            destination TEXT,
            destinationTitle TEXT,
            dates TEXT,
            duration TEXT,
            durationDays INTEGER,
            travelerCount INTEGER,
            currency TEXT,
            targetBudget REAL,
            transportAllocation REAL,
            hotelAllocation REAL,
            culinaryAllocation REAL,
            activityAllocation REAL,
            status TEXT
          )
        ''');

        // 3. Table Expenses (Finance Hub)
        await db.execute('''
          CREATE TABLE expenses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,
            category TEXT,
            amount REAL,
            date TEXT,
            isIncome INTEGER,
            tripId INTEGER
          )
        ''');

        // 4. Table Feedback (Saran & Kesan)
        await db.execute('''
          CREATE TABLE feedback (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            userEmail TEXT,
            rating INTEGER,
            comment TEXT,
            createdAt TEXT
          )
        ''');

        // 5. Table Hotels (Database Hotel Se-Indonesia)
        await _createHotelsTable(db);

        await _createTripItemsTable(db);
        await _createTripItineraryDaysTable(db);

        // Seed data hotel
        await _seedHotels(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 3) {
          await db.execute('DROP TABLE IF EXISTS hotels');
          await _createHotelsTable(db);
          await _seedHotels(db);
        }
        if (oldVersion < 4) {
          // Migrasi tabel users untuk enkripsi salt & passwordHash
          try {
            final tableInfo = await db.rawQuery('PRAGMA table_info(users)');
            final hasSalt = tableInfo.any((c) => c['name'] == 'salt');
            if (!hasSalt) {
              await db.execute('ALTER TABLE users ADD COLUMN salt TEXT');
              await db.execute('ALTER TABLE users ADD COLUMN passwordHash TEXT');
              await db.execute('ALTER TABLE users ADD COLUMN createdAt TEXT');
            }

            // Migrasi akun lama yang masih memakai kolom password plaintext
            final legacyUsers = await db.query('users');
            for (final u in legacyUsers) {
              final rawHash = u['passwordHash'] as String?;
              if (rawHash == null || rawHash.isEmpty) {
                final plain = (u['password'] ?? 'password123').toString();
                final salt = PasswordHasher.generateSalt();
                final hash = PasswordHasher.hashPassword(plain, salt);
                await db.update(
                  'users',
                  {
                    'passwordHash': hash,
                    'salt': salt,
                    'createdAt': DateTime.now().toIso8601String(),
                  },
                  where: 'id = ?',
                  whereArgs: [u['id']],
                );
              }
            }
          } catch (_) {
            await _createUsersTable(db);
            await _seedDefaultUser(db);
          }
        }
        if (oldVersion < 5) {
          // Migrasi: tambah kolom biometricEnabled ke tabel users
          try {
            final tableInfo = await db.rawQuery('PRAGMA table_info(users)');
            final hasBiometric =
                tableInfo.any((c) => c['name'] == 'biometricEnabled');
            if (!hasBiometric) {
              await db.execute(
                'ALTER TABLE users ADD COLUMN biometricEnabled INTEGER DEFAULT 0',
              );
            }
            // Aktifkan untuk akun default demo agar pengguna bisa langsung mencoba fitur biometrik
            await db.rawUpdate(
              "UPDATE users SET biometricEnabled = 1 WHERE LOWER(email) = 'amalia@localluxe.id'",
            );
          } catch (_) {}
        }
        if (oldVersion < 6) {
          final tripColumns =
              await db.rawQuery('PRAGMA table_info(trips)');
          final tripColumnNames =
              tripColumns.map((column) => column['name']).toSet();
          if (!tripColumnNames.contains('durationDays')) {
            await db.execute('ALTER TABLE trips ADD COLUMN durationDays INTEGER');
          }
          if (!tripColumnNames.contains('travelerCount')) {
            await db.execute('ALTER TABLE trips ADD COLUMN travelerCount INTEGER');
          }

          final expenseColumns =
              await db.rawQuery('PRAGMA table_info(expenses)');
          if (!expenseColumns.any((column) => column['name'] == 'tripId')) {
            await db.execute('ALTER TABLE expenses ADD COLUMN tripId INTEGER');
          }

          await _createTripItemsTable(db);
          await db.delete(
            'trips',
            where: '''
              destination = ? AND destinationTitle = ? AND dates = ?
              AND targetBudget = ? AND status = ?
            ''',
            whereArgs: [
              'Yogyakarta',
              'Yogyakarta (DIY)',
              '24 Okt - 28 Okt 2026',
              5000000.0,
              'active',
            ],
          );
          await db.delete(
            'expenses',
            where: '(title = ? AND category = ? AND amount = ?) OR '
                '(title = ? AND category = ? AND amount = ?)',
            whereArgs: [
              'Kopi Klotok & Pisang Goreng',
              'Kuliner',
              25000.0,
              'Parkir Area Malioboro',
              'Transport',
              15000.0,
            ],
          );
        }
        if (oldVersion < 7) {
          await _createTripItineraryDaysTable(db);
        }
      },
    );

    // Pastikan tabel users terbuat dan memiliki data seed
    await _createUsersTable(db);
    await _seedDefaultUser(db);

    // Isi tabel wisata dari file assets/db/lokaluxe_wisata.sqlite (hanya sekali)
    await _importWisataIfEmpty(db);

    // Buat & isi tabel transportasi (hanya sekali)
    await _ensureTransports(db);
    return db;
  }

  // --- TABEL USERS & SEED ---
  static Future<void> _createUsersTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fullName TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        passwordHash TEXT NOT NULL,
        salt TEXT NOT NULL,
        currency TEXT,
        createdAt TEXT,
        biometricEnabled INTEGER DEFAULT 0,
        fingerprintEnabled INTEGER DEFAULT 0,
        faceIdEnabled INTEGER DEFAULT 0,
        securityPin TEXT
      )
    ''');
    await _ensureUserSecurityColumns(db);
  }

  static Future<void> _ensureUserSecurityColumns(Database db) async {
    try {
      final info = await db.rawQuery('PRAGMA table_info(users)');
      final colNames = info.map((c) => c['name'].toString()).toSet();
      if (!colNames.contains('biometricEnabled')) {
        await db.execute('ALTER TABLE users ADD COLUMN biometricEnabled INTEGER DEFAULT 0');
      }
      if (!colNames.contains('fingerprintEnabled')) {
        await db.execute('ALTER TABLE users ADD COLUMN fingerprintEnabled INTEGER DEFAULT 0');
      }
      if (!colNames.contains('faceIdEnabled')) {
        await db.execute('ALTER TABLE users ADD COLUMN faceIdEnabled INTEGER DEFAULT 0');
      }
      if (!colNames.contains('securityPin')) {
        await db.execute('ALTER TABLE users ADD COLUMN securityPin TEXT');
      }
    } catch (_) {}
  }

  static Future<void> _seedDefaultUser(Database db) async {
    final count = Sqflite.firstIntValue(
          await db.rawQuery(
            "SELECT COUNT(*) FROM users WHERE LOWER(email) = 'amalia@localluxe.id'",
          ),
        ) ??
        0;

    if (count == 0) {
      final salt = PasswordHasher.generateSalt();
      final hash = PasswordHasher.hashPassword('password123', salt);
      await db.insert('users', {
        'fullName': 'Amalia Nur Azizah',
        'email': 'amalia@localluxe.id',
        'passwordHash': hash,
        'salt': salt,
        'currency': 'IDR (Rupiah Indonesia)',
        'createdAt': DateTime.now().toIso8601String(),
        'biometricEnabled': 1,
      });
    }
  }

  static Future<void> _importWisataIfEmpty(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS wisata (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        kategori TEXT NOT NULL,
        nama_wisata TEXT NOT NULL,
        latitude REAL,
        longitude REAL,
        alamat TEXT,
        provinsi TEXT,
        kota_kabupaten TEXT,
        nama_lengkap TEXT,
        deskripsi TEXT,
        image_url TEXT,
        harga_tiket REAL
      )
    ''');

    // Database lama (sebelum ada harga): tambahkan kolom harga_tiket
    final kolom = await db.rawQuery('PRAGMA table_info(wisata)');
    final adaHarga = kolom.any((c) => c['name'] == 'harga_tiket');
    if (!adaHarga) {
      await db.execute('ALTER TABLE wisata ADD COLUMN harga_tiket REAL');
    }

    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_wisata_provinsi ON wisata(provinsi)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_wisata_kategori ON wisata(kategori)');

    final count = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM wisata'),
        ) ??
        0;
    if (count > 0) {
      await _isiHargaWisata(db); // isi harga untuk data yang belum punya
      return;
    }

    // 1. Salin file sqlite dari assets ke penyimpanan database
    final bytes = await rootBundle.load('assets/db/lokaluxe_wisata.sqlite');
    final uint8List = bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
    final String tmpPath;
    if (kIsWeb) {
      tmpPath = 'wisata_source.db';
    } else {
      final dbPath = await getDatabasesPath();
      tmpPath = join(dbPath, 'wisata_source.db');
    }
    await databaseFactory.writeDatabaseBytes(tmpPath, uint8List);

    // 2. Baca semua baris, lalu masukkan ke database utama
    final src = await openDatabase(tmpPath, readOnly: true);
    final rows = await src.query('wisata');
    await src.close();

    final batch = db.batch();
    for (final r in rows) {
      batch.insert('wisata', {
        'kategori': r['kategori'],
        'nama_wisata': r['nama_wisata'],
        'latitude': r['latitude'],
        'longitude': r['longitude'],
        'alamat': r['alamat'],
        'provinsi': r['provinsi'],
        'kota_kabupaten': r['kota_kabupaten'],
        'nama_lengkap': r['nama_lengkap'],
        'deskripsi': r['deskripsi'],
        'image_url': r['image_url'],
        'harga_tiket': r['harga_tiket'],
      });
    }
    await batch.commit(noResult: true);

    // 3. Hapus database sementara
    try {
      await databaseFactory.deleteDatabase(tmpPath);
    } catch (_) {}

    // 4. Isi estimasi harga tiket
    await _isiHargaWisata(db);
  }

  static Future<void> _isiHargaWisata(Database db) async {
    await db.execute('''
      UPDATE wisata SET harga_tiket = CASE LOWER(REPLACE(TRIM(kategori), '  ', ' '))
        WHEN 'pantai' THEN 10000
        WHEN 'gunung' THEN 20000
        WHEN 'air terjun' THEN 15000
        WHEN 'bukit' THEN 10000
        WHEN 'lembah' THEN 15000
        WHEN 'candi' THEN 50000
        WHEN 'museum' THEN 15000
        WHEN 'kebun binatang' THEN 60000
        WHEN 'wahana keluarga' THEN 100000
        WHEN 'wisata tematik' THEN 75000
        WHEN 'wisata edukasi' THEN 25000
        WHEN 'wisata kerajaan' THEN 20000
        WHEN 'rumah adat' THEN 10000
        WHEN 'monumen' THEN 10000
        WHEN 'taman' THEN 5000
        WHEN 'wisata alam' THEN 15000
        WHEN 'wisata lampion' THEN 30000
        WHEN 'wisata religi' THEN 5000
        WHEN 'wisata kuliner' THEN 50000
        WHEN 'alun-alun' THEN 5000
        WHEN 'mall' THEN 20000
        WHEN 'cafe view' THEN 50000
        ELSE 10000
      END
      WHERE harga_tiket IS NULL OR harga_tiket = 0
    ''');
  }

  static Future<void> _createHotelsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS hotels (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        province TEXT NOT NULL,
        city TEXT NOT NULL,
        stars INTEGER,
        price_per_night REAL NOT NULL,
        latitude REAL,
        longitude REAL,
        address TEXT,
        image_url TEXT
      )
    ''');
  }

  static Future<void> _seedHotels(Database db) async {
    final count = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM hotels'),
        ) ??
        0;
    if (count > 0) return;

    final batch = db.batch();
    for (final h in hotelSeedData) {
      batch.insert('hotels', h);
    }
    await batch.commit(noResult: true);
  }

  // ---------- TRANSPORTASI ----------
  static Future<void> _ensureTransports(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS transports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        category TEXT,
        operator_name TEXT,
        province TEXT NOT NULL,
        route TEXT,
        price REAL NOT NULL,
        description TEXT,
        image_url TEXT
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_transports_type ON transports(type)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_transports_province ON transports(province)');

    final count = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM transports'),
        ) ??
        0;
    if (count > 0) return;

    final batch = db.batch();
    for (final t in transportSeedData) {
      batch.insert('transports', t);
    }
    await batch.commit(noResult: true);
  }

  static Future<List<Map<String, dynamic>>> getTransports({
    String? type,
    String? province,
  }) async {
    final db = await database;
    final where = <String>[];
    final args = <Object?>[];
    if (type != null) {
      where.add('type = ?');
      args.add(type);
    }
    if (province != null) {
      where.add('province = ?');
      args.add(province);
    }
    return db.query(
      'transports',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'type ASC, price ASC',
    );
  }

  static Future<List<TransportModel>> getTransportModels() async {
    final maps = await getTransports();
    return maps.map((m) => TransportModel.fromMap(m)).toList();
  }

  // --- USER AUTH OPERATIONS (SQLITE + PBKDF2/SHA-256) ---

  /// Mendaftarkan user baru dengan password yang sudah di-hash beserta salt unik
  static Future<int> registerUser(UserModel user) async {
    final db = await database;
    try {
      return await db.insert('users', user.toMap());
    } catch (e) {
      return -1; // -1 jika email sudah terdaftar (UNIQUE constraint)
    }
  }

  /// Memvalidasi kredensial login dengan membandingkan hash password input + salt
  static Future<UserModel?> loginUser(
    String email,
    String plainPassword,
  ) async {
    final user = await getUserByEmail(email);
    if (user == null) return null;

    final isValid = PasswordHasher.verifyPassword(
      plainPassword,
      user.passwordHash,
      user.salt,
    );

    if (isValid) {
      return user;
    }
    return null;
  }

  /// Mengambil data user berdasarkan email
  static Future<UserModel?> getUserByEmail(String email) async {
    final db = await database;
    final res = await db.query(
      'users',
      where: 'LOWER(email) = ?',
      whereArgs: [email.trim().toLowerCase()],
      limit: 1,
    );
    if (res.isNotEmpty) {
      return UserModel.fromMap(res.first);
    }
    return null;
  }

  /// Mengambil data user berdasarkan ID
  static Future<UserModel?> getUserById(int id) async {
    final db = await database;
    final res = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (res.isNotEmpty) {
      return UserModel.fromMap(res.first);
    }
    return null;
  }

  /// Memperbarui status biometrik user di SQLite
  static Future<void> updateUserBiometric(int userId, bool enabled) async {
    final db = await database;
    await db.update(
      'users',
      {
        'biometricEnabled': enabled ? 1 : 0,
        'fingerprintEnabled': enabled ? 1 : 0,
        'faceIdEnabled': enabled ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  /// Memperbarui pengaturan biometrik & keamanan user (Sidik Jari, Face ID, PIN)
  static Future<void> updateUserBiometricSettings(
    int userId, {
    bool? biometricEnabled,
    bool? fingerprintEnabled,
    bool? faceIdEnabled,
    String? securityPin,
  }) async {
    final db = await database;
    final values = <String, dynamic>{};
    if (biometricEnabled != null) {
      values['biometricEnabled'] = biometricEnabled ? 1 : 0;
    }
    if (fingerprintEnabled != null) {
      values['fingerprintEnabled'] = fingerprintEnabled ? 1 : 0;
      if (fingerprintEnabled) values['biometricEnabled'] = 1;
    }
    if (faceIdEnabled != null) {
      values['faceIdEnabled'] = faceIdEnabled ? 1 : 0;
      if (faceIdEnabled) values['biometricEnabled'] = 1;
    }
    if (securityPin != null) {
      values['securityPin'] = securityPin;
    }
    if (values.isNotEmpty) {
      await db.update('users', values, where: 'id = ?', whereArgs: [userId]);
    }
  }

  /// Mengambil pengaturan biometrik user lengkap
  static Future<Map<String, dynamic>> getUserSecuritySettings(int userId) async {
    final db = await database;
    final res = await db.query(
      'users',
      columns: [
        'biometricEnabled',
        'fingerprintEnabled',
        'faceIdEnabled',
        'securityPin',
      ],
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (res.isNotEmpty) {
      final row = res.first;
      final bio = (row['biometricEnabled'] as int? ?? 0) == 1;
      final fp = (row['fingerprintEnabled'] as int? ?? (bio ? 1 : 0)) == 1;
      final face = (row['faceIdEnabled'] as int? ?? (bio ? 1 : 0)) == 1;
      return {
        'biometricEnabled': bio || fp || face,
        'fingerprintEnabled': fp,
        'faceIdEnabled': face,
        'securityPin': row['securityPin'] as String?,
      };
    }
    return {
      'biometricEnabled': false,
      'fingerprintEnabled': false,
      'faceIdEnabled': false,
      'securityPin': null,
    };
  }

  /// Mengambil status biometrik user dari SQLite
  static Future<bool> getUserBiometricStatus(int userId) async {
    final settings = await getUserSecuritySettings(userId);
    return (settings['biometricEnabled'] == true) ||
        (settings['fingerprintEnabled'] == true) ||
        (settings['faceIdEnabled'] == true);
  }

  // --- TRIP & BUDGET OPERATIONS ---
  static Future<int> saveTrip(TripModel trip) async {
    final db = await database;
    return db.transaction((txn) async {
      await txn.update(
        'trips',
        {'status': 'archived'},
        where: 'status = ?',
        whereArgs: ['active'],
      );
      return txn.insert('trips', trip.toMap());
    });
  }

  static Future<int> saveTripWithItinerary({
    required TripModel trip,
    required List<TripItineraryDay> days,
  }) async {
    final db = await database;
    return db.transaction((txn) async {
      await txn.update(
        'trips',
        {'status': 'archived'},
        where: 'status = ?',
        whereArgs: ['active'],
      );
      final tripId = await txn.insert('trips', trip.toMap());
      for (final day in days) {
        await txn.insert('trip_itinerary_days', {
          ...day.toMap(),
          'tripId': tripId,
        });
      }
      return tripId;
    });
  }

  static Future<void> _createTripItemsTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS trip_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tripId INTEGER NOT NULL,
        title TEXT NOT NULL,
        category TEXT NOT NULL,
        location TEXT NOT NULL,
        unitPrice REAL NOT NULL,
        quantity INTEGER NOT NULL,
        totalCost REAL NOT NULL,
        plannedDate TEXT NOT NULL,
        FOREIGN KEY (tripId) REFERENCES trips(id)
      )
    ''');
  }

  static Future<void> _createTripItineraryDaysTable(
    DatabaseExecutor db,
  ) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS trip_itinerary_days (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tripId INTEGER NOT NULL,
        dayNumber INTEGER NOT NULL,
        title TEXT NOT NULL,
        activities TEXT NOT NULL,
        FOREIGN KEY (tripId) REFERENCES trips(id)
      )
    ''');
  }

  static Future<List<TripItineraryDay>> getActiveTripItineraryDays() async {
    final trip = await getActiveTrip();
    if (trip?.id == null) return [];

    final db = await database;
    final rows = await db.query(
      'trip_itinerary_days',
      where: 'tripId = ?',
      whereArgs: [trip!.id],
      orderBy: 'dayNumber ASC',
    );
    return rows.map(TripItineraryDay.fromMap).toList();
  }

  static Future<TripModel?> getActiveTrip() async {
    final db = await database;
    final res = await db.query(
      'trips',
      where: 'status = ?',
      whereArgs: ['active'],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (res.isNotEmpty) {
      return TripModel.fromMap(res.first);
    }
    return null;
  }

  static Future<int> getCompletedTripCount() async {
    final db = await database;
    return Sqflite.firstIntValue(
          await db.rawQuery(
            "SELECT COUNT(*) FROM trips WHERE status IN ('archived', 'completed')",
          ),
        ) ??
        0;
  }

  static Future<void> updateActiveTripBudget({
    required double targetBudget,
    required double transportAllocation,
    required double hotelAllocation,
    required double culinaryAllocation,
    required double activityAllocation,
  }) async {
    final db = await database;
    final trip = await getActiveTrip();
    final budgetFields = {
      'targetBudget': targetBudget,
      'transportAllocation': transportAllocation,
      'hotelAllocation': hotelAllocation,
      'culinaryAllocation': culinaryAllocation,
      'activityAllocation': activityAllocation,
    };

    if (trip == null) {
      await db.insert('trips', {
        'destination': '',
        'destinationTitle': '',
        'dates': '',
        'duration': '',
        'durationDays': null,
        'travelerCount': null,
        'currency': 'IDR',
        ...budgetFields,
        'status': 'active',
      });
      return;
    }
    if (trip.id == null) {
      throw StateError('The active trip has no database ID.');
    }

    final updatedRows = await db.update(
      'trips',
      budgetFields,
      where: 'id = ?',
      whereArgs: [trip.id],
    );
    if (updatedRows == 0) {
      throw StateError('The active trip budget could not be updated.');
    }
  }

  static Future<void> updateActiveTripDetails({
    required String destination,
    required DateTime startDate,
    required int durationDays,
    required int travelerCount,
  }) async {
    final db = await database;
    final trip = await getActiveTrip();
    if (trip?.id == null) {
      throw StateError('Create and save a trip budget before trip details.');
    }
    final updatedRows = await db.update(
      'trips',
      {
        'destination': destination,
        'destinationTitle': destination,
        'dates': startDate.toIso8601String(),
        'duration': '$durationDays hari',
        'durationDays': durationDays,
        'travelerCount': travelerCount,
      },
      where: 'id = ?',
      whereArgs: [trip!.id],
    );
    if (updatedRows == 0) {
      throw StateError('Trip details could not be saved.');
    }
  }

  static Future<List<Map<String, dynamic>>> getActiveTripItems({
    DateTime? plannedDate,
  }) async {
    final trip = await getActiveTrip();
    if (trip?.id == null) return [];

    final db = await database;
    return db.query(
      'trip_items',
      where: plannedDate == null
          ? 'tripId = ?'
          : 'tripId = ? AND plannedDate = ?',
      whereArgs: plannedDate == null
          ? [trip!.id]
          : [trip!.id, _dateOnly(plannedDate)],
      orderBy: 'id ASC',
    );
  }

  static Future<void> deleteActiveTripItem(int itemId) async {
    final trip = await getActiveTrip();
    if (trip?.id == null) {
      throw StateError('There is no active trip to update.');
    }

    final db = await database;
    final deletedRows = await db.delete(
      'trip_items',
      where: 'id = ? AND tripId = ?',
      whereArgs: [itemId, trip!.id],
    );
    if (deletedRows == 0) {
      throw StateError('The itinerary item could not be found.');
    }
  }

  static Future<TripItemSaveResult> insertActiveTripItem({
    required String title,
    required String category,
    required String location,
    required double unitPrice,
    required int quantity,
    required DateTime plannedDate,
  }) async {
    final db = await database;
    return db.transaction((txn) async {
      final trips = await txn.query(
        'trips',
        where: 'status = ?',
        whereArgs: ['active'],
        orderBy: 'id DESC',
        limit: 1,
      );
      if (trips.isEmpty) return TripItemSaveResult.noActiveTrip;

      final trip = TripModel.fromMap(trips.first);
      if (trip.id == null) return TripItemSaveResult.noActiveTrip;

      final duplicates = await txn.query(
        'trip_items',
        columns: ['id'],
        where: 'tripId = ? AND title = ? AND category = ? AND plannedDate = ?',
        whereArgs: [trip.id, title, category, _dateOnly(plannedDate)],
        limit: 1,
      );
      if (duplicates.isNotEmpty) return TripItemSaveResult.duplicate;

      final expenseRows = await txn.rawQuery(
        'SELECT COALESCE(SUM(amount), 0) AS total FROM expenses '
        'WHERE tripId = ? AND isIncome = 0',
        [trip.id],
      );
      final itemRows = await txn.rawQuery(
        'SELECT COALESCE(SUM(totalCost), 0) AS total FROM trip_items '
        'WHERE tripId = ?',
        [trip.id],
      );
      final spent =
          (expenseRows.first['total'] as num).toDouble() +
          (itemRows.first['total'] as num).toDouble();
      final totalCost = unitPrice * quantity;
      if (totalCost > trip.targetBudget - spent) {
        return TripItemSaveResult.budgetExceeded;
      }

      await txn.insert('trip_items', {
        'tripId': trip.id,
        'title': title,
        'category': category,
        'location': location,
        'unitPrice': unitPrice,
        'quantity': quantity,
        'totalCost': totalCost,
        'plannedDate': _dateOnly(plannedDate),
      });
      return TripItemSaveResult.saved;
    });
  }

  static String _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day).toIso8601String();

  // --- EXPENSE OPERATIONS ---
  static Future<int> insertExpense(ExpenseModel expense) async {
    final db = await database;
    final trip = await getActiveTrip();
    return await db.insert('expenses', {
      ...expense.toMap(),
      'tripId': trip?.id,
    });
  }

  static Future<List<ExpenseModel>> getExpenses() async {
    final db = await database;
    final res = await db.query('expenses', orderBy: 'id DESC');
    return res.map((m) => ExpenseModel.fromMap(m)).toList();
  }

  static Future<double> getTotalExpenses() async {
    final db = await database;
    final trip = await getActiveTrip();
    if (trip?.id == null) return 0.0;
    final expenses = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) AS total FROM expenses '
      'WHERE tripId = ? AND isIncome = 0',
      [trip!.id],
    );
    final items = await db.rawQuery(
      'SELECT COALESCE(SUM(totalCost), 0) AS total FROM trip_items '
      'WHERE tripId = ?',
      [trip.id],
    );
    return (expenses.first['total'] as num).toDouble() +
        (items.first['total'] as num).toDouble();
  }

  static Future<double> getRemainingBudget() async {
    final trip = await getActiveTrip();
    if (trip == null) return 0.0;
    final double target = trip.targetBudget;
    final double spent = await getTotalExpenses();
    return target - spent;
  }

  // --- HOTEL & WISATA OPERATIONS ---
  static Future<List<Map<String, dynamic>>> getWisata({
    String? provinsi,
    String? kategori,
    String? cari,
  }) async {
    final db = await database;
    final where = <String>[];
    final args = <Object?>[];
    if (provinsi != null) {
      where.add('provinsi = ?');
      args.add(provinsi);
    }
    if (kategori != null) {
      where.add('kategori = ?');
      args.add(kategori);
    }
    if (cari != null && cari.trim().isNotEmpty) {
      where.add('nama_wisata LIKE ?');
      args.add('%${cari.trim()}%');
    }
    return db.query(
      'wisata',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'nama_wisata ASC',
    );
  }

  static Future<List<Map<String, dynamic>>> getHotels() async {
    final db = await database;
    return await db.query('hotels');
  }

  static Future<List<HotelModel>> getHotelModels() async {
    final db = await database;
    final maps = await db.query('hotels');
    return maps.map((m) => HotelModel.fromMap(m)).toList();
  }

  // --- FEEDBACK (SARAN & KESAN) ---
  static Future<int> insertFeedback(
      String userEmail, int rating, String comment) async {
    final db = await database;
    return await db.insert('feedback', {
      'userEmail': userEmail,
      'rating': rating,
      'comment': comment,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }
}
