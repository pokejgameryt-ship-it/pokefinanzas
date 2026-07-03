import 'package:flutter/material.dart';
import '../../models/app_notification.dart';
import '../../services/database_service.dart';
import '../../services/pdf_service.dart';
import '../reports/report_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _db = DatabaseService.instance;
  List<AppNotification> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final notifications = await _db.getAllNotifications();
      if (mounted) {
        setState(() {
          _notifications = notifications;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markAllAsRead() async {
    await _db.markAllNotificationsAsRead();
    _loadData();
  }

  Future<void> _deleteNotification(String id) async {
    await _db.deleteNotification(id);
    _loadData();
  }

  Future<void> _downloadPdf(AppNotification notif) async {
    // Extract month/year from the notification's createdAt
    final month = notif.createdAt.month;
    final year = notif.createdAt.year;

    try {
      final pdf = await PdfService.generateMonthlyReport(month, year);
      final fileName = '${year}_${month.toString().padLeft(2, '0')}_Informe.pdf';
      await PdfService.sharePdf(pdf, fileName);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF generado correctamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al generar PDF: $e')),
        );
      }
    }
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'monthly_report':
        return Icons.picture_as_pdf;
      case 'weekly_report':
        return Icons.view_week;
      case 'annual_report':
        return Icons.assessment;
      case 'savings_alert':
      case 'savings_goal_reached':
        return Icons.savings;
      case 'budget_alert':
      case 'budget_warning':
      case 'budget_exceeded':
        return Icons.warning_amber;
      case 'recurring_expense_reminder':
        return Icons.receipt_long;
      case 'recurring_income_reminder':
        return Icons.account_balance;
      default:
        return Icons.notifications;
    }
  }

  Color _getColor(String type) {
    switch (type) {
      case 'monthly_report':
        return const Color(0xFF1565C0);
      case 'weekly_report':
        return const Color(0xFF7B1FA2);
      case 'annual_report':
        return const Color(0xFF00695C);
      case 'savings_alert':
      case 'savings_goal_reached':
        return const Color(0xFF4CAF50);
      case 'budget_alert':
      case 'budget_warning':
        return const Color(0xFFFF9800);
      case 'budget_exceeded':
        return const Color(0xFFF44336);
      case 'recurring_expense_reminder':
        return const Color(0xFFE53935);
      case 'recurring_income_reminder':
        return const Color(0xFF43A047);
      default:
        return const Color(0xFF607D8B);
    }
  }

  Map<String, String?>? _parseReportNotification(AppNotification notif) {
    final title = notif.title;

    if (notif.type == 'monthly_report') {
      // Title format: "Informe Mensual - Junio 2026"
      final monthNames = {
        'Enero': 1, 'Febrero': 2, 'Marzo': 3, 'Abril': 4,
        'Mayo': 5, 'Junio': 6, 'Julio': 7, 'Agosto': 8,
        'Septiembre': 9, 'Octubre': 10, 'Noviembre': 11, 'Diciembre': 12,
      };
      for (final entry in monthNames.entries) {
        if (title.contains(entry.key)) {
          final yearMatch = RegExp(r'(\d{4})').firstMatch(title);
          return {
            'type': 'monthly',
            'month': entry.value.toString(),
            'year': yearMatch?.group(1),
          };
        }
      }
    } else if (notif.type == 'weekly_report') {
      return {'type': 'weekly'};
    } else if (notif.type == 'annual_report') {
      final yearMatch = RegExp(r'(\d{4})').firstMatch(title);
      return {
        'type': 'annual',
        'year': yearMatch?.group(1),
      };
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final unreadCount = _notifications.where((n) => !n.isRead).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text('Marcar todo leído'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child              : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_none,
                        size: 72,
                        color: colorScheme.primary.withValues(alpha: 0.25),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Sin notificaciones',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Recibirás alertas sobre tus finanzas, presupuestos y reportes aquí',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                            ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final notif = _notifications[index];
                    final color = _getColor(notif.type);
                    final isReport = notif.type == 'monthly_report' ||
                        notif.type == 'weekly_report' ||
                        notif.type == 'annual_report';

                    return Dismissible(
                      key: Key(notif.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: colorScheme.error,
                        child: const Icon(Icons.delete,
                            color: Colors.white),
                      ),
                      confirmDismiss: (_) async {
                        await _deleteNotification(notif.id);
                        return false;
                      },
                      child: Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        color: notif.isRead
                            ? null
                            : color.withValues(alpha: 0.05),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: color.withValues(alpha: 0.1),
                            child: Icon(
                              _getIcon(notif.type),
                              color: color,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            notif.title,
                            style: TextStyle(
                              fontWeight: notif.isRead
                                  ? FontWeight.normal
                                  : FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            notif.message,
                            style: const TextStyle(fontSize: 13),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isReport)
                                IconButton(
                                  icon: Icon(
                                    Icons.download,
                                    color: colorScheme.primary,
                                    size: 20,
                                  ),
                                  tooltip: 'Descargar PDF',
                                  onPressed: () => _downloadPdf(notif),
                                ),
                              if (!notif.isRead)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          onTap: () {
                            if (!notif.isRead) {
                              _db.markNotificationAsRead(notif.id);
                              setState(() {
                                _notifications[index] =
                                    notif.copyWith(isRead: true);
                              });
                            }
                            // Navigate to report for report types
                            if (notif.type == 'monthly_report' ||
                                notif.type == 'weekly_report' ||
                                notif.type == 'annual_report') {
                              final reportData = _parseReportNotification(notif);
                              if (reportData != null) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ReportScreen(
                                      reportType: reportData['type']!,
                                      month: reportData['month'] != null ? int.tryParse(reportData['month']!) : null,
                                      year: reportData['year'] != null ? int.tryParse(reportData['year']!) : null,
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
            ),
    );
  }
}
