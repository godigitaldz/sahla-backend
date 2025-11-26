import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../cart_provider.dart';
import '../../l10n/app_localizations.dart';
import '../../models/menu_item.dart';
import '../../models/restaurant.dart';
import '../../services/menu_item_image_service.dart';
import '../../utils/price_formatter.dart';

/// Drinks section widget - displays available drinks from the restaurant
class DrinksSection extends StatefulWidget {
  const DrinksSection({
    required this.drinks,
    required this.restaurant,
    required this.isLoading,
    required this.onItemAddedToCart,
    super.key,
  });

  final List<MenuItem> drinks;
  final Restaurant restaurant;
  final bool isLoading;
  final VoidCallback onItemAddedToCart;

  @override
  State<DrinksSection> createState() => _DrinksSectionState();
}

class _DrinksSectionState extends State<DrinksSection> {
  final Map<String, String> _drinkImageCache = {};
  // PERFORMANCE: Use ValueNotifier to avoid setState rebuilds during scroll
  final Map<String, ValueNotifier<int>> _drinkQuantityNotifiers = {};
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _loadDrinkImageCache();
  }

  @override
  void dispose() {
    // PERFORMANCE: Dispose all ValueNotifiers to prevent memory leaks
    for (final notifier in _drinkQuantityNotifiers.values) {
      notifier.dispose();
    }
    _drinkQuantityNotifiers.clear();
    super.dispose();
  }

  // PERFORMANCE: Get or create ValueNotifier for a drink quantity
  ValueNotifier<int> _getQuantityNotifier(String drinkId) {
    if (!_drinkQuantityNotifiers.containsKey(drinkId)) {
      _drinkQuantityNotifiers[drinkId] = ValueNotifier<int>(0);
    }
    return _drinkQuantityNotifiers[drinkId]!;
  }

  void _incrementQuantity(String drinkId) {
    // PERFORMANCE: Update ValueNotifier directly, no setState needed
    final notifier = _getQuantityNotifier(drinkId);
    notifier.value = notifier.value + 1;
  }

  void _decrementQuantity(String drinkId) {
    // PERFORMANCE: Update ValueNotifier directly, no setState needed
    final notifier = _getQuantityNotifier(drinkId);
    final currentQty = notifier.value;
    if (currentQty > 0) {
      notifier.value = currentQty - 1;
    }
  }

  void _addDrinkToCart(BuildContext context, MenuItem drink, int quantity) {
    if (quantity <= 0) return;

    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    // Create cart item for the drink
    final cartItem = CartItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: drink.name,
      price: drink.price,
      quantity: quantity,
      image: drink.image,
      restaurantName: widget.restaurant.name,
      customizations: {
        'menu_item_id': drink.id,
        'restaurant_id': widget.restaurant.id.toString(),
      },
      drinkQuantities: {},
      specialInstructions: null,
    );

    // Add to cart
    cartProvider.addToCart(cartItem);

    // PERFORMANCE: Reset quantity using ValueNotifier, no setState needed
    final notifier = _getQuantityNotifier(drink.id);
    notifier.value = 0;

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context)!.addedToCart,
          style: GoogleFonts.poppins(),
        ),
        backgroundColor: Colors.green[600],
        duration: const Duration(seconds: 1),
      ),
    );

    // Trigger callback
    widget.onItemAddedToCart();
  }

  Future<void> _loadDrinkImageCache() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final cacheJson = _prefs!.getString('drink_image_cache');
      if (cacheJson != null && cacheJson.isNotEmpty) {
        final Map<String, dynamic> decoded = json.decode(cacheJson);
        if (mounted) {
          setState(() {
            _drinkImageCache
                .addAll(decoded.map((k, v) => MapEntry(k, v.toString())));
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading drink image cache: $e');
    }
  }

  Future<void> _saveDrinkImageCache() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final cacheJson = json.encode(_drinkImageCache);
      await _prefs!.setString('drink_image_cache', cacheJson);
    } catch (e) {
      debugPrint('❌ Error saving drink image cache: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Don't show section if loading or no drinks
    if (widget.isLoading) {
      return _buildLoadingState(context);
    }

    if (widget.drinks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: SizedBox(
        height: 167, // 132 (card) + 8 (spacing) + 27 (button 32*0.85) = 167
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(left: 16), // Safe area for first card
          // PERFORMANCE: Add itemExtent for O(1) layout calculations
          itemExtent: 118.0, // 108 (card width) + 10 (margin)
          itemCount: widget.drinks.length,
          itemBuilder: (context, index) {
            final drink = widget.drinks[index];
            // PERFORMANCE: Use ValueListenableBuilder to only rebuild this specific card
            return ValueListenableBuilder<int>(
              valueListenable: _getQuantityNotifier(drink.id),
              builder: (context, quantity, child) {
                return _buildDrinkCard(context, drink, quantity);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildDrinkCard(BuildContext context, MenuItem drink, int quantity) {
    // Get size from pricing_options (same as menu_item_full_popup.dart)
    String? drinkSize;
    if (drink.pricingOptions.isNotEmpty) {
      final firstOption = drink.pricingOptions[0];
      if (firstOption.containsKey('size')) {
        final sizeValue = firstOption['size']?.toString() ?? '';
        if (sizeValue.isNotEmpty) {
          drinkSize = sizeValue;
        }
      }
    }

    return Container(
      width: 108,
      margin: const EdgeInsets.only(right: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drink card
          Container(
            width: 108,
            height: 132,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  spreadRadius: 0,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  spreadRadius: 0,
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Background Image - fills entire card
                  _buildDrinkImage(drink),

                  // Gradient overlay for better text visibility
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.1),
                          Colors.black.withValues(alpha: 0.6),
                        ],
                      ),
                    ),
                  ),

                  // Content overlay
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Top row: Price (start) and Size (end) - RTL aware
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          textDirection: Directionality.of(context),
                          children: [
                            // Price chip (start side) (localized)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange[600],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '+ ${PriceFormatter.formatWithSettings(context, drink.price.toString())}',
                                style: GoogleFonts.poppins(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                                textDirection: Directionality.of(context),
                              ),
                            ),

                            // Size chip (end side)
                            if (drinkSize != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  drinkSize,
                                  style: GoogleFonts.poppins(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                  textDirection: Directionality.of(context),
                                ),
                              ),
                          ],
                        ),

                        // Quantity Selector at bottom
                        Container(
                          height: 24,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              // Decrease quantity
                              InkWell(
                                onTap: quantity > 0
                                    ? () => _decrementQuantity(drink.id)
                                    : null,
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.remove,
                                    size: 10,
                                    color: quantity > 0
                                        ? const Color(0xFFfc9d2d)
                                        : Colors.grey[400],
                                  ),
                                ),
                              ),

                              // Quantity display
                              Expanded(
                                child: Text(
                                  '$quantity',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF2E2E2E),
                                  ),
                                ),
                              ),

                              // Increase quantity
                              InkWell(
                                onTap: quantity < 10
                                    ? () => _incrementQuantity(drink.id)
                                    : null,
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.add,
                                    size: 10,
                                    color: quantity < 10
                                        ? const Color(0xFFfc9d2d)
                                        : Colors.grey[400],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Add button
          const SizedBox(height: 8),
          SizedBox(
            width: 92, // 108 * 0.85 = 91.8 ≈ 92 (reduced by 15%)
            height: 27, // 32 * 0.85 = 27.2 ≈ 27 (reduced by 15%)
            child: ElevatedButton(
              onPressed: quantity > 0
                  ? () => _addDrinkToCart(context, drink, quantity)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    quantity > 0 ? Colors.orange[600] : Colors.grey[400],
                foregroundColor: Colors.white,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100), // Full rounded
                ),
                elevation: quantity > 0 ? 2 : 0,
                disabledBackgroundColor: Colors.grey[400],
                disabledForegroundColor: Colors.white,
              ),
              child: Text(
                AppLocalizations.of(context)?.add ?? 'Add',
                style: GoogleFonts.poppins(
                  fontSize: 10, // Reduced from 12 to match smaller button
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrinkImage(MenuItem drink) {
    final supabase = Supabase.instance.client;

    // Check cache first for fast loading
    if (_drinkImageCache.containsKey(drink.id)) {
      final cachedFilename = _drinkImageCache[drink.id]!;
      if (cachedFilename == 'custom') {
        // Use custom image from drink.image
        return CachedNetworkImage(
          imageUrl: MenuItemImageService().ensureImageUrl(drink.image),
          fit: BoxFit.cover,
          // PERFORMANCE: Add cache dimensions for 108x132 card (2x = 216x264)
          memCacheWidth: 216,
          memCacheHeight: 264,
          filterQuality: FilterQuality.low,
          placeholder: (context, url) => _buildDrinkLoadingState(),
          errorWidget: (context, url, error) {
            // Cache was wrong, remove and try default
            _drinkImageCache.remove(drink.id);
            return _buildDefaultDrinkImage(drink, supabase);
          },
        );
      } else if (cachedFilename == 'none') {
        // Known to have no image, show placeholder immediately
        return _buildDrinkPlaceholder();
      } else {
        // Use cached filename from bucket
        final imageUrl =
            supabase.storage.from('drink_images').getPublicUrl(cachedFilename);
        return CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          // PERFORMANCE: Add cache dimensions for 108x132 card (2x = 216x264)
          memCacheWidth: 216,
          memCacheHeight: 264,
          filterQuality: FilterQuality.low,
          placeholder: (context, url) => _buildDrinkLoadingState(),
          errorWidget: (context, url, error) {
            // Cache was wrong, remove and try again
            _drinkImageCache.remove(drink.id);
            return _buildDefaultDrinkImage(drink, supabase);
          },
        );
      }
    }

    // If drink has custom image, try it first
    if (drink.image.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: MenuItemImageService().ensureImageUrl(drink.image),
        fit: BoxFit.cover,
        // PERFORMANCE: Add cache dimensions for 108x132 card (2x = 216x264)
        memCacheWidth: 216,
        memCacheHeight: 264,
        filterQuality: FilterQuality.low,
        placeholder: (context, url) => _buildDrinkLoadingState(),
        errorWidget: (context, url, error) {
          // Custom image failed, try default
          return _buildDefaultDrinkImage(drink, supabase);
        },
        imageBuilder: (context, imageProvider) {
          // Successfully loaded, cache it
          _drinkImageCache[drink.id] = 'custom';
          _saveDrinkImageCache();
          return Image(
            image: imageProvider,
            fit: BoxFit.cover,
          );
        },
      );
    }

    // No custom image, try default image from drink_images bucket
    return _buildDefaultDrinkImage(drink, supabase);
  }

  Widget _buildDrinkLoadingState() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      period: const Duration(milliseconds: 1200),
      child: Container(
        color: Colors.white,
      ),
    );
  }

  Widget _buildDrinkPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey[300]!,
            Colors.grey[200]!,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.local_drink,
          size: 45,
          color: Colors.grey[400],
        ),
      ),
    );
  }

  Widget _buildDefaultDrinkImage(MenuItem drink, SupabaseClient supabase) {
    // Create multiple filename variations for smart detection
    final baseName = drink.name.trim();

    // Remove special characters but keep spaces for processing
    final cleanName = baseName.replaceAll(RegExp(r'[^\w\s]'), '');

    // Generate filename variations
    final variations = [
      // Underscore versions
      cleanName.replaceAll(RegExp(r'\s+'), '_'), // Coca_Cola
      cleanName.toLowerCase().replaceAll(RegExp(r'\s+'), '_'), // coca_cola
      // Hyphen versions
      cleanName.replaceAll(RegExp(r'\s+'), '-'), // Coca-Cola
      cleanName.toLowerCase().replaceAll(RegExp(r'\s+'), '-'), // coca-cola
      // No separator versions
      cleanName.replaceAll(RegExp(r'\s+'), ''), // CocaCola
      cleanName.toLowerCase().replaceAll(RegExp(r'\s+'), ''), // cocacola
      // Original as-is (lowercase)
      cleanName.toLowerCase(), // coca cola
    ];

    // Remove duplicates while preserving order
    final uniqueVariations = <String>[];
    for (final v in variations) {
      if (!uniqueVariations.contains(v) && v.isNotEmpty) {
        uniqueVariations.add(v);
      }
    }

    // Try each variation with each extension
    return _tryImageVariations(supabase, uniqueVariations, 0, drink);
  }

  Widget _tryImageVariations(
    SupabaseClient supabase,
    List<String> variations,
    int variationIndex,
    MenuItem drink,
  ) {
    if (variationIndex >= variations.length) {
      // All variations exhausted, show placeholder and cache
      _drinkImageCache[drink.id] = 'none';
      _saveDrinkImageCache();
      return _buildDrinkPlaceholder();
    }

    final currentVariation = variations[variationIndex];

    // Try each extension for this variation
    return _tryImageExtensions(
      supabase,
      currentVariation,
      0,
      variations,
      variationIndex,
      drink,
    );
  }

  Widget _tryImageExtensions(
    SupabaseClient supabase,
    String variation,
    int extensionIndex,
    List<String> variations,
    int variationIndex,
    MenuItem drink,
  ) {
    const extensions = ['png', 'jpg', 'jpeg'];

    if (extensionIndex >= extensions.length) {
      // Try next variation
      return _tryImageVariations(
        supabase,
        variations,
        variationIndex + 1,
        drink,
      );
    }

    final filename = '$variation.${extensions[extensionIndex]}';
    final imageUrl =
        supabase.storage.from('drink_images').getPublicUrl(filename);

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      // PERFORMANCE: Add cache dimensions for 108x132 card (2x = 216x264)
      memCacheWidth: 216,
      memCacheHeight: 264,
      filterQuality: FilterQuality.low,
      placeholder: (context, url) => _buildDrinkLoadingState(),
      errorWidget: (context, url, error) {
        // This extension failed, try next
        return _tryImageExtensions(
          supabase,
          variation,
          extensionIndex + 1,
          variations,
          variationIndex,
          drink,
        );
      },
      imageBuilder: (context, imageProvider) {
        // Successfully loaded, cache the filename
        _drinkImageCache[drink.id] = filename;
        _saveDrinkImageCache();
        return Image(
          image: imageProvider,
          fit: BoxFit.cover,
        );
      },
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: SizedBox(
        height: 167, // 132 (card) + 8 (spacing) + 27 (button 32*0.85) = 167
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(left: 16), // Safe area for first card
          itemCount: 5,
          itemBuilder: (context, index) {
            return Container(
              width: 108,
              margin: const EdgeInsets.only(right: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 108,
                    height: 132,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 92, // 108 * 0.85 = 91.8 ≈ 92 (reduced by 15%)
                    height: 27, // 32 * 0.85 = 27.2 ≈ 27 (reduced by 15%)
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(100), // Full rounded
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
