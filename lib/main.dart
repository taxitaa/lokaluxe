import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/database/database_initializer.dart';
import 'core/services/auth_service.dart';
import 'core/services/currency_provider.dart';
import 'core/services/localization_provider.dart';
import 'core/services/location_provider.dart';
import 'core/services/session_service.dart';
import 'core/theme/app_colors.dart';
import 'screens/auth/login_screen.dart';
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

        ChangeNotifierProvider<LocalizationProvider>(
          create: (_) => LocalizationProvider()..initialize(),
        ),

        ChangeNotifierProxyProvider<CurrencyProvider, LocationProvider>(
          create: (ctx) =>
              LocationProvider(ctx.read<CurrencyProvider>())..initialize(),
          update: (ctx, currency, previous) =>
              previous ?? LocationProvider(currency)..initialize(),
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

final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> with WidgetsBindingObserver {
  Timer? _idleTimer;
  DateTime? _lastActivity;
  DateTime? _lastSessionRefresh;
  bool _refreshInProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restoreSessionTimeout();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _idleTimer?.cancel();
    super.dispose();
  }

  Future<void> _restoreSessionTimeout() async {
    final session = await SessionService.getSessionData();
    if (!mounted || session == null) return;

    final now = DateTime.now();
    final expiresIn = session.expiresAt.difference(now);
    final remaining = expiresIn > SessionService.inactivityTimeout
        ? SessionService.inactivityTimeout
        : expiresIn;
    if (remaining <= Duration.zero) {
      await SessionService.isSessionActive();
      return;
    }

    _lastActivity = now.subtract(
      SessionService.inactivityTimeout - remaining,
    );
    _scheduleIdleTimeout(remaining);
  }

  void _recordActivity() {
    final now = DateTime.now();
    final previousActivity = _lastActivity;
    if (previousActivity != null &&
        now.difference(previousActivity) >= SessionService.inactivityTimeout) {
      _expireIfIdle();
      return;
    }

    _lastActivity = now;
    _scheduleIdleTimeout(SessionService.inactivityTimeout);

    final lastRefresh = _lastSessionRefresh;
    if (_refreshInProgress ||
        (lastRefresh != null &&
            now.difference(lastRefresh) < const Duration(seconds: 1))) {
      return;
    }

    _refreshInProgress = true;
    _lastSessionRefresh = now;
    _refreshSession();
  }

  Future<void> _refreshSession() async {
    try {
      await SessionService.refreshSession();
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'session timeout',
          context: ErrorDescription('while refreshing the active session'),
        ),
      );
    } finally {
      _refreshInProgress = false;
    }
  }

  void _scheduleIdleTimeout(Duration duration) {
    _idleTimer?.cancel();
    _idleTimer = Timer(duration, _expireIfIdle);
  }

  Future<void> _expireIfIdle() async {
    final lastActivity = _lastActivity;
    if (lastActivity == null) return;

    final remaining = SessionService.inactivityTimeout -
        DateTime.now().difference(lastActivity);
    if (remaining > Duration.zero) {
      _scheduleIdleTimeout(remaining);
      return;
    }

    final session = await SessionService.getSessionData();
    if (session == null) {
      _lastActivity = null;
      return;
    }

    await AuthService.logout();
    if (!mounted) return;
    _navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => const LoginScreen(),
      ),
      (_) => false,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;

    final lastActivity = _lastActivity;
    if (lastActivity == null) {
      _restoreSessionTimeout();
      return;
    }

    final remaining = SessionService.inactivityTimeout -
        DateTime.now().difference(lastActivity);
    if (remaining <= Duration.zero) {
      _expireIfIdle();
    } else {
      _scheduleIdleTimeout(remaining);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localization = context.watch<LocalizationProvider>();
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'LokaLuxe',
      locale: Locale(localization.langCode),
      supportedLocales: const [Locale('id'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.warmCream,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primaryGreen),
      ),
      home: const SplashScreen(),
      builder: (context, child) => Focus(
        onKeyEvent: (node, event) {
          _recordActivity();
          return KeyEventResult.ignored;
        },
        child: Listener(
          onPointerDown: (_) => _recordActivity(),
          onPointerMove: (_) => _recordActivity(),
          onPointerSignal: (_) => _recordActivity(),
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}