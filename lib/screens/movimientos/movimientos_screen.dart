import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../../models/daily_income.dart';
import '../../models/expense.dart';
import '../../models/savings_distribution.dart';
import '../../models/unified_movement.dart';
import '../../models/subcategory.dart';
import '../../providers/app_state.dart';
import '../../services/database_service.dart';
import '../../services/import_service.dart';
import '../../services/notification_service.dart';
import '../../utils/formatters.dart';
import '../../utils/theme.dart';
import '../../widgets/category_pill.dart';
import '../../widgets/filter_pill.dart';
import '../../widgets/movement_card.dart';
import '../../widgets/summary_card.dart';
import '../../widgets/type_chip.dart';
import '../../widgets/shimmer_loading.dart';
import '../calendar/unified_calendar_screen.dart';

enum MovementType { ingreso, gasto, cajero }

class MovimientosScreen extends StatefulWidget {
  const MovimientosScreen({super.key});

  @override
  State<MovimientosScreen> createState() => _MovimientosScreenState();
}

enum SummaryPeriod { global, year, month, week }
enum CashFilter { all, cash, bank }

class _MovimientosScreenState extends State<MovimientosScreen> {
  final _db = DatabaseService.instance;
  final _searchController = TextEditingController();
  List<UnifiedMovement> _movements = [];
  double _summaryIncome = 0;
  double _summaryExpense = 0;
  SummaryPeriod _summaryPeriod = SummaryPeriod.global;
  CashFilter _cashFilter = CashFilter.all;
  bool _isLoading = true;
  MovementType? _selectedType;
  String? _selectedCategory;
  String _searchQuery = '';
  List<DistributionCategory> _distributionCategories = [];
  List<Subcategory> _subcategories = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    AppState.instance.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    AppState.instance.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) _loadData();
  }

  Future<void> _loadData() async {
    try {
      final incomes = await _db.getAllIncomes();
      final expenses = await _db.getAllExpenses();

      // Calculate summary totals based on selected period
      final now = DateTime.now();
      final periodDates = _getPeriodDates(_summaryPeriod, now);

      double summaryIncome = 0;
      for (final i in incomes) {
        if (i.type == 'cajero') continue;
        if (periodDates != null) {
          if (i.date.isBefore(periodDates.$1) || i.date.isAfter(periodDates.$2)) continue;
        }
        summaryIncome += i.totalAmount;
      }
      double summaryExpense = 0;
      for (final e in expenses) {
        if (e.isTransfer) continue;
        if (e.category == 'Cajero') continue;
        if (periodDates != null) {
          if (e.date.isBefore(periodDates.$1) || e.date.isAfter(periodDates.$2)) continue;
        }
        summaryExpense += e.amount;
      }

      // Load distribution categories for filter
      SavingsDistribution? dist;
      try {
        dist = await _db.getDistribution(now.month, now.year);
      } catch (_) {}

      // Load subcategories
      List<Subcategory> subcats = [];
      for (final cat in _distributionCategories) {
        try {
          final catSubcats = await _db.getSubcategories(cat.name);
          subcats.addAll(catSubcats);
        } catch (_) {}
      }

      final List<UnifiedMovement> all = [];

      for (final inc in incomes) {
        if (inc.isCashTransfer) continue;
        String label;
        if (inc.isRecurring) {
          label = inc.recurringName ?? _getIncomeTypeLabel(inc.type);
        } else if (inc.type == 'hourly') {
          label = '${inc.hoursWorked}h × ${Formatters.formatCurrency(inc.hourlyRate)}/h';
        } else {
          label = _getIncomeTypeLabel(inc.type);
        }
        all.add(UnifiedMovement(
          id: inc.id,
          amount: inc.totalAmount,
          label: label,
          subtitle: inc.notes,
          date: inc.date,
          isIncome: true,
          isRecurring: inc.isRecurring,
          recurringName: inc.recurringName,
          income: inc,
        ));
      }

      for (final exp in expenses) {
        if (exp.isCashTransfer) continue;
        final subLabel = exp.subcategory.isNotEmpty ? ' › ${exp.subcategory}' : '';
        all.add(UnifiedMovement(
          id: exp.id,
          amount: exp.amount,
          label: exp.isRecurring ? (exp.recurringName ?? (exp.category.isNotEmpty ? exp.category : 'Sin categoría')) : (exp.category.isNotEmpty ? exp.category : 'Sin categoría'),
          subtitle: '${exp.description ?? ''}$subLabel'.trim().isEmpty ? null : '${exp.description ?? ''}$subLabel'.trim(),
          date: exp.date,
          isIncome: false,
          isRecurring: exp.isRecurring,
          recurringName: exp.recurringName,
          expense: exp,
        ));
      }

      all.sort((a, b) {
        final cmp = b.date.compareTo(a.date);
        if (cmp != 0) return cmp;
        return b.id.compareTo(a.id);
      });

      if (mounted) {
        setState(() {
          _movements = all;
          _summaryIncome = summaryIncome;
          _summaryExpense = summaryExpense;
          _distributionCategories = dist?.categories.toList() ?? [];
          _subcategories = subcats;
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

  String _getIncomeTypeLabel(String type) {
    switch (type) {
      case 'hourly':
        return 'Por horas';
      case 'recurring':
        return 'Recurrente';
      default:
        return 'Fijo';
    }
  }

  (DateTime, DateTime)? _getPeriodDates(SummaryPeriod period, DateTime now) {
    switch (period) {
      case SummaryPeriod.global:
        return null;
      case SummaryPeriod.year:
        return (DateTime(now.year, 1, 1), DateTime(now.year, 12, 31, 23, 59, 59));
      case SummaryPeriod.month:
        return (DateTime(now.year, now.month, 1), DateTime(now.year, now.month + 1, 0, 23, 59, 59));
      case SummaryPeriod.week:
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        final weekEnd = weekStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
        return (weekStart, weekEnd);
    }
  }

  String _getPeriodLabel(SummaryPeriod period) {
    final now = DateTime.now();
    switch (period) {
      case SummaryPeriod.global:
        return 'Global';
      case SummaryPeriod.year:
        return 'Año ${now.year}';
      case SummaryPeriod.month:
        return Formatters.formatMonthYear(now);
      case SummaryPeriod.week:
        return 'Esta semana';
    }
  }

  void _showAddMovementDialog({MovementType? initialType, UnifiedMovement? existing}) {
    MovementType movementType = initialType ?? MovementType.gasto;
    if (existing != null) {
      movementType = existing.isIncome ? MovementType.ingreso : MovementType.gasto;
    }

    final amountController = TextEditingController(
      text: existing?.amount.abs().toString() ?? '',
    );
    final descriptionController = TextEditingController(
      text: existing?.subtitle ?? '',
    );
    final recurringNameController = TextEditingController(
      text: existing?.recurringName ?? '',
    );

    DateTime selectedDate = existing?.date ?? DateTime.now();
    bool isRecurring = false;
    bool isCash = existing != null
        ? (existing.isIncome
            ? (existing.income?.isCash ?? false)
            : (existing.expense?.isCash ?? false))
        : false;
    String incomeType = 'fixed';
    String selectedCategory = '';
    String selectedSubcategory = '';
    String selectedTransferTo = '';
    bool isSaving = false;
    bool isCajeroCashToBank = true;
    List<String> selectedTags = List.from(existing?.expense?.tags ?? []);

    if (existing?.income != null) {
      incomeType = existing!.income!.type == 'cajero' ? 'fixed' : existing.income!.type;
      isRecurring = existing.income!.isRecurring;
    }
    if (existing?.expense != null) {
      selectedCategory = existing!.expense!.category;
      selectedSubcategory = existing!.expense!.subcategory;
      selectedTransferTo = existing!.expense!.transferTo ?? '';
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
            left: 24,
            right: 24,
            top: 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  existing == null ? 'Nuevo Movimiento' : 'Editar Movimiento',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 20),

                // Selector Ingreso / Gasto
                Text(
                  'Tipo',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setModalState(() => movementType = MovementType.ingreso),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: movementType == MovementType.ingreso
                                ? AppTheme.incomeColor
                                : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: movementType == MovementType.ingreso
                                  ? AppTheme.incomeColor
                                  : Theme.of(context).colorScheme.outline,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_circle_outline,
                                color: movementType == MovementType.ingreso
                                    ? Colors.white
                                    : AppTheme.incomeColor,
                                size: 20,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Ingreso',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: movementType == MovementType.ingreso
                                      ? Colors.white
                                      : AppTheme.incomeColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setModalState(() => movementType = MovementType.gasto),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: movementType == MovementType.gasto
                                ? AppTheme.expenseColor
                                : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: movementType == MovementType.gasto
                                  ? AppTheme.expenseColor
                                  : Theme.of(context).colorScheme.outline,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.remove_circle_outline,
                                color: movementType == MovementType.gasto
                                    ? Colors.white
                                    : AppTheme.expenseColor,
                                size: 20,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Gasto',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: movementType == MovementType.gasto
                                      ? Colors.white
                                      : AppTheme.expenseColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setModalState(() {
                          movementType = MovementType.cajero;
                          isCajeroCashToBank = true;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: movementType == MovementType.cajero
                                ? Colors.teal
                                : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: movementType == MovementType.cajero
                                  ? Colors.teal
                                  : Theme.of(context).colorScheme.outline,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.local_atm,
                                color: movementType == MovementType.cajero
                                    ? Colors.white
                                    : Colors.teal,
                                size: 20,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Cajero',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: movementType == MovementType.cajero
                                      ? Colors.white
                                      : Colors.teal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // === CAMPOS CAJERO ===
                if (movementType == MovementType.cajero) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.teal),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Transferencia entre tus cuentas. No cuenta como ingreso ni gasto.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Direccion',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TypeChip(
                          icon: Icons.money_rounded,
                          label: 'Efectivo \u2192 Banco',
                          isSelected: isCajeroCashToBank,
                          onTap: () => setModalState(() => isCajeroCashToBank = true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TypeChip(
                          icon: Icons.account_balance_rounded,
                          label: 'Banco \u2192 Efectivo',
                          isSelected: !isCajeroCashToBank,
                          onTap: () => setModalState(() => isCajeroCashToBank = false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Cantidad (\u20ac)',
                      prefixIcon: Icon(Icons.local_atm),
                    ),
                  ),
                ],

                // === CAMPOS INGRESO ===
                if (movementType == MovementType.ingreso) ...[
                  Text(
                    'Tipo de ingreso',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TypeChip(
                          icon: Icons.euro,
                          label: 'Fijo',
                          isSelected: incomeType == 'fixed',
                          onTap: () => setModalState(() => incomeType = 'fixed'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TypeChip(
                          icon: Icons.repeat,
                          label: 'Recurrente',
                          isSelected: incomeType == 'recurring',
                          onTap: () => setModalState(() => incomeType = 'recurring'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (incomeType == 'fixed' || incomeType == 'recurring') ...[
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: incomeType == 'recurring' ? 'Cantidad mensual (\u20ac)' : 'Cantidad (\u20ac)',
                        prefixIcon: const Icon(Icons.euro),
                      ),
                    ),
                    if (incomeType == 'recurring') ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: recurringNameController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre (ej: Alquiler, Pensi\u00f3n)',
                          prefixIcon: Icon(Icons.label),
                        ),
                      ),
                    ],
                  ],

                  if (incomeType != 'recurring') ...[
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Ingreso recurrente'),
                      subtitle: const Text('Se repite cada mes'),
                      value: isRecurring,
                      onChanged: (value) => setModalState(() => isRecurring = value),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],

                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Notas (opcional)',
                      prefixIcon: Icon(Icons.note),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('Efectivo'),
                    subtitle: const Text('El dinero est\u00e1 en f\u00edsico'),
                    value: isCash,
                    onChanged: (value) => setModalState(() => isCash = value),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],

                // === CAMPOS GASTO ===
                if (movementType == MovementType.gasto) ...[
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Cantidad (\u20ac)',
                      prefixIcon: Icon(Icons.euro),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Categoría',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 8),
                  if (_distributionCategories.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        'Configura categorías en Distribución primero',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilterChip(
                          label: const Text('Sin categoría'),
                          selected: selectedCategory.isEmpty,
                          onSelected: (_) => setModalState(() {
                            selectedCategory = '';
                            selectedTransferTo = '';
                          }),
                          avatar: Icon(
                            Icons.category_outlined,
                            size: 18,
                            color: selectedCategory.isEmpty ? Colors.white : Theme.of(context).colorScheme.primary,
                          ),
                          selectedColor: Theme.of(context).colorScheme.primary,
                          checkmarkColor: Colors.white,
                          labelStyle: TextStyle(color: selectedCategory.isEmpty ? Colors.white : null),
                        ),
                        FilterChip(
                          label: const Text('Transferencia'),
                          selected: selectedCategory == 'Transferencia',
                          onSelected: (_) => setModalState(() {
                            selectedCategory = selectedCategory == 'Transferencia' ? '' : 'Transferencia';
                            if (selectedCategory != 'Transferencia') selectedTransferTo = '';
                          }),
                          avatar: Icon(
                            Icons.swap_horiz,
                            size: 18,
                            color: selectedCategory == 'Transferencia'
                                ? Colors.white
                                : Theme.of(context).colorScheme.tertiary,
                          ),
                          selectedColor: Theme.of(context).colorScheme.tertiary,
                          checkmarkColor: Colors.white,
                          labelStyle: TextStyle(
                            color: selectedCategory == 'Transferencia' ? Colors.white : null,
                          ),
                        ),
                        ..._distributionCategories.map((cat) {
                          final isSelected = selectedCategory == cat.name;
                          return FilterChip(
                            label: Text(cat.name),
                            selected: isSelected,
                            onSelected: (_) => setModalState(() => selectedCategory = cat.name),
                            avatar: Icon(
                              Icons.category,
                              size: 18,
                              color: isSelected ? Colors.white : Theme.of(context).colorScheme.primary,
                            ),
                            selectedColor: Theme.of(context).colorScheme.primary,
                            checkmarkColor: Colors.white,
                            labelStyle: TextStyle(color: isSelected ? Colors.white : null),
                          );
                        }),
                      ],
                    ),
                  const SizedBox(height: 16),
                  // Subcategory selector
                  if (selectedCategory.isNotEmpty) ...[
                    Text(
                      'Subcategoría (opcional)',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilterChip(
                          label: const Text('Sin subcategoría'),
                          selected: selectedSubcategory.isEmpty,
                          onSelected: (_) => setModalState(() => selectedSubcategory = ''),
                          avatar: Icon(
                            Icons.category_outlined,
                            size: 18,
                            color: selectedSubcategory.isEmpty
                                ? Colors.white
                                : Theme.of(context).colorScheme.primary,
                          ),
                          selectedColor: Theme.of(context).colorScheme.primary,
                          checkmarkColor: Colors.white,
                          labelStyle: TextStyle(
                            color: selectedSubcategory.isEmpty ? Colors.white : null,
                          ),
                        ),
                        ..._subcategories
                            .where((s) => s.categoryId == selectedCategory)
                            .map((sub) {
                          final isSelected = selectedSubcategory == sub.name;
                          return FilterChip(
                            label: Text(sub.name),
                            selected: isSelected,
                            onSelected: (_) =>
                                setModalState(() => selectedSubcategory = sub.name),
                            avatar: Icon(
                              Icons.label,
                              size: 18,
                              color: isSelected
                                  ? Colors.white
                                  : Theme.of(context).colorScheme.primary,
                            ),
                            selectedColor: Theme.of(context).colorScheme.primary,
                            checkmarkColor: Colors.white,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : null,
                            ),
                          );
                        }),
                        // Add new subcategory chip
                        ActionChip(
                          avatar: Icon(
                            Icons.add,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          label: Text(
                            'Añadir',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          onPressed: () => _showAddSubcategoryDialog(
                            context,
                            selectedCategory,
                            setModalState,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  // Transfer destination selector
                  if (selectedCategory == 'Transferencia') ...[
                    Text(
                      'Destino',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ..._distributionCategories.map((cat) {
                          final isSelected = selectedTransferTo == cat.name;
                          return FilterChip(
                            label: Text(cat.name),
                            selected: isSelected,
                            onSelected: (_) => setModalState(() {
                              selectedTransferTo = isSelected ? '' : cat.name;
                            }),
                            avatar: Icon(
                              Icons.account_balance_wallet,
                              size: 18,
                              color: isSelected ? Colors.white : Theme.of(context).colorScheme.tertiary,
                            ),
                            selectedColor: Theme.of(context).colorScheme.tertiary,
                            checkmarkColor: Colors.white,
                            labelStyle: TextStyle(color: isSelected ? Colors.white : null),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: descriptionController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Descripción (opcional)',
                      prefixIcon: Icon(Icons.note),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Tags
                  _TagsInput(
                    selectedTags: selectedTags,
                    onChanged: (tags) => setModalState(() => selectedTags = tags),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Gasto recurrente'),
                    subtitle: const Text('Se repite cada mes'),
                    value: isRecurring,
                    onChanged: (value) => setModalState(() => isRecurring = value),
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (isRecurring) ...[
                    TextField(
                      controller: recurringNameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre (ej: Netflix, Alquiler)',
                        prefixIcon: Icon(Icons.label),
                      ),
                    ),
                  ],
                  SwitchListTile(
                    title: const Text('Efectivo'),
                    subtitle: const Text('El pago es en físico'),
                    value: isCash,
                    onChanged: (value) => setModalState(() => isCash = value),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],

                const SizedBox(height: 16),

                // Fecha
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      locale: const Locale('es', 'ES'),
                    );
                    if (picked != null) {
                      setModalState(() => selectedDate = picked);
                    }
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: Text(Formatters.formatDate(selectedDate)),
                ),
                const SizedBox(height: 24),

                // Guardar
                FilledButton(
                  onPressed: isSaving ? null : () async {
                    setModalState(() => isSaving = true);
                    try {
                    if (movementType == MovementType.cajero) {
                      final totalAmount = double.tryParse(amountController.text) ?? 0;
                      if (totalAmount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Introduce una cantidad valida')),
                        );
                        return;
                      }

                      if (isCajeroCashToBank) {
                        // Efectivo -> Banco: cash expense + bank income
                        final cashExpense = Expense(
                          id: const Uuid().v4(),
                          amount: totalAmount,
                          category: 'Cajero',
                          subcategory: '',
                          date: selectedDate,
                          description: 'ATM: Efectivo a Banco',
                          isRecurring: false,
                          isCash: true,
                          tags: const ['cajero', 'transferencia'],
                        );
                        await _db.insertExpense(cashExpense);

                        final bankIncome = DailyIncome(
                          id: const Uuid().v4(),
                          date: selectedDate,
                          hoursWorked: 0,
                          hourlyRate: 0,
                          totalAmount: totalAmount,
                          notes: 'ATM: Efectivo a Banco',
                          type: 'cajero',
                          isRecurring: false,
                          isCash: false,
                        );
                        await _db.insertIncome(bankIncome);
                      } else {
                        // Banco -> Efectivo: bank expense + cash income
                        final bankExpense = Expense(
                          id: const Uuid().v4(),
                          amount: totalAmount,
                          category: 'Cajero',
                          subcategory: '',
                          date: selectedDate,
                          description: 'ATM: Banco a Efectivo',
                          isRecurring: false,
                          isCash: false,
                          tags: const ['cajero', 'transferencia'],
                        );
                        await _db.insertExpense(bankExpense);

                        final cashIncome = DailyIncome(
                          id: const Uuid().v4(),
                          date: selectedDate,
                          hoursWorked: 0,
                          hourlyRate: 0,
                          totalAmount: totalAmount,
                          notes: 'ATM: Banco a Efectivo',
                          type: 'cajero',
                          isRecurring: false,
                          isCash: true,
                        );
                        await _db.insertIncome(cashIncome);
                      }

                      if (mounted) {
                        Navigator.pop(context);
                        _loadData();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Transferencia ATM realizada')),
                        );
                      }
                      return;
                    }

                    if (movementType == MovementType.ingreso) {
                      final amount = double.tryParse(amountController.text) ?? 0;
                      if (amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Introduce una cantidad válida')),
                        );
                        return;
                      }

                      final effectiveIsRecurring = incomeType == 'recurring' || isRecurring;
                      final effectiveType = incomeType == 'recurring' && isRecurring
                          ? 'recurring'
                          : incomeType;

                      final newIncome = DailyIncome(
                        id: existing?.id ?? const Uuid().v4(),
                        date: selectedDate,
                        totalAmount: amount,
                        notes: descriptionController.text.isEmpty ? null : descriptionController.text,
                        type: effectiveType,
                        isRecurring: effectiveIsRecurring,
                        recurringName: effectiveIsRecurring
                            ? (recurringNameController.text.isEmpty
                                ? null
                                : recurringNameController.text)
                            : null,
                        isCash: isCash,
                      );

                      if (existing == null) {
                        await _db.insertIncome(newIncome);
                      } else {
                        await _db.updateIncome(newIncome);
                      }
                    } else {
                      final amount = double.tryParse(amountController.text) ?? 0;
                      if (amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Introduce una cantidad válida')),
                        );
                        return;
                      }

                      final newExpense = Expense(
                        id: existing?.id ?? const Uuid().v4(),
                        amount: amount,
                        category: selectedCategory,
                        subcategory: selectedSubcategory,
                        date: selectedDate,
                        description: descriptionController.text.isEmpty ? null : descriptionController.text,
                        isRecurring: isRecurring,
                        recurringName: isRecurring
                            ? recurringNameController.text.isEmpty
                                ? null
                                : recurringNameController.text
                            : null,
                        transferTo: selectedCategory == 'Transferencia' && selectedTransferTo.isNotEmpty
                            ? selectedTransferTo
                            : null,
                        isCash: isCash,
                        tags: selectedTags,
                      );

                      if (existing == null) {
                        await _db.insertExpense(newExpense);
                      } else {
                        await _db.updateExpense(newExpense);
                      }

                      // Check budget alerts for this category (skip transfers)
                      if (selectedCategory.isNotEmpty && selectedCategory != 'Transferencia') {
                        try {
                          final now = DateTime.now();
                          final budget = await _db.getBudgetByCategory(
                              now.month, now.year, selectedCategory);
                          if (budget != null && budget.limitAmount > 0) {
                            final allExpenses = await _db.getExpensesByMonth(
                                now.month, now.year);
                            double categorySpent = 0;
                            for (final e in allExpenses) {
                              if (e.category == selectedCategory) {
                                categorySpent += e.amount;
                              }
                            }
                            await NotificationService.instance.checkBudgetAlerts(
                                categorySpent, budget.limitAmount, selectedCategory);
                          }
                        } catch (_) {}
                      }
                    }

                    if (context.mounted) {
                      Navigator.pop(context);
                      _loadData();
                    }
                    } finally {
                      if (mounted) setModalState(() => isSaving = false);
                    }
                  },
                  child: Text(existing == null ? 'Añadir' : 'Guardar'),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddSubcategoryDialog(
    BuildContext context,
    String categoryName,
    StateSetter setModalState,
  ) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva subcategoría'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Nombre',
            prefixIcon: const Icon(Icons.label),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              final sub = Subcategory(
                id: const Uuid().v4(),
                name: name,
                categoryId: categoryName,
              );
              await _db.insertSubcategory(sub);
              if (ctx.mounted) Navigator.pop(ctx);
              // Refresh subcategories in the parent modal
              setModalState(() {
                _subcategories.add(sub);
              });
            },
            child: const Text('Añadir'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMovement(UnifiedMovement movement) async {
    final isIncome = movement.isIncome;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isIncome ? 'Eliminar ingreso' : 'Eliminar gasto'),
        content: Text(isIncome
            ? 'Eliminar este ingreso de ${Formatters.formatCurrency(movement.amount)}?'
            : 'Eliminar este gasto de ${Formatters.formatCurrency(movement.amount)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      if (isIncome) {
        await _db.deleteIncome(movement.id);
      } else {
        await _db.deleteExpense(movement.id);
      }

      // For ATM transfers, also delete the linked counterpart
      if (isIncome && movement.income?.type == 'cajero') {
        final allExpenses = await _db.getAllExpenses();
        for (final exp in allExpenses) {
          if (exp.category == 'Cajero' &&
              exp.date.year == movement.date.year &&
              exp.date.month == movement.date.month &&
              exp.date.day == movement.date.day &&
              exp.amount == movement.amount) {
            await _db.deleteExpense(exp.id);
          }
        }
      } else if (!isIncome && movement.expense?.category == 'Cajero') {
        final allIncomes = await _db.getAllIncomes();
        for (final inc in allIncomes) {
          if (inc.type == 'cajero' &&
              inc.date.year == movement.date.year &&
              inc.date.month == movement.date.month &&
              inc.date.day == movement.date.day &&
              inc.totalAmount == movement.amount) {
            await _db.deleteIncome(inc.id);
          }
        }
      }

      _loadData();

      if (!mounted) return;
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Movimiento eliminado'),
          action: SnackBarAction(
            label: 'Deshacer',
            onPressed: () async {
              if (isIncome && movement.income != null) {
                await _db.insertIncome(movement.income!);
              } else if (!isIncome && movement.expense != null) {
                await _db.insertExpense(movement.expense!);
              }
              _loadData();
            },
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _showImportDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Importar CSV'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Formato: Fecha,Tipo,Categoria,Descripcion,Cantidad\n'
                  'Fecha: YYYY-MM-DD o DD/MM/YYYY\n'
                  'Tipo: "ingreso" o "gasto"',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    hintText: 'Pega el contenido CSV aquí...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                final csvContent = controller.text.trim();
                if (csvContent.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No hay datos para importar')),
                  );
                  return;
                }
                Navigator.pop(context);
                await _processCsvImport(csvContent);
              },
              child: const Text('Importar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processCsvImport(String csvContent) async {
    final result = ImportService.importCsv(csvContent);

    if (!mounted) return;

    if (result.totalRows == 0 && !result.hasErrors) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se encontraron registros válidos')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vista previa de importación'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (result.incomes.isNotEmpty)
                Text('Ingresos: ${result.incomes.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              for (final inc in result.incomes.take(5))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '  ${Formatters.formatDate(inc.date)} - ${Formatters.formatCurrency(inc.totalAmount)}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              if (result.incomes.length > 5)
                Text('  ... y ${result.incomes.length - 5} más'),
              const SizedBox(height: 8),
              if (result.expenses.isNotEmpty)
                Text('Gastos: ${result.expenses.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              for (final exp in result.expenses.take(5))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '  ${Formatters.formatDate(exp.date)} - ${exp.category} - ${Formatters.formatCurrency(exp.amount)}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              if (result.expenses.length > 5)
                Text('  ... y ${result.expenses.length - 5} más'),
              if (result.hasErrors) ...[
                const SizedBox(height: 12),
                Text('Errores: ${result.errors.length}',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.error)),
                for (final err in result.errors.take(3))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text('  $err', style: const TextStyle(fontSize: 11)),
                  ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar importación'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      int importedCount = 0;
      for (final inc in result.incomes) {
        await _db.insertIncome(inc);
        importedCount++;
      }
      for (final exp in result.expenses) {
        await _db.insertExpense(exp);
        importedCount++;
      }

      _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$importedCount registros importados')),
        );
      }
    }
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) return 'Hoy';
    if (dateOnly == today.subtract(const Duration(days: 1))) return 'Ayer';

    final months = [
      '', 'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    return '${date.day} ${months[date.month]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    var filtered = _movements;

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((m) {
        final matchesLabel = m.label.toLowerCase().contains(query);
        final matchesSubtitle = m.subtitle?.toLowerCase().contains(query) ?? false;
        final matchesAmount = m.amount.toString().contains(query);
        final matchesCategory = m.expense?.category.toLowerCase().contains(query) ?? false;
        final matchesTags = m.expense?.tags.any((t) => t.toLowerCase().contains(query)) ?? false;
        final matchesDescription = m.expense?.description?.toLowerCase().contains(query) ?? false;
        return matchesLabel || matchesSubtitle || matchesAmount || matchesCategory || matchesTags || matchesDescription;
      }).toList();
    }

    if (_selectedType == MovementType.ingreso) {
      filtered = filtered.where((m) => m.isIncome).toList();
    } else if (_selectedType == MovementType.gasto) {
      filtered = filtered.where((m) => !m.isIncome).toList();
    }
    if (_selectedCategory != null) {
      if (_selectedCategory == '__sin_categoria__') {
        filtered = filtered.where((m) =>
            !m.isIncome && m.expense?.category.isEmpty == true).toList();
      } else {
        filtered = filtered.where((m) =>
            !m.isIncome && m.expense?.category == _selectedCategory).toList();
      }
    }
    if (_cashFilter == CashFilter.cash) {
      filtered = filtered.where((m) => m.isCash).toList();
    } else if (_cashFilter == CashFilter.bank) {
      filtered = filtered.where((m) => !m.isCash).toList();
    }

    // Group movements by date
    final Map<String, List<UnifiedMovement>> grouped = {};
    final Map<String, DateTime> groupDates = {};
    for (final m in filtered) {
      final key = '${m.date.year}-${m.date.month.toString().padLeft(2, '0')}-${m.date.day.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []).add(m);
      groupDates[key] = DateTime(m.date.year, m.date.month, m.date.day);
    }
    final groupedKeys = grouped.keys.toList()
      ..sort((a, b) => groupDates[b]!.compareTo(groupDates[a]!));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Movimientos'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'import') _showImportDialog();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'import',
                child: Row(
                  children: [
                    Icon(Icons.file_upload_outlined, size: 20),
                    SizedBox(width: 8),
                    Text('Importar CSV'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddMovementDialog(),
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const ShimmerMovimientosList()
          : RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
              slivers: [
                // ── Summary cards ──
                SliverToBoxAdapter(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.25),
                    ),
                    child: Column(
                      children: [
                        // Period selector
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: SummaryPeriod.values.map((period) {
                            final isSelected = _summaryPeriod == period;
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: ChoiceChip(
                                label: Text(
                                  period == SummaryPeriod.global
                                      ? 'Global'
                                      : period == SummaryPeriod.year
                                          ? 'Año'
                                          : period == SummaryPeriod.month
                                              ? 'Mes'
                                              : 'Semana',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                selected: isSelected,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() => _summaryPeriod = period);
                                    _loadData();
                                  }
                                },
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getPeriodLabel(_summaryPeriod),
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: SummaryCard(
                                label: 'Ingresos',
                                amount: '+${Formatters.formatCurrency(_summaryIncome)}',
                                color: AppTheme.incomeColor,
                                icon: Icons.arrow_downward_rounded,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SummaryCard(
                                label: 'Gastos',
                                amount: '-${Formatters.formatCurrency(_summaryExpense)}',
                                color: AppTheme.expenseColor,
                                icon: Icons.arrow_upward_rounded,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SummaryCard(
                          label: 'Balance',
                          amount: Formatters.formatCurrency(_summaryIncome - _summaryExpense),
                          color: (_summaryIncome - _summaryExpense) >= 0 ? AppTheme.incomeColor : AppTheme.expenseColor,
                          icon: (_summaryIncome - _summaryExpense) >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                          wide: true,
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Search bar ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Buscar movimientos...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                  ),
                ),

                // ── Type filter chips ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              FilterPill(
                                label: 'Todos',
                                isSelected: _selectedType == null,
                                onTap: () => setState(() {
                                  _selectedType = null;
                                  _selectedCategory = null;
                                }),
                              ),
                              const SizedBox(width: 8),
                              FilterPill(
                                label: 'Ingresos',
                                icon: Icons.add_circle_outline,
                                iconColor: AppTheme.incomeColor,
                                isSelected: _selectedType == MovementType.ingreso,
                                onTap: () => setState(() {
                                  _selectedType = _selectedType == MovementType.ingreso ? null : MovementType.ingreso;
                                  _selectedCategory = null;
                                }),
                              ),
                              const SizedBox(width: 8),
                              FilterPill(
                                label: 'Gastos',
                                icon: Icons.remove_circle_outline,
                                iconColor: AppTheme.expenseColor,
                                isSelected: _selectedType == MovementType.gasto,
                                onTap: () => setState(() {
                                  _selectedType = _selectedType == MovementType.gasto ? null : MovementType.gasto;
                                  _selectedCategory = null;
                                }),
                              ),
                              const SizedBox(width: 8),
                              FilterPill(
                                label: 'Efectivo',
                                icon: Icons.money_rounded,
                                iconColor: Colors.orange,
                                isSelected: _cashFilter == CashFilter.cash,
                                onTap: () => setState(() {
                                  _cashFilter = _cashFilter == CashFilter.cash ? CashFilter.all : CashFilter.cash;
                                }),
                              ),
                              const SizedBox(width: 8),
                              FilterPill(
                                label: 'Banco',
                                icon: Icons.account_balance_rounded,
                                iconColor: Colors.blue,
                                isSelected: _cashFilter == CashFilter.bank,
                                onTap: () => setState(() {
                                  _cashFilter = _cashFilter == CashFilter.bank ? CashFilter.all : CashFilter.bank;
                                }),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Category filter chips ──
                if (_selectedType != MovementType.ingreso && _distributionCategories.isNotEmpty)
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 52,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        children: [
                          CategoryPill(
                            label: 'Sin categoría',
                            icon: Icons.category_outlined,
                            isSelected: _selectedCategory == '__sin_categoria__',
                            onTap: () => setState(() {
                              _selectedCategory = _selectedCategory == '__sin_categoria__' ? null : '__sin_categoria__';
                            }),
                          ),
                          const SizedBox(width: 8),
                          ..._distributionCategories.map((cat) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: CategoryPill(
                                label: cat.name,
                                icon: Icons.category,
                                isSelected: _selectedCategory == cat.name,
                                onTap: () => setState(() {
                                  _selectedCategory = _selectedCategory == cat.name ? null : cat.name;
                                }),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 8)),

                // ── Movement list grouped by date ──
                if (filtered.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_rounded, size: 72,
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25)),
                          const SizedBox(height: 16),
                          Text(
                            'Sin movimientos',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Registra ingresos y gastos para llevar el control de tus finanzas',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                                ),
                          ),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed: () => _showAddMovementDialog(),
                            icon: const Icon(Icons.add),
                            label: const Text('Añadir movimiento'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, groupIndex) {
                            final key = groupedKeys[groupIndex];
                            final dayMovements = grouped[key]!;
                            final firstDate = dayMovements.first.date;
                            final dayIncome = dayMovements
                                .where((m) => m.isIncome)
                                .fold<double>(0, (sum, m) => sum + m.amount);
                            final dayExpense = dayMovements
                                .where((m) => !m.isIncome)
                                .fold<double>(0, (sum, m) => sum + m.amount);
                            final dayBalance = dayIncome - dayExpense;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Date header
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                                  child: Row(
                                    children: [
                                      Text(
                                        _formatDateHeader(firstDate),
                                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.2,
                                            ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: dayBalance >= 0
                                              ? AppTheme.incomeColor.withValues(alpha: 0.1)
                                              : AppTheme.expenseColor.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          '${dayBalance >= 0 ? '+' : ''}${Formatters.formatCurrency(dayBalance)}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: dayBalance >= 0 ? AppTheme.incomeColor : AppTheme.expenseColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Day total summary
                                if (dayIncome > 0 || dayExpense > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8, left: 4, right: 4),
                                    child: Row(
                                      children: [
                                        if (dayIncome > 0) ...[
                                          Icon(Icons.arrow_downward_rounded, size: 12, color: AppTheme.incomeColor),
                                          const SizedBox(width: 3),
                                          Text(
                                            Formatters.formatCurrency(dayIncome),
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: AppTheme.incomeColor,
                                            ),
                                          ),
                                        ],
                                        if (dayIncome > 0 && dayExpense > 0)
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                            child: Text('·', style: TextStyle(
                                              fontSize: 12,
                                              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                                            )),
                                          ),
                                        if (dayExpense > 0) ...[
                                          Icon(Icons.arrow_upward_rounded, size: 12, color: AppTheme.expenseColor),
                                          const SizedBox(width: 3),
                                          Text(
                                            Formatters.formatCurrency(dayExpense),
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: AppTheme.expenseColor,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),

                                // Movement cards
                                ...dayMovements.map((m) => MovementCard(
                                      movement: m,
                                      onTap: () => _showAddMovementDialog(existing: m),
                                      onDelete: () => _deleteMovement(m),
                                    )),

                                if (groupIndex < groupedKeys.length - 1)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Divider(
                                      height: 1,
                                      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
                                    ),
                                  ),
                              ],
                            );
                          },
                        childCount: groupedKeys.length,
                      ),
                    ),
                  ),
              ],
            ),
          ),
    );
  }
}

class _TagsInput extends StatefulWidget {
  final List<String> selectedTags;
  final ValueChanged<List<String>> onChanged;

  const _TagsInput({required this.selectedTags, required this.onChanged});

  @override
  State<_TagsInput> createState() => _TagsInputState();
}

class _TagsInputState extends State<_TagsInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _addTag() {
    final tag = _controller.text.trim();
    if (tag.isNotEmpty && !widget.selectedTags.contains(tag)) {
      widget.onChanged([...widget.selectedTags, tag]);
      _controller.clear();
    }
    _focusNode.requestFocus();
  }

  void _removeTag(String tag) {
    widget.onChanged(widget.selectedTags.where((t) => t != tag).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.selectedTags.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: widget.selectedTags.map((tag) => Chip(
              label: Text(tag, style: const TextStyle(fontSize: 12)),
              deleteIcon: const Icon(Icons.close, size: 16),
              onDeleted: () => _removeTag(tag),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            )).toList(),
          ),
        if (widget.selectedTags.isNotEmpty) const SizedBox(height: 8),
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          decoration: InputDecoration(
            hintText: 'Añadir etiqueta...',
            prefixIcon: const Icon(Icons.label_outline, size: 20),
            suffixIcon: IconButton(
              icon: const Icon(Icons.add, size: 20),
              onPressed: _addTag,
            ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onSubmitted: (_) => _addTag(),
        ),
      ],
    );
  }
}
