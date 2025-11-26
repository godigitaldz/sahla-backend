import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../services/enhanced_menu_item_service.dart';

/// Dialog for editing item name
class EditNameDialog extends StatelessWidget {
  final String initialName;
  final int maxLength;

  const EditNameDialog({
    required this.initialName,
    this.maxLength = 100,
    super.key,
  });

  static Future<String?> show(BuildContext context, String initialName) {
    return showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return EditNameDialog(initialName: initialName);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextEditingController nameController =
        TextEditingController(text: initialName);

    return AlertDialog(
      title: const Text('Edit Name'),
      content: TextField(
        controller: nameController,
        decoration: const InputDecoration(
          labelText: 'Item Name',
          hintText: 'Enter item name',
          border: OutlineInputBorder(),
        ),
        autofocus: true,
        maxLength: maxLength,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final newName = nameController.text.trim();
            if (newName.isNotEmpty) {
              Navigator.of(context).pop(newName);
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Dialog for editing price (discounted or original)
class EditPriceDialog extends StatelessWidget {
  final double? initialPrice;
  final String title;
  final String labelText;
  final String hintText;

  const EditPriceDialog({
    required this.initialPrice,
    required this.title,
    required this.labelText,
    required this.hintText,
    super.key,
  });

  static Future<double?> show(
    BuildContext context,
    double? initialPrice, {
    required String title,
    required String labelText,
    required String hintText,
  }) {
    return showDialog<double>(
      context: context,
      builder: (BuildContext dialogContext) {
        return EditPriceDialog(
          initialPrice: initialPrice,
          title: title,
          labelText: labelText,
          hintText: hintText,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextEditingController priceController = TextEditingController(
      text: initialPrice?.toString() ?? '',
    );

    return AlertDialog(
      title: Text(title),
      content: TextField(
        controller: priceController,
        decoration: InputDecoration(
          labelText: labelText,
          hintText: hintText,
          border: const OutlineInputBorder(),
          prefixText: 'DZD ',
        ),
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final newPrice = priceController.text.trim();
            if (newPrice.isNotEmpty) {
              final priceValue = double.tryParse(newPrice);
              if (priceValue != null && priceValue >= 0) {
                Navigator.of(context).pop(priceValue);
              }
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Dialog for editing preparation time
class EditPrepTimeDialog extends StatelessWidget {
  final int initialPrepTime;

  const EditPrepTimeDialog({
    required this.initialPrepTime,
    super.key,
  });

  static Future<int?> show(BuildContext context, int initialPrepTime) {
    return showDialog<int>(
      context: context,
      builder: (BuildContext dialogContext) {
        return EditPrepTimeDialog(initialPrepTime: initialPrepTime);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextEditingController prepTimeController =
        TextEditingController(text: initialPrepTime.toString());

    return AlertDialog(
      title: const Text('Edit Preparation Time'),
      content: TextField(
        controller: prepTimeController,
        decoration: const InputDecoration(
          labelText: 'Preparation Time (minutes)',
          hintText: 'Enter preparation time in minutes',
          border: OutlineInputBorder(),
        ),
        autofocus: true,
        keyboardType: TextInputType.number,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final newPrepTime = prepTimeController.text.trim();
            if (newPrepTime.isNotEmpty) {
              final prepTimeValue = int.tryParse(newPrepTime);
              if (prepTimeValue != null && prepTimeValue >= 0) {
                Navigator.of(context).pop(prepTimeValue);
              }
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Dialog for editing pricing
class EditPricingDialog extends StatefulWidget {
  final String menuItemId;
  final String variantId;
  final Map<String, dynamic> pricing;

  const EditPricingDialog({
    required this.menuItemId,
    required this.variantId,
    required this.pricing,
    super.key,
  });

  static Future<Map<String, dynamic>?> show(
    BuildContext context,
    String menuItemId,
    String variantId,
    Map<String, dynamic> pricing,
  ) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext dialogContext) {
        return EditPricingDialog(
          menuItemId: menuItemId,
          variantId: variantId,
          pricing: pricing,
        );
      },
    );
  }

  @override
  State<EditPricingDialog> createState() => _EditPricingDialogState();
}

class _EditPricingDialogState extends State<EditPricingDialog> {
  final _sizeController = TextEditingController();
  final _portionController = TextEditingController();
  final _priceController = TextEditingController();
  bool _isDefault = false;
  bool _isLoading = false;
  final _enhancedService = EnhancedMenuItemService();

  @override
  void initState() {
    super.initState();
    _sizeController.text = widget.pricing['size'] ?? '';
    _portionController.text = widget.pricing['portion'] ?? '';
    _priceController.text = (widget.pricing['price'] ?? 0.0).toString();
    _isDefault = widget.pricing['is_default'] ?? false;
  }

  @override
  void dispose() {
    _sizeController.dispose();
    _portionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
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

    setState(() => _isLoading = true);

    try {
      final pricingId = widget.pricing['id'] as String? ?? '';
      await _enhancedService.updatePricing(
        menuItemId: widget.menuItemId,
        pricingId: pricingId,
        size: size.isEmpty ? null : size,
        portion: portion.isEmpty ? null : portion,
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
        'Edit Pricing',
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
          onPressed: _isLoading ? null : _save,
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
