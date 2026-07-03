import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/redistribution_config.dart';
import '../../models/redistribution_preset.dart';
import '../../models/savings_distribution.dart';
import '../../services/database_service.dart';

class RedistributionPresetsScreen extends StatefulWidget {
  final List<RedistributionPreset> presets;
  final SavingsDistribution? currentDistribution;
  final Function(List<RedistributionPreset>) onPresetsChanged;

  const RedistributionPresetsScreen({
    super.key,
    required this.presets,
    required this.currentDistribution,
    required this.onPresetsChanged,
  });

  @override
  State<RedistributionPresetsScreen> createState() => _RedistributionPresetsScreenState();
}

class _RedistributionPresetsScreenState extends State<RedistributionPresetsScreen> {
  String _filter = 'all'; // all, general, individual
  final _db = DatabaseService.instance;

  List<RedistributionPreset> get _filteredPresets {
    if (_filter == 'general') return widget.presets.where((p) => p.type == 'general').toList();
    if (_filter == 'individual') return widget.presets.where((p) => p.type == 'individual').toList();
    return widget.presets;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Presets de redistribución'),
        actions: [
          IconButton(
            onPressed: _createPresetFromCurrent,
            icon: const Icon(Icons.add),
            tooltip: 'Crear preset',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _FilterChip(
                  label: 'Todos',
                  selected: _filter == 'all',
                  onTap: () => setState(() => _filter = 'all'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Generales',
                  selected: _filter == 'general',
                  onTap: () => setState(() => _filter = 'general'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Individuales',
                  selected: _filter == 'individual',
                  onTap: () => setState(() => _filter = 'individual'),
                ),
              ],
            ),
          ),

          // Preset list
          Expanded(
            child: _filteredPresets.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bookmark_border, size: 72,
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25)),
                        const SizedBox(height: 16),
                        Text('Sin presets',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            )),
                        const SizedBox(height: 6),
                        Text('Crea un preset guardando la configuración actual',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                            )),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredPresets.length,
                    itemBuilder: (context, index) {
                      final preset = _filteredPresets[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(
                            preset.type == 'general' ? Icons.inventory_2 : Icons.label,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          title: Text(preset.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            preset.type == 'general'
                                ? '${preset.categories?.length ?? 0} categorías'
                                : 'Categoría: ${preset.categoryName}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: PopupMenuButton(
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(value: 'apply', child: Text('Aplicar')),
                              const PopupMenuItem(value: 'delete', child: Text('Eliminar', style: TextStyle(color: Colors.red))),
                            ],
                            onSelected: (value) async {
                              if (value == 'apply') _applyPreset(preset);
                              if (value == 'delete') _deletePreset(preset);
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _applyPreset(RedistributionPreset preset) async {
    if (widget.currentDistribution == null) return;

    final cats = List<DistributionCategory>.from(widget.currentDistribution!.categories);

    if (preset.type == 'general' && preset.categories != null) {
      for (var i = 0; i < cats.length; i++) {
        if (cats[i].isAutomatic) continue;
        final presetCat = preset.categories![cats[i].name];
        if (presetCat != null) {
          cats[i] = cats[i].copyWith(redistributionPercentages: presetCat);
          // Preserve redistribution day
          final configs = await _db.getRedistributionConfigs();
          final existing = configs[cats[i].name];
          await _db.insertRedistributionConfig(cats[i].name, RedistributionConfig(
            redistributionPercentages: presetCat,
            redistributionDay: existing?.redistributionDay,
          ));
        }
      }
    } else if (preset.type == 'individual' && preset.singleCategory != null) {
      for (var i = 0; i < cats.length; i++) {
        if (cats[i].name == preset.categoryName) {
          cats[i] = cats[i].copyWith(redistributionPercentages: preset.singleCategory!);
          final configs = await _db.getRedistributionConfigs();
          final existing = configs[cats[i].name];
          await _db.insertRedistributionConfig(cats[i].name, RedistributionConfig(
            redistributionPercentages: preset.singleCategory!,
            redistributionDay: existing?.redistributionDay,
          ));
          break;
        }
      }
    }

    // Save updated distribution
    await DatabaseService.instance.insertDistribution(widget.currentDistribution!.copyWith(categories: cats));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Preset "${preset.name}" aplicado')),
      );
      widget.onPresetsChanged(await _db.getRedistributionPresets());
    }
  }

  void _deletePreset(RedistributionPreset preset) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar preset'),
        content: Text('¿Eliminar "${preset.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _db.deleteRedistributionPreset(preset.id);
      widget.onPresetsChanged(await _db.getRedistributionPresets());
    }
  }

  void _createPresetFromCurrent() async {
    final nameController = TextEditingController();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Crear preset'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nombre del preset'),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            Text('Tipo:', style: Theme.of(ctx).textTheme.titleSmall),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (nameController.text.isEmpty) return;
              Navigator.pop(ctx, {'name': nameController.text, 'type': 'general'});
            },
            child: const Text('General'),
          ),
          OutlinedButton(
            onPressed: () {
              if (nameController.text.isEmpty) return;
              Navigator.pop(ctx, {'name': nameController.text, 'type': 'individual'});
            },
            child: const Text('Individual'),
          ),
        ],
      ),
    );

    if (result == null || widget.currentDistribution == null) return;

    final categories = <String, Map<String, double>>{};
    for (final cat in widget.currentDistribution!.userCategories) {
      categories[cat.name] = cat.redistributionPercentages;
    }

    final preset = RedistributionPreset(
      id: const Uuid().v4(),
      name: result['name']!,
      type: result['type']!,
      categories: result['type'] == 'general' ? categories : null,
      singleCategory: result['type'] == 'individual'
          ? (widget.currentDistribution!.userCategories.isNotEmpty
              ? widget.currentDistribution!.userCategories.first.redistributionPercentages
              : null)
          : null,
      categoryName: result['type'] == 'individual'
          ? (widget.currentDistribution!.userCategories.isNotEmpty
              ? widget.currentDistribution!.userCategories.first.name
              : null)
          : null,
      createdAt: DateTime.now(),
    );

    await _db.insertRedistributionPreset(preset);
    widget.onPresetsChanged(await _db.getRedistributionPresets());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Preset "${preset.name}" creado')),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
