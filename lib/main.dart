import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/main_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'services/database_service.dart';
import 'services/auth_service.dart';
import 'services/update_service.dart';
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
    try {
      await DatabaseService.instance.syncFromFirebase();
    } catch (_) {}
    // Actualizar version remota
    try {
      await UpdateService.updateRemoteVersion();
    } catch (_) {}
    if (mounted) {
      setState(() => _syncing = false);
      _checkForUpdate();
    }
  }

  Future<void> _checkForUpdate() async {
    try {
      final hasUpdate = await UpdateService.isNewVersionAvailable();
      if (hasUpdate && mounted) {
        _showUpdateDialog();
      }
    } catch (_) {}
  }

  void _showUpdateDialog() {
    final version = UpdateService.remoteVersion ?? 'nueva';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.system_update, size: 48, color: Colors.orange),
        title: const Text('Actualizacion disponible'),
        content: Text(
          'Hay una nueva version de PokeFinanzas (v$version). '
          'Actualiza para obtener las ultimas mejoras.',
        ),
        actions: [
          if (!kIsWeb)
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _downloadAndOpenApk(ctx, version);
              },
              icon: const Icon(Icons.download),
              label: const Text('Descargar e instalar'),
            ),
          if (kIsWeb)
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _reloadPage();
              },
              child: const Text('Actualizar ahora'),
            ),
        ],
      ),
    );
  }

  Future<void> _downloadAndOpenApk(BuildContext context, String version) async {
    final apkUrl = 'https://github.com/pokejgameryt-ship-it/pokefinanzas/releases/download/v$version/app-release.apk';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Descargando actualizacion...'),
          ],
        ),
      ),
    );

    try {
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/app-release.apk';
      await Dio().download(apkUrl, filePath);
      if (mounted) {
        Navigator.of(context).pop();
        await OpenFile.open(filePath);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al descargar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _reloadPage() {
    if (kIsWeb) {
      _reloadPageWeb();
    } else {
      Navigator.of(context).pushReplacementNamed('/main');
    }
  }

  void _reloadPageWeb() {
    // En web, volver a la pantalla principal
    Navigator.of(context).pushReplacementNamed('/main');
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
