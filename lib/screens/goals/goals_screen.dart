import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/goal.dart';
import '../../models/product.dart';
import '../../models/product_group.dart';
import '../../services/database_service.dart';
import '../../utils/formatters.dart';
import 'goal_detail_screen.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final _db = DatabaseService.instance;
  List<Goal> _goals = [];
  List<Product> _products = [];
  List<ProductGroup> _groups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final goals = await _db.getAllGoals();
    final products = await _db.getAllProducts();
    final groups = await _db.getAllProductGroups();
    setState(() {
      _goals = goals;
      _products = products;
      _groups = groups;
      _isLoading = false;
    });
  }

  Product? _getProductById(String id) {
    try {
      return _products.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  ProductGroup? _getGroupById(String? id) {
    if (id == null) return null;
    try {
      return _groups.firstWhere((g) => g.id == id);
    } catch (_) {
      return null;
    }
  }

  String _getFrequencyLabel(String? freq) {
    switch (freq) {
      case 'daily': return 'Diario';
      case 'weekly': return 'Semanal';
      case 'monthly': return 'Mensual';
      case 'quarterly': return 'Trimestral';
      case 'annual': return 'Anual';
      default: return freq ?? '';
    }
  }

  void _showAddGoalDialog({Goal? goal}) {
    final nameController = TextEditingController(text: goal?.name ?? '');
    final savedController = TextEditingController(
      text: goal?.savedAmount.toString() ?? '0',
    );
    List<String> selectedProductIds = List.from(goal?.productIds ?? []);
    DateTime? deadline = goal?.deadline;
    
    bool hasFixedPayment = goal?.hasFixedPayment ?? false;
    String? paymentFrequency = goal?.paymentFrequency ?? 'monthly';
    final paymentAmountController = TextEditingController(
      text: goal?.paymentAmount?.toString() ?? '',
    );
    DateTime? firstPaymentDate = goal?.firstPaymentDate;

    double calculateTarget() {
      return selectedProductIds.fold(0.0, (sum, id) {
        final product = _getProductById(id);
        return sum + (product?.price ?? 0);
      });
    }

    int? calculateTotalPayments(double target, double payment) {
      if (payment <= 0 || target <= 0) return null;
      return (target / payment).ceil();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24, right: 24, top: 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  goal == null ? 'Crear Meta' : 'Editar Meta',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 24),

                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la meta',
                    prefixIcon: Icon(Icons.flag),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 20),

                // === PRODUCT/GROUP SELECTION ===
                if (_products.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Añade productos primero en la pestaña Productos',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  )
                else ...[
                  // Selection by group
                  if (_groups.isNotEmpty) ...[
                    Text(
                      'Seleccionar por grupo',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _groups.map((group) {
                        final groupProducts = _products.where((p) => p.groupId == group.id).toList();
                        final allSelected = groupProducts.isNotEmpty &&
                            groupProducts.every((p) => selectedProductIds.contains(p.id));
                        final someSelected = groupProducts.any((p) => selectedProductIds.contains(p.id));

                        return ActionChip(
                          avatar: Container(
                            width: 10, height: 10,
                            decoration: BoxDecoration(
                              color: group.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          label: Text('${group.name} (${groupProducts.length})'),
                          backgroundColor: allSelected
                              ? group.color.withValues(alpha: 0.2)
                              : someSelected
                                  ? group.color.withValues(alpha: 0.1)
                                  : null,
                          side: allSelected || someSelected
                              ? BorderSide(color: group.color)
                              : null,
                          onPressed: () {
                            setModalState(() {
                              if (allSelected) {
                                for (final p in groupProducts) {
                                  selectedProductIds.remove(p.id);
                                }
                              } else {
                                for (final p in groupProducts) {
                                  if (!selectedProductIds.contains(p.id)) {
                                    selectedProductIds.add(p.id);
                                  }
                                }
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                  ],

                  // Individual product selection
                  Text(
                    'Seleccionar productos individuales',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _products.length,
                      itemBuilder: (context, index) {
                        final product = _products[index];
                        final isSelected = selectedProductIds.contains(product.id);
                        final group = _getGroupById(product.groupId);
                        return CheckboxListTile(
                          value: isSelected,
                          onChanged: (value) {
                            setModalState(() {
                              if (value == true) {
                                selectedProductIds.add(product.id);
                              } else {
                                selectedProductIds.remove(product.id);
                              }
                            });
                          },
                          title: Text(product.name),
                          subtitle: Row(
                            children: [
                              Text(Formatters.formatCurrency(product.price)),
                              if (group != null) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: group.color.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    group.name,
                                    style: TextStyle(fontSize: 9, color: group.color, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          secondary: Icon(
                            isSelected ? Icons.check_circle : Icons.add_circle_outline,
                            color: isSelected ? Theme.of(context).colorScheme.primary : null,
                          ),
                        );
                      },
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Target amount
                if (selectedProductIds.isNotEmpty)
                  Card(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Objetivo total:', style: Theme.of(context).textTheme.titleSmall),
                          Text(
                            Formatters.formatCurrency(calculateTarget()),
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),

                // Saved amount
                TextField(
                  controller: savedController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Cantidad ahorrada (\u20ac)',
                    prefixIcon: Icon(Icons.savings),
                  ),
                ),
                const SizedBox(height: 16),

                // Deadline
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: deadline ?? DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                      locale: const Locale('es', 'ES'),
                    );
                    if (picked != null) {
                      setModalState(() => deadline = picked);
                    }
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    deadline != null
                        ? 'Fecha límite: ${Formatters.formatDate(deadline!)}'
                        : 'Establecer fecha límite (opcional)',
                  ),
                ),
                const SizedBox(height: 24),

                // === FIXED PAYMENT SECTION ===
                Card(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.payment, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              'Plan de Pagos Fijos',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          title: const Text('Tiene pago fijo'),
                          subtitle: const Text('Activa para compras a plazos'),
                          value: hasFixedPayment,
                          onChanged: (value) => setModalState(() => hasFixedPayment = value),
                          contentPadding: EdgeInsets.zero,
                        ),
                        if (hasFixedPayment) ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: paymentFrequency,
                            decoration: const InputDecoration(
                              labelText: 'Frecuencia de pago',
                              prefixIcon: Icon(Icons.repeat),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'daily', child: Text('Diario')),
                              DropdownMenuItem(value: 'weekly', child: Text('Semanal')),
                              DropdownMenuItem(value: 'monthly', child: Text('Mensual')),
                              DropdownMenuItem(value: 'quarterly', child: Text('Trimestral')),
                              DropdownMenuItem(value: 'annual', child: Text('Anual')),
                            ],
                            onChanged: (value) => setModalState(() => paymentFrequency = value),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: paymentAmountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Importe por pago (\u20ac)',
                              prefixIcon: Icon(Icons.euro),
                            ),
                            onChanged: (_) => setModalState(() {}),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: firstPaymentDate ?? DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                                locale: const Locale('es', 'ES'),
                              );
                              if (picked != null) {
                                setModalState(() => firstPaymentDate = picked);
                              }
                            },
                            icon: const Icon(Icons.event),
                            label: Text(
                              firstPaymentDate != null
                                  ? 'Primer pago: ${Formatters.formatDate(firstPaymentDate!)}'
                                  : 'Fecha del primer pago (opcional)',
                            ),
                          ),
                          // Show calculated info
                          if (paymentAmountController.text.isNotEmpty &&
                              double.tryParse(paymentAmountController.text) != null &&
                              double.tryParse(paymentAmountController.text)! > 0 &&
                              calculateTarget() > 0) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  _infoRow(
                                    'Total de pagos',
                                    '${calculateTotalPayments(calculateTarget(), double.tryParse(paymentAmountController.text) ?? 0)}',
                                  ),
                                  _infoRow(
                                    'Importe total',
                                    Formatters.formatCurrency(calculateTarget()),
                                  ),
                                  _infoRow(
                                    'Por pago',
                                    Formatters.formatCurrency(double.tryParse(paymentAmountController.text) ?? 0),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                FilledButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final saved = double.tryParse(savedController.text) ?? 0;
                    final target = calculateTarget();

                    if (name.isEmpty || selectedProductIds.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Introduce un nombre y selecciona al menos un producto'),
                        ),
                      );
                      return;
                    }

                    final paymentAmount = hasFixedPayment
                        ? (double.tryParse(paymentAmountController.text) ?? 0)
                        : null;
                    final totalPayments = hasFixedPayment && paymentAmount != null && paymentAmount > 0
                        ? calculateTotalPayments(target, paymentAmount)
                        : null;

                    final newGoal = Goal(
                      id: goal?.id ?? const Uuid().v4(),
                      name: name,
                      productIds: selectedProductIds,
                      targetAmount: target,
                      savedAmount: saved,
                      deadline: deadline,
                      createdAt: goal?.createdAt ?? DateTime.now(),
                      hasFixedPayment: hasFixedPayment,
                      paymentFrequency: hasFixedPayment ? paymentFrequency : null,
                      paymentAmount: paymentAmount,
                      totalPayments: totalPayments,
                      completedPayments: goal?.completedPayments ?? 0,
                      firstPaymentDate: hasFixedPayment ? firstPaymentDate : null,
                      paymentHistory: goal?.paymentHistory ?? [],
                    );

                    if (goal == null) {
                      await _db.insertGoal(newGoal);
                    } else {
                      await _db.updateGoal(newGoal);
                    }

                    if (context.mounted) {
                      Navigator.pop(context);
                      _loadData();
                    }
                  },
                  child: Text(goal == null ? 'Crear Meta' : 'Guardar'),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showAddSavingsDialog(Goal goal) {
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Añadir ahorro'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Meta: ${goal.name}'),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Cantidad a ahorrar (\u20ac)',
                prefixIcon: Icon(Icons.euro),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text) ?? 0;
              if (amount <= 0) return;
              final updatedGoal = goal.copyWith(savedAmount: goal.savedAmount + amount);
              await _db.updateGoal(updatedGoal);
              if (context.mounted) {
                Navigator.pop(context);
                _loadData();
              }
            },
            child: const Text('Añadir'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteGoal(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar meta'),
        content: const Text('¿Estás seguro de que quieres eliminar esta meta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _db.deleteGoal(id);
      _loadData();
    }
  }

  Future<void> _setActiveGoal(String id) async {
    await _db.setActiveGoal(id);
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Metas')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddGoalDialog(),
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: _goals.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.flag_outlined, size: 72,
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25)),
                      const SizedBox(height: 16),
                      Text('Sin metas aún',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          )),
                      const SizedBox(height: 6),
                      Text('Crea una meta para empezar a ahorrar y alcanzar tus objetivos',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                          )),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: () => _showAddGoalDialog(),
                        icon: const Icon(Icons.add),
                        label: const Text('Crear meta'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _goals.length,
                  itemBuilder: (context, index) {
                    final goal = _goals[index];
                    return GoalCard(
                      goal: goal,
                      products: _products,
                      onAddSavings: () => _showAddSavingsDialog(goal),
                      onEdit: () => _showAddGoalDialog(goal: goal),
                      onDelete: () => _deleteGoal(goal.id),
                      onSetActive: () => _setActiveGoal(goal.id),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => GoalDetailScreen(goal: goal),
                          ),
                        ).then((_) => _loadData());
                      },
                    );
                  },
                ),
            ),
    );
  }
}

class GoalCard extends StatelessWidget {
  final Goal goal;
  final List<Product> products;
  final VoidCallback onAddSavings;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSetActive;
  final VoidCallback? onTap;

  const GoalCard({
    super.key,
    required this.goal,
    required this.products,
    required this.onAddSavings,
    required this.onEdit,
    required this.onDelete,
    required this.onSetActive,
    this.onTap,
  });

  String _getFrequencyLabel(String? freq) {
    switch (freq) {
      case 'daily': return 'Diario';
      case 'weekly': return 'Semanal';
      case 'monthly': return 'Mensual';
      case 'quarterly': return 'Trimestral';
      case 'annual': return 'Anual';
      default: return freq ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = goal.progressPercentage / 100;

    final productNames = goal.productIds
        .map((id) {
          try {
            return products.firstWhere((p) => p.id == id).name;
          } catch (_) {
            return null;
          }
        })
        .where((n) => n != null)
        .toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    goal.isActive ? Icons.flag : Icons.outlined_flag,
                    color: goal.isActive ? colorScheme.primary : colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          goal.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          goal.hasFixedPayment
                              ? '${goal.productIds.length} productos \u00b7 ${_getFrequencyLabel(goal.paymentFrequency)}'
                              : '${goal.productIds.length} productos',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton(
                    itemBuilder: (context) => [
                      if (!goal.isActive)
                        const PopupMenuItem(value: 'activate', child: Text('Activar como meta')),
                      const PopupMenuItem(value: 'edit', child: Text('Editar')),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Eliminar', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'activate') onSetActive();
                      if (value == 'edit') onEdit();
                      if (value == 'delete') onDelete();
                    },
                  ),
                ],
              ),

              if (productNames.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: productNames.take(5).map((name) => Chip(
                        label: Text(name!, style: const TextStyle(fontSize: 10)),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      )).toList(),
                ),
                if (productNames.length > 5)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '+${productNames.length - 5} más',
                      style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                    ),
                  ),
              ],

              const SizedBox(height: 16),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(Formatters.formatCurrency(goal.savedAmount),
                          style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary)),
                      Text(Formatters.formatCurrency(goal.targetAmount),
                          style: TextStyle(color: colorScheme.onSurfaceVariant)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 12,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation(
                          goal.isCompleted ? Colors.green : colorScheme.primary),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${goal.progressPercentage.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: goal.isCompleted ? Colors.green : colorScheme.primary,
                        ),
                      ),
                      if (goal.deadline != null)
                        Text(
                          'Fecha límite: ${Formatters.formatDate(goal.deadline!)}',
                          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                ],
              ),

              if (goal.hasFixedPayment) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.tertiaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.payment, size: 16, color: colorScheme.tertiary),
                      const SizedBox(width: 8),
                      Text(
                        '${goal.completedPayments}/${goal.totalPayments} pagos',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.tertiary,
                        ),
                      ),
                      const Spacer(),
                      if (goal.nextPaymentDate != null && !goal.isCompleted)
                        Text(
                          'Próximo: ${Formatters.formatDate(goal.nextPaymentDate!)}',
                          style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),

              if (!goal.isCompleted)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onAddSavings,
                    icon: const Icon(Icons.savings, size: 18),
                    label: const Text('Añadir Ahorro'),
                  ),
                ),

              if (goal.isCompleted)
                Card(
                  color: Colors.green.withValues(alpha: 0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green),
                        const SizedBox(width: 8),
                        Text('¡Meta alcanzada!',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[700])),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
