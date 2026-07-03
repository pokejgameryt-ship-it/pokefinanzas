import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/main_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'services/database_service.dart';
import 'services/auth_service.dart';
import 'utils/formatters.dart';
import 'utils/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.init();
  await Formatters.loadCurrency();
  runApp(const FinanzasApp());
}

class FinanzasApp extends StatefulWidget {
  const FinanzasApp({super.key});

  static void setTheme(BuildContext context, ThemeMode mode) {
    final state = context.findAncestorStateOfType<_FinanzasAppState>();
    state?.setTheme(mode);
  }

  static ThemeMode currentTheme(BuildContext context) {
    final state = context.findAncestorStateOfType<_FinanzasAppState>();
    return state?._themeMode ?? ThemeMode.light;
  }

  @override
  State<FinanzasApp> createState() => _FinanzasAppState();
}

class _FinanzasAppState extends State<FinanzasApp> {
  ThemeMode _themeMode = ThemeMode.light;
  bool _onboardingSeen = false;
  bool _prefsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('darkMode') ?? false;
    final onboardingSeen = await OnboardingScreen.hasSeenOnboarding();
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
      _onboardingSeen = onboardingSeen;
      _prefsLoaded = true;
    });
  }

  void setTheme(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', mode == ThemeMode.dark);
    setState(() {
      _themeMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_prefsLoaded) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final Widget home;
    if (!_onboardingSeen) {
      home = const OnboardingScreen();
    } else if (AuthService.isLoggedIn) {
      home = const _SyncAndGoMain();
    } else {
      home = const AuthScreen();
    }

    return MaterialApp(
      title: 'Finanzas App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: _themeMode,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'ES'),
        Locale('en', 'US'),
      ],
      locale: const Locale('es', 'ES'),
      home: home,
      routes: {
        '/onboarding': (_) => const OnboardingScreen(),
        '/auth': (_) => const AuthScreen(),
        '/main': (_) => const _SyncAndGoMain(),
      },
    );
  }
}

class _SyncAndGoMain extends StatefulWidget {
  const _SyncAndGoMain();

  @override
  State<_SyncAndGoMain> createState() => _SyncAndGoMainState();
}

class _SyncAndGoMainState extends State<_SyncAndGoMain> {
  bool _syncing = true;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  Future<void> _sync() async {
    await DatabaseService.instance.resetForNewUser();
    try {
      await DatabaseService.instance.syncFromFirebase();
    } catch (_) {}
    if (mounted) {
      setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_syncing) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Sincronizando datos...',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return const MainScreen();
  }
}
