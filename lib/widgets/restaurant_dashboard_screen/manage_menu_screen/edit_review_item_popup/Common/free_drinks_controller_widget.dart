import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../core/data/repositories/menu_item_repository.dart';
import '../../../../../models/menu_item.dart';
import '../../../../../services/menu_item_service.dart';

/// Free Drinks Controller Widget
/// Allows hiding free drinks, editing global quantity, and adding new free drinks
class LTOFreeDrinksControllerWidget extends StatefulWidget {
  final MenuItem menuItem;
  final VoidCallback onChanged;

  const LTOFreeDrinksControllerWidget({
    required this.menuItem,
    required this.onChanged,
    super.key,
  });

  @override
  State<LTOFreeDrinksControllerWidget> createState() =>
      _LTOFreeDrinksControllerWidgetState();
}

class _LTOFreeDrinksControllerWidgetState
    extends State<LTOFreeDrinksControllerWidget> {
  bool _isLoading = false;
  final MenuItemService _menuItemService = MenuItemService();
  final MenuItemRepository _menuItemRepository = MenuItemRepository();
  Map<String, String> _drinkNames = {}; // Cache drink IDs to names

  // Get current free drinks settings from first pricing option (assuming all are the same)
  bool get _freeDrinksIncluded {
    if (widget.menuItem.pricingOptions.isEmpty) return false;
    final firstPricing = widget.menuItem.pricingOptions.first;
    return firstPricing['free_drinks_included'] ?? false;
  }

  int get _freeDrinksQuantity {
    if (widget.menuItem.pricingOptions.isEmpty) return 1;
    final firstPricing = widget.menuItem.pricingOptions.first;
    return firstPricing['free_drinks_quantity'] ?? 1;
  }

  List<String> get _freeDrinksList {
    if (widget.menuItem.pricingOptions.isEmpty) return [];
    final firstPricing = widget.menuItem.pricingOptions.first;
    final list = firstPricing['free_drinks_list'];
    if (list == null) return [];
    if (list is List) {
      return list.map((e) => e.toString()).toList();
    }
    return [];
  }

  Future<void> _toggleFreeDrinks(bool value) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Update all pricing options with the new free_drinks_included value
      final updatedPricingOptions =
          widget.menuItem.pricingOptions.map((pricing) {
        final updatedPricing = Map<String, dynamic>.from(pricing);
        updatedPricing['free_drinks_included'] = value;
        updatedPricing['updated_at'] = DateTime.now().toIso8601String();
        return updatedPricing;
      }).toList();

      final updatedMenuItem = widget.menuItem.copyWith(
        pricingOptions: updatedPricingOptions,
      );

      final success = await _menuItemService.updateMenuItem(updatedMenuItem);

      if (!success) {
        throw Exception('Failed to update menu item');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value ? 'Free drinks enabled' : 'Free drinks hidden',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        widget.onChanged();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating free drinks: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _editGlobalQuantity() async {
    final quantityController =
        TextEditingController(text: _freeDrinksQuantity.toString());

    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Edit Global Allowed Quantity',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          content: TextField(
            controller: quantityController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Quantity',
              hintText: 'Enter maximum quantity',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.numbers),
            ),
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  color: Colors.grey[600],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final quantityStr = quantityController.text.trim();
                if (quantityStr.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a quantity'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                final quantity = int.tryParse(quantityStr);
                if (quantity == null || quantity < 1) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content:
                          Text('Please enter a valid quantity (1 or more)'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                Navigator.of(dialogContext).pop();

                if (mounted) {
                  setState(() {
                    _isLoading = true;
                  });
                }

                try {
                  // Update all pricing options with the new quantity
                  final updatedPricingOptions =
                      widget.menuItem.pricingOptions.map((pricing) {
                    final updatedPricing = Map<String, dynamic>.from(pricing);
                    updatedPricing['free_drinks_quantity'] = quantity;
                    updatedPricing['updated_at'] =
                        DateTime.now().toIso8601String();
                    return updatedPricing;
                  }).toList();

                  final updatedMenuItem = widget.menuItem.copyWith(
                    pricingOptions: updatedPricingOptions,
                  );

                  final success =
                      await _menuItemService.updateMenuItem(updatedMenuItem);

                  if (!success) {
                    throw Exception('Failed to update menu item');
                  }

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Global quantity updated successfully'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 2),
                      ),
                    );
                    widget.onChanged();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error updating quantity: $e'),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                } finally {
                  if (mounted) {
                    setState(() {
                      _isLoading = false;
                    });
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFd47b00),
                foregroundColor: Colors.white,
              ),
              child: Text(
                'Save',
                style: GoogleFonts.poppins(),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addNewFreeDrink() async {
    if (_isLoading) return;

    try {
      debugPrint('🍹 Add Free Drink: Starting...');

      // Get current user
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        debugPrint('❌ Add Free Drink: User not authenticated');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User not authenticated'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Get restaurant ID from menu item
      final restaurantId = widget.menuItem.restaurantId;
      debugPrint('🍹 Add Free Drink: Restaurant ID: $restaurantId');

      if (restaurantId.isEmpty) {
        debugPrint('❌ Add Free Drink: Restaurant ID is empty');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Restaurant ID not found'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      setState(() {
        _isLoading = true;
      });

      // PERF: Use repository with 3-tier caching and isolate parsing
      // This eliminates direct Supabase query and JSON parsing on main thread
      debugPrint('🍹 Add Free Drink: Fetching drinks...');
      final stopwatch = Stopwatch()..start();

      final drinks = await _menuItemRepository.getDrinksByRestaurant(
        restaurantId,
        forceRefresh: false, // Use cache if available
      );

      stopwatch.stop();
      debugPrint('⏱️ Drinks fetch took ${stopwatch.elapsedMilliseconds}ms');

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      if (drinks.isEmpty) {
        debugPrint('❌ Add Free Drink: No drinks found');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No drinks found in your menu. Add drinks first.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      debugPrint(
          '🍹 Add Free Drink: Showing dialog with ${drinks.length} drinks');

      // Get current free drinks list
      final currentFreeDrinks = _freeDrinksList;

      // Show selection dialog
      if (!mounted) return;
      final selectedDrink = await showDialog<MenuItem>(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Select Free Drink',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            content: SizedBox(
              width: double.maxFinite,
              // PERF: Use fixed height instead of shrinkWrap for better performance
              // Dialog with ListView - limit height to prevent O(N) layout issues
              height: 400, // Fixed height for dialog content
              child: ListView.builder(
                // PERF: Removed shrinkWrap - using fixed height container instead
                itemCount: drinks.length,
                // PERF: Set reasonable cache extent
                cacheExtent: 250,
                itemBuilder: (context, index) {
                  final drink = drinks[index];
                  final isSelected = currentFreeDrinks.contains(drink.id);

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: drink.image.isNotEmpty
                          ? NetworkImage(drink.image)
                          : null,
                      child: drink.image.isEmpty
                          ? const Icon(Icons.local_drink)
                          : null,
                    ),
                    title: Text(
                      drink.name,
                      style: GoogleFonts.poppins(),
                    ),
                    subtitle: Text(
                      '${drink.price.toStringAsFixed(0)} DZD',
                      style: GoogleFonts.poppins(
                        color: Colors.grey[600],
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(
                            Icons.check_circle,
                            color: Color(0xFFd47b00),
                          )
                        : null,
                    onTap: () {
                      Navigator.of(dialogContext).pop(drink);
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.poppins(
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          );
        },
      );

      if (selectedDrink == null) {
        debugPrint('🍹 Add Free Drink: No drink selected');
        return;
      }

      debugPrint(
          '🍹 Add Free Drink: Selected drink: ${selectedDrink.name} (${selectedDrink.id})');

      // Check if already in list
      if (currentFreeDrinks.contains(selectedDrink.id)) {
        debugPrint('❌ Add Free Drink: Drink already in list');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This drink is already in the free drinks list'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Add to list
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }

      debugPrint('🍹 Add Free Drink: Updating pricing options...');

      try {
        // Update all pricing options with the new free drink
        final updatedPricingOptions =
            widget.menuItem.pricingOptions.map((pricing) {
          final updatedPricing = Map<String, dynamic>.from(pricing);
          final currentList = List<String>.from(
            updatedPricing['free_drinks_list'] ?? [],
          );
          if (!currentList.contains(selectedDrink.id)) {
            currentList.add(selectedDrink.id);
          }
          updatedPricing['free_drinks_list'] = currentList;
          updatedPricing['free_drinks_included'] =
              true; // Enable if not already
          updatedPricing['updated_at'] = DateTime.now().toIso8601String();
          return updatedPricing;
        }).toList();

        final updatedMenuItem = widget.menuItem.copyWith(
          pricingOptions: updatedPricingOptions,
        );

        final success = await _menuItemService.updateMenuItem(updatedMenuItem);

        if (!success) {
          throw Exception('Failed to update menu item');
        }

        debugPrint(
            '✅ Add Free Drink: Successfully added ${selectedDrink.name}');

        if (mounted) {
          // Reload drink names
          _loadDrinkNames();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${selectedDrink.name} added to free drinks'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
          widget.onChanged();
        }
      } catch (e) {
        debugPrint('❌ Add Free Drink: Error updating menu item: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error adding free drink: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Add Free Drink: Error loading drinks: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading drinks: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _removeFreeDrink(String drinkId) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Update all pricing options to remove the drink
      final updatedPricingOptions =
          widget.menuItem.pricingOptions.map((pricing) {
        final updatedPricing = Map<String, dynamic>.from(pricing);
        final currentList = List<String>.from(
          updatedPricing['free_drinks_list'] ?? [],
        );
        currentList.remove(drinkId);
        updatedPricing['free_drinks_list'] = currentList;
        // If list is empty, disable free drinks
        if (currentList.isEmpty) {
          updatedPricing['free_drinks_included'] = false;
        }
        updatedPricing['updated_at'] = DateTime.now().toIso8601String();
        return updatedPricing;
      }).toList();

      final updatedMenuItem = widget.menuItem.copyWith(
        pricingOptions: updatedPricingOptions,
      );

      final success = await _menuItemService.updateMenuItem(updatedMenuItem);

      if (!success) {
        throw Exception('Failed to update menu item');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Free drink removed'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        widget.onChanged();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing free drink: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadDrinkNames() async {
    final freeDrinksList = _freeDrinksList;
    if (freeDrinksList.isEmpty) return;

    try {
      // PERF: Use repository batch query to fix N+1 pattern
      // This replaces individual queries with a single batch query
      final stopwatch = Stopwatch()..start();

      final drinkNames = await _menuItemRepository.getMenuItemsNamesByIds(
        freeDrinksList,
        forceRefresh: false, // Use cache if available
      );

      stopwatch.stop();
      debugPrint('⏱️ Load drink names took ${stopwatch.elapsedMilliseconds}ms');

      // Update drink names cache
      if (mounted) {
        setState(() {
          _drinkNames = {..._drinkNames, ...drinkNames};
        });
      }
    } catch (e) {
      debugPrint('Error loading drink names: $e');
    }
  }


  @override
  void initState() {
    super.initState();
    // Load drink names when widget is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDrinkNames();
    });
  }

  @override
  void didUpdateWidget(LTOFreeDrinksControllerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload drink names if menu item changed
    final oldFreeDrinksList = oldWidget.menuItem.pricingOptions.isEmpty
        ? <String>[]
        : (oldWidget.menuItem.pricingOptions.first['free_drinks_list'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            <String>[];
    if (oldWidget.menuItem.id != widget.menuItem.id ||
        _freeDrinksList != oldFreeDrinksList) {
      _loadDrinkNames();
    }
  }

  @override
  Widget build(BuildContext context) {
    final freeDrinksIncluded = _freeDrinksIncluded;
    final freeDrinksQuantity = _freeDrinksQuantity;
    final freeDrinksList = _freeDrinksList;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Free Drinks',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            // Hide/Show toggle
            Switch(
              value: freeDrinksIncluded,
              onChanged: _isLoading ? null : _toggleFreeDrinks,
              activeColor: const Color(0xFFd47b00),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (freeDrinksIncluded) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey[300]!,
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Global quantity display and edit
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Global Allowed Quantity',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$freeDrinksQuantity',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFd47b00),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 18),
                      color: const Color(0xFFd47b00),
                      onPressed: _isLoading ? null : _editGlobalQuantity,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const Divider(height: 24),
                // Free drinks list
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Free Drinks List',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: _isLoading ? null : _addNewFreeDrink,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFd47b00),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.add,
                                size: 14, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              'Add Free Drink',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (freeDrinksList.isEmpty)
                  Text(
                    'No free drinks added yet. Tap "Add Free Drink" to add one.',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: freeDrinksList.map((drinkId) {
                      final drinkName = _drinkNames[drinkId] ?? drinkId;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.grey[300]!,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              drinkName,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: _isLoading
                                  ? null
                                  : () => _removeFreeDrink(drinkId),
                              child: const Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ] else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey[300]!,
                width: 1,
              ),
            ),
            child: Text(
              'Free drinks are hidden. Toggle the switch above to show free drinks.',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        const SizedBox(height: 20),
      ],
    );
  }
}
