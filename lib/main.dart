import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/database/database_initializer.dart';
import 'core/services/currency_provider.dart';
import 'core/theme/app_colors.dart';
import 'screens/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // WAJIB untuk Windows/Linux/macOS: aktifkan SQLite FFI sebelum DB dipakai
  initializeDatabase();

  // Configure status bar and navigation bar styling
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.warmCream,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const LokaLuxeApp());
}

class LokaLuxeApp extends StatelessWidget {
  const LokaLuxeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // CurrencyProvider: state management global untuk konversi mata uang
        // Menyediakan data kurs ke seluruh widget tree
        ChangeNotifierProvider(
          create: (_) => CurrencyProvider()..initialize(),
        ),
      ],
      child: MaterialApp(
        title: 'LokaLuxe',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: AppColors.warmCream,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primaryGreen,
          ),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}