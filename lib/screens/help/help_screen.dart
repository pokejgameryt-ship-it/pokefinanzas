import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayuda'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HelpSection(
            icon: Icons.home,
            title: 'Inicio',
            color: colorScheme.primary,
            items: [
              _HelpItem(
                title: 'Balance Total',
                description: 'Muestra tu saldo acumulado de todos los tiempos (ingresos - gastos).',
              ),
              _HelpItem(
                title: 'Mensual / Semanal',
                description: 'Resumen del balance del mes actual y de la semana en curso.',
              ),
              _HelpItem(
                title: 'Ingresos / Gastos',
                description: 'Total de ingresos y gastos del mes actual con número de registros.',
              ),
              _HelpItem(
                title: 'Ahorro',
                description: 'Muestra el ahorro total acumulado, lo ahorrado este mes y el presupuesto asignado a ahorro.',
              ),
              _HelpItem(
                title: 'Meta Activa',
                description: 'Si tienes una meta activa, se muestra su progreso con barra porcentual.',
              ),
              _HelpItem(
                title: 'Actividad Reciente',
                description: 'Resumen rápido de ingresos y gastos del mes.',
              ),
            ],
          ),
          const SizedBox(height: 8),

          _HelpSection(
            icon: Icons.receipt_long,
            title: 'Movimientos',
            color: const Color(0xFF2196F3),
            items: [
              _HelpItem(
                title: 'Lista unificada',
                description: 'Todos tus ingresos y gastos en una sola vista, ordenados por fecha.',
              ),
              _HelpItem(
                title: 'Buscador',
                description: 'Filtra movimientos por nombre, descripción o cantidad.',
              ),
              _HelpItem(
                title: 'Filtros',
                description: 'Filtra por tipo (ingresos/gastos) y por categoría.',
              ),
              _HelpItem(
                title: 'Añadir movimiento',
                description: 'Pulsa el botón "+" para crear un ingreso o gasto. Puedes configurar si es recurrente.',
              ),
              _HelpItem(
                title: 'Editar / Eliminar',
                description: 'Toca un movimiento para editarlo. Desliza hacia la izquierda para eliminarlo.',
              ),
              _HelpItem(
                title: 'Transferencia',
                description: 'Categoría especial para simular movimientos entre cuentas (ej: de Comida a Ahorro). No afecta al presupuesto.',
              ),
              _HelpItem(
                title: 'Importar CSV',
                description: 'Importa datos desde un archivo CSV o pegando contenido directamente.',
              ),
            ],
          ),
          const SizedBox(height: 8),

          _HelpSection(
            icon: Icons.bar_chart,
            title: 'Estadísticas',
            color: const Color(0xFFFF9800),
            items: [
              _HelpItem(
                title: 'Resumen del Mes',
                description: 'Ingresos, gastos, ahorro del mes y total acumulado.',
              ),
              _HelpItem(
                title: 'Comparativa Mensual',
                description: 'Compara el mes actual con el anterior: ingresos, gastos, ahorro y balance.',
              ),
              _HelpItem(
                title: 'Gráfico de barras',
                description: 'Evolución de ingresos vs gastos en los últimos meses.',
              ),
              _HelpItem(
                title: 'Gráfico de líneas',
                description: 'Tendencia de ingresos, gastos y ahorro mensual.',
              ),
              _HelpItem(
                title: 'Gráfico circular',
                description: 'Distribución porcentual de gastos por categoría.',
              ),
              _HelpItem(
                title: 'Desglose por subcategoría',
                description: 'Detalla el gasto dentro de cada categoría.',
              ),
              _HelpItem(
                title: 'Exportar CSV',
                description: 'Copia los datos del mes al portapapeles en formato CSV.',
              ),
            ],
          ),
          const SizedBox(height: 8),

          _HelpSection(
            icon: Icons.pie_chart,
            title: 'Distribución',
            color: const Color(0xFF4CAF50),
            items: [
              _HelpItem(
                title: 'Presupuesto mensual',
                description: 'Configura cuánto dinero se asigna a cada categoría del mes.',
              ),
              _HelpItem(
                title: 'Porcentaje vs Fijo',
                description: 'Puedes definir presupuesto como cantidad fija (ej: 45€) o como porcentaje del ingreso (ej: 50%).',
              ),
              _HelpItem(
                title: 'Ingreso mensual',
                description: 'Es la base para calcular los porcentajes. Edítalo tocando el lápiz.',
              ),
              _HelpItem(
                title: 'Redistribución',
                description: 'El dinero no gastado de una categoría se reparte entre otras. Configura los porcentajes tocando cada categoría.',
              ),
              _HelpItem(
                title: 'Toggle "Redistribuir"',
                description: 'Activa o desactiva la redistribución globalmente.',
              ),
              _HelpItem(
                title: 'Día de redistribución',
                description: 'Configura el día del mes en que se aplica. Puedes poner un día global o por categoría.',
              ),
              _HelpItem(
                title: 'Presets',
                description: 'Guarda y carga configuraciones de redistribución. Los presets generales aplican a todas las categorías.',
              ),
              _HelpItem(
                title: 'Vista semanal',
                description: ' Divide el presupuesto mensual entre 4.3 para ver la asignación semanal.',
              ),
              _HelpItem(
                title: 'Bloqueo automático',
                description: 'Si los gastos fijos superan el ingreso, la redistribución se desactiva automáticamente.',
              ),
            ],
          ),
          const SizedBox(height: 8),

          _HelpSection(
            icon: Icons.shopping_bag,
            title: 'Tienda',
            color: const Color(0xFFE91E63),
            items: [
              _HelpItem(
                title: 'Productos',
                description: 'Lista de productos que deseas comprar o que ya tienes.',
              ),
              _HelpItem(
                title: 'Favoritos',
                description: 'Marca productos con estrella para encontrarlos rápido.',
              ),
              _HelpItem(
                title: 'Grupos',
                description: 'Organiza productos en grupos (ej: Electrónica, Ropa).',
              ),
              _HelpItem(
                title: 'Añadir producto',
                description: 'Pulsa "+" para añadir un producto con nombre, precio, grupo y si es favorito.',
              ),
            ],
          ),
          const SizedBox(height: 8),

          _HelpSection(
            icon: Icons.flag,
            title: 'Metas',
            color: const Color(0xFF9C27B0),
            items: [
              _HelpItem(
                title: 'Objetivos de ahorro',
                description: 'Crea metas con un objetivo de dinero y una fecha límite.',
              ),
              _HelpItem(
                title: 'Meta activa',
                description: 'Solo puedes tener una meta activa a la vez. Se muestra en el Dashboard.',
              ),
              _HelpItem(
                title: 'Progreso',
                description: 'Añade dinero a tu meta y sigue el progreso con la barra porcentual.',
              ),
            ],
          ),
          const SizedBox(height: 8),

          _HelpSection(
            icon: Icons.notifications,
            title: 'Notificaciones',
            color: const Color(0xFFFF5722),
            items: [
              _HelpItem(
                title: 'Informe mensual',
                description: 'Se genera automáticamente el día 1 de cada mes con el resumen.',
              ),
              _HelpItem(
                title: 'Alertas de presupuesto',
                description: 'Aviso al 90% y al 100% del presupuesto de una categoría.',
              ),
              _HelpItem(
                title: 'Alerta de ahorro',
                description: 'Recordatorio del ahorro del mes anterior.',
              ),
              _HelpItem(
                title: 'Recordatorios de pago',
                description: 'Notificación 2 días antes de que se cobre un gasto recurrente.',
              ),
            ],
          ),
          const SizedBox(height: 8),

          _HelpSection(
            icon: Icons.swap_horiz,
            title: 'Transferencias',
            color: const Color(0xFF00BCD4),
            items: [
              _HelpItem(
                title: 'Simular movimientos entre cuentas',
                description: 'Usa la categoría "Transferencia" en gastos para mover dinero entre categorías.',
              ),
              _HelpItem(
                title: 'No afecta presupuesto',
                description: 'Las transferencias no se cuentan como gasto real ni en stats ni en distribución.',
              ),
              _HelpItem(
                title: 'Destino',
                description: 'Al crear una transferencia, selecciona la categoría destino.',
              ),
            ],
          ),
          const SizedBox(height: 8),

          _HelpSection(
            icon: Icons.settings,
            title: 'Ajustes',
            color: const Color(0xFF607D8B),
            items: [
              _HelpItem(
                title: 'Modo oscuro',
                description: 'Cambia entre tema claro y oscuro.',
              ),
              _HelpItem(
                title: 'Moneda',
                description: 'Selecciona entre EUR, USD o GBP.',
              ),
              _HelpItem(
                title: 'Caché',
                description: 'Los datos se guardan localmente para funcionar sin conexión.',
              ),
              _HelpItem(
                title: 'Eliminar datos',
                description: 'Borra todos tus datos permanentemente.',
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _HelpSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final List<_HelpItem> items;

  const _HelpSection({
    required this.icon,
    required this.title,
    required this.color,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}

class _HelpItem {
  final String title;
  final String description;

  const _HelpItem({required this.title, required this.description});
}
