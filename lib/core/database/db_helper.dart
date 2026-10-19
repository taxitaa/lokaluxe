import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/expense_model.dart';
import '../models/trip_model.dart';
import '../models/user_model.dart';

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
      version: 1,
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
        await db.execute('''
          CREATE TABLE hotels (
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

        // Seed Contoh Data Hotel
        await db.insert('hotels', {
          'name': 'Adimulia Hotel Medan',
          'province': 'Sumatera Utara',
          'city': 'Medan',
          'stars': 4,
          'price_per_night': 1100000.0,
          'latitude': 3.5852,
          'longitude': 98.6721,
          'address': 'Jl. Pangeran Diponegoro No.21',
          'image_url': 'https://images.unsplash.com/photo-1566073771259-6a8506099945'
        });
      },
    );
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
    return await db.query('hotels');
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