import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/expense.dart';
import '../../models/savings_distribution.dart';
import '../../models/redistribution_config.dart';
import '../../models/redistribution_preset.dart';
import '../../services/database_service.dart';
import '../../utils/formatters.dart';
import '../../validators/distribution_validator.dart';
import 'presets_screen.dart';

class DistributionScreen extends StatefulWidget {
  const DistributionScreen({super.key});

  @override
  State<DistributionScreen> createState() => _DistributionScreenState();
}

class _DistributionScreenState extends State<DistributionScreen> {
  final _db = DatabaseService.instance;
  SavingsDistribution? _currentDistribution;
  DateTime _selectedMonth = DateTime.now();
  bool _isLoading = true;
  double _previousMonthRedistribution = 0;
  bool _isWeeklyView = false;
  int _globalRedistributionDay = 1;
  bool _redistributionEnabled = true;
  Map<String, RedistributionConfig> _redistributionConfigs = {};
  List<RedistributionPreset> _redistributionPresets = [];
  double _transfersToSavings = 0;
  Map<String, double> _redistributionReceivedMap = {};

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _loadData();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isWeeklyView = prefs.getBool('budget_weekly_view') ?? false;
      });
    }
  }

  Future<void> _toggleBudgetView(bool isWeekly) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('budget_weekly_view', isWeekly);
    if (mounted) {
      setState(() {
        _isWeeklyView = isWeekly;
      });
    }
  }

  Future<void> _loadData() async {
    try {
      final month = _selectedMonth.month;
      final year = _selectedMonth.year;

      SavingsDistribution? dist;
      try {
        dist = await _db.getDistribution(month, year);
      } catch (_) {
        dist = null;
      }

      // If in-memory data exists for this month, keep it
      if (dist == null && _currentDistribution != null &&
          _currentDistribution!.month == month && _currentDistribution!.year == year) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      // Always sync monthlyIncome with actual previous month income (daily recalculation)
      // This preserves spentAmount in categories while updating the budget
      if (dist != null) {
        final prevMonth = month == 1 ? 12 : month - 1;
        final prevYear = month == 1 ? year - 1 : year;
        final actualPrevIncome = await _db.getTotalIncomeByMonth(prevMonth, prevYear);
        if (actualPrevIncome > 0 && dist.monthlyIncome != actualPrevIncome) {
          dist = dist.copyWith(monthlyIncome: actualPrevIncome);
          await _db.insertDistribution(dist);
        }
      }

      // Calculate redistribution from previous month
      double prevRedistribution = 0;
      try {
        prevRedistribution = await _db.calculateRedistributionForMonth(month, year);
      } catch (_) {}

      // If still null, try to copy from previous month
      if (dist == null) {
        final prevMonth = month == 1 ? 12 : month - 1;
        final prevYear = month == 1 ? year - 1 : year;
        SavingsDistribution? prevDist;
        try {
          prevDist = await _db.getDistribution(prevMonth, prevYear);
        } catch (_) {}

        if (prevDist != null) {
          // Use actual total income from previous month as the budget
          final actualPrevIncome = await _db.getTotalIncomeByMonth(prevMonth, prevYear);
          // Copy categories from previous month
          final newCategories = prevDist.userCategories.map((cat) => DistributionCategory(
            name: cat.name,
            fixedAmount: cat.fixedAmount,
            percentage: cat.percentage,
            isFixed: cat.isFixed,
            spentAmount: 0,
            isAutomatic: false,
            isEnabled: cat.isEnabled,
            redistributionPercentages: cat.redistributionPercentages,
          )).toList();
          newCategories.add(DistributionCategory(
            name: 'Ahorro',
            isFixed: true,
            isAutomatic: true,
          ));
          dist = SavingsDistribution(
            id: const Uuid().v4(),
            month: month,
            year: year,
            monthlyIncome: actualPrevIncome > 0 ? actualPrevIncome : 0,
            categories: newCategories,
          );
          // Persist the new distribution
          await _db.insertDistribution(dist);
        } else {
          // No previous month distribution record — still check actual income
          final actualPrevIncome = await _db.getTotalIncomeByMonth(prevMonth, prevYear);
          if (actualPrevIncome > 0) {
            // Create from previous month's actual income with default categories
            dist = SavingsDistribution(
              id: const Uuid().v4(),
              month: month,
              year: year,
              monthlyIncome: actualPrevIncome,
              categories: [
                DistributionCategory(
                  name: 'Ahorro',
                  isFixed: true,
                  isAutomatic: true,
                ),
              ],
            );
            await _db.insertDistribution(dist);
          } else {
            // No previous month data — create empty placeholder
            dist = SavingsDistribution(
              id: const Uuid().v4(),
              month: month,
              year: year,
              monthlyIncome: 0,
              categories: [
                DistributionCategory(
                  name: 'Ahorro',
                  isFixed: true,
                  isAutomatic: true,
                ),
              ],
            );
          }
        }
      }

      // Ensure Ahorro category exists
      if (!dist.categories.any((c) => c.isAutomatic)) {
        final cats = List<DistributionCategory>.from(dist.categories);
        cats.add(DistributionCategory(
          name: 'Ahorro',
          isFixed: true,
          isAutomatic: true,
        ));
        dist = dist.copyWith(categories: cats);
      }

      // Calculate spent amounts from actual expenses
      List<Expense> expenses = [];
      try {
        expenses = await _db.getExpensesByMonth(month, year);
      } catch (_) {}

      // Calculate actual transfers to savings
      double transfersToSavings = 0;
      for (final expense in expenses) {
        if (expense.isTransfer && expense.transferTo == 'Ahorro') {
          transfersToSavings += expense.amount;
        }
      }

      final updatedCategories = dist.categories.map((cat) {
        if (cat.isAutomatic) {
          return cat.copyWith(spentAmount: transfersToSavings);
        }
        double spent = 0;
        for (final expense in expenses) {
          if (expense.isTransfer) continue;
          if (expense.category == cat.name ||
              (expense.isRecurring && expense.recurringName == cat.name)) {
            spent += expense.amount;
          }
        }
        return cat.copyWith(spentAmount: spent);
      }).toList();

      final updatedDist = dist.copyWith(categories: updatedCategories);

      // Persist recalculated spentAmount so redistribution engine uses correct values
      await _db.updateDistribution(updatedDist);

      // Load redistribution settings
      _globalRedistributionDay = await _db.getGlobalRedistributionDay();
      _redistributionEnabled = await _db.getRedistributionEnabled();
      _redistributionConfigs = await _db.getRedistributionConfigs();
      _redistributionPresets = await _db.getRedistributionPresets();

      // Calculate redistribution received by each category from previous month
      // Use saved totalRedistributionReceived if available (already applied by autoRedistributeIfNeeded)
      // Otherwise recalculate from previous month's actual unspent
      final Map<String, double> redistributionReceived = {};
      
      // First check if redistribution was already applied (totalRedistributionReceived > 0)
      bool hasAppliedRedistribution = false;
      for (final cat in updatedDist.userCategories) {
        if (cat.totalRedistributionReceived > 0) {
          redistributionReceived[cat.name] = cat.totalRedistributionReceived;
          hasAppliedRedistribution = true;
        }
      }
      
      // If no redistribution was applied yet, calculate expected redistribution from previous month
      if (!hasAppliedRedistribution && _redistributionEnabled) {
        SavingsDistribution? prevDist;
        try {
          final prevMonth = month == 1 ? 12 : month - 1;
          final prevYear = month == 1 ? year - 1 : year;
          prevDist = await _db.getDistribution(prevMonth, prevYear);
        } catch (_) {}
        if (prevDist != null) {
          // Get actual income for consistency with autoRedistributeIfNeeded
          final actualPrevIncome = await _db.getTotalIncomeByMonth(month == 1 ? 12 : month - 1, month == 1 ? year - 1 : year);
          final income = actualPrevIncome > 0 ? actualPrevIncome : prevDist.monthlyIncome;
          
          final Map<String, double> redistributionByTarget = {};
          for (final sourceCat in prevDist.categories) {
            if (sourceCat.isAutomatic) continue;
            if (!sourceCat.isEnabled) continue;
            final unspent = prevDist.getCategoryUnspentBase(sourceCat);
            if (unspent <= 0) continue;
            final config = _redistributionConfigs[sourceCat.name];
            final percentages = config?.redistributionPercentages.isNotEmpty == true
                ? config!.redistributionPercentages
                : (sourceCat.redistributionPercentages.isNotEmpty
                    ? sourceCat.redistributionPercentages
                    : {sourceCat.name: 100.0});
            for (final entry in percentages.entries) {
              redistributionByTarget[entry.key] =
                  (redistributionByTarget[entry.key] ?? 0) + unspent * entry.value / 100;
            }
          }
          // Cap at net savings (same logic as autoRedistributeIfNeeded)
          final netSavings = income - prevDist.totalSpent;
          double totalRedistributed = redistributionByTarget.values.fold(0.0, (a, b) => a + b);
          if (totalRedistributed > netSavings && netSavings > 0) {
            final factor = netSavings / totalRedistributed;
            for (final key in redistributionByTarget.keys) {
              redistributionByTarget[key] = redistributionByTarget[key]! * factor;
            }
          }
          for (final cat in updatedDist.userCategories) {
            redistributionReceived[cat.name] = redistributionByTarget[cat.name] ?? 0;
          }
        }
      }

      if (mounted) {
        setState(() {
          _currentDistribution = updatedDist;
          _previousMonthRedistribution = prevRedistribution;
          _transfersToSavings = transfersToSavings;
          _redistributionReceivedMap = redistributionReceived;
          _isLoading = false;
        });
      }
    } catch (e) {

      if (mounted) {
        setState(() {
          _currentDistribution = _currentDistribution ?? SavingsDistribution(
            id: const Uuid().v4(),
            month: DateTime.now().month,
            year: DateTime.now().year,
            monthlyIncome: 0,
            categories: [
              DistributionCategory(
                name: 'Ahorro',
                isFixed: true,
                isAutomatic: true,
              ),
            ],
          );
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveDistribution(SavingsDistribution dist) async {
    try {
      DistributionValidator.validateAll(dist);
    } on ValidationException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
      return;
    }
    await _db.insertDistribution(dist);
    // Reload all data to recalculate redistribution, spent amounts, etc.
    _loadData();
  }

  void _showEditIncomeDialog() {
    final controller = TextEditingController(
      text: _currentDistribution?.monthlyIncome.toString() ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ingreso Mensual'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Cuánto cobras al mes (\u20ac)',
                prefixIcon: Icon(Icons.euro),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ingresos del mes anterior + redistribución',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
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
              final amount = double.tryParse(controller.text) ?? 0;
              if (amount <= 0) return;
              final updated = _currentDistribution!.copyWith(
                monthlyIncome: amount,
              );
              await _saveDistribution(updated);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showAddCategoryDialog() {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    bool isFixed = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 24, right: 24, top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Añadir Categoría', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre (ej: Comidas, Transporte)',
                  prefixIcon: Icon(Icons.label),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<bool>(
                      title: const Text('Cantidad fija'),
                      subtitle: const Text('Ej: 45\u20ac'),
                      value: true, groupValue: isFixed,
                      onChanged: (v) => setModalState(() => isFixed = v ?? true),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<bool>(
                      title: const Text('Porcentaje'),
                      subtitle: const Text('Ej: 45%'),
                      value: false, groupValue: isFixed,
                      onChanged: (v) => setModalState(() => isFixed = v ?? true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (isFixed)
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Cantidad (\u20ac)',
                    prefixIcon: Icon(Icons.euro),
                  ),
                )
              else
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Porcentaje (%)',
                    suffixText: '%',
                    prefixIcon: Icon(Icons.percent),
                  ),
                ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  final amount = double.tryParse(amountController.text) ?? 0;
                  if (name.isEmpty || amount <= 0) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Introduce nombre y cantidad')),
                    );
                    return;
                  }
                  final newCat = DistributionCategory(
                    name: name,
                    fixedAmount: isFixed ? amount : null,
                    percentage: isFixed ? null : amount,
                    isFixed: isFixed,
                  );
                  final currentCats = List<DistributionCategory>.from(
                      _currentDistribution!.categories);
                  final ahorroIndex = currentCats.indexWhere((c) => c.isAutomatic);
                  if (ahorroIndex >= 0) {
                    currentCats.insert(ahorroIndex, newCat);
                  } else {
                    currentCats.add(newCat);
                  }
                  await _saveDistribution(_currentDistribution!.copyWith(
                    categories: currentCats,
                  ));
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Añadir'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showCategoryRedistributionDialog(int categoryIndex) {
    final dist = _currentDistribution!;
    final cat = dist.categories[categoryIndex];

    // Include ALL categories (including self) + Ahorro
    final allTargets = <String>{
      ...dist.userCategories.map((c) => c.name),
      'Ahorro',
    };
    final Map<String, TextEditingController> controllers = {};

    for (final name in allTargets) {
      controllers[name] = TextEditingController(
        text: (cat.redistributionPercentages[name] ?? 0)
            .toStringAsFixed(0),
      );
    }

    final budget = cat.isAutomatic
        ? dist.savingsBudget
        : dist.getCategoryBudget(cat);
    final unspent = cat.isAutomatic
        ? (dist.savingsBudget - cat.spentAmount).clamp(0.0, double.infinity)
        : (budget - cat.spentAmount).clamp(0.0, double.infinity);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 24, right: 24, top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Redistribución: ${cat.name}',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'No gastado: ${Formatters.formatCurrency(unspent)} de ${Formatters.formatCurrency(budget)}',
                style: TextStyle(
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Indica a dónde va el dinero no gastado (%)\nPuede ir a la misma categoría',
                style: TextStyle(
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              ...controllers.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          entry.key,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: entry.value,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            suffixText: '%',
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  final newPercentages = <String, double>{};
                  for (final entry in controllers.entries) {
                    final val = double.tryParse(entry.value.text) ?? 0;
                    if (val > 0) {
                      newPercentages[entry.key] = val;
                    }
                  }
                  final updatedCat = cat.copyWith(
                    redistributionPercentages: newPercentages,
                  );
                  final cats = List<DistributionCategory>.from(dist.categories);
                  cats[categoryIndex] = updatedCat;
                  await _saveDistribution(dist.copyWith(categories: cats));
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Guardar'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleCategoryEnabled(int index, bool value) {
    final cat = _currentDistribution!.categories[index];
    if (cat.isAutomatic) return;
    final categories = List<DistributionCategory>.from(
        _currentDistribution!.categories);
    categories[index] = cat.copyWith(isEnabled: value);
    _saveDistribution(_currentDistribution!.copyWith(categories: categories));
  }

  Future<void> _confirmDeleteCategory(int index) async {
    final cat = _currentDistribution!.categories[index];
    if (cat.isAutomatic) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar categoría'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Estás seguro de eliminar "${cat.name}"?'),
            const SizedBox(height: 4),
            Text(
              'Los gastos de esta categoría no se perderán, pero '
              'desaparecerá del presupuesto.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _deleteCategory(index);
    }
  }

  Future<void> _deleteCategory(int index) async {
    final cat = _currentDistribution!.categories[index];
    if (cat.isAutomatic) return;
    final categories = List<DistributionCategory>.from(
        _currentDistribution!.categories);
    categories.removeAt(index);
    await _saveDistribution(_currentDistribution!.copyWith(categories: categories));
  }

  void _showGlobalSettingsDialog() {
    int tempDay = _globalRedistributionDay;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
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
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Configuración de redistribución',
                  style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 20),

                // Global redistribution day
                Text('Día de redistribución global',
                  style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  )),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: tempDay.toDouble(),
                        min: 1, max: 28,
                        divisions: 27,
                        label: 'Día $tempDay',
                        onChanged: (v) => setModalState(() => tempDay = v.round()),
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      child: Text('Día $tempDay',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Presets section
                Row(
                  children: [
                    Text('Presets',
                      style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                      )),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showPresetsScreen();
                      },
                      icon: const Icon(Icons.launch, size: 16),
                      label: const Text('Ver todos'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // General presets buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _loadGeneralPreset(ctx),
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text('Cargar preset general'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _saveAsGeneralPreset(ctx),
                        icon: const Icon(Icons.upload, size: 16),
                        label: const Text('Guardar como general'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Per-category settings
                Text('Configuración por categoría',
                  style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  )),
                const SizedBox(height: 8),

                if (_currentDistribution != null)
                  ..._currentDistribution!.userCategories.map((cat) {
                    final config = _redistributionConfigs[cat.name];
                    final catDay = config?.redistributionDay;
                    final useGlobal = catDay == null;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          useGlobal
                              ? 'Día: Global (día $tempDay)'
                              : 'Día: ${catDay}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Toggle global/custom day
                            Switch(
                              value: !useGlobal,
                              onChanged: (custom) async {
                                if (custom) {
                                  // Show day picker
                                  final picked = await showDialog<int>(
                                    context: ctx,
                                    builder: (dCtx) => _DayPickerDialog(
                                      currentDay: catDay ?? tempDay,
                                    ),
                                  );
                                  if (picked != null) {
                                    final newConfig = RedistributionConfig(
                                      redistributionDay: picked,
                                      redistributionPercentages: config?.redistributionPercentages ?? {cat.name: 100},
                                    );
                                    await _db.insertRedistributionConfig(cat.name, newConfig);
                                    setModalState(() {
                                      _redistributionConfigs[cat.name] = newConfig;
                                    });
                                  }
                                } else {
                                  final newConfig = RedistributionConfig(
                                    redistributionDay: null,
                                    redistributionPercentages: config?.redistributionPercentages ?? {cat.name: 100},
                                  );
                                  await _db.insertRedistributionConfig(cat.name, newConfig);
                                  setModalState(() {
                                    _redistributionConfigs[cat.name] = newConfig;
                                  });
                                }
                              },
                            ),
                            // Individual preset
                            IconButton(
                              onPressed: () => _showIndividualPresetDialog(ctx, cat.name),
                              icon: const Icon(Icons.bookmark_border, size: 20),
                              tooltip: 'Presets individuales',
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                const SizedBox(height: 16),

                // Save button
                FilledButton(
                  onPressed: () async {
                    await _db.setGlobalRedistributionDay(tempDay);
                    if (mounted) setState(() => _globalRedistributionDay = tempDay);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Guardar'),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPresetsScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RedistributionPresetsScreen(
        presets: _redistributionPresets,
        currentDistribution: _currentDistribution,
        onPresetsChanged: (presets) async {
          setState(() => _redistributionPresets = presets);
          _loadData();
        },
      )),
    );
  }

  void _loadGeneralPreset(BuildContext ctx) {
    final generalPresets = _redistributionPresets.where((p) => p.type == 'general').toList();
    if (generalPresets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay presets generales guardados')),
      );
      return;
    }

    showDialog(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        title: const Text('Cargar preset general'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: generalPresets.length,
            itemBuilder: (_, i) {
              final preset = generalPresets[i];
              return ListTile(
                title: Text(preset.name),
                subtitle: Text('${preset.categories?.length ?? 0} categorías'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (dCtx) => AlertDialog(
                            title: const Text('Eliminar preset'),
                            content: Text('¿Eliminar "${preset.name}"?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancelar')),
                              FilledButton(
                                onPressed: () => Navigator.pop(dCtx, true),
                                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                child: const Text('Eliminar'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          await _db.deleteRedistributionPreset(preset.id);
                          Navigator.pop(dCtx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Preset "${preset.name}" eliminado')),
                            );
                          }
                          _loadData();
                        }
                      },
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                onTap: () async {
                  Navigator.pop(dCtx);
                  // Apply preset
                  if (preset.categories != null && _currentDistribution != null) {
                    final cats = List<DistributionCategory>.from(_currentDistribution!.categories);
                    for (var j = 0; j < cats.length; j++) {
                      if (cats[j].isAutomatic) continue;
                      final presetCat = preset.categories![cats[j].name];
                      if (presetCat != null) {
                        cats[j] = cats[j].copyWith(redistributionPercentages: presetCat);
                        await _db.insertRedistributionConfig(cats[j].name, RedistributionConfig(
                          redistributionPercentages: presetCat,
                          redistributionDay: _redistributionConfigs[cats[j].name]?.redistributionDay,
                        ));
                      }
                    }
                    await _saveDistribution(_currentDistribution!.copyWith(categories: cats));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Preset "${preset.name}" aplicado')),
                    );
                    _loadData();
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  void _saveAsGeneralPreset(BuildContext ctx) {
    final nameController = TextEditingController();

    showDialog(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        title: const Text('Guardar preset general'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Nombre del preset',
            hintText: 'Ej: Configuración normal',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              if (nameController.text.isEmpty) return;
              final categories = <String, Map<String, double>>{};
              if (_currentDistribution != null) {
                for (final cat in _currentDistribution!.userCategories) {
                  categories[cat.name] = cat.redistributionPercentages;
                }
              }
              final preset = RedistributionPreset(
                id: const Uuid().v4(),
                name: nameController.text,
                type: 'general',
                categories: categories,
                createdAt: DateTime.now(),
              );
              await _db.insertRedistributionPreset(preset);
              if (dCtx.mounted) Navigator.pop(dCtx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Preset "${preset.name}" guardado')),
              );
              _loadData();
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showIndividualPresetDialog(BuildContext ctx, String categoryName) {
    final config = _redistributionConfigs[categoryName];
    final individualPresets = _redistributionPresets
        .where((p) => p.type == 'individual' && p.categoryName == categoryName)
        .toList();

    showModalBottomSheet(
      context: ctx,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sCtx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Presets: $categoryName',
              style: Theme.of(sCtx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // Save current as preset
            OutlinedButton.icon(
              onPressed: () async {
                Navigator.pop(sCtx);
                final nameController = TextEditingController();
                final result = await showDialog<String>(
                  context: ctx,
                  builder: (dCtx) => AlertDialog(
                    title: const Text('Guardar preset individual'),
                    content: TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Nombre'),
                      autofocus: true,
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancelar')),
                      FilledButton(
                        onPressed: () => Navigator.pop(dCtx, nameController.text),
                        child: const Text('Guardar'),
                      ),
                    ],
                  ),
                );
                if (result != null && result.isNotEmpty) {
                  final preset = RedistributionPreset(
                    id: const Uuid().v4(),
                    name: result,
                    type: 'individual',
                    categoryName: categoryName,
                    singleCategory: config?.redistributionPercentages ?? {categoryName: 100},
                    createdAt: DateTime.now(),
                  );
                  await _db.insertRedistributionPreset(preset);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Preset "$result" guardado')),
                  );
                  _loadData();
                }
              },
              icon: const Icon(Icons.save, size: 16),
              label: const Text('Guardar configuración actual como preset'),
            ),
            const SizedBox(height: 16),

            // List of individual presets for this category
            if (individualPresets.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No hay presets individuales para esta categoría',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey)),
              )
            else
              ...individualPresets.map((preset) => ListTile(
                title: Text(preset.name),
                subtitle: Text(
                  preset.singleCategory?.entries.map((e) => '${e.value.toStringAsFixed(0)}% → ${e.key}').join(', ') ?? '',
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (dCtx) => AlertDialog(
                            title: const Text('Eliminar preset'),
                            content: Text('¿Eliminar "${preset.name}"?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancelar')),
                              FilledButton(
                                onPressed: () => Navigator.pop(dCtx, true),
                                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                child: const Text('Eliminar'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          await _db.deleteRedistributionPreset(preset.id);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Preset "${preset.name}" eliminado')),
                            );
                          }
                          _loadData();
                        }
                      },
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                onTap: () async {
                  Navigator.pop(sCtx);
                  // Apply individual preset
                  if (preset.singleCategory != null && _currentDistribution != null) {
                    final newConfig = RedistributionConfig(
                      redistributionDay: config?.redistributionDay,
                      redistributionPercentages: preset.singleCategory!,
                    );
                    await _db.insertRedistributionConfig(categoryName, newConfig);
                    _loadData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Preset "${preset.name}" aplicado')),
                    );
                  }
                },
              )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dist = _currentDistribution;
    if (dist == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final colorScheme = Theme.of(context).colorScheme;
    final savingsBudget = dist.savingsBudget;
    final savingsColor = savingsBudget > 0
        ? const Color(0xFF4CAF50)
        : colorScheme.error;

    // Use pre-computed redistribution received from _loadData
    final redistributionReceived = _redistributionReceivedMap;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Distribución Mensual'),
        actions: [
          IconButton(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedMonth,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                locale: const Locale('es', 'ES'),
              );
              if (picked != null) {
                setState(() => _selectedMonth = picked);
                _loadData();
              }
            },
            icon: const Icon(Icons.calendar_month),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCategoryDialog,
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Presupuesto mensual total
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Text(
                            Formatters.formatMonthYear(_selectedMonth),
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            Formatters.formatCurrency(dist.monthlyIncome),
                            style: Theme.of(context)
                                .textTheme
                                .displaySmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Ingresos del mes anterior',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Budget progress bar
                          if (dist.monthlyIncome > 0) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Presupuesto total',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                Text(
                                  '${Formatters.formatCurrency(dist.totalSpent)} / ${Formatters.formatCurrency(dist.monthlyIncome)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: dist.totalSpent > dist.monthlyIncome
                                        ? colorScheme.error
                                        : colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: dist.monthlyIncome > 0
                                    ? (dist.totalSpent / dist.monthlyIncome).clamp(0.0, 1.0)
                                    : 0,
                                minHeight: 10,
                                backgroundColor: colorScheme.surfaceContainerHighest,
                                valueColor: AlwaysStoppedAnimation(
                                  dist.totalSpent > dist.monthlyIncome
                                      ? colorScheme.error
                                      : const Color(0xFF4CAF50),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${dist.monthlyIncome > 0 ? ((dist.totalSpent / dist.monthlyIncome) * 100).clamp(0, 100).toStringAsFixed(0) : 0}% gastado',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: dist.totalSpent > dist.monthlyIncome
                                        ? colorScheme.error
                                        : const Color(0xFF4CAF50),
                                  ),
                                ),
                                Text(
                                  'Restante: ${Formatters.formatCurrency((dist.monthlyIncome - dist.totalSpent).clamp(0, double.infinity))}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Savings target
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.savings, size: 18, color: Color(0xFF4CAF50)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Ahorrar: ${Formatters.formatCurrency(savingsBudget)}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF4CAF50),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${Formatters.formatCurrency(_transfersToSavings)} / ${Formatters.formatCurrency(savingsBudget)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (_previousMonthRedistribution > 0) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.swap_horiz, size: 16, color: Color(0xFF4CAF50)),
                                  const SizedBox(width: 4),
                                  Text(
                                    '+${Formatters.formatCurrency(_previousMonthRedistribution)} redistribuidos del mes anterior',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF4CAF50),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    ),
                  const SizedBox(height: 16),

                  // Budget period toggle
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Vista del presupuesto',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _toggleBudgetView(false),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: !_isWeeklyView
                                          ? Theme.of(context).colorScheme.primary
                                          : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: !_isWeeklyView
                                            ? Theme.of(context).colorScheme.primary
                                            : Theme.of(context).colorScheme.outline,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.calendar_month,
                                          size: 16,
                                          color: !_isWeeklyView
                                              ? Colors.white
                                              : Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Mensual',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            color: !_isWeeklyView
                                                ? Colors.white
                                                : Theme.of(context).colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _toggleBudgetView(true),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: _isWeeklyView
                                          ? Theme.of(context).colorScheme.primary
                                          : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: _isWeeklyView
                                            ? Theme.of(context).colorScheme.primary
                                            : Theme.of(context).colorScheme.outline,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.view_week,
                                          size: 16,
                                          color: _isWeeklyView
                                              ? Colors.white
                                              : Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Semanal',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            color: _isWeeklyView
                                                ? Colors.white
                                                : Theme.of(context).colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Weekly budget summary (when in weekly view)
                  if (_isWeeklyView && dist.monthlyIncome > 0) ...[
                    const SizedBox(height: 12),
                    Card(
                      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.view_week, size: 20, color: Theme.of(context).colorScheme.primary),
                                const SizedBox(width: 8),
                                Text(
                                  'Vista Semanal',
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _WeeklyBudgetRow(
                              label: 'Presupuesto semanal',
                              amount: dist.monthlyIncome / 4.3,
                              icon: Icons.account_balance,
                            ),
                            const SizedBox(height: 8),
                            _WeeklyBudgetRow(
                              label: 'Gastado este mes',
                              amount: dist.totalSpent,
                              icon: Icons.receipt_long,
                            ),
                            const SizedBox(height: 8),
                            _WeeklyBudgetRow(
                              label: 'Gasto semanal promedio',
                              amount: dist.totalSpent / (DateTime.now().day / 7.0).clamp(1.0, 4.3),
                              icon: Icons.trending_up,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Resumen
                  if (dist.monthlyIncome > 0) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryCard(
                            title: 'Gastado',
                            amount: dist.totalSpent,
                            color: dist.isOverBudget
                                ? colorScheme.error
                                : const Color(0xFFF44336),
                            icon: Icons.receipt_long,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _SummaryCard(
                            title: 'Ahorro',
                            amount: savingsBudget,
                            color: savingsColor,
                            icon: Icons.savings,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _SummaryCard(
                            title: 'Restante',
                            amount: dist.monthlyIncome - dist.totalSpent,
                            color: (dist.monthlyIncome - dist.totalSpent) >= 0
                                ? const Color(0xFF4CAF50)
                                : colorScheme.error,
                            icon: Icons.account_balance_wallet,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Categorías with settings
                  Row(
                    children: [
                      Text(
                        'Categorías',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const Spacer(),
                      // Redistribution toggle
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Redistribuir',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(width: 4),
                          Switch(
                            value: _redistributionEnabled,
                            onChanged: (value) async {
                              await _db.setRedistributionEnabled(value);
                              setState(() => _redistributionEnabled = value);
                            },
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: _showGlobalSettingsDialog,
                        icon: const Icon(Icons.settings, size: 20),
                        tooltip: 'Configuración de redistribución',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (dist.userCategories.isEmpty && dist.monthlyIncome == 0)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.category_outlined, size: 72,
                                  color: colorScheme.primary.withValues(alpha: 0.25)),
                              const SizedBox(height: 16),
                              Text(
                                'Configura tu distribución',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Establece tu ingreso mensual y añade categorías para controlar tus gastos y ahorrar',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                                    ),
                              ),
                              const SizedBox(height: 20),
                              FilledButton.icon(
                                onPressed: _showEditIncomeDialog,
                                icon: const Icon(Icons.edit),
                                label: const Text('Configurar ingreso'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    ...List.generate(dist.categories.length, (index) {
                      final cat = dist.categories[index];
                      final budgetAmount = dist.getCategoryBudget(cat);
                      final percentage = cat.isAutomatic
                          ? (savingsBudget > 0
                              ? ((dist.monthlyIncome - dist.totalSpent) /
                                      savingsBudget * 100)
                                  .clamp(0.0, 100.0)
                              : 0.0)
                          : (budgetAmount > 0
                              ? (cat.spentAmount / budgetAmount * 100).clamp(0.0, 100.0)
                              : 0.0);
                      final overBudget = cat.spentAmount > budgetAmount && !cat.isAutomatic ? cat.spentAmount - budgetAmount : 0.0;
                      final color = cat.isAutomatic
                          ? savingsColor
                          : cat.spentAmount > budgetAmount && !cat.isAutomatic
                              ? colorScheme.error
                              : percentage >= 80
                                  ? const Color(0xFFFF9800)
                                  : const Color(0xFF4CAF50);

                      if (cat.isAutomatic) {
                        final transferTarget = savingsBudget;
                        final transferred = _transfersToSavings;
                        final ahorroRedistributed = redistributionReceived['Ahorro'] ?? 0;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: savingsColor.withValues(alpha: 0.1),
                          child: InkWell(
                            onTap: () => _showCategoryRedistributionDialog(index),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.savings,
                                          color: Color(0xFF4CAF50), size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('Ahorro',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF4CAF50),
                                              ),
                                            ),
                                            Text(
                                              'Transferido: ${Formatters.formatCurrency(transferred)}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            Formatters.formatCurrency(transferred),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: transferred >= transferTarget
                                                  ? const Color(0xFF4CAF50)
                                                  : colorScheme.onSurface,
                                            ),
                                          ),
                                          Text(
                                            '/ ${Formatters.formatCurrency(transferTarget)}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: LinearProgressIndicator(
                                      value: transferTarget > 0
                                          ? (transferred / transferTarget).clamp(0.0, 1.0)
                                          : 0,
                                      minHeight: 8,
                                      backgroundColor: colorScheme.surfaceContainerHighest,
                                      valueColor: AlwaysStoppedAnimation(
                                        transferred >= transferTarget
                                            ? const Color(0xFF4CAF50)
                                            : const Color(0xFFFF9800),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${transferTarget > 0 ? ((transferred / transferTarget) * 100).clamp(0, 100).toStringAsFixed(0) : 0}% transferido',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF4CAF50),
                                        ),
                                      ),
                                      if (transferred >= transferTarget)
                                        const Text(
                                          '¡Completado!',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF4CAF50),
                                          ),
                                        )
                                      else
                                        Text(
                                          'Falta: ${Formatters.formatCurrency((transferTarget - transferred).clamp(0, double.infinity))}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (_redistributionEnabled &&
                                      cat.redistributionPercentages.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: colorScheme.tertiaryContainer.withValues(alpha: 0.5),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.swap_horiz, size: 14,
                                              color: colorScheme.tertiary),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              'Redistribuye: ${cat.redistributionPercentages.entries.map((e) => '${e.value.toStringAsFixed(0)}% → ${e.key}').join(', ')}',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: colorScheme.tertiary,
                                              ),
                                            ),
                                          ),
                                          if (ahorroRedistributed > 0)
                                            Text(
                                              '+${Formatters.formatCurrency(ahorroRedistributed)}',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF4CAF50),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      }

                      // Calculate redistribution this category will contribute (current unspent)
                      double redistributionOut = 0;
                      if (cat.redistributionPercentages.isNotEmpty && !cat.isAutomatic) {
                        final unspent = (budgetAmount - cat.spentAmount).clamp(0.0, double.infinity);
                        final totalPct = cat.redistributionPercentages.values.fold(0.0, (a, b) => a + b);
                        redistributionOut = unspent * totalPct / 100;
                      }

                      return _buildCategoryCard(
                        index, cat, budgetAmount, percentage, overBudget, color, redistributionOut);
                    }),
                ],
              ),
            ),
            ),
    );
  }
  Widget _buildCategoryCard(
    int index,
    DistributionCategory cat,
    double budgetAmount,
    double percentage,
    double overBudget,
    Color color,
    double redistributed,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final dist = _currentDistribution!;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: cat.isEnabled
          ? null
          : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: InkWell(
        onTap: () => _showCategoryRedistributionDialog(index),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    cat.isFixed ? Icons.euro : Icons.percent,
                    color: cat.isEnabled ? color : colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cat.isEnabled
                              ? cat.name
                              : '${cat.name} (desactivada)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: cat.isEnabled
                                ? null
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          cat.isEnabled
                              ? (cat.isFixed
                                  ? '${Formatters.formatCurrency(cat.fixedAmount ?? 0)} fijo'
                                  : (dist.monthlyIncome > 0
                                      ? '${cat.percentage?.toStringAsFixed(0)}% = ${Formatters.formatCurrency(budgetAmount)}'
                                      : 'Sin ingreso mensual'))
                              : (cat.isFixed
                                  ? '${Formatters.formatCurrency(cat.fixedAmount ?? 0)} fijo'
                                  : '${cat.percentage?.toStringAsFixed(0)}%'),
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        Formatters.formatCurrency(cat.spentAmount),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: cat.isEnabled ? color : colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (cat.isEnabled)
                        Text(
                          '/ ${Formatters.formatCurrency(budgetAmount)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 40,
                    child: Transform.scale(
                      scale: 0.7,
                      child: Switch(
                        value: cat.isEnabled,
                        onChanged: (v) => _toggleCategoryEnabled(index, v),
                      ),
                    ),
                  ),
                ],
              ),
              if (cat.isEnabled) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (percentage / 100).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${percentage.toStringAsFixed(0)}% usado',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    if (overBudget > 0)
                      Text(
                        'Exceso: ${Formatters.formatCurrency(overBudget)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.error,
                        ),
                      )
                    else
                      Text(
                        cat.isFixed || dist.monthlyIncome > 0
                            ? 'Restante: ${Formatters.formatCurrency((budgetAmount - cat.spentAmount).clamp(0, double.infinity))}'
                            : 'Sin ingreso',
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ],
              if (!cat.isEnabled)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Categoría desactivada — no afecta al presupuesto',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              if (_redistributionEnabled &&
                  (cat.redistributionPercentages.isNotEmpty ||
                      redistributed > 0)) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.tertiaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.swap_horiz, size: 14,
                          color: colorScheme.tertiary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          cat.redistributionPercentages.isNotEmpty
                              ? 'Redistribuye: ${cat.redistributionPercentages.entries.map((e) => '${e.value.toStringAsFixed(0)}% → ${e.key}').join(', ')}'
                              : 'Toca para configurar redistribución',
                          style: TextStyle(
                            fontSize: 10,
                            color: colorScheme.tertiary,
                          ),
                        ),
                      ),
                      if (redistributed > 0)
                        Text(
                          '+${Formatters.formatCurrency(redistributed)}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4CAF50),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Eliminar'),
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.error,
                    ),
                    onPressed: () => _confirmDeleteCategory(index),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final double amount;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.title,
    required this.amount,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                Formatters.formatCurrency(amount),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeeklyBudgetRow extends StatelessWidget {
  final String label;
  final double amount;
  final IconData icon;

  const _WeeklyBudgetRow({
    required this.label,
    required this.amount,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          Formatters.formatCurrency(amount),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _DayPickerDialog extends StatefulWidget {
  final int currentDay;
  const _DayPickerDialog({required this.currentDay});

  @override
  State<_DayPickerDialog> createState() => _DayPickerDialogState();
}

class _DayPickerDialogState extends State<_DayPickerDialog> {
  late int _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = widget.currentDay;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Seleccionar día'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Día de redistribución para esta categoría'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _selectedDay.toDouble(),
                  min: 1, max: 28,
                  divisions: 27,
                  label: 'Día $_selectedDay',
                  onChanged: (v) => setState(() => _selectedDay = v.round()),
                ),
              ),
              SizedBox(
                width: 40,
                child: Text('$_selectedDay',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selectedDay),
          child: const Text('Aceptar'),
        ),
      ],
    );
  }
}
