import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import 'home/dashboard_screen.dart';
import 'movimientos/movimientos_screen.dart';
import 'products/products_screen.dart';
import 'goals/goals_screen.dart';
import 'stats/stats_screen.dart';
import 'savings/distribution_screen.dart';
import 'notifications/notifications_screen.dart';
import 'settings/settings_screen.dart';
import 'help/help_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  int _unreadCount = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const MovimientosScreen(),
    const StatsScreen(),
    const DistributionScreen(),
    const ProductsScreen(),
    const GoalsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    try {
      final count = await DatabaseService.instance.getUnreadNotificationCount();
      if (mounted) setState(() => _unreadCount = count);
    } catch (_) {}
  }

  void _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
    _loadUnreadCount();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PokeFinanzas'),
        actions: [
          // Icono notificaciones con badge
          Stack(
            children: [
              IconButton(
                onPressed: _openNotifications,
                icon: Icon(
                  _unreadCount > 0
                      ? Icons.notifications_active
                      : Icons.notifications_outlined,
                  color: _unreadCount > 0
                      ? Theme.of(context).colorScheme.error
                      : null,
                ),
                tooltip: 'Notificaciones',
              ),
              if (_unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _unreadCount > 99 ? '99+' : '$_unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          // Ajustes
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            icon: const Icon(Icons.settings),
            tooltip: 'Ajustes',
          ),
          // Ayuda
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HelpScreen()),
              );
            },
            icon: const Icon(Icons.help_outline),
            tooltip: 'Ayuda',
          ),
          // Logout
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'logout') {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Cerrar sesión'),
                    content: Text(
                        '¿Seguro que quieres cerrar sesión?\n\n${AuthService.currentUser?.email ?? ""}'),
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
                if (confirmed == true) {
                  await AuthService.logout();
                  await DatabaseService.instance.resetForNewUser();
                  if (context.mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                        '/auth', (route) => false);
                  }
                }
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem<String>(
                enabled: false,
                child: Text(
                  AuthService.currentUser?.email ?? '',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20),
                    SizedBox(width: 8),
                    Text('Cerrar sesión'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Movimientos',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Stats',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline),
            selectedIcon: Icon(Icons.pie_chart),
            label: 'Distribución',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_bag_outlined),
            selectedIcon: Icon(Icons.shopping_bag),
            label: 'Tienda',
          ),
          NavigationDestination(
            icon: Icon(Icons.flag_outlined),
            selectedIcon: Icon(Icons.flag),
            label: 'Metas',
          ),
        ],
      ),
    );
  }
}
