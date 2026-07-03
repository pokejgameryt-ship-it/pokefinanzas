import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/product.dart';
import '../../models/product_group.dart';
import '../../services/database_service.dart';
import '../../utils/formatters.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _db = DatabaseService.instance;
  List<Product> _products = [];
  List<ProductGroup> _groups = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String? _filterGroupId;
  bool _filterFavorites = false;
  bool _viewByGroup = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final products = await _db.getAllProducts();
    final groups = await _db.getAllProductGroups();
    setState(() {
      _products = products;
      _groups = groups;
      _isLoading = false;
    });
  }

  ProductGroup? _getGroupById(String? id) {
    if (id == null) return null;
    try {
      return _groups.firstWhere((g) => g.id == id);
    } catch (_) {
      return null;
    }
  }

  // === ADD/EDIT GROUP ===
  void _showAddGroupDialog({ProductGroup? group}) {
    final nameController = TextEditingController(text: group?.name ?? '');
    int selectedColor = group?.colorValue ?? 0xFF4CAF50;

    final colors = [
      0xFF4CAF50, 0xFF2196F3, 0xFFFF9800, 0xFFF44336,
      0xFF9C27B0, 0xFF00BCD4, 0xFFFF5722, 0xFF795548,
      0xFF607D8B, 0xFFE91E63, 0xFF3F51B5, 0xFF009688,
    ];

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
                group == null ? 'Nuevo Grupo' : 'Editar Grupo',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del grupo',
                  prefixIcon: Icon(Icons.folder),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              Text('Color', style: Theme.of(ctx).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: colors.map((c) {
                  final isSelected = selectedColor == c;
                  return GestureDetector(
                    onTap: () => setModalState(() => selectedColor = c),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(
                                color: Theme.of(ctx).colorScheme.onSurface,
                                width: 3,
                              )
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 18)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Introduce un nombre')),
                    );
                    return;
                  }
                  final newGroup = ProductGroup(
                    id: group?.id ?? const Uuid().v4(),
                    name: name,
                    colorValue: selectedColor,
                    createdAt: group?.createdAt ?? DateTime.now(),
                  );
                  if (group == null) {
                    await _db.insertProductGroup(newGroup);
                  } else {
                    await _db.updateProductGroup(newGroup);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadData();
                },
                child: Text(group == null ? 'Crear' : 'Guardar'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // === ADD/EDIT PRODUCT ===
  void _showAddProductDialog({Product? product}) {
    final nameController = TextEditingController(text: product?.name ?? '');
    final priceController = TextEditingController(
      text: product?.price.toString() ?? '',
    );
    String? selectedGroupId = product?.groupId;

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
                  product == null ? 'Añadir Producto' : 'Editar Producto',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del producto',
                    prefixIcon: Icon(Icons.shopping_bag),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Precio (€)',
                    prefixIcon: Icon(Icons.euro),
                  ),
                ),
                const SizedBox(height: 16),
                // Group selector
                if (_groups.isNotEmpty) ...[
                  DropdownButtonFormField<String?>(
                    value: selectedGroupId,
                    decoration: const InputDecoration(
                      labelText: 'Grupo (opcional)',
                      prefixIcon: Icon(Icons.folder_outlined),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Sin grupo'),
                      ),
                      ..._groups.map((g) => DropdownMenuItem<String?>(
                            value: g.id,
                            child: Row(
                              children: [
                                Container(
                                  width: 12, height: 12,
                                  decoration: BoxDecoration(
                                    color: g.color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(g.name),
                              ],
                            ),
                          )),
                    ],
                    onChanged: (v) => setModalState(() => selectedGroupId = v),
                  ),
                  const SizedBox(height: 16),
                ],
                FilledButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final price = double.tryParse(priceController.text) ?? 0;
                    if (name.isEmpty || price <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Introduce nombre y precio válidos')),
                      );
                      return;
                    }
                    final newProduct = Product(
                      id: product?.id ?? const Uuid().v4(),
                      name: name,
                      price: price,
                      groupId: selectedGroupId,
                      createdAt: product?.createdAt ?? DateTime.now(),
                    );
                    if (product == null) {
                      await _db.insertProduct(newProduct);
                    } else {
                      await _db.updateProduct(newProduct);
                    }
                    if (context.mounted) Navigator.pop(context);
                    _loadData();
                  },
                  child: Text(product == null ? 'Añadir' : 'Guardar'),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteProduct(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: const Text('¿Estás seguro de que quieres eliminar este producto?'),
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
      await _db.deleteProduct(id);
      _loadData();
    }
  }

  Future<void> _deleteGroup(ProductGroup group) async {
    final productCount = _products.where((p) => p.groupId == group.id).length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar grupo'),
        content: Text(
          productCount > 0
              ? 'El grupo "${group.name}" tiene $productCount productos. Se desvincularán pero no se eliminarán.'
              : '¿Eliminar el grupo "${group.name}"?',
        ),
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
      await _db.deleteProductGroup(group.id);
      _loadData();
    }
  }

  Future<void> _toggleFavorite(Product product) async {
    final updated = product.copyWith(isFavorite: !product.isFavorite);
    await _db.updateProduct(updated);
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final filteredProducts = _searchQuery.isEmpty
        ? _products
        : _products.where((p) =>
            p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (_getGroupById(p.groupId)?.name.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)).toList();

    var displayProducts = filteredProducts;
    if (_filterGroupId != null) {
      displayProducts = displayProducts.where((p) => p.groupId == _filterGroupId).toList();
    }
    if (_filterFavorites) {
      displayProducts = displayProducts.where((p) => p.isFavorite).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Productos'),
        actions: [
          // View toggle
          IconButton(
            onPressed: () => setState(() => _viewByGroup = !_viewByGroup),
            icon: Icon(_viewByGroup ? Icons.view_list : Icons.folder),
            tooltip: _viewByGroup ? 'Vista lista' : 'Vista por grupos',
          ),
          // Group management
          IconButton(
            onPressed: () => _showAddGroupDialog(),
            icon: const Icon(Icons.create_new_folder),
            tooltip: 'Nuevo grupo',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddProductDialog(),
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Buscar productos o grupos...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => setState(() => _searchQuery = ''),
                            )
                          : null,
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),

                // Group filter chips
                if (_groups.isNotEmpty && _searchQuery.isEmpty)
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: const Text('Todos'),
                            selected: _filterGroupId == null && !_filterFavorites,
                            onSelected: (_) => setState(() {
                              _filterGroupId = null;
                              _filterFavorites = false;
                            }),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            avatar: const Icon(Icons.star, size: 16, color: Colors.amber),
                            label: const Text('Favoritos'),
                            selected: _filterFavorites,
                            onSelected: (_) => setState(() {
                              _filterFavorites = !_filterFavorites;
                              _filterGroupId = null;
                            }),
                          ),
                        ),
                        ..._groups.map((g) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                avatar: Container(
                                  width: 10, height: 10,
                                  decoration: BoxDecoration(
                                    color: g.color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                label: Text(g.name),
                                selected: _filterGroupId == g.id,
                                onSelected: (_) => setState(() =>
                                    _filterGroupId = _filterGroupId == g.id ? null : g.id),
                              ),
                            )),
                      ],
                    ),
                  ),

                // Stats
                if (_products.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Row(
                      children: [
                        _StatBadge(
                          label: '${displayProducts.length} productos',
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        _StatBadge(
                          label: Formatters.formatCurrency(
                            displayProducts.fold(0.0, (sum, p) => sum + p.price),
                          ),
                          color: Theme.of(context).colorScheme.tertiary,
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 4),

                // Product list
                Expanded(
                  child: displayProducts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.shopping_bag_outlined,
                                size: 72,
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'Sin resultados para "$_searchQuery"'
                                    : _filterGroupId != null
                                        ? 'Sin productos en este grupo'
                                        : 'Sin productos aún',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _searchQuery.isEmpty && _filterGroupId == null
                                    ? 'Añade productos que quieras comprar para organizarlos por grupos'
                                    : 'Prueba con otros filtros o crea un nuevo producto',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                                    ),
                              ),
                              if (_searchQuery.isEmpty && _filterGroupId == null) ...[
                                const SizedBox(height: 20),
                                FilledButton.icon(
                                  onPressed: () => _showAddProductDialog(),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Crear producto'),
                                ),
                              ],
                            ],
                          ),
                        )
                      : _viewByGroup
                          ? _buildGroupedList(displayProducts)
                          : _buildFlatList(displayProducts),
                ),
              ],
            ),
            ),
    );
  }

  Widget _buildGroupedList(List<Product> products) {
    // Group products by groupId
    final Map<String?, List<Product>> grouped = {};
    for (final p in products) {
      grouped.putIfAbsent(p.groupId, () => []).add(p);
    }

    final ungrouped = grouped.remove(null) ?? [];
    final sortedGroupIds = grouped.keys.toList()..sort((a, b) {
      final ga = _getGroupById(a);
      final gb = _getGroupById(b);
      return (ga?.name ?? '').compareTo(gb?.name ?? '');
    });

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        // Ungrouped products
        if (ungrouped.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Sin grupo',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ),
          ...ungrouped.map((p) => _buildProductTile(p)),
        ],

        // Grouped products
        for (final groupId in sortedGroupIds) ...[
          _GroupExpansionTile(
            group: _getGroupById(groupId)!,
            products: grouped[groupId]!,
            onProductTap: _showAddProductDialog,
            onProductDelete: _deleteProduct,
            db: _db,
            onReload: _loadData,
          ),
        ],
      ],
    );
  }

  Widget _buildFlatList(List<Product> products) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: products.length,
      itemBuilder: (context, index) => _buildProductTile(products[index]),
    );
  }

  Widget _buildProductTile(Product product) {
    final group = _getGroupById(product.groupId);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: group != null
              ? group.color.withValues(alpha: 0.15)
              : Theme.of(context).colorScheme.tertiaryContainer,
          child: Icon(
            Icons.shopping_bag,
            color: group?.color ?? Theme.of(context).colorScheme.onTertiaryContainer,
          ),
        ),
        title: Text(product.name),
        subtitle: Row(
          children: [
            Text(Formatters.formatCurrency(product.price)),
            if (group != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: group.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  group.name,
                  style: TextStyle(fontSize: 10, color: group.color, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                product.isFavorite ? Icons.star : Icons.star_border,
                color: product.isFavorite ? Colors.amber : null,
              ),
              onPressed: () => _toggleFavorite(product),
              tooltip: product.isFavorite ? 'Quitar de favoritos' : 'Añadir a favoritos',
            ),
            PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Editar')),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Eliminar', style: TextStyle(color: Colors.red)),
                ),
              ],
              onSelected: (value) {
                if (value == 'edit') _showAddProductDialog(product: product);
                if (value == 'delete') _deleteProduct(product.id);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupExpansionTile extends StatefulWidget {
  final ProductGroup group;
  final List<Product> products;
  final Function({Product? product}) onProductTap;
  final Function(String) onProductDelete;
  final DatabaseService db;
  final VoidCallback onReload;

  const _GroupExpansionTile({
    required this.group,
    required this.products,
    required this.onProductTap,
    required this.onProductDelete,
    required this.db,
    required this.onReload,
  });

  @override
  State<_GroupExpansionTile> createState() => _GroupExpansionTileState();
}

class _GroupExpansionTileState extends State<_GroupExpansionTile> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final totalPrice = widget.products.fold(0.0, (sum, p) => sum + p.price);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 14, height: 14,
                    decoration: BoxDecoration(
                      color: widget.group.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.group.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${widget.products.length} productos · ${Formatters.formatCurrency(totalPrice)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton(
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Text('Editar grupo')),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Eliminar grupo', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'edit') {
                        // Access parent state through widget
                        final parentState = context.findAncestorStateOfType<_ProductsScreenState>();
                        parentState?._showAddGroupDialog(group: widget.group);
                      }
                      if (value == 'delete') {
                        final parentState = context.findAncestorStateOfType<_ProductsScreenState>();
                        parentState?._deleteGroup(widget.group);
                      }
                    },
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            ...widget.products.map((p) => ListTile(
                  dense: true,
                  leading: Icon(Icons.circle, size: 6, color: widget.group.color),
                  title: Text(p.name),
                  subtitle: Text(Formatters.formatCurrency(p.price)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          p.isFavorite ? Icons.star : Icons.star_border,
                          color: p.isFavorite ? Colors.amber : null,
                          size: 20,
                        ),
                        onPressed: () {
                          final updated = p.copyWith(isFavorite: !p.isFavorite);
                          widget.db.updateProduct(updated);
                          widget.onReload();
                        },
                        tooltip: p.isFavorite ? 'Quitar de favoritos' : 'Añadir a favoritos',
                      ),
                      PopupMenuButton(
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'edit', child: Text('Editar')),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Eliminar', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                        onSelected: (value) {
                          if (value == 'edit') widget.onProductTap(product: p);
                          if (value == 'delete') widget.onProductDelete(p.id);
                        },
                      ),
                    ],
                  ),
                )),
            // Add product button for this group
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    final parentState = context.findAncestorStateOfType<_ProductsScreenState>();
                    // Pre-select this group when adding
                    widget.onProductTap();
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Añadir producto al grupo'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
