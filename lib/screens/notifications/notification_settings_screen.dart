import 'package:flutter/material.dart';
import '../../services/push_notification_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  Map<String, List<NotificationPreference>> _groupedPreferences = {};
  bool _isLoading = true;
  bool _allEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final grouped = await PushNotificationService.getPreferencesByCategory();
    final master = await PushNotificationService.isMasterEnabled();
    
    setState(() {
      _groupedPreferences = grouped;
      _allEnabled = master;
      _isLoading = false;
    });
  }

  Future<void> _togglePreference(String id, bool value) async {
    await PushNotificationService.setEnabled(id, value);
    final grouped = await PushNotificationService.getPreferencesByCategory();
    setState(() {
      _groupedPreferences = grouped;
    });
  }

  Future<void> _toggleAll(bool value) async {
    await PushNotificationService.toggleAll(value);
    _loadPreferences();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          Switch(
            value: _allEnabled,
            onChanged: _toggleAll,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                Card(
                  margin: const EdgeInsets.all(16),
                  color: _allEnabled
                      ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                      : colorScheme.errorContainer.withValues(alpha: 0.3),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          _allEnabled ? Icons.notifications_active : Icons.notifications_off,
                          color: _allEnabled ? colorScheme.primary : colorScheme.error,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _allEnabled ? 'Notificaciones activadas' : 'Notificaciones desactivadas',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _allEnabled ? colorScheme.primary : colorScheme.error,
                                ),
                              ),
                              Text(
                                _allEnabled
                                    ? 'Recibiras notificaciones segun tu configuracion'
                                    : 'No recibiras ninguna notificacion',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                ..._groupedPreferences.entries.map((entry) {
                  final category = entry.key;
                  final preferences = entry.value;
                  final enabledInCategory = preferences.where((p) => p.isEnabled).length;
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Row(
                          children: [
                            Text(
                              category.toUpperCase(),
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '$enabledInCategory/${preferences.length}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...preferences.map((pref) => SwitchListTile(
                        title: Text(pref.title),
                        subtitle: Text(pref.description),
                        value: pref.isEnabled,
                        onChanged: (value) => _togglePreference(pref.id, value),
                      )),
                      const Divider(),
                    ],
                  );
                }),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, color: colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Acerca de las notificaciones',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Las notificaciones te ayudan a mantener el control de tus finanzas. '
                            'Puedes activar o desactivar cada tipo segun tus preferencias.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Tipos de notificacion:',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text('- Alertas de presupuesto y gastos', style: Theme.of(context).textTheme.bodySmall),
                          Text('- Recordatorios de metas de ahorro', style: Theme.of(context).textTheme.bodySmall),
                          Text('- Avisos de pagos recurrentes y a plazos', style: Theme.of(context).textTheme.bodySmall),
                          Text('- Informes semanales y mensuales', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
