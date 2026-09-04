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
                description: 'Total de ingresos y gastos del mes actual con desglose por efectivo/banco.',
              ),
              _HelpItem(
                title: 'Ahorro',
                description: 'Muestra el ahorro total acumulado, lo ahorrado este mes y el presupuesto asignado a ahorro.',
              ),
              _HelpItem(
                title: 'Meta Activa',
                description: 'Si tienes una meta activa, se muestra su progreso con barra porcentual y proximo pago.',
              ),
              _HelpItem(
                title: 'Pagos Pendientes',
                description: 'Muestra los pagos proximos de metas con plan de pagos fijos.',
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
                description: 'Todos tus ingresos y gastos en una sola vista, ordenados por fecha. Sin filtro de mes.',
              ),
              _HelpItem(
                title: 'Buscador global',
                description: 'Busca por nombre, descripcion, categoria o etiquetas.',
              ),
              _HelpItem(
                title: 'Filtros',
                description: 'Filtra por tipo (ingresos/gastos), por categoria y por efectivo/banco.',
              ),
              _HelpItem(
                title: 'Etiquetas (Tags)',
                description: 'Aniade etiquetas a tus gastos para organizarlos mejor. Se muestran como chips en la tarjeta.',
              ),
              _HelpItem(
                title: 'Categorias personalizadas',
                description: 'Crea tus propias categorias con icono y color. Puedes reordenarlas o desactivarlas.',
              ),
              _HelpItem(
                title: 'Efectivo / Banco',
                description: 'Indica si un ingreso o gasto es en efectivo o banco. Se muestra el desglose en las tarjetas.',
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
                title: 'Desglose Efectivo/Banco',
                description: 'Resumen de movimientos por tipo de cuenta en ingresos y gastos.',
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
                description: 'Es el ingreso del mes anterior. Se usa como base para calcular los porcentajes.',
              ),
              _HelpItem(
                title: 'Redistribución',
                description: 'El dinero no gastado de una categoría se reparte entre otras. Se ejecuta al abrir la app.',
              ),
              _HelpItem(
                title: 'Bloqueo automático',
                description: 'Si los gastos fijos superan el ingreso O el gasto total supera el ingreso, la redistribución se desactiva.',
              ),
              _HelpItem(
                title: 'Tope de redistribución',
                description: 'La redistribución nunca supera el ahorro neto (ingreso - gasto total). Se reparte proporcionalmente.',
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
                description: 'Guarda y carga configuraciones de redistribución. Puedes eliminar presets desde la pantalla de presets o al cargar.',
              ),
              _HelpItem(
                title: 'Vista semanal',
                description: 'Divide el presupuesto mensual entre 4.3 para ver la asignación semanal.',
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
              _HelpItem(
                title: 'Plan de pagos fijos',
                description: 'Configura un pago fijo periodico (diario, semanal, mensual, trimestral, anual). La app calcula el proximo pago automaticamente.',
              ),
              _HelpItem(
                title: 'Recordatorios de pago',
                description: 'Recibe una notificacion 2 dias antes de que se cobre un pago fijo de una meta.',
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
                description: 'Notificación 2 días antes de que se cobre un gasto recurrente o pago fijo de meta.',
              ),
              _HelpItem(
                title: 'Configuracion',
                description: 'Puedes activar o desactivar cada tipo de notificacion individualmente en Ajustes > Notificaciones.',
              ),
              _HelpItem(
                title: 'Notificaciones Push (Web)',
                description: 'En el navegador, activa las notificaciones push para recibir alertas aunque no tengas la pestana abierta. Ve a Ajustes > Notificaciones para activarlas.',
              ),
            ],
          ),
          const SizedBox(height: 8),

          _HelpSection(
            icon: Icons.category,
            title: 'Categorias',
            color: const Color(0xFF795548),
            items: [
              _HelpItem(
                title: 'Categorias por defecto',
                description: 'La app viene con categorias predeterminadas. Se cargan la primera vez que inicias sesion.',
              ),
              _HelpItem(
                title: 'Crear categoria',
                description: 'Pulsa "+" para crear una categoria con nombre, icono (36 opciones) y color (20 opciones).',
              ),
              _HelpItem(
                title: 'Reordenar',
                description: 'Mantén pulsado y arrastra para cambiar el orden de las categorias.',
              ),
              _HelpItem(
                title: 'Activar / Desactivar',
                description: 'Puedes ocultar categorias sin eliminarlas usando el toggle.',
              ),
              _HelpItem(
                title: 'Eliminar',
                description: 'Borra una categoria personalizada. Las categorias por defecto no se pueden eliminar.',
              ),
            ],
          ),
          const SizedBox(height: 8),

          _HelpSection(
            icon: Icons.label,
            title: 'Etiquetas',
            color: const Color(0xFF009688),
            items: [
              _HelpItem(
                title: 'Aniadir etiquetas',
                description: 'Al crear o editar un gasto, escribe etiquetas separadas por coma o pulsa Enter.',
              ),
              _HelpItem(
                title: 'Buscar por etiqueta',
                description: 'Usa el buscador de movimientos para filtrar por etiqueta.',
              ),
              _HelpItem(
                title: 'Visualizacion',
                description: 'Las etiquetas se muestran como chips en la tarjeta del movimiento (maximo 3 + "+N").',
              ),
            ],
          ),
          const SizedBox(height: 8),

          _HelpSection(
            icon: Icons.description,
            title: 'Informes PDF',
            color: const Color(0xFF3F51B5),
            items: [
              _HelpItem(
                title: 'Generar informe',
                description: 'Crea un PDF con el resumen del mes: ingresos, gastos, ahorro y balance.',
              ),
              _HelpItem(
                title: 'Graficos',
                description: 'Incluye graficos de lineas con evolucion de balances y gastos por categoria.',
              ),
              _HelpItem(
                title: 'Formato',
                description: 'Tema claro, valores exactos con 2 decimales, fechas en formato DDMMAAAA.',
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
                description: 'Selecciona entre EUR, USD o GBP con simbolo y decimales automaticos.',
              ),
              _HelpItem(
                title: 'Eliminar datos',
                description: 'Borra todos tus datos permanentemente.',
              ),
              _HelpItem(
                title: 'Cuenta',
                description: 'Cierra sesion o elimina tu cuenta.',
              ),
            ],
          ),
          const SizedBox(height: 8),

          _HelpSection(
            icon: Icons.phone_android,
            title: 'Aplicacion',
            color: const Color(0xFF3DDC84),
            items: [
              _HelpItem(
                title: 'Buscar actualizaciones',
                description: 'Comprueba si hay una nueva version disponible en Firebase.',
              ),
              _HelpItem(
                title: 'Actualizacion automatica (APK)',
                description: 'Al abrir la app, si hay nueva version, puedes descargarla e instalarla directamente desde la app.',
              ),
              _HelpItem(
                title: 'Descargar APK',
                description: 'Descarga la ultima version de Android desde GitHub.',
              ),
              _HelpItem(
                title: 'Abrir version web',
                description: 'Abre la app en el navegador.',
              ),
              _HelpItem(
                title: 'Codigo fuente',
                description: 'Accede al repositorio de GitHub.',
              ),
              _HelpItem(
                title: 'Reinstalar acceso directo (Web)',
                description: 'Si el acceso directo de la PWA no funciona, eliminaalo y vuelve a aniadirlo desde el navegador.',
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
