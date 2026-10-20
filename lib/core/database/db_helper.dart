import 'package:flutter/foundation.dart';
import 'database_initializer.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/expense_model.dart';
import '../models/hotel_model.dart';
import '../models/transport_model.dart';
import '../models/trip_model.dart';
import '../models/user_model.dart';
import '../security/password_hasher.dart';
import 'hotel_seed_data.dart';
import 'transport_seed_data.dart';

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
      version: 4,
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
            isIncome INTEGER
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

        // Seed Default Trip (Yogyakarta)
        await db.insert('trips', {
          'destination': 'Yogyakarta',
          'destinationTitle': 'Yogyakarta (DIY)',
          'dates': '24 Okt - 28 Okt 2026',
          'duration': '5 Hari, 4 Malam • Rekreasi santai',
          'currency': 'IDR',
          'targetBudget': 5000000.0,
          'transportAllocation': 1750000.0,
          'hotelAllocation': 1500000.0,
          'culinaryAllocation': 1000000.0,
          'activityAllocation': 750000.0,
          'status': 'active',
        });

        // Seed Initial Expenses
        await db.insert('expenses', {
          'title': 'Kopi Klotok & Pisang Goreng',
          'category': 'Kuliner',
          'amount': 25000.0,
          'date': 'Hari ini • 09:30',
          'isIncome': 0,
        });

        await db.insert('expenses', {
          'title': 'Parkir Area Malioboro',
          'category': 'Transport',
          'amount': 15000.0,
          'date': 'Hari ini • 08:15',
          'isIncome': 0,
        });

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
        createdAt TEXT
      )
    ''');
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

  // --- TRIP & BUDGET OPERATIONS ---
  static Future<int> saveTrip(TripModel trip) async {
    final db = await database;
    await db.update('trips', {'status': 'archived'},
        where: 'status = ?', whereArgs: ['active']);
    return await db.insert('trips', trip.toMap());
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

  // --- EXPENSE OPERATIONS ---
  static Future<int> insertExpense(ExpenseModel expense) async {
    final db = await database;
    return await db.insert('expenses', expense.toMap());
  }

  static Future<List<ExpenseModel>> getExpenses() async {
    final db = await database;
    final res = await db.query('expenses', orderBy: 'id DESC');
    return res.map((m) => ExpenseModel.fromMap(m)).toList();
  }

  static Future<double> getTotalExpenses() async {
    final db = await database;
    final res = await db.rawQuery(
        'SELECT SUM(amount) as total FROM expenses WHERE isIncome = 0');
    if (res.isNotEmpty && res.first['total'] != null) {
      return (res.first['total'] as num).toDouble();
    }
    return 0.0;
  }

  static Future<double> getRemainingBudget() async {
    final trip = await getActiveTrip();
    final double target = trip?.targetBudget ?? 5000000.0;
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
