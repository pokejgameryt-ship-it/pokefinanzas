import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/category_model.dart';
import '../../models/savings_distribution.dart';
import '../../services/database_service.dart';
import '../../utils/formatters.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final _db = DatabaseService.instance;
  List<CategoryModel> _categories = [];
  SavingsDistribution? _currentDist;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final cats = await _db.getAllCategories();
    final now = DateTime.now();
    final dist = await _db.getDistribution(now.month, now.year);
    setState(() {
      _categories = cats..sort((a, b) => a.order.compareTo(b.order));
      _currentDist = dist;
      _loading = false;
    });
  }

  DistributionCategory? _getDistCat(CategoryModel cat) {
    if (_currentDist == null) return null;
    try {
      return _currentDist!.categories.firstWhere((c) => c.name == cat.name);
    } catch (_) {
      return null;
    }
  }

  Future<void> _addCategory() async {
    final result = await Navigator.push<CategoryModel>(
      context,
      MaterialPageRoute(builder: (_) => const _CategoryEditScreen()),
    );
    if (result != null) {
      await _db.insertCategory(result);
      await _loadCategories();
    }
  }

  Future<void> _editCategory(CategoryModel cat) async {
    final distCat = _getDistCat(cat);
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => _CategoryEditScreen(
          category: cat,
          distCategory: distCat,
          monthlyIncome: _currentDist?.monthlyIncome ?? 0,
        ),
      ),
    );
    if (result != null) {
      final updatedCat = result['category'] as CategoryModel;
      await _db.updateCategory(updatedCat);

      // Save budget changes to distribution
      final budgetType = result['budgetType'] as String?;
      final budgetValue = result['budgetValue'] as double?;
      if (_currentDist != null && budgetType != null && budgetValue != null) {
        final cats = List<DistributionCategory>.from(_currentDist!.categories);
        final idx = cats.indexWhere((c) => c.name == cat.name);
        if (idx >= 0) {
          if (budgetType == 'fixed') {
            cats[idx] = cats[idx].copyWith(
              fixedAmount: budgetValue,
              percentage: null,
              isFixed: true,
            );
          } else {
            cats[idx] = cats[idx].copyWith(
              percentage: budgetValue,
              fixedAmount: null,
              isFixed: false,
            );
          }
          final updatedDist = _currentDist!.copyWith(categories: cats);
          await _db.insertDistribution(updatedDist);
        }
      }
      await _loadCategories();
    }
  }

  Future<void> _deleteCategory(CategoryModel cat) async {
    if (cat.isDefault) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pueden eliminar categorías predeterminadas')),
        );
      }
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar categoría'),
        content: Text('¿Eliminar "${cat.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await _db.deleteCategory(cat.id);
      await _loadCategories();
    }
  }

  Future<void> _toggleCategory(CategoryModel cat) async {
    final updated = cat.copyWith(isEnabled: !cat.isEnabled);
    await _db.updateCategory(updated);
    await _loadCategories();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categorías'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addCategory,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _categories.isEmpty
              ? const Center(child: Text('No hay categorías'))
              : ReorderableListView.builder(
                  itemCount: _categories.length,
                  onReorder: (oldIdx, newIdx) async {
                    if (newIdx > oldIdx) newIdx--;
                    final item = _categories.removeAt(oldIdx);
                    _categories.insert(newIdx, item);
                    for (int i = 0; i < _categories.length; i++) {
                      await _db.updateCategory(_categories[i].copyWith(order: i));
                    }
                    setState(() {});
                  },
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final distCat = _getDistCat(cat);
                    final budgetStr = distCat != null
                        ? (distCat.isFixed
                            ? Formatters.formatCurrency(distCat.fixedAmount ?? 0)
                            : '${(distCat.percentage ?? 0).toStringAsFixed(0)}%')
                        : 'Sin presupuesto';
                    return ListTile(
                      key: ValueKey(cat.id),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: cat.color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(cat.icon, color: cat.color, size: 20),
                      ),
                      title: Text(cat.name),
                      subtitle: Text(budgetStr),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: cat.isEnabled,
                            onChanged: (_) => _toggleCategory(cat),
                          ),
                          if (!cat.isDefault)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              onPressed: () => _deleteCategory(cat),
                            ),
                          const Icon(Icons.drag_handle),
                        ],
                      ),
                      onTap: () => _editCategory(cat),
                    );
                  },
                ),
    );
  }
}

class _CategoryEditScreen extends StatefulWidget {
  final CategoryModel? category;
  final DistributionCategory? distCategory;
  final double monthlyIncome;

  const _CategoryEditScreen({
    this.category,
    this.distCategory,
    this.monthlyIncome = 0,
  });

  @override
  State<_CategoryEditScreen> createState() => _CategoryEditScreenState();
}

class _CategoryEditScreenState extends State<_CategoryEditScreen> {
  late TextEditingController _nameController;
  late TextEditingController _budgetController;
  late int _selectedIcon;
  late int _selectedColor;
  late bool _isFixed;
  late bool _hasBudget;

  static const _icons = [
    Icons.home, Icons.restaurant, Icons.directions_bus, Icons.bolt,
    Icons.sports_esports, Icons.local_hospital, Icons.checkroom, Icons.savings,
    Icons.more_horiz, Icons.shopping_cart, Icons.flight, Icons.school,
    Icons.pets, Icons.child_care, Icons.local_grocery_store, Icons.local_bar,
    Icons.coffee, Icons.local_gas_station, Icons.local_pharmacy, Icons.fitness_center,
    Icons.movie, Icons.music_note, Icons.computer, Icons.phone,
    Icons.wifi, Icons.local_atm, Icons.account_balance, Icons.credit_card,
    Icons.monetization_on, Icons.card_giftcard, Icons.card_travel, Icons.work,
    Icons.build, Icons.brush, Icons.camera_alt, Icons.palette,
  ];

  static const _colors = [
    Color(0xFFE53935), Color(0xFFFF9800), Color(0xFF2196F3), Color(0xFFFFC107),
    Color(0xFF9C27B0), Color(0xFF4CAF50), Color(0xFF795548), Color(0xFF00BCD4),
    Color(0xFF607D8B), Color(0xFFE91E63), Color(0xFF3F51B5), Color(0xFF009688),
    Color(0xFFFF5722), Color(0xFF8BC34A), Color(0xFF673AB7), Color(0xFFCDDC39),
    Color(0xFF03A9F4), Color(0xFFAFB42B), Color(0xFFD32F2F), Color(0xFF1976D2),
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
    _selectedIcon = widget.category?.iconCodePoint ?? Icons.category.codePoint;
    _selectedColor = widget.category?.colorValue ?? Colors.grey.value;

    if (widget.distCategory != null) {
      _isFixed = widget.distCategory!.isFixed;
      _hasBudget = true;
      final val = widget.distCategory!.isFixed
          ? (widget.distCategory!.fixedAmount ?? 0)
          : (widget.distCategory!.percentage ?? 0);
      _budgetController = TextEditingController(
        text: val > 0 ? (widget.distCategory!.isFixed ? val.toStringAsFixed(2) : val.toStringAsFixed(0)) : '',
      );
    } else {
      _isFixed = true;
      _hasBudget = false;
      _budgetController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un nombre')),
      );
      return;
    }

    final cat = CategoryModel(
      id: widget.category?.id ?? const Uuid().v4(),
      name: name,
      iconCodePoint: _selectedIcon,
      colorValue: _selectedColor,
      isDefault: widget.category?.isDefault ?? false,
      isEnabled: widget.category?.isEnabled ?? true,
      order: widget.category?.order ?? 0,
    );

    String? budgetType;
    double? budgetValue;
    if (_hasBudget) {
      budgetType = _isFixed ? 'fixed' : 'percentage';
      budgetValue = double.tryParse(_budgetController.text) ?? 0;
    }

    Navigator.pop(context, {
      'category': cat,
      'budgetType': budgetType,
      'budgetValue': budgetValue,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category == null ? 'Nueva categoría' : 'Editar categoría'),
        actions: [
          TextButton(onPressed: _save, child: const Text('GUARDAR')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nombre',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),

          // ── Budget ──
          if (widget.category != null) ...[
            Row(
              children: [
                const Text('Presupuesto', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                Switch(
                  value: _hasBudget,
                  onChanged: (v) => setState(() => _hasBudget = v),
                ),
              ],
            ),
            if (_hasBudget) ...[
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Fijo (€)'), icon: Icon(Icons.euro)),
                  ButtonSegment(value: false, label: Text('% del sobrante'), icon: Icon(Icons.percent)),
                ],
                selected: {_isFixed},
                onSelectionChanged: (s) => setState(() => _isFixed = s.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _budgetController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _isFixed ? 'Cantidad fija (€)' : 'Porcentaje del sobrante (%)',
                  border: const OutlineInputBorder(),
                  prefixText: _isFixed ? '€ ' : '',
                  suffixText: _isFixed ? '' : '%',
                ),
              ),
              if (_isFixed && widget.monthlyIncome > 0) ...[
                const SizedBox(height: 4),
                Text(
                  'Ingreso mensual: ${Formatters.formatCurrency(widget.monthlyIncome)}',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ],
            const SizedBox(height: 24),
          ],

          const Text('Icono', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _icons.map((icon) {
              final selected = icon.codePoint == _selectedIcon;
              return GestureDetector(
                onTap: () => setState(() => _selectedIcon = icon.codePoint),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: selected
                        ? Color(_selectedColor).withOpacity(0.2)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: selected
                        ? Border.all(color: Color(_selectedColor), width: 2)
                        : null,
                  ),
                  child: Icon(icon, color: selected ? Color(_selectedColor) : Colors.grey, size: 22),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          const Text('Color', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _colors.map((color) {
              final selected = color.value == _selectedColor;
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = color.value),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                    border: selected
                        ? Border.all(color: Colors.white, width: 3)
                        : null,
                    boxShadow: selected
                        ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8)]
                        : null,
                  ),
                  child: selected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Color(_selectedColor).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Color(_selectedColor).withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(IconData(_selectedIcon, fontFamily: 'MaterialIcons'),
                      color: Color(_selectedColor), size: 24),
                  const SizedBox(width: 10),
                  Text(
                    _nameController.text.isEmpty ? 'Vista previa' : _nameController.text,
                    style: TextStyle(
                      color: Color(_selectedColor),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
