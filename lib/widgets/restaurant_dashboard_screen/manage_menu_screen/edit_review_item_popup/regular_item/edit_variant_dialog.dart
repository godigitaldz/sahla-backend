import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../models/menu_item.dart';
import '../../../../../models/menu_item_supplement.dart';
import '../../../../../services/enhanced_menu_item_service.dart';
import '../../../../../services/restaurant_supplement_service.dart';

/// Comprehensive variant edit dialog
/// Allows editing variant name, availability, pricing, and supplements
class EditVariantDialog extends StatefulWidget {
  final MenuItem menuItem;
  final Map<String, dynamic> variant;
  final VoidCallback? onUpdated;

  const EditVariantDialog({
    required this.menuItem,
    required this.variant,
    this.onUpdated,
    super.key,
  });

  @override
  State<EditVariantDialog> createState() => _EditVariantDialogState();
}

class _EditVariantDialogState extends State<EditVariantDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _enhancedService = EnhancedMenuItemService();

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  bool _isDefault = false;
  bool _isLoading = false;

  // Pricing state
  List<Map<String, dynamic>> _pricingOptions = [];
  final Map<String, TextEditingController> _pricingControllers = {};

  // Supplements state
  List<Map<String, dynamic>> _supplements = [];
  final Map<String, TextEditingController> _supplementPriceControllers = {};
  final Map<String, bool> _supplementAvailability = {};
  final RestaurantSupplementService _restaurantSupplementService =
      RestaurantSupplementService();
  List<MenuItemSupplement> _availableSupplements = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchingSupplements = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeData();
    _loadRestaurantSupplements();
  }

  Future<void> _loadRestaurantSupplements() async {
    try {
      final supplements =
          await _restaurantSupplementService.getRestaurantSupplements(
        widget.menuItem.restaurantId,
      );
      setState(() {
        _availableSupplements = supplements;
      });
    } catch (e) {
      debugPrint('Error loading restaurant supplements: $e');
    }
  }

  void _initializeData() {
    final variantId = widget.variant['id'] as String? ?? '';
    _nameController = TextEditingController(text: widget.variant['name'] ?? '');
    _descriptionController =
        TextEditingController(text: widget.variant['description'] ?? '');
    _isDefault = widget.variant['is_default'] ?? false;

    // Load pricing options for this variant
    final allPricing = widget.menuItem.pricingOptions;
    _pricingOptions = allPricing
        .where((p) => p['variant_id'] == variantId)
        .map((p) => Map<String, dynamic>.from(p))
        .toList();

    // Initialize pricing controllers
    for (final pricing in _pricingOptions) {
      final pricingId = pricing['id'] as String? ?? '';
      _pricingControllers[pricingId] = TextEditingController(
        text: (pricing['price'] ?? 0.0).toString(),
      );
    }

    // Load supplements - filter to show only those assigned to this variant
    // OR supplements with null/empty available_for_variants (legacy supplements)
    final allSupplements = widget.menuItem.supplements;
    final variantSupplements = allSupplements.where((s) {
      final availableFor = s['available_for_variants'];

      // If null, treat as global (show for all variants in edit dialog)
      if (availableFor == null) {
        return true; // Show legacy/global supplements
      }

      // If it's a list, check if it's empty or contains this variant
      if (availableFor is List) {
        final availableForList = availableFor.map((e) => e.toString()).toList();
        // Empty list means global (legacy), non-empty means check if contains variant
        return availableForList.isEmpty || availableForList.contains(variantId);
      }

      return false;
    }).toList();

    _supplements =
        variantSupplements.map((s) => Map<String, dynamic>.from(s)).toList();

    // Initialize supplement controllers and availability
    for (final supplement in _supplements) {
      final supplementId = supplement['id'] as String? ?? '';
      _supplementPriceControllers[supplementId] = TextEditingController(
        text: (supplement['price'] ?? 0.0).toString(),
      );

      final availableForVariants =
          (supplement['available_for_variants'] as List?)?.cast<String>() ?? [];
      _supplementAvailability[supplementId] = availableForVariants.isEmpty ||
          availableForVariants.contains(variantId);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _searchController.dispose();
    for (final controller in _pricingControllers.values) {
      controller.dispose();
    }
    for (final controller in _supplementPriceControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _saveVariant() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Variant name is required')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final variantId = widget.variant['id'] as String? ?? '';
      await _enhancedService.updateVariant(
        menuItemId: widget.menuItem.id,
        variantId: variantId,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        isDefault: _isDefault,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Variant updated successfully')),
        );
        widget.onUpdated?.call();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating variant: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteVariant() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Variant'),
        content: const Text(
          'Are you sure you want to delete this variant? This will also delete all pricing options for this variant.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final variantId = widget.variant['id'] as String? ?? '';
      await _enhancedService.deleteVariant(
        menuItemId: widget.menuItem.id,
        variantId: variantId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Variant deleted successfully')),
        );
        widget.onUpdated?.call();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting variant: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addPricing() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _AddEditPricingDialog(
        menuItemId: widget.menuItem.id,
        variantId: widget.variant['id'] as String? ?? '',
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _initializeData(); // Reload data
      });
    }
  }

  Future<void> _editPricing(Map<String, dynamic> pricing) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _AddEditPricingDialog(
        menuItemId: widget.menuItem.id,
        variantId: widget.variant['id'] as String? ?? '',
        pricing: pricing,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _initializeData(); // Reload data
      });
    }
  }

  Future<void> _deletePricing(String pricingId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Pricing'),
        content:
            const Text('Are you sure you want to delete this pricing option?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      await _enhancedService.deletePricing(
        menuItemId: widget.menuItem.id,
        pricingId: pricingId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pricing deleted successfully')),
        );
        setState(() {
          _initializeData(); // Reload data
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting pricing: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateSupplementPrice(String supplementId) async {
    final priceText = _supplementPriceControllers[supplementId]?.text ?? '';
    final price = double.tryParse(priceText);

    if (price == null || price < 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid price')),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _enhancedService.updateSupplement(
        menuItemId: widget.menuItem.id,
        supplementId: supplementId,
        price: price,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Supplement price updated')),
        );
        setState(() {
          _initializeData(); // Reload data
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating supplement: $e')),
        );
        // Revert the text field to original value on error
        final supplement = _supplements.firstWhere(
          (s) => s['id'] == supplementId,
        );
        _supplementPriceControllers[supplementId]?.text =
            (supplement['price'] ?? 0.0).toString();
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleSupplementAvailability(String supplementId) async {
    final variantId = widget.variant['id'] as String? ?? '';
    final supplement = _supplements.firstWhere(
      (s) => s['id'] == supplementId,
    );

    final currentAvailableForVariants =
        (supplement['available_for_variants'] as List?)?.cast<String>() ?? [];
    final isCurrentlyAvailable =
        currentAvailableForVariants.contains(variantId);

    final newAvailableForVariants =
        List<String>.from(currentAvailableForVariants);
    if (isCurrentlyAvailable) {
      newAvailableForVariants.remove(variantId);
    } else {
      newAvailableForVariants.add(variantId);
    }

    // Optimistically update UI
    setState(() {
      _supplementAvailability[supplementId] = !isCurrentlyAvailable;
    });

    try {
      await _enhancedService.updateSupplement(
        menuItemId: widget.menuItem.id,
        supplementId: supplementId,
        availableForVariants: newAvailableForVariants,
      );

      if (mounted) {
        setState(() {
          _initializeData(); // Reload data to ensure consistency
        });
      }
    } catch (e) {
      // Revert on error
      if (mounted) {
        setState(() {
          _supplementAvailability[supplementId] = isCurrentlyAvailable;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating supplement: $e')),
        );
      }
    }
  }

  Future<void> _addSupplementFromRestaurant(
      MenuItemSupplement supplement) async {
    setState(() => _isLoading = true);

    try {
      // Add the supplement to the menu item
      await _enhancedService.addSupplement(
        menuItemId: widget.menuItem.id,
        name: supplement.name,
        price: supplement.price,
        description: supplement.description,
        isAvailable: supplement.isAvailable,
      );

      // Reload menu item to get the new supplement ID
      final updatedMenuItem =
          await _enhancedService.getEnhancedMenuItem(widget.menuItem.id);

      // Set availability for this variant
      final variantId = widget.variant['id'] as String? ?? '';
      final allSupplements = updatedMenuItem.supplements;

      if (allSupplements.isNotEmpty) {
        final newSupplement = allSupplements.last; // Get the newly added one
        final newSupplementId = newSupplement.id;

        await _enhancedService.updateSupplement(
          menuItemId: widget.menuItem.id,
          supplementId: newSupplementId,
          availableForVariants: [variantId],
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Supplement added successfully')),
        );
        setState(() {
          _initializeData(); // Reload data
          _isSearchingSupplements = false;
          _searchController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding supplement: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteSupplement(String supplementId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Supplement'),
        content: const Text(
          'Are you sure you want to delete this supplement? This will remove it from all variants.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      await _enhancedService.deleteSupplement(
        menuItemId: widget.menuItem.id,
        supplementId: supplementId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Supplement deleted successfully')),
        );
        setState(() {
          _initializeData(); // Reload data
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting supplement: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: double.maxFinite,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Edit Variant: ${widget.variant['name'] ?? ''}',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Tabs
            TabBar(
              controller: _tabController,
              labelColor: const Color(0xFFd47b00),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFFd47b00),
              tabs: const [
                Tab(text: 'Info'),
                Tab(text: 'Pricing'),
                Tab(text: 'Supplements'),
              ],
            ),
            const SizedBox(height: 10),

            // Tab Content
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 200,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildInfoTab(),
                          _buildPricingTab(),
                          _buildSupplementsTab(),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _deleteVariant,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Delete Variant',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveVariant,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFd47b00),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Save Changes',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Variant Name
          Text(
            'Variant Name',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            style: GoogleFonts.poppins(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Enter variant name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Description
          Text(
            'Description (Optional)',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descriptionController,
            style: GoogleFonts.poppins(fontSize: 14),
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Enter description',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Default Variant
          Row(
            children: [
              Expanded(
                child: Text(
                  'Set as Default Variant',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              Switch(
                value: _isDefault,
                onChanged: (value) {
                  setState(() => _isDefault = value);
                },
                activeColor: const Color(0xFFd47b00),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPricingTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Pricing Options',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: _addPricing,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Pricing'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFd47b00),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _pricingOptions.isEmpty
              ? Center(
                  child: Text(
                    'No pricing options yet.\nTap "Add Pricing" to add one.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _pricingOptions.length,
                  itemBuilder: (context, index) {
                    final pricing = _pricingOptions[index];
                    final pricingId = pricing['id'] as String? ?? '';
                    final size = pricing['size'] ?? '';
                    final portion = pricing['portion'] ?? '';
                    final price = pricing['price'] ?? 0.0;
                    final isDefault = pricing['is_default'] ?? false;
                    final sizeLabel = size.isNotEmpty
                        ? size
                        : (portion.isNotEmpty ? portion : 'Standard');

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDefault ? Colors.green[50] : Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDefault
                              ? Colors.green[300]!
                              : Colors.grey[300]!,
                          width: isDefault ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      sizeLabel,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    if (isDefault) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'Default',
                                          style: GoogleFonts.poppins(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${price.toStringAsFixed(0)} DZD',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFd47b00),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            color: const Color(0xFFd47b00),
                            onPressed: () => _editPricing(pricing),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 20),
                            color: Colors.red,
                            onPressed: () => _deletePricing(pricingId),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSupplementsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Supplements',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _isSearchingSupplements = !_isSearchingSupplements;
                  if (!_isSearchingSupplements) {
                    _searchController.clear();
                  }
                });
              },
              icon: Icon(_isSearchingSupplements ? Icons.close : Icons.add),
              label: Text(_isSearchingSupplements ? 'Cancel' : 'Add'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFd47b00),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Add Supplement Search
        if (_isSearchingSupplements) ...[
          TextField(
            controller: _searchController,
            autofocus: true,
            style: GoogleFonts.poppins(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search supplements...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            onChanged: (value) {
              setState(() {});
            },
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _buildSupplementSuggestions(),
          ),
        ] else ...[
          Expanded(
            child: _supplements.isEmpty
                ? Center(
                    child: Text(
                      'No supplements available.',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _supplements.length,
                    itemBuilder: (context, index) {
                      final supplement = _supplements[index];
                      final supplementId = supplement['id'] as String? ?? '';
                      final name = supplement['name'] ?? '';
                      final isAvailable =
                          _supplementAvailability[supplementId] ?? false;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color:
                              isAvailable ? Colors.blue[50] : Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isAvailable
                                ? Colors.blue[300]!
                                : Colors.grey[300]!,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    name,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                Switch(
                                  value: isAvailable,
                                  onChanged: _isLoading
                                      ? null
                                      : (value) =>
                                          _toggleSupplementAvailability(
                                              supplementId),
                                  activeColor: const Color(0xFFd47b00),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _supplementPriceControllers[
                                        supplementId],
                                    enabled: !_isLoading,
                                    style: GoogleFonts.poppins(fontSize: 14),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'Price (DZD)',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                    ),
                                    onSubmitted: (value) {
                                      if (value.isNotEmpty) {
                                        _updateSupplementPrice(supplementId);
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton(
                                  onPressed: _isLoading
                                      ? null
                                      : () =>
                                          _updateSupplementPrice(supplementId),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFd47b00),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                  ),
                                  child: const Text('Update'),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 20),
                                  color: Colors.red,
                                  onPressed: _isLoading
                                      ? null
                                      : () => _deleteSupplement(supplementId),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ],
    );
  }

  Widget _buildSupplementSuggestions() {
    final searchQuery = _searchController.text.toLowerCase();
    final filteredSupplements = _availableSupplements.where((supplement) {
      if (searchQuery.isEmpty) return true;
      return supplement.name.toLowerCase().contains(searchQuery);
    }).toList();

    // Filter out supplements that are already added
    final existingSupplementIds =
        _supplements.map((s) => s['id'] as String).toSet();
    final availableToAdd = filteredSupplements.where((supplement) {
      return !existingSupplementIds.contains(supplement.id);
    }).toList();

    if (availableToAdd.isEmpty) {
      return Center(
        child: Text(
          searchQuery.isEmpty
              ? 'No supplements available to add'
              : 'No supplements found matching "$searchQuery"',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: availableToAdd.length,
      itemBuilder: (context, index) {
        final supplement = availableToAdd[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey[300]!,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      supplement.name,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    if (supplement.description != null &&
                        supplement.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        supplement.description!,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      '${supplement.price.toStringAsFixed(0)} DZD',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFd47b00),
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () => _addSupplementFromRestaurant(supplement),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFd47b00),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                child: const Text('Add'),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Dialog for adding/editing pricing options
class _AddEditPricingDialog extends StatefulWidget {
  final String menuItemId;
  final String variantId;
  final Map<String, dynamic>? pricing;

  const _AddEditPricingDialog({
    required this.menuItemId,
    required this.variantId,
    this.pricing,
  });

  @override
  State<_AddEditPricingDialog> createState() => _AddEditPricingDialogState();
}

class _AddEditPricingDialogState extends State<_AddEditPricingDialog> {
  final _formKey = GlobalKey<FormState>();
  final _sizeController = TextEditingController();
  final _portionController = TextEditingController();
  final _priceController = TextEditingController();
  bool _isDefault = false;
  bool _isLoading = false;

  final _enhancedService = EnhancedMenuItemService();

  @override
  void initState() {
    super.initState();
    if (widget.pricing != null) {
      _sizeController.text = widget.pricing!['size'] ?? '';
      _portionController.text = widget.pricing!['portion'] ?? '';
      _priceController.text = (widget.pricing!['price'] ?? 0.0).toString();
      _isDefault = widget.pricing!['is_default'] ?? false;
    }
  }

  @override
  void dispose() {
    _sizeController.dispose();
    _portionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final size = _sizeController.text.trim();
    final portion = _portionController.text.trim();
    final price = double.tryParse(_priceController.text.trim());

    if (price == null || price < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid price')),
      );
      return;
    }

    if (size.isEmpty && portion.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter either size or portion')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (widget.pricing != null) {
        // Update existing pricing
        final pricingId = widget.pricing!['id'] as String? ?? '';
        await _enhancedService.updatePricing(
          menuItemId: widget.menuItemId,
          pricingId: pricingId,
          size: size.isEmpty ? null : size,
          portion: portion.isEmpty ? null : portion,
          price: price,
          isDefault: _isDefault,
        );
      } else {
        // Add new pricing
        await _enhancedService.addPricing(
          menuItemId: widget.menuItemId,
          variantId: widget.variantId,
          size: size.isEmpty ? '' : size,
          portion: portion.isEmpty ? '' : portion,
          price: price,
          isDefault: _isDefault,
        );
      }

      if (mounted) {
        Navigator.of(context).pop({'success': true});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        widget.pricing != null ? 'Edit Pricing' : 'Add Pricing',
        style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
      ),
      content: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _sizeController,
                      decoration: InputDecoration(
                        labelText: 'Size (e.g., S, M, L)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _portionController,
                      decoration: InputDecoration(
                        labelText: 'Portion (e.g., 1 serving, 2-3 people)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Price (DZD)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a price';
                        }
                        final price = double.tryParse(value);
                        if (price == null || price < 0) {
                          return 'Please enter a valid price';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Set as Default',
                            style: GoogleFonts.poppins(fontSize: 14),
                          ),
                        ),
                        Switch(
                          value: _isDefault,
                          onChanged: (value) =>
                              setState(() => _isDefault = value),
                          activeColor: const Color(0xFFd47b00),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFd47b00),
            foregroundColor: Colors.white,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
