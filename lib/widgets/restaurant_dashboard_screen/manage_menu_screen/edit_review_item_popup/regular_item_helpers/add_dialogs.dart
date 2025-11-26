import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../services/enhanced_menu_item_service.dart';

/// Dialog for adding a new variant
class AddVariantDialog extends StatefulWidget {
  final String menuItemId;
  final VoidCallback? onAdded;

  const AddVariantDialog({
    required this.menuItemId,
    this.onAdded,
    super.key,
  });

  static Future<Map<String, dynamic>?> show(
    BuildContext context,
    String menuItemId, {
    VoidCallback? onAdded,
  }) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AddVariantDialog(menuItemId: menuItemId, onAdded: onAdded);
      },
    );
  }

  @override
  State<AddVariantDialog> createState() => _AddVariantDialogState();
}

class _AddVariantDialogState extends State<AddVariantDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isDefault = false;
  bool _isLoading = false;
  final _enhancedService = EnhancedMenuItemService();

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _addVariant() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a variant name'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _enhancedService.addVariant(
        menuItemId: widget.menuItemId,
        name: name,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        isDefault: _isDefault,
      );

      if (mounted) {
        Navigator.of(context).pop({'success': true});
        widget.onAdded?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Variant added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding variant: $e'),
            backgroundColor: Colors.red,
          ),
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Text(
        'Add Variant',
        style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
      ),
      content: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Variant Name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      labelText: 'Description (optional)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    maxLines: 2,
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
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _addVariant,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFd47b00),
            foregroundColor: Colors.white,
          ),
          child: const Text('Add'),
        ),
      ],
    );
  }
}

/// Dialog for adding pricing
class AddPricingDialog extends StatefulWidget {
  final String menuItemId;
  final String variantId;

  const AddPricingDialog({
    required this.menuItemId,
    required this.variantId,
    super.key,
  });

  static Future<Map<String, dynamic>?> show(
    BuildContext context,
    String menuItemId,
    String variantId,
  ) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AddPricingDialog(
          menuItemId: menuItemId,
          variantId: variantId,
        );
      },
    );
  }

  @override
  State<AddPricingDialog> createState() => _AddPricingDialogState();
}

class _AddPricingDialogState extends State<AddPricingDialog> {
  final _sizeController = TextEditingController();
  final _portionController = TextEditingController();
  final _priceController = TextEditingController();
  bool _isDefault = false;
  bool _isLoading = false;
  final _enhancedService = EnhancedMenuItemService();

  @override
  void dispose() {
    _sizeController.dispose();
    _portionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _addPricing() async {
    final size = _sizeController.text.trim();
    final portion = _portionController.text.trim();
    final price = double.tryParse(_priceController.text.trim());

    if (price == null || price < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid price'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (size.isEmpty && portion.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter either size or portion'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _enhancedService.addPricing(
        menuItemId: widget.menuItemId,
        variantId: widget.variantId,
        size: size.isEmpty ? '' : size,
        portion: portion.isEmpty ? '' : portion,
        price: price,
        isDefault: _isDefault,
      );

      if (context.mounted) {
        Navigator.of(context).pop({'success': true});
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Text(
        'Add Size',
        style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
      ),
      content: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
                      labelText: 'Portion (e.g., 1 serving)',
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
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _addPricing,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFd47b00),
            foregroundColor: Colors.white,
          ),
          child: const Text('Add'),
        ),
      ],
    );
  }
}

/// Dialog for adding a supplement
class AddSupplementDialog extends StatefulWidget {
  final String menuItemId;
  final String? variantId;
  final VoidCallback? onAdded;

  const AddSupplementDialog({
    required this.menuItemId,
    this.variantId,
    this.onAdded,
    super.key,
  });

  static Future<Map<String, dynamic>?> show(
    BuildContext context,
    String menuItemId,
    String? variantId, {
    VoidCallback? onAdded,
  }) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AddSupplementDialog(
          menuItemId: menuItemId,
          variantId: variantId,
          onAdded: onAdded,
        );
      },
    );
  }

  @override
  State<AddSupplementDialog> createState() => _AddSupplementDialogState();
}

class _AddSupplementDialogState extends State<AddSupplementDialog> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isAvailable = true;
  bool _isLoading = false;
  final _enhancedService = EnhancedMenuItemService();

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _addSupplement() async {
    final name = _nameController.text.trim();
    final priceStr = _priceController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a name'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final price = double.tryParse(priceStr);
    if (price == null || price < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid price'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final availableForVariants = widget.variantId != null
          ? <String>[widget.variantId.toString()]
          : <String>[]; // Empty = global

      await _enhancedService.addSupplement(
        menuItemId: widget.menuItemId,
        name: name,
        price: price,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        isAvailable: _isAvailable,
        availableForVariants: availableForVariants,
      );

      if (mounted) {
        Navigator.of(context).pop({'success': true});
        widget.onAdded?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Supplement added successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding supplement: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Text(
        'Add Supplement',
        style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
      ),
      content: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a name';
                      }
                      return null;
                    },
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
                  TextField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      labelText: 'Description (optional)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Available',
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                      ),
                      Switch(
                        value: _isAvailable,
                        onChanged: (value) =>
                            setState(() => _isAvailable = value),
                        activeColor: const Color(0xFFd47b00),
                      ),
                    ],
                  ),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _addSupplement,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFd47b00),
            foregroundColor: Colors.white,
          ),
          child: const Text('Add'),
        ),
      ],
    );
  }
}

/// Dialog for adding a global supplement (available for all variants)
class AddGlobalSupplementDialog extends StatefulWidget {
  final String menuItemId;
  final VoidCallback? onAdded;

  const AddGlobalSupplementDialog({
    required this.menuItemId,
    this.onAdded,
    super.key,
  });

  static Future<Map<String, dynamic>?> show(
    BuildContext context,
    String menuItemId, {
    VoidCallback? onAdded,
  }) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AddGlobalSupplementDialog(
          menuItemId: menuItemId,
          onAdded: onAdded,
        );
      },
    );
  }

  @override
  State<AddGlobalSupplementDialog> createState() =>
      _AddGlobalSupplementDialogState();
}

class _AddGlobalSupplementDialogState extends State<AddGlobalSupplementDialog> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isAvailable = true;
  bool _isLoading = false;
  final _enhancedService = EnhancedMenuItemService();

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _addSupplement() async {
    final name = _nameController.text.trim();
    final priceStr = _priceController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a name'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final price = double.tryParse(priceStr);
    if (price == null || price < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid price'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _enhancedService.addSupplement(
        menuItemId: widget.menuItemId,
        name: name,
        price: price,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        isAvailable: _isAvailable,
        availableForVariants: [], // Empty = global
      );

      if (mounted) {
        Navigator.of(context).pop({'success': true});
        widget.onAdded?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Global supplement added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding supplement: $e'),
            backgroundColor: Colors.red,
          ),
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Text(
        'Add Global Supplement',
        style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
      ),
      content: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Name',
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
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      labelText: 'Description (optional)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Available',
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                      ),
                      Switch(
                        value: _isAvailable,
                        onChanged: (value) =>
                            setState(() => _isAvailable = value),
                        activeColor: const Color(0xFFd47b00),
                      ),
                    ],
                  ),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _addSupplement,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFd47b00),
            foregroundColor: Colors.white,
          ),
          child: const Text('Add'),
        ),
      ],
    );
  }
}

/// Dialog for adding a global size with variant selection
class AddGlobalSizeDialog extends StatefulWidget {
  final String menuItemId;
  final List<Map<String, dynamic>> variants;
  final VoidCallback? onAdded;

  const AddGlobalSizeDialog({
    required this.menuItemId,
    required this.variants,
    this.onAdded,
    super.key,
  });

  static Future<Map<String, dynamic>?> show(
    BuildContext context,
    String menuItemId,
    List<Map<String, dynamic>> variants, {
    VoidCallback? onAdded,
  }) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AddGlobalSizeDialog(
          menuItemId: menuItemId,
          variants: variants,
          onAdded: onAdded,
        );
      },
    );
  }

  @override
  State<AddGlobalSizeDialog> createState() => _AddGlobalSizeDialogState();
}

class _AddGlobalSizeDialogState extends State<AddGlobalSizeDialog> {
  final _sizeController = TextEditingController();
  final _portionController = TextEditingController();
  final _priceController = TextEditingController();
  final List<String?> _selectedVariantIds = [
    null
  ]; // Global selected by default
  bool _isDefault = false;
  bool _isLoading = false;
  final _enhancedService = EnhancedMenuItemService();

  @override
  void dispose() {
    _sizeController.dispose();
    _portionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _addSize() async {
    final size = _sizeController.text.trim();
    final portion = _portionController.text.trim();
    final priceStr = _priceController.text.trim();

    final price = double.tryParse(priceStr);
    if (price == null || price < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid price'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedVariantIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one variant'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      int successCount = 0;
      for (final variantId in _selectedVariantIds) {
        try {
          await _enhancedService.addPricing(
            menuItemId: widget.menuItemId,
            variantId: variantId, // null for global
            size: size.isEmpty ? '' : size,
            portion: portion.isEmpty ? '' : portion,
            price: price,
            isDefault: _isDefault,
          );
          successCount++;
        } catch (e) {
          debugPrint('Error adding pricing for variant $variantId: $e');
        }
      }

      if (mounted) {
        Navigator.of(context).pop({'success': true});
        widget.onAdded?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              successCount == _selectedVariantIds.length
                  ? 'Size added successfully to $successCount variant(s)'
                  : 'Size added to $successCount of ${_selectedVariantIds.length} variant(s)',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding size: $e'),
            backgroundColor: Colors.red,
          ),
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Text(
        'Add Size',
        style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
      ),
      content: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Variant selection
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Select Variants (Multiple)',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Global option
                        InkWell(
                          onTap: () {
                            setState(() {
                              if (_selectedVariantIds.contains(null)) {
                                _selectedVariantIds.remove(null);
                              } else {
                                _selectedVariantIds.add(null);
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: _selectedVariantIds.contains(null)
                                  ? const Color(0xFFd47b00).withOpacity(0.1)
                                  : Colors.transparent,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(12),
                                topRight: Radius.circular(12),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _selectedVariantIds.contains(null)
                                      ? Icons.check_circle
                                      : Icons.circle_outlined,
                                  size: 18,
                                  color: _selectedVariantIds.contains(null)
                                      ? const Color(0xFFd47b00)
                                      : Colors.grey[600],
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Global (No Variant)',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: _selectedVariantIds.contains(null)
                                          ? const Color(0xFFd47b00)
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (widget.variants.isNotEmpty)
                          Divider(height: 1, color: Colors.grey[300]),
                        // Variant list
                        ...widget.variants.map((variant) {
                          final variantId = variant['id']?.toString() ?? '';
                          final variantName = variant['name'] ?? '';
                          final isSelected =
                              _selectedVariantIds.contains(variantId);
                          final isLast = widget.variants.last == variant;

                          return Column(
                            children: [
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    if (isSelected) {
                                      _selectedVariantIds.remove(variantId);
                                    } else {
                                      _selectedVariantIds.add(variantId);
                                    }
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFFd47b00)
                                            .withOpacity(0.1)
                                        : Colors.transparent,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isSelected
                                            ? Icons.check_circle
                                            : Icons.circle_outlined,
                                        size: 18,
                                        color: isSelected
                                            ? const Color(0xFFd47b00)
                                            : Colors.grey[600],
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          variantName,
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: isSelected
                                                ? const Color(0xFFd47b00)
                                                : Colors.black87,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (!isLast)
                                Divider(height: 1, color: Colors.grey[300]),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
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
                      labelText: 'Portion (e.g., 1 serving)',
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
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _addSize,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFd47b00),
            foregroundColor: Colors.white,
          ),
          child: const Text('Add'),
        ),
      ],
    );
  }
}
