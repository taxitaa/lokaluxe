import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/expense_model.dart';
import '../models/hotel_model.dart';
import '../models/trip_model.dart';
import '../models/user_model.dart';
import 'hotel_seed_data.dart';

class DBHelper {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  static Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'lokaluxe_local.db');

    return await openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        // 1. Table Users
        await db.execute('''
          CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            fullName TEXT,
            email TEXT UNIQUE,
            password TEXT,
            currency TEXT
          )
        ''');

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

        // Seed Default User (Amalia Nur Azizah)
        await db.insert('users', {
          'fullName': 'Amalia Nur Azizah',
          'email': 'amalia@localluxe.id',
          'password': 'password123',
          'currency': 'IDR (Rupiah Indonesia)',
        });

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
      // Dipanggil kalau database lama dibuka dengan version yang lebih baru
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 3) {
          // Buang tabel hotel lama (kalau ada), buat ulang, isi 46 hotel
          await db.execute('DROP TABLE IF EXISTS hotels');
          await _createHotelsTable(db);
          await _seedHotels(db);
        }
      },
    );
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
    // Cek apakah tabel kosong atau belum memiliki seluruh data hotel dari seed
    final count = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM hotels'),
        ) ??
        0;
    if (count < hotelSeedData.length) {
      if (count > 0) {
        await db.delete('hotels');
      }
      final batch = db.batch();
      for (final h in hotelSeedData) {
        batch.insert('hotels', h);
      }
      await batch.commit(noResult: true);
    }
  }

  // --- USER AUTH OPERATIONS ---
  static Future<int> registerUser(UserModel user) async {
    final db = await database;
    try {
      return await db.insert('users', user.toMap());
    } catch (e) {
      return -1; 
    }
  }

  static Future<UserModel?> loginUser(String email, String password) async {
    final db = await database;
    final res = await db.query(
      'users',
      where: 'email = ? AND password = ?',
      whereArgs: [email, password],
    );
    if (res.isNotEmpty) {
      return UserModel.fromMap(res.first);
    }
    return null;
  }

  static Future<UserModel?> getUserByEmail(String email) async {
    final db = await database;
    final res = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
    );
    if (res.isNotEmpty) {
      return UserModel.fromMap(res.first);
    }
    return null;
  }

  // --- TRIP & BUDGET OPERATIONS ---
  static Future<int> saveTrip(TripModel trip) async {
    final db = await database;
    await db.update('trips', {'status': 'archived'}, where: 'status = ?', whereArgs: ['active']);
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
    final res = await db.rawQuery('SELECT SUM(amount) as total FROM expenses WHERE isIncome = 0');
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

  // --- HOTEL OPERATIONS ---
  static Future<List<Map<String, dynamic>>> getHotels() async {
    final db = await database;
    var res = await db.query('hotels');
    if (res.length < hotelSeedData.length) {
      await _seedHotels(db);
      res = await db.query('hotels');
    }
    return res;
  }

  static Future<List<HotelModel>> getHotelModels() async {
    final raw = await getHotels();
    return raw.map((m) => HotelModel.fromMap(m)).toList();
  }

  static Future<List<HotelModel>> searchHotels(String keyword) async {
    final db = await database;
    final term = '%$keyword%';
    final res = await db.query(
      'hotels',
      where: 'name LIKE ? OR city LIKE ? OR province LIKE ? OR address LIKE ?',
      whereArgs: [term, term, term, term],
    );
    return res.map((m) => HotelModel.fromMap(m)).toList();
  }

  // --- FEEDBACK (SARAN & KESAN) ---
  static Future<int> insertFeedback(String userEmail, int rating, String comment) async {
    final db = await database;
    return await db.insert('feedback', {
      'userEmail': userEmail,
      'rating': rating,
      'comment': comment,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }
}