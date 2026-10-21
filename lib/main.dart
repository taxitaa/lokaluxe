import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/database/database_initializer.dart';
import 'core/services/currency_provider.dart';
import 'core/services/localization_provider.dart';
import 'core/services/location_provider.dart';
import 'core/theme/app_colors.dart';
import 'screens/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // WAJIB untuk desktop (Windows/Linux/macOS): aktifkan SQLite FFI
  initializeDatabase();

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
        // 1. CurrencyProvider — kurs & konversi mata uang global
        ChangeNotifierProvider<CurrencyProvider>(
          create: (_) => CurrencyProvider()..initialize(),
        ),

        // 2. LocalizationProvider — bahasa UI (id/en) global
        //    Harus didaftarkan SEBELUM LocationProvider
        ChangeNotifierProvider<LocalizationProvider>(
          create: (_) => LocalizationProvider()..initialize(),
        ),

        // 3. LocationProvider — lokasi aktif, mengatur currency & bahasa
        //    Bergantung pada CurrencyProvider + LocalizationProvider
        ChangeNotifierProxyProvider2<CurrencyProvider, LocalizationProvider,
            LocationProvider>(
          create: (ctx) => LocationProvider(
            ctx.read<CurrencyProvider>(),
            ctx.read<LocalizationProvider>(),
          )..initialize(),
          update: (ctx, currency, localization, previous) =>
              previous ??
              LocationProvider(currency, localization)..initialize(),
        ),
      ],
      // LocalizationScope menyebarkan AppStrings aktif ke seluruh widget tree
      child: Consumer<LocalizationProvider>(
        builder: (_, locProv, child) => LocalizationScope(
          strings: locProv.strings,
          child: child!,
        ),
        child: const _AppRoot(),
      ),
    );
  }
}

class _AppRoot extends StatelessWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LokaLuxe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.warmCream,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primaryGreen),
      ),
      home: const SplashScreen(),
    );
  }
}