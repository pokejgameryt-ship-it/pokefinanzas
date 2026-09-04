import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../main.dart';
import '../../models/currency_config.dart';
import '../../services/auth_service.dart';
import '../../services/cache_service.dart';
import '../../services/database_service.dart';
import '../../services/redistribution_notifier.dart';
import '../../services/update_service.dart';
import '../../services/url_opener.dart';
import '../../utils/formatters.dart';
import '../reports/export_summary_screen.dart';
import '../savings/recurring_screen.dart';
import '../notifications/notification_settings_screen.dart';
import 'categories_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _version = '1.0.0';
  String _buildNumber = '1';
  String _currencyCode = 'EUR';
  String _lastSyncTime = 'Nunca';

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
    _loadCurrency();
    _loadCacheInfo();
  }

  Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _version = info.version;
          _buildNumber = info.buildNumber;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _currencyCode = prefs.getString('currencyCode') ?? 'EUR';
      });
    }
  }

  Future<void> _loadCacheInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getString('cache_lastSyncTime');
    if (mounted) {
      setState(() {
        _lastSyncTime = lastSync ?? 'Nunca';
      });
    }
  }

  Future<void> _checkForUpdates(BuildContext context) async {
    try {
      final hasUpdate = await UpdateService.isNewVersionAvailable();
      if (!mounted) return;
      if (hasUpdate) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nueva version disponible. Actualiza la app.'),
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tienes la ultima version.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo comprobar actualizaciones'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _reinstallShortcut(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.refresh, size: 48, color: Colors.teal),
        title: const Text('Reinstalar acceso directo'),
        content: const Text(
          'Esto eliminara el acceso directo actual y te permitira '
          'crear uno nuevo desde el navegador.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showReinstallSteps(context);
            },
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }

  void _showReinstallSteps(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pasos para reinstalar'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('1. Elimina el acceso directo actual del inicio'),
            SizedBox(height: 8),
            Text('2. Abre la app en Chrome'),
            SizedBox(height: 8),
            Text('3. Pulsa los 3 puntos > Instalar app'),
            SizedBox(height: 8),
            Text('4. Confirma la instalacion'),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              UrlOpener.open('https://pokefinanzas.web.app');
            },
            child: const Text('Abrir en navegador'),
          ),
        ],
      ),
    );
  }

  void _showDownloadDialog(BuildContext context) {
    final apkUrl = 'https://github.com/pokejgameryt-ship-it/pokefinanzas/releases/download/v$_version/app-release.apk';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.android, size: 48, color: Color(0xFF3DDC84)),
        title: const Text('Descargar APK'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Descarga la versión más reciente de PokeFinanzas para Android.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.tag, size: 16),
                  const SizedBox(width: 8),
                  Text('v$_version'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Si es la primera vez, activa "Fuentes desconocidas" en la configuración de tu dispositivo.',
              style: TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () {
              UrlOpener.open(apkUrl);
              Navigator.pop(ctx);
            },
            icon: const Icon(Icons.download),
            label: const Text('Descargar'),
          ),
        ],
      ),
    );
  }

  Future<void> _showRedistributionDayDialog() async {
    final db = DatabaseService.instance;
    int currentDay = await db.getGlobalRedistributionDay();
    int tempDay = currentDay;

    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Día de redistribución'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'El día del mes en que se redistribuye el sobrante de cada categoría.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Al cambiar, se recalcularán los presupuestos basados en los ingresos de los últimos 30 días.',
                  style: TextStyle(fontSize: 11),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Slider(
                      value: tempDay.toDouble(),
                      min: 1,
                      max: 28,
                      divisions: 27,
                      label: 'Día $tempDay',
                      onChanged: (v) => setDialogState(() => tempDay = v.round()),
                    ),
                  ),
                  SizedBox(
                    width: 50,
                    child: Text(
                      'Día $tempDay',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, tempDay),
              child: const Text('Guardar y recalcular'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      // Show loading
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        );
      }

      // Save the new day
      await db.setGlobalRedistributionDay(result);

      // Calculate period based on redistribution day
      final now = DateTime.now();
      final month = now.month;
      final year = now.year;
      final prevMonth = month == 1 ? 12 : month - 1;
      final prevYear = month == 1 ? year - 1 : year;
      final periodStart = DateTime(prevYear, prevMonth, result);
      final periodEnd = DateTime(month, year, result > 1 ? result - 1 : 1);

      // Recalculate income from redistribution period
      final periodIncome = await db.getIncomesByDateRange(periodStart, periodEnd);

      // Update monthly income
      final currentDist = await db.getDistribution(month, year);
      if (currentDist != null && periodIncome > 0) {
        await db.insertDistribution(currentDist.copyWith(monthlyIncome: periodIncome));
      }

      // Recalculate spent amounts from actual expenses (redistribution period)
      await db.recalculateDistributionSpent(from: periodStart, to: periodEnd);

      // Notify distribution screen to reload
      RedistributionNotifier.instance.notify();

      // Reload distribution to get updated values
      final updatedDist = await db.getDistribution(month, year);
      final totalSpent = updatedDist?.totalSpent ?? 0;

      // Close loading
      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Día $result. '
              'Ingresos: ${Formatters.formatCurrency(periodIncome)}, '
              'Gastado: ${Formatters.formatCurrency(totalSpent)}',
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final email = AuthService.currentUser?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajustes'),
      ),
      body: ListView(
        children: [
          // ── Cuenta ──
          _SectionHeader(title: 'Cuenta'),
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: const Text('Email'),
            subtitle: Text(email),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Cerrar sesión', style: TextStyle(color: Colors.red)),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Cerrar sesión'),
                  content: Text('¿Seguro que quieres cerrar sesión?\n\n$email'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Cerrar sesión'),
                    ),
                  ],
                ),
              );
              if (confirmed == true && context.mounted) {
                await AuthService.logout();
                await DatabaseService.instance.resetForNewUser();
                if (context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil('/auth', (route) => false);
                }
              }
            },
          ),

          const Divider(),

          // ── Apariencia ──
          _SectionHeader(title: 'Apariencia'),
          SwitchListTile(
            secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
            title: const Text('Modo oscuro'),
            subtitle: Text(isDark ? 'Activado' : 'Desactivado'),
            value: isDark,
            onChanged: (value) {
              FinanzasApp.setTheme(
                context,
                value ? ThemeMode.dark : ThemeMode.light,
              );
              setState(() {});
            },
          ),

          const Divider(),

          // ── Moneda ──
          _SectionHeader(title: 'Moneda'),
          ListTile(
            leading: const Icon(Icons.monetization_on_outlined),
            title: const Text('Moneda'),
            subtitle: Text(CurrencyConfig.fromCode(_currencyCode).name),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => SimpleDialog(
                  title: const Text('Seleccionar moneda'),
                  children: CurrencyConfig.available.map((currency) {
                    return RadioListTile<String>(
                      title: Text('${currency.symbol} ${currency.name}'),
                      subtitle: Text(currency.code),
                      value: currency.code,
                      groupValue: _currencyCode,
                      onChanged: (value) async {
                        if (value != null) {
                          await Formatters.setCurrency(value);
                          setState(() => _currencyCode = value);
                          if (context.mounted) Navigator.pop(context);
                        }
                      },
                    );
                  }).toList(),
                ),
              );
            },
          ),

          const Divider(),

          // ── Datos ──
          _SectionHeader(title: 'Datos'),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
            title: const Text('Exportar Resumen PDF'),
            subtitle: const Text('Genera un informe profesional con gráficos'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ExportSummaryScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.repeat, color: Colors.blue),
            title: const Text('Movimientos Recurrentes'),
            subtitle: const Text('Gestiona ingresos y gastos recurrentes'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RecurringScreen()),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.category, color: Colors.teal[700]),
            title: const Text('Categorías'),
            subtitle: const Text('Gestiona categorías con iconos y colores'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CategoriesScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.calendar_today, color: Colors.orange),
            title: const Text('Día de redistribución'),
            subtitle: const Text('Día del mes en que se redistribuye el sobrante'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showRedistributionDayDialog,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Borrar todos los datos', style: TextStyle(color: Colors.red)),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Borrar todos los datos'),
                  content: const Text(
                    '¿Estás seguro? Esta acción eliminará todos tus ingresos, gastos, presupuestos y configuración. No se puede deshacer.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                      child: const Text('Borrar todo'),
                    ),
                  ],
                ),
              );
              if (confirmed == true && context.mounted) {
                await DatabaseService.instance.deleteAllData();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Todos los datos han sido eliminados')),
                  );
                }
              }
            },
          ),

          const Divider(),

          // ── Notificaciones ──
          _SectionHeader(title: 'Notificaciones'),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Configurar Notificaciones'),
            subtitle: const Text('Activa o desactiva notificaciones push'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
              );
            },
          ),

          const Divider(),

          // ── Caché ──
          _SectionHeader(title: 'Caché'),
          ListTile(
            leading: const Icon(Icons.cloud_outlined),
            title: const Text('Última sincronización'),
            subtitle: Text(_lastSyncTime),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.orange),
            title: const Text('Borrar caché local',
                style: TextStyle(color: Colors.orange)),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Borrar caché'),
                  content: const Text(
                    'Se eliminarán los datos almacenados localmente. Los datos en Firebase no se verán afectados.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Borrar'),
                    ),
                  ],
                ),
              );
              if (confirmed == true && context.mounted) {
                await CacheService.clearData();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Caché local eliminada')),
                  );
                }
              }
            },
          ),

          const Divider(),

          // ── Información ──
          _SectionHeader(title: 'Información'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Versión'),
            subtitle: Text('$_version (build $_buildNumber)'),
          ),

          const Divider(),

          // ── Aplicación ──
          _SectionHeader(title: 'Aplicación'),
          ListTile(
            leading: const Icon(Icons.system_update, color: Colors.orange),
            title: const Text('Buscar actualizaciones'),
            subtitle: const Text('Comprueba si hay nueva version'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _checkForUpdates(context),
          ),
          if (kIsWeb) ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.refresh, color: Colors.teal),
              title: const Text('Reinstalar acceso directo'),
              subtitle: const Text('Soluciona problemas de acceso directo'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _reinstallShortcut(context),
            ),
          ],
          const Divider(),
          ListTile(
            leading: const Icon(Icons.android, color: Color(0xFF3DDC84)),
            title: const Text('Descargar APK Android'),
            subtitle: const Text('Instala la app en tu dispositivo'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showDownloadDialog(context),
          ),
          ListTile(
            leading: const Icon(Icons.language, color: Colors.blue),
            title: const Text('Abrir versión web'),
            subtitle: const Text('Abre la app en el navegador'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => UrlOpener.open('https://pokefinanzas.web.app'),
          ),
          ListTile(
            leading: Icon(Icons.code, color: Colors.grey[600]),
            title: const Text('Código fuente'),
            subtitle: const Text('GitHub'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => UrlOpener.open('https://github.com/pokejgameryt-ship-it/pokefinanzas'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
