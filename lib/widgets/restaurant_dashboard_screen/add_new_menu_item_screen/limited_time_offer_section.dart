import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/menu_item_form_controller.dart';
import '../../../models/menu_item.dart';

/// Limited Time Offer Section Widget
/// Allows users to configure promotional offers for menu items
class LimitedTimeOfferSection extends StatefulWidget {
  final MenuItemFormController controller;
  final Color primaryColor;
  final String? restaurantId;

  const LimitedTimeOfferSection({
    required this.controller,
    required this.primaryColor,
    this.restaurantId,
    super.key,
  });

  @override
  State<LimitedTimeOfferSection> createState() =>
      _LimitedTimeOfferSectionState();
}

class _LimitedTimeOfferSectionState extends State<LimitedTimeOfferSection> {
  // Drinks are loaded on-demand when dialog opens (same as special packs)

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.controller.isLimitedOffer
                  ? Colors.grey[800]!
                  : Colors.grey[300]!,
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildOfferToggle(),
              if (widget.controller.isLimitedOffer) ...[
                const SizedBox(height: 12),
                _buildOfferTypesSelector(),
                const SizedBox(height: 12),
                _buildDateRangePicker(),
                if (widget.controller.offerTypes.contains('special_price')) ...[
                  const SizedBox(height: 12),
                  _buildOriginalPriceField(),
                ],
                if (widget.controller.offerTypes.contains('free_drinks')) ...[
                  const SizedBox(height: 12),
                  _buildFreeDrinksSelector(),
                ],
                if (widget.controller.offerTypes
                    .contains('special_delivery')) ...[
                  const SizedBox(height: 12),
                  _buildSpecialDeliverySelector(),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildOfferToggle() {
    return Row(
      children: [
        Icon(
          Icons.local_offer,
          color:
              widget.controller.isLimitedOffer ? Colors.grey[800] : Colors.grey,
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Limited Time Offer',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
        Switch(
          value: widget.controller.isLimitedOffer,
          onChanged: (value) {
            widget.controller.setLimitedOffer(value: value);
          },
          activeColor: Colors.grey[800],
        ),
      ],
    );
  }

  Widget _buildOfferTypesSelector() {
    final offerTypes = [
      const _OfferType(
        key: 'special_price',
        label: 'Special Price',
        icon: Icons.discount,
        description: 'Offer a discounted price',
      ),
      const _OfferType(
        key: 'free_drinks',
        label: 'Free Drinks',
        icon: Icons.local_drink,
        description: 'Include free drinks with this item',
      ),
      const _OfferType(
        key: 'special_delivery',
        label: 'Special Delivery',
        icon: Icons.delivery_dining,
        description: 'Delivery discount for this item',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Offer Types',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: offerTypes.map((type) {
              final isSelected =
                  widget.controller.offerTypes.contains(type.key);
              final index = offerTypes.indexOf(type);
              return Padding(
                padding: EdgeInsets.only(
                    right: index < offerTypes.length - 1 ? 8 : 0),
                child: GestureDetector(
                  onTap: () {
                    widget.controller.toggleOfferType(type.key);
                  },
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.grey[800] : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color:
                            isSelected ? Colors.grey[800]! : Colors.grey[300]!,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          type.icon,
                          size: 16,
                          color: isSelected ? Colors.white : Colors.grey[700],
                        ),
                        const SizedBox(width: 5),
                        Text(
                          type.label,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDateRangePicker() {
    final dateFormat = DateFormat('MMM dd, yyyy hh:mm a');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Offer Duration',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildDateTimeField(
                label: 'Start Date/Time',
                value: widget.controller.offerStartAt,
                onTap: () => _selectStartDateTime(context),
                dateFormat: dateFormat,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDateTimeField(
                label: 'End Date/Time *',
                value: widget.controller.offerEndAt,
                onTap: () => _selectEndDateTime(context),
                dateFormat: dateFormat,
                isRequired: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDateTimeField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
    required DateFormat dateFormat,
    bool isRequired = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: value != null && isRequired
                ? widget.primaryColor
                : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today,
              size: 16,
              color: value != null ? widget.primaryColor : Colors.grey[400],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                value != null ? dateFormat.format(value) : label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: value != null ? Colors.black87 : Colors.grey[400],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectStartDateTime(BuildContext context) async {
    // ignore: use_build_context_synchronously
    final date = await showDatePicker(
      context: context,
      initialDate: widget.controller.offerStartAt ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: widget.primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (date == null) return;
    if (!mounted) return;

    // ignore: use_build_context_synchronously
    final time = await showTimePicker(
      // ignore: use_build_context_synchronously
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        widget.controller.offerStartAt ?? DateTime.now(),
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: widget.primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (time != null && mounted) {
      final startDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      widget.controller.setOfferDates(
        startDateTime,
        widget.controller.offerEndAt,
      );
    }
  }

  Future<void> _selectEndDateTime(BuildContext context) async {
    // ignore: use_build_context_synchronously
    final date = await showDatePicker(
      context: context,
      initialDate: widget.controller.offerEndAt ??
          DateTime.now().add(const Duration(days: 1)),
      firstDate: widget.controller.offerStartAt ?? DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: widget.primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (date == null) return;
    if (!mounted) return;

    // ignore: use_build_context_synchronously
    final time = await showTimePicker(
      // ignore: use_build_context_synchronously
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        widget.controller.offerEndAt ??
            DateTime.now().add(const Duration(hours: 1)),
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: widget.primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (time != null && mounted) {
      final endDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      widget.controller.setOfferDates(
        widget.controller.offerStartAt,
        endDateTime,
      );
    }
  }

  Widget _buildOriginalPriceField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Original Price (DA)',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 40,
          child: TextFormField(
            initialValue: widget.controller.originalPrice != null
                ? widget.controller.originalPrice!.toInt().toString()
                : '',
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'e.g., 1500',
              hintStyle: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[400],
              ),
              prefixIcon: Icon(Icons.attach_money,
                  color: widget.primaryColor, size: 18),
              suffixText: 'DA',
              suffixStyle: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(color: widget.primaryColor, width: 1.5),
              ),
            ),
            style: GoogleFonts.poppins(fontSize: 12),
            onChanged: (value) {
              if (value.isEmpty) {
                widget.controller.setOriginalPrice(null);
              } else {
                final price = double.tryParse(value);
                widget.controller.setOriginalPrice(price);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFreeDrinksSelector() {
    final selectedDrinkIds =
        widget.controller.offerDetails['free_drinks_list'] as List<dynamic>? ??
            [];
    final selectedQuantity =
        widget.controller.offerDetails['free_drinks_quantity'] as int? ?? 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Free Drinks',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: _showDrinkSelectionDialog,
              icon: const Icon(Icons.local_drink, size: 18),
              label: Text(
                'Select Drinks',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.primaryColor,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ],
        ),
        if (selectedDrinkIds.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$selectedQuantity ${selectedQuantity == 1 ? "drink" : "drinks"} selected: ${selectedDrinkIds.length} ${selectedDrinkIds.length == 1 ? "option" : "options"}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSpecialDeliverySelector() {
    final deliveryType =
        widget.controller.offerDetails['delivery_type'] as String? ?? 'free';
    final deliveryValue =
        widget.controller.offerDetails['delivery_value'] as double? ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Special Delivery',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 10),
        // Delivery type selector
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildDeliveryTypeChip(
                label: 'Free Delivery',
                value: 'free',
                icon: Icons.delivery_dining,
                isSelected: deliveryType == 'free',
              ),
              const SizedBox(width: 8),
              _buildDeliveryTypeChip(
                label: 'Fixed Discount',
                value: 'fixed',
                icon: Icons.attach_money,
                isSelected: deliveryType == 'fixed',
              ),
              const SizedBox(width: 8),
              _buildDeliveryTypeChip(
                label: 'Percentage Off',
                value: 'percentage',
                icon: Icons.percent,
                isSelected: deliveryType == 'percentage',
              ),
            ],
          ),
        ),
        // Show input field for fixed or percentage discount
        if (deliveryType == 'fixed' || deliveryType == 'percentage') ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: TextFormField(
              initialValue: deliveryValue > 0 ? deliveryValue.toString() : '',
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: deliveryType == 'fixed' ? 'e.g., 100' : 'e.g., 50',
                hintStyle: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[400],
                ),
                prefixIcon: Icon(
                  deliveryType == 'fixed' ? Icons.attach_money : Icons.percent,
                  color: widget.primaryColor,
                  size: 18,
                ),
                suffixText: deliveryType == 'fixed' ? 'DA' : '%',
                suffixStyle: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide:
                      BorderSide(color: widget.primaryColor, width: 1.5),
                ),
              ),
              style: GoogleFonts.poppins(fontSize: 12),
              onChanged: (value) {
                final numValue = double.tryParse(value);
                widget.controller
                    .setOfferDetail('delivery_value', numValue ?? 0.0);
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDeliveryTypeChip({
    required String label,
    required String value,
    required IconData icon,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () {
        widget.controller.setOfferDetail('delivery_type', value);
        // Clear value when switching types
        if (value == 'free') {
          widget.controller.setOfferDetail('delivery_value', 0.0);
        }
      },
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.grey[800] : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.grey[800]! : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : Colors.grey[700],
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Load drinks on-demand (same logic as special packs)
  Future<void> _showDrinkSelectionDialog() async {
    try {
      // Get current user
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        debugPrint('❌ LTO: User not authenticated');
        return;
      }

      // Get restaurant (use widget.restaurantId if available, otherwise fetch)
      String? restaurantId = widget.restaurantId;

      if (restaurantId == null) {
        // Fetch restaurant from database
        final restaurantResponse = await Supabase.instance.client
            .from('restaurants')
            .select('id')
            .eq('owner_id', currentUser.id)
            .maybeSingle();

        if (restaurantResponse == null) {
          debugPrint('❌ LTO: No restaurant found');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'No restaurant found. Please set up your restaurant first.',
                  style: GoogleFonts.poppins(),
                ),
                backgroundColor: Colors.orange[600],
              ),
            );
          }
          return;
        }
        restaurantId = restaurantResponse['id'] as String;
      }

      debugPrint('🔍 LTO: Loading drinks for restaurant: $restaurantId');

      // Fetch available drinks from menu (same query as special packs)
      final drinksResponse = await Supabase.instance.client
          .from('menu_items')
          .select('id, name, image, price')
          .eq('restaurant_id', restaurantId)
          .eq('is_available', true)
          .or('category.ilike.%drink%,category.ilike.%beverage%')
          .order('name');

      final drinks =
          (drinksResponse as List).map((d) => MenuItem.fromJson(d)).toList();

      debugPrint('✅ LTO: Loaded ${drinks.length} drinks');

      if (drinks.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'No drinks found in your menu. Add drinks first.',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.orange[600],
            ),
          );
        }
        return;
      }

      // Get current selection from offer_details
      final currentSelection = widget
              .controller.offerDetails['free_drinks_list'] as List<dynamic>? ??
          [];
      final currentQuantity =
          widget.controller.offerDetails['free_drinks_quantity'] as int? ?? 1;

      final initialSelection =
          currentSelection.map((id) => id.toString()).toList();

      // Show selection dialog with quantity
      if (!mounted) return;
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (BuildContext context) {
          return _LTOFreeDrinksSelectionDialog(
            drinks: drinks,
            initialSelection: initialSelection,
            initialQuantity: currentQuantity,
            primaryColor: widget.primaryColor,
          );
        },
      );

      if (result != null) {
        final drinkIds = result['drinkIds'] as List<String>;
        final quantity = result['quantity'] as int;
        widget.controller.setLTOFreeDrinks(drinkIds, quantity: quantity);
      }
    } catch (e) {
      debugPrint('❌ LTO: Error showing drink selection dialog: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error loading drinks. Please try again.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    }
  }
}

/// Helper class for offer type definition
class _OfferType {
  final String key;
  final String label;
  final IconData icon;
  final String description;

  const _OfferType({
    required this.key,
    required this.label,
    required this.icon,
    required this.description,
  });
}

/// Stateful dialog for selecting LTO free drinks with quantity
class _LTOFreeDrinksSelectionDialog extends StatefulWidget {
  final List<MenuItem> drinks;
  final List<String> initialSelection;
  final int initialQuantity;
  final Color primaryColor;

  const _LTOFreeDrinksSelectionDialog({
    required this.drinks,
    required this.initialSelection,
    required this.initialQuantity,
    required this.primaryColor,
  });

  @override
  State<_LTOFreeDrinksSelectionDialog> createState() =>
      _LTOFreeDrinksSelectionDialogState();
}

class _LTOFreeDrinksSelectionDialogState
    extends State<_LTOFreeDrinksSelectionDialog> {
  late List<String> selectedIds;
  late int quantity;

  @override
  void initState() {
    super.initState();
    selectedIds = List<String>.from(widget.initialSelection);
    quantity = widget.initialQuantity;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'Select Free Drinks',
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Quantity selector
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Max Free Drinks:',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: quantity > 1
                            ? () => setState(() => quantity--)
                            : null,
                        icon: const Icon(Icons.remove_circle_outline),
                        color: widget.primaryColor,
                      ),
                      Text(
                        quantity.toString(),
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        onPressed: quantity < 10
                            ? () => setState(() => quantity++)
                            : null,
                        icon: const Icon(Icons.add_circle_outline),
                        color: widget.primaryColor,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Instructions
            Text(
              'Select drinks to include with this offer (up to $quantity)',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            // Drinks list
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.drinks.length,
                itemBuilder: (context, index) {
                  final drink = widget.drinks[index];
                  final isSelected = selectedIds.contains(drink.id);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected
                            ? widget.primaryColor
                            : Colors.grey[300]!,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: CheckboxListTile(
                      value: isSelected,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            selectedIds.add(drink.id);
                          } else {
                            selectedIds.remove(drink.id);
                          }
                        });
                      },
                      activeColor: widget.primaryColor,
                      title: Text(
                        drink.name,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        '${drink.price.toStringAsFixed(0)} DA',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      secondary: drink.image.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                drink.image,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                // PERFORMANCE FIX: Add cacheWidth/cacheHeight for list items
                                // Prevents decoding full-size images which causes scroll jank
                                cacheWidth: 100, // 50dp * 2x for retina
                                cacheHeight: 100,
                                filterQuality: FilterQuality
                                    .low, // Faster decoding for thumbnails
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.local_drink,
                                      color: Colors.grey[400]),
                                ),
                              ),
                            )
                          : Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.local_drink,
                                  color: Colors.grey[400]),
                            ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: GoogleFonts.poppins(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop({
              'drinkIds': selectedIds,
              'quantity': quantity,
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: Text(
            'Save (${selectedIds.length} selected)',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
