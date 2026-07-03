import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../main.dart';
import '../../models/currency_config.dart';
import '../../services/auth_service.dart';
import '../../services/cache_service.dart';
import '../../services/database_service.dart';
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
