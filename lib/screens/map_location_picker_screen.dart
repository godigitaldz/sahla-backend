import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/location_provider.dart';
import '../services/enhanced_location_service.dart';
import '../services/ios_location_service.dart';
import '../services/location_autocomplete_service.dart';
import '../services/map_location_permission_service.dart';
import '../widgets/home_screen/home_layout_helper.dart';

class MapLocationPickerScreen extends StatefulWidget {
  final Function(EnhancedLocationData)? onLocationSelected;
  final String? initialAddress;
  final double? initialLatitude;
  final double? initialLongitude;

  const MapLocationPickerScreen({
    super.key,
    this.onLocationSelected,
    this.initialAddress,
    this.initialLatitude,
    this.initialLongitude,
  });

  @override
  State<MapLocationPickerScreen> createState() =>
      _MapLocationPickerScreenState();
}

class _MapLocationPickerScreenState extends State<MapLocationPickerScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  EnhancedLocationData? _currentLocationData;
  bool _isLoading = true;
  bool _isMapReady = false;
  bool _isMapPreloading = false; // Add preloading state
  double _mapZoom = 15.0;
  final MapType _currentMapType = MapType.normal;
  bool _locationActivated = false; // Track if location was activated during session
  LatLng? _initialLocation; // Track initial location to detect changes
  bool _hasLocationChanged = false; // Track if location has been edited

  // Performance optimizations
  static const int _maxCacheSize = 50;
  static const Duration _preloadDelay = Duration(milliseconds: 100);

  final Set<Marker> _markers = {};

  // Address display and search
  final TextEditingController _addressController = TextEditingController();
  final FocusNode _addressFocusNode = FocusNode();
  final LocationAutocompleteService _autocompleteService = LocationAutocompleteService();

  // Search and prediction state
  List<LocationPrediction> _predictions = [];
  bool _isSearching = false;
  bool _showPredictions = false;
  bool _isUserTyping = false; // Track if user is typing vs map update

  // Performance optimizations
  Timer? _debounceTimer;
  Timer? _addressUpdateTimer;
  Timer? _addressTimeoutTimer;
  Timer? _searchDebounceTimer;
  final Map<String, EnhancedLocationData> _addressCache = {};
  bool _isUpdatingAddress = false;

  // Animation controllers for smooth transitions
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Default location (Biskra, Algeria)
  static const LatLng _defaultLocation = LatLng(34.8504, 5.7281);

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    // Start with full opacity if we have initial address
    if (widget.initialAddress != null && widget.initialAddress!.isNotEmpty) {
      _fadeController.value = 1.0;
    }

    // Initialize address controller with initial address
    if (widget.initialAddress != null && widget.initialAddress!.isNotEmpty) {
      _addressController.text = widget.initialAddress!;
    } else {
      // Set a placeholder to avoid empty white state
      _addressController.text = '';
    }

    // Add listener for search functionality
    _addressController.addListener(_onAddressTextChanged);
    _addressFocusNode.addListener(_onAddressFocusChanged);

    // Ensure loading state is properly initialized
    _isUpdatingAddress = false;

    // Add lifecycle observer to detect when user returns from settings
    WidgetsBinding.instance.addObserver(this);

    // Initialize location asynchronously to prevent blocking
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Add small delay to ensure UI is fully rendered
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _checkPermissionsAndInitialize();
        }
      });

      // Initialize map in background with delay
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) {
          _initializeMap();
        }
      });
    });
  }

  Future<void> _initializeMap() async {
    try {
      // Start preloading immediately
      if (mounted) {
        setState(() {
          _isMapPreloading = true;
        });
      }

      // Preload map tiles and initialize map state with minimal delay
      await Future.delayed(_preloadDelay);

      // Preload common map tiles in background
      _preloadMapTiles();

      // Add timeout to prevent infinite loading
      await Future.delayed(const Duration(seconds: 3));

      if (mounted) {
        setState(() {
          _isMapReady = true;
          _isMapPreloading = false;
        });
      }
    } catch (e) {
      debugPrint('Error initializing map: $e');
      if (mounted) {
        setState(() {
          _isMapReady = true; // Show map even if initialization fails
          _isMapPreloading = false;
        });
      }
    }
  }

  void _preloadMapTiles() {
    // Preload tiles for common zoom levels around current location
    if (_selectedLocation != null) {
      final zoomLevels = [14.0, 15.0, 16.0];

      for (final _ in zoomLevels) {
        // Preload tiles asynchronously without blocking UI
        Future.microtask(() {
          if (_mapController != null && mounted) {
            _mapController!.getVisibleRegion().then((bounds) {
              // Tiles are now cached for this region
            }).catchError((e) {
              // Ignore preload errors
            });
          }
        });
      }
    }
  }

  /// Check permissions and initialize location
  Future<void> _checkPermissionsAndInitialize() async {
    try {
      debugPrint('📍 MapLocationPicker: Checking permissions...');

      // Use iOS-specific service for better iPhone compatibility
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _checkIOSPermissionsAndInitialize();
      } else {
        await _checkGenericPermissionsAndInitialize();
      }
    } catch (e) {
      debugPrint('❌ MapLocationPicker: Error checking permissions: $e');
      // Proceed with initialization even if permission check fails
      await _initializeLocation();
    }
  }

  /// iOS-specific permission checking using native dialogs
  Future<void> _checkIOSPermissionsAndInitialize() async {
    try {
      debugPrint('🍎 MapLocationPicker: Checking iOS permissions...');

      final iosStatus = await IOSLocationService.checkIOSLocationStatus();

      if (!iosStatus.isReady) {
        debugPrint(
            '❌ MapLocationPicker: iOS permission not ready: ${iosStatus.message}');

        if (iosStatus.needsLocationServices) {
          // Show simple message and open settings
          if (mounted) {
            await IOSLocationService
                .showIOSLocationServicesMessageAndOpenSettings(
              context,
              message:
                  'Location Services are disabled. Please enable them in Settings.',
            );
          }
          // Proceed with default location
          await _initializeLocation();
          return;
        } else if (iosStatus.needsPermission) {
          // Request permission using native iOS dialog
          debugPrint(
              '🍎 MapLocationPicker: Requesting permission with native iOS dialog...');
          final permissionResult =
              await IOSLocationService.requestIOSLocationPermissionNative();

          if (permissionResult.isReady) {
            debugPrint('✅ MapLocationPicker: iOS permission granted');
            await _initializeLocation();
          } else if (permissionResult.needsSettings) {
            // Show simple message and open settings
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(permissionResult.message),
                  action: SnackBarAction(
                    label: 'Open Settings',
                    onPressed: () async {
                      await IOSLocationService.openIOSAppSettings();
                    },
                  ),
                ),
              );
            }
            // Proceed with default location
            await _initializeLocation();
          } else {
            // Proceed with default location
            await _initializeLocation();
          }
        } else if (iosStatus.needsSettings) {
          // Show simple message and open settings
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(iosStatus.message),
                action: SnackBarAction(
                  label: 'Open Settings',
                  onPressed: () async {
                    await IOSLocationService.openIOSAppSettings();
                  },
                ),
              ),
            );
          }
          // Proceed with default location
          await _initializeLocation();
        } else {
          // Proceed with default location
          await _initializeLocation();
        }
      } else {
        // Permission is ready, proceed with location initialization
        await _initializeLocation();
      }
    } catch (e) {
      debugPrint('❌ MapLocationPicker: Error checking iOS permissions: $e');
      // Proceed with initialization even if permission check fails
      await _initializeLocation();
    }
  }

  /// Generic permission checking for non-iOS platforms
  Future<void> _checkGenericPermissionsAndInitialize() async {
    try {
      debugPrint('📍 MapLocationPicker: Checking generic permissions...');

      final permissionResult = await MapLocationPermissionService
          .checkAndRequestLocationPermission();

      if (!permissionResult.granted) {
        debugPrint(
            '❌ MapLocationPicker: Permission not granted: ${permissionResult.message}');

        if (permissionResult.needsLocationServices) {
          // Show dialog to enable location services
          if (!mounted) return;
          final shouldOpenSettings =
              await MapLocationPermissionService.showLocationServicesDialog(
            context,
            title: 'Location Services Required',
            message: 'Please enable location services to use this feature.',
            onOpenSettings: () async {
              await MapLocationPermissionService.openLocationSettings();
            },
          );

          if (!shouldOpenSettings) {
            // User cancelled, proceed with default location
            await _initializeLocation();
            return;
          }
        } else if (permissionResult.needsPermission ||
            permissionResult.needsSettings) {
          // Show permission dialog
          if (!mounted) return;
          final shouldRequest =
              await MapLocationPermissionService.showPermissionDialog(
            context,
            title: 'Location Permission Required',
            message:
                'This feature requires location permission to work properly.',
            onRequestPermission: () async {
              // Try requesting permission again
              final retryResult = await MapLocationPermissionService
                  .checkAndRequestLocationPermission();
              if (retryResult.granted) {
                await _initializeLocation();
              }
            },
            onOpenSettings: () async {
              await MapLocationPermissionService.openAppSettings();
            },
          );

          if (!shouldRequest) {
            // User cancelled, proceed with default location
            await _initializeLocation();
            return;
          }
        }
      }

      // Proceed with location initialization
      await _initializeLocation();
    } catch (e) {
      debugPrint('❌ MapLocationPicker: Error checking generic permissions: $e');
      // Proceed with initialization even if permission check fails
      await _initializeLocation();
    }
  }

  Future<void> _initializeLocation() async {
    try {
      // Show loading state immediately
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }

      // Use microtask to prevent blocking the main thread
      await Future.microtask(() async {
        if (!mounted) return;

        try {
          final locationProvider =
              Provider.of<LocationProvider>(context, listen: false);

          // Use provided initial coordinates if available
          if (widget.initialLatitude != null &&
              widget.initialLongitude != null) {
            _selectedLocation = LatLng(
              widget.initialLatitude!,
              widget.initialLongitude!,
            );
            _initialLocation = _selectedLocation; // Store initial location
            _addMarker(_selectedLocation!);
            await _getAddressFromLocation(_selectedLocation!);
          }
          // Try to get current location if no initial coordinates provided
          else if (locationProvider.currentLocation != null) {
            _selectedLocation = LatLng(
              locationProvider.currentLocation!.latitude,
              locationProvider.currentLocation!.longitude,
            );
            _initialLocation = _selectedLocation; // Store initial location
            _addMarker(_selectedLocation!);
            await _getAddressFromLocation(_selectedLocation!);
          } else {
            // Use default location
            _selectedLocation = _defaultLocation;
            _initialLocation = _selectedLocation; // Store initial location
            _addMarker(_selectedLocation!);
            await _getAddressFromLocation(_selectedLocation!);
          }
        } catch (e) {
          debugPrint('Error in location initialization: $e');
          // Use default location as fallback
          _selectedLocation = _defaultLocation;
          _initialLocation = _selectedLocation; // Store initial location
          _addMarker(_selectedLocation!);
          await _getAddressFromLocation(_selectedLocation!);
        }
      });

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error in _initializeLocation: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          // Use default location as fallback
          _selectedLocation = _defaultLocation;
          _addMarker(_selectedLocation!);
        });
      }
    }
  }

  void _addMarker(LatLng position) {
    if (!mounted) return;

    setState(() {
      _markers.clear();

      // Add selected location marker with custom icon
      _markers.add(
        Marker(
          markerId: const MarkerId('selected_location'),
          position: position,
          draggable: true,
          onDragEnd: (newPosition) {
            _onLocationChanged(newPosition);
          },
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
              title: AppLocalizations.of(context)?.selectedLocation ??
                  'Selected Location',
              snippet: _currentLocationData?.displayAddress ??
                  (AppLocalizations.of(context)?.tapToSelectLocation ??
                      'Tap to select location')),
        ),
      );

    });
  }

  void _onLocationChanged(LatLng newLocation) {
    // Debounce rapid location changes (reduced from 200ms to 100ms for faster updates)
    _addressUpdateTimer?.cancel();
    _addressUpdateTimer = Timer(const Duration(milliseconds: 100), () {
      if (!mounted) return;

      // Only update if user is not typing
      if (!_isUserTyping) {
        // Check if location has changed from initial
        if (_initialLocation != null) {
          final distance = _calculateDistance(
            _initialLocation!.latitude,
            _initialLocation!.longitude,
            newLocation.latitude,
            newLocation.longitude,
          );
          // Mark as changed if moved more than 50 meters
          if (distance > 0.05) {
            _hasLocationChanged = true;
          }
        }

        setState(() {
          _selectedLocation = newLocation;
        });
        _getAddressFromLocation(newLocation);
      }
    });
  }

  /// Calculate distance between two coordinates in kilometers
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = (dLat / 2) * (dLat / 2) +
        _toRadians(lat1) * _toRadians(lat2) *
        (dLon / 2) * (dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  /// Convert degrees to radians
  double _toRadians(double degrees) {
    return degrees * (3.141592653589793 / 180);
  }

  /// Handle address text changes for search
  void _onAddressTextChanged() {
    if (!mounted) return;

    final query = _addressController.text;

    // If user is typing and query is not empty, search for predictions
    if (_isUserTyping && query.trim().isNotEmpty) {
      _searchDebounceTimer?.cancel();
      _searchDebounceTimer = Timer(const Duration(milliseconds: 250), () {
        if (mounted && _isUserTyping) {
          _performSearch(query);
        }
      });
    } else if (query.trim().isEmpty) {
      // Clear predictions when query is empty
      setState(() {
        _predictions = [];
        _showPredictions = false;
        _isSearching = false;
      });
    }
  }

  /// Handle address focus changes
  void _onAddressFocusChanged() {
    if (!mounted) return;

    setState(() {
      if (!_addressFocusNode.hasFocus) {
        // Close predictions when focus is lost
        _showPredictions = false;
      } else {
        // Show predictions when focused and there are results or searching
        _showPredictions = _predictions.isNotEmpty || _isSearching;
      }
    });
  }

  /// Perform search for predictions
  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _predictions = [];
        _isSearching = false;
        _showPredictions = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _showPredictions = true;
    });

    try {
      // Get current location for bias if available
      double? latitude;
      double? longitude;

      if (_selectedLocation != null) {
        latitude = _selectedLocation!.latitude;
        longitude = _selectedLocation!.longitude;
      } else {
        // Try to get from location provider
        final locationProvider = Provider.of<LocationProvider>(context, listen: false);
        if (locationProvider.currentLocation != null) {
          latitude = locationProvider.currentLocation!.latitude;
          longitude = locationProvider.currentLocation!.longitude;
        }
      }

      final predictions = await _autocompleteService.debouncedSearch(
        query,
        latitude: latitude,
        longitude: longitude,
        useNominatim: true, // Use Nominatim (OpenStreetMap) as primary source
      );

      if (mounted && _isUserTyping) {
        setState(() {
          _predictions = predictions;
          _isSearching = false;
          _showPredictions = _addressFocusNode.hasFocus && predictions.isNotEmpty;
        });
      }
    } catch (e) {
      debugPrint('❌ Search error: $e');
      if (mounted) {
        setState(() {
          _predictions = [];
          _isSearching = false;
          _showPredictions = false;
        });
      }
    }
  }

  /// Handle prediction selection
  Future<void> _onPredictionSelected(LocationPrediction prediction) async {
    if (!mounted) return;

    setState(() {
      _isUserTyping = false;
      _showPredictions = false;
      _predictions = [];
      _addressController.text = prediction.description;
    });

    _addressFocusNode.unfocus();

    try {
      // Get place details to get coordinates
      PlaceDetails? placeDetails;

      if (prediction.latitude != null && prediction.longitude != null) {
        // Use coordinates directly if available (Nominatim)
        final location = LatLng(prediction.latitude!, prediction.longitude!);
        await _updateLocationFromPrediction(location, prediction.description);
      } else {
        // Get place details from API (try Nominatim first, fallback to Google Places)
        placeDetails = await _autocompleteService.getPlaceDetails(
          prediction.placeId,
          useNominatim: true, // Use Nominatim as primary source
        );

        if (placeDetails != null && mounted) {
          final location = LatLng(placeDetails.latitude, placeDetails.longitude);
          await _updateLocationFromPrediction(location, placeDetails.formattedAddress);
        } else {
          // Fallback: try to geocode the description using EnhancedLocationService
          debugPrint('⚠️ Place details not available, geocoding description: ${prediction.description}');
          await _geocodeAndUpdateLocation(prediction.description);
        }
      }
    } catch (e) {
      debugPrint('❌ Error selecting prediction: $e');
      // Fallback: try to geocode the description
      await _geocodeAndUpdateLocation(prediction.description);
    }
  }

  /// Update location from prediction
  Future<void> _updateLocationFromPrediction(LatLng location, String address) async {
    if (!mounted) return;

    // Check if location has changed from initial
    if (_initialLocation != null) {
      final distance = _calculateDistance(
        _initialLocation!.latitude,
        _initialLocation!.longitude,
        location.latitude,
        location.longitude,
      );
      // Mark as changed if moved more than 50 meters
      if (distance > 0.05) {
        _hasLocationChanged = true;
      }
    }

    setState(() {
      _selectedLocation = location;
      _isUserTyping = false;
    });

    // Update marker
    _addMarker(location);

    // Animate camera to location
    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(location, _mapZoom),
    );

    // Get enhanced address information
    await _getAddressFromLocation(location);
  }

  /// Geocode address and update location
  Future<void> _geocodeAndUpdateLocation(String address) async {
    try {
      final enhancedService = EnhancedLocationService();
      final results = await enhancedService.forwardGeocode(address);

      if (results.isNotEmpty && mounted) {
        final location = LatLng(
          results.first.latitude,
          results.first.longitude,
        );
        await _updateLocationFromPrediction(location, address);
      }
    } catch (e) {
      debugPrint('❌ Geocoding error: $e');
    }
  }

  /// Build predictions list widget
  Widget _buildPredictionsList() {
    final l10n = AppLocalizations.of(context);
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);

    // Check if current location is available
    final hasPermission = locationProvider.hasPermission;
    final isLocationEnabled = locationProvider.isLocationEnabled;
    final showCurrentLocation = hasPermission && isLocationEnabled;

    // Combine current location option with predictions
    final List<Widget> items = [];

    // Add "Current Location" as first option if permissions granted
    if (showCurrentLocation) {
      items.add(
        _buildPredictionItem(
          icon: Icons.my_location,
          mainText: l10n?.getCurrentLocation ?? 'Current Location',
          secondaryText: l10n?.useYourCurrentLocation ?? 'Use your current location',
          onTap: () async {
            setState(() {
              _isUserTyping = false;
              _showPredictions = false;
              _predictions = [];
            });
            _addressFocusNode.unfocus();
            await _selectCurrentLocation();
          },
          isCurrentLocation: true,
        ),
      );
    }

    // Add loading indicator if searching
    if (_isSearching && _predictions.isEmpty) {
      items.add(
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[600]!),
            ),
          ),
        ),
      );
    } else if (_predictions.isEmpty && !_isSearching) {
      // Show empty state
      items.add(
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            l10n?.noResultsFound ?? 'No results found',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    } else {
      // Add predictions
      for (int i = 0; i < _predictions.length; i++) {
        final prediction = _predictions[i];
        items.add(
          _buildPredictionItem(
            icon: Icons.location_on,
            mainText: prediction.mainText ?? prediction.description,
            secondaryText: prediction.secondaryText,
            onTap: () => _onPredictionSelected(prediction),
            isCurrentLocation: false,
          ),
        );

        // Add divider between items (except last)
        if (i < _predictions.length - 1) {
          items.add(
            Divider(
              height: 1,
              thickness: 1,
              color: Colors.grey[200],
              indent: 48,
            ),
          );
        }
      }
    }

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: items,
    );
  }

  /// Build individual prediction item
  Widget _buildPredictionItem({
    required IconData icon,
    required String mainText,
    String? secondaryText,
    required VoidCallback onTap,
    required bool isCurrentLocation,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              color: isCurrentLocation ? const Color(0xFFd47b00) : Colors.grey[600],
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mainText,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (secondaryText != null && secondaryText.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      secondaryText,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Optimized address lookup with caching and debouncing
  Future<void> _getAddressFromLocation(LatLng location) async {
    // Prevent duplicate requests
    if (_isUpdatingAddress) return;

    // Don't update address if user is typing
    if (_isUserTyping) return;

    // Check cache first with higher precision (6 decimal places = ~0.1m accuracy)
    final cacheKey =
        '${location.latitude.toStringAsFixed(6)},${location.longitude.toStringAsFixed(6)}';

    // Check if we have a cached result for this exact location
    if (_addressCache.containsKey(cacheKey)) {
      final cachedData = _addressCache[cacheKey]!;
      if (!_isUserTyping && mounted) {
        setState(() {
          _currentLocationData = cachedData;
          _addressController.text = cachedData.displayAddress;
          _isUpdatingAddress = false;
        });
        // Ensure fade animation is visible for cached data
        if (_fadeController.value < 1.0) {
          await _fadeController.forward();
        }
      }
      return;
    }

    // Check if we moved significantly from last cached location
    // If moved more than ~100m, force a refresh even if cache exists
    if (_currentLocationData != null) {
      final distance = _calculateDistance(
        _currentLocationData!.latitude,
        _currentLocationData!.longitude,
        location.latitude,
        location.longitude,
      );
      // If moved less than 100m, use cached address but still update location
      if (distance < 0.1) {
        // Still update the location but keep the address
        if (!_isUserTyping && mounted) {
          setState(() {
            _selectedLocation = location;
            _isUpdatingAddress = false;
          });
        }
        return;
      }
    }

    // Limit cache size to prevent memory issues
    if (_addressCache.length >= _maxCacheSize) {
      final oldestKey = _addressCache.keys.first;
      _addressCache.remove(oldestKey);
    }

    // Debounce rapid location changes (reduced from 200ms to 150ms for faster updates)
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 150), () async {
      if (!mounted) return;

      setState(() {
        _isUpdatingAddress = true;
      });

      // Set a timeout to reset the loading state if it takes too long
      _addressTimeoutTimer?.cancel();
      _addressTimeoutTimer = Timer(const Duration(seconds: 8), () {
        if (mounted && _isUpdatingAddress) {
          setState(() {
            _isUpdatingAddress = false;
            _addressController.text =
                '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}';
          });
          debugPrint('Address fetch timeout - showing coordinates');
        }
      });

      try {
        // Use Nominatim for reverse geocoding
        debugPrint('🌐 Reverse geocoding with Nominatim: ${location.latitude}, ${location.longitude}');
        final nominatimData = await _autocompleteService
            .reverseGeocode(location.latitude, location.longitude)
            .timeout(const Duration(seconds: 5));

        EnhancedLocationData locationData;

        if (nominatimData != null) {
          // Parse Nominatim response
          final address = nominatimData['address'] as Map<String, dynamic>?;
          final displayName = nominatimData['display_name'] as String? ?? '';

          // Extract address components
          String? streetNumber;
          String? route;
          String? locality;
          String? administrativeArea;
          String? country;
          String? postalCode;
          String? neighborhood;

          if (address != null) {
            streetNumber = address['house_number'] as String?;
            route = address['road'] as String? ?? address['street'] as String?;
            locality = address['city'] as String? ??
                       address['town'] as String? ??
                       address['village'] as String?;
            administrativeArea = address['state'] as String? ??
                                address['region'] as String?;
            country = address['country'] as String?;
            postalCode = address['postcode'] as String?;
            neighborhood = address['suburb'] as String? ??
                           address['neighbourhood'] as String?;
          }

          // Build formatted address
          String formattedAddress = displayName;
          if (formattedAddress.isEmpty && route != null && locality != null) {
            formattedAddress = '$route, $locality';
          } else if (formattedAddress.isEmpty && locality != null) {
            formattedAddress = locality;
          }

          locationData = EnhancedLocationData(
            latitude: location.latitude,
            longitude: location.longitude,
            formattedAddress: formattedAddress.isNotEmpty ? formattedAddress : null,
            streetNumber: streetNumber,
            route: route,
            locality: locality,
            administrativeArea: administrativeArea,
            country: country,
            postalCode: postalCode,
            neighborhood: neighborhood,
            timestamp: DateTime.now(),
          );
        } else {
          // Fallback to EnhancedLocationService if Nominatim fails
          debugPrint('⚠️ Nominatim reverse geocode failed, trying Google Maps API as fallback');
          final enhancedLocationService = EnhancedLocationService();
          locationData = await enhancedLocationService
              .reverseGeocode(
                location.latitude,
                location.longitude,
              )
              .timeout(const Duration(seconds: 5));
        }

        // Cache the result
        _addressCache[cacheKey] = locationData;

        // Only update if this is still the latest request and widget is mounted
        // and user is not typing
        if (mounted && !_isUserTyping) {
          _addressTimeoutTimer
              ?.cancel(); // Cancel timeout since we got the result
          setState(() {
            _currentLocationData = locationData;
            _addressController.text = locationData.displayAddress;
            _isUpdatingAddress = false;
          });

          // Start fade animation
          await _fadeController.forward();
        }
      } catch (e) {
        debugPrint('Failed to get address: $e');
        if (mounted) {
          _addressTimeoutTimer
              ?.cancel(); // Cancel timeout since we handled the error
          setState(() {
            _isUpdatingAddress = false;
            // Show coordinates as fallback
            _addressController.text =
                '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}';
          });
          await _fadeController.forward();
        }
      }
    });
  }

  Future<void> _selectCurrentLocation() async {
    try {
      debugPrint('📍 MapLocationPicker: Selecting current location...');

      // Use iOS-specific service for better iPhone compatibility
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _selectCurrentLocationIOS();
      } else {
        await _selectCurrentLocationGeneric();
      }
    } catch (e) {
      debugPrint('❌ MapLocationPicker: Error selecting current location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${AppLocalizations.of(context)?.failedToGetCurrentLocation ?? 'Failed to get current location'}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// iOS-specific current location selection using native dialogs
  Future<void> _selectCurrentLocationIOS() async {
    try {
      debugPrint('🍎 MapLocationPicker: Selecting current location on iOS...');

      final iosStatus = await IOSLocationService.checkIOSLocationStatus();

      if (!iosStatus.isReady) {
        debugPrint(
            '❌ MapLocationPicker: iOS permission not ready: ${iosStatus.message}');

        if (iosStatus.needsLocationServices) {
          // Show simple message and open settings
          if (!mounted) return;
          await IOSLocationService
              .showIOSLocationServicesMessageAndOpenSettings(
            context,
            message:
                'Location Services are disabled. Please enable them in Settings.',
          );
          return;
        } else if (iosStatus.needsPermission) {
          // Request permission using native iOS dialog
          debugPrint(
              '🍎 MapLocationPicker: Requesting permission with native iOS dialog...');
          final permissionResult =
              await IOSLocationService.requestIOSLocationPermissionNative();

          if (permissionResult.isReady) {
            debugPrint('✅ MapLocationPicker: iOS permission granted');
            await _getCurrentLocationAndUpdateMap();
          } else if (permissionResult.needsSettings) {
            // Show simple message and open settings
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(permissionResult.message),
                  action: SnackBarAction(
                    label: 'Open Settings',
                    onPressed: () async {
                      await IOSLocationService.openIOSAppSettings();
                    },
                  ),
                ),
              );
            }
          }
          return;
        } else if (iosStatus.needsSettings) {
          // Show simple message and open settings
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(iosStatus.message),
                action: SnackBarAction(
                  label: 'Open Settings',
                  onPressed: () async {
                    await IOSLocationService.openIOSAppSettings();
                  },
                ),
              ),
            );
          }
          return;
        }

        return;
      }

      // Permission granted, get current location
      await _getCurrentLocationAndUpdateMap();
    } catch (e) {
      debugPrint(
          '❌ MapLocationPicker: Error selecting current location on iOS: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${AppLocalizations.of(context)?.failedToGetCurrentLocation ?? 'Failed to get current location'}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Generic current location selection for non-iOS platforms
  Future<void> _selectCurrentLocationGeneric() async {
    try {
      debugPrint(
          '📍 MapLocationPicker: Selecting current location on generic platform...');

      // Check permissions using the generic service
      final permissionResult = await MapLocationPermissionService
          .checkAndRequestLocationPermission();

      if (!permissionResult.granted) {
        debugPrint(
            '❌ MapLocationPicker: Permission not granted: ${permissionResult.message}');

        if (permissionResult.needsLocationServices) {
          // Show dialog to enable location services
          if (!mounted) return;
          final shouldOpenSettings =
              await MapLocationPermissionService.showLocationServicesDialog(
            context,
            title: 'Location Services Required',
            message:
                'Please enable location services to get your current location.',
            onOpenSettings: () async {
              await MapLocationPermissionService.openLocationSettings();
            },
          );

          if (!shouldOpenSettings) {
            return; // User cancelled
          }
        } else if (permissionResult.needsPermission ||
            permissionResult.needsSettings) {
          // Show permission dialog
          if (!mounted) return;
          final shouldRequest =
              await MapLocationPermissionService.showPermissionDialog(
            context,
            title: 'Location Permission Required',
            message:
                'This feature requires location permission to get your current location.',
            onRequestPermission: () async {
              // Try requesting permission again
              final retryResult = await MapLocationPermissionService
                  .checkAndRequestLocationPermission();
              if (retryResult.granted) {
                await _getCurrentLocationAndUpdateMap();
              }
            },
            onOpenSettings: () async {
              await MapLocationPermissionService.openAppSettings();
            },
          );

          if (!shouldRequest) {
            return; // User cancelled
          }
        }

        return;
      }

      // Permission granted, get current location
      await _getCurrentLocationAndUpdateMap();
    } catch (e) {
      debugPrint(
          '❌ MapLocationPicker: Error selecting current location on generic platform: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${AppLocalizations.of(context)?.failedToGetCurrentLocation ?? 'Failed to get current location'}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Get current location and update map
  Future<void> _getCurrentLocationAndUpdateMap() async {
    try {
      final locationProvider =
          Provider.of<LocationProvider>(context, listen: false);
      final success = await locationProvider.getCurrentLocationWithAddress();

      if (success && locationProvider.currentLocation != null) {
        final location = LatLng(
          locationProvider.currentLocation!.latitude,
          locationProvider.currentLocation!.longitude,
        );

        _selectedLocation = location;
        _addMarker(location);
        await _getAddressFromLocation(location);

        // Animate camera to current location
        await _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(location, _mapZoom),
        );

        debugPrint(
            '✅ MapLocationPicker: Current location updated successfully');
      } else {
        debugPrint('❌ MapLocationPicker: Failed to get current location');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  AppLocalizations.of(context)?.failedToGetCurrentLocation ??
                      'Failed to get current location'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ MapLocationPicker: Error getting current location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${AppLocalizations.of(context)?.failedToGetCurrentLocation ?? 'Failed to get current location'}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _confirmLocation() {
    if (_selectedLocation != null && _currentLocationData != null) {
      if (widget.onLocationSelected != null) {
        // Use callback pattern
        widget.onLocationSelected!(_currentLocationData!);
        Navigator.of(context).pop();
      } else {
        // Return result pattern
        Navigator.of(context).pop({
          'latitude': _selectedLocation!.latitude,
          'longitude': _selectedLocation!.longitude,
          'address': _currentLocationData!.displayAddress,
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)?.pleaseSelectLocation ??
              'Please select a location on the map'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

      return PopScope(
        canPop: !_locationActivated && !_hasLocationChanged, // Allow pop if location wasn't changed
        onPopInvokedWithResult: (bool didPop, dynamic result) async {
          if (didPop) return;
          // If location was activated or changed, show confirmation dialog
          if (_locationActivated || _hasLocationChanged) {
            await _handleBackButton();
          }
        },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
        children: [
          // Main content
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFd47b00)),
              ),
            )
          else
            _isMapReady
                ? GoogleMap(
                    onMapCreated: (c) {
                      try {
                        // Initialize map controller asynchronously
                        Future.microtask(() {
                          if (mounted) {
                            _mapController = c;
                            // Animate to selected location if available
                            if (_selectedLocation != null) {
                              _mapController?.animateCamera(
                                  CameraUpdate.newLatLngZoom(
                                      _selectedLocation!, _mapZoom));
                            }
                          }
                        });
                      } catch (e) {
                        debugPrint('Error in onMapCreated: $e');
                      }
                    },
                    initialCameraPosition: CameraPosition(
                      target: _selectedLocation ?? _defaultLocation,
                      zoom: _mapZoom,
                    ),
                    onTap: (LatLng position) {
                      try {
                        // Close predictions when tapping on map
                        if (_showPredictions) {
                          setState(() {
                            _showPredictions = false;
                          });
                          _addressFocusNode.unfocus();
                        }

                        // Handle tap asynchronously to prevent blocking
                        Future.microtask(() {
                          if (mounted) {
                            // Check if location has changed from initial
                            if (_initialLocation != null) {
                              final distance = _calculateDistance(
                                _initialLocation!.latitude,
                                _initialLocation!.longitude,
                                position.latitude,
                                position.longitude,
                              );
                              // Mark as changed if moved more than 50 meters
                              if (distance > 0.05) {
                                _hasLocationChanged = true;
                              }
                            }

                            _selectedLocation = position;
                            _addMarker(position);
                            _getAddressFromLocation(position);
                            _mapController?.animateCamera(
                                CameraUpdate.newLatLngZoom(position, _mapZoom));
                          }
                        });
                      } catch (e) {
                        debugPrint('Error in onTap: $e');
                      }
                    },
                    markers: _markers,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: true,
                    mapType: _currentMapType,
                    onCameraMove: (CameraPosition position) {
                      try {
                        if (mounted) {
                          _mapZoom = position.zoom;
                          // Update selected location as camera moves
                          if (!_isUserTyping) {
                            _selectedLocation = position.target;
                            _addMarker(position.target);
                          }
                        }
                      } catch (e) {
                        debugPrint('Error in onCameraMove: $e');
                      }
                    },
                    onCameraIdle: () {
                      // Update address when camera stops moving
                      if (!_isUserTyping && _selectedLocation != null) {
                        // Check if location has changed from initial
                        if (_initialLocation != null) {
                          final distance = _calculateDistance(
                            _initialLocation!.latitude,
                            _initialLocation!.longitude,
                            _selectedLocation!.latitude,
                            _selectedLocation!.longitude,
                          );
                          // Mark as changed if moved more than 50 meters
                          if (distance > 0.05) {
                            _hasLocationChanged = true;
                          }
                        }
                        _getAddressFromLocation(_selectedLocation!);
                      }
                    },
                    buildingsEnabled: false, // Disabled for performance
                    trafficEnabled: false,
                    compassEnabled: true,
                    rotateGesturesEnabled: true,
                    scrollGesturesEnabled: true,
                    tiltGesturesEnabled: false, // Disabled for performance
                    zoomGesturesEnabled: true,
                  )
                : Container(
                    color: Colors.grey[100],
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isMapPreloading) ...[
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.orange.shade600),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Preloading map...',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ] else ...[
                            Icon(
                              Icons.map_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Map loading failed',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Please check your internet connection',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _isMapReady = false;
                                  _isMapPreloading = true;
                                });
                                _initializeMap();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange.shade600,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Retry'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

          // Header with address display and back arrow
          Positioned(
            top: HomeLayoutHelper.getHeaderTopPosition(context),
            left: 16,
            right: 16,
            child: RepaintBoundary(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Back button
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black),
                      onPressed: () => _handleBackButton(),
                    ),
                    // Address display (read-only)
                    Expanded(
                      child: _isUpdatingAddress
                          ? Row(
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.grey[600]!),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    l10n?.gettingAddress ??
                                        'Getting address...',
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : FadeTransition(
                              opacity: _fadeAnimation,
                              child: TextField(
                                controller: _addressController,
                                focusNode: _addressFocusNode,
                                readOnly: false,
                                onTap: () {
                                  setState(() {
                                    _isUserTyping = true;
                                  });
                                },
                                onChanged: (value) {
                                  setState(() {
                                    _isUserTyping = true;
                                  });
                                },
                                decoration: InputDecoration(
                                  hintText: l10n?.selectLocationOnMap ??
                                      'Search for a location',
                                  hintStyle: GoogleFonts.inter(
                                    color: Colors.grey[500],
                                    fontSize: 16,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  suffixIcon: _isSearching
                                      ? SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: Padding(
                                            padding: const EdgeInsets.all(12.0),
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      Colors.grey[600]!),
                                            ),
                                          ),
                                        )
                                      : _addressController.text.isNotEmpty
                                          ? IconButton(
                                              icon: const Icon(
                                                Icons.clear,
                                                color: Colors.grey,
                                                size: 20,
                                              ),
                                              onPressed: () {
                                                setState(() {
                                                  _addressController.clear();
                                                  _isUserTyping = false;
                                                  _predictions = [];
                                                  _showPredictions = false;
                                                });
                                                _addressFocusNode.unfocus();
                                              },
                                            )
                                          : IconButton(
                                              icon: const Icon(
                                                Icons.search,
                                                color: Colors.grey,
                                                size: 20,
                                              ),
                                              onPressed: null,
                                            ),
                                ),
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
                ),
              ),
            ),

          // Prediction dropdown overlay
          if (_showPredictions)
            Positioned(
              top: MediaQuery.of(context).padding.top + 80, // Below header
              left: 16,
              right: 16,
              child: GestureDetector(
                onTap: () {
                  // Prevent tap from propagating to map
                },
                child: RepaintBoundary(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    constraints: const BoxConstraints(
                      maxHeight: 300,
                    ),
                    child: _buildPredictionsList(),
                  ),
                ),
              ),
            ),

          // Floating get location button (bottom right)
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom * 0.6 +
                100, // 40% reduction
            right: 16,
            child: RepaintBoundary(
              child: FloatingActionButton(
                heroTag: 'location_picker_get_location_fab',
                onPressed: _selectCurrentLocation,
                backgroundColor: const Color(0xFFd47b00), // Orange 600
                foregroundColor: Colors.white,
                elevation: 4,
                tooltip: l10n?.getCurrentLocation ?? 'Get current location',
                child: const Icon(Icons.my_location),
              ),
            ),
          ),

          // Floating confirm location button (bottom center)
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom * 0.6 +
                20, // 40% reduction
            left: 20,
            right: 20,
            child: RepaintBoundary(
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _confirmLocation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFd47b00), // Orange 600
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25), // Full rounded
                    ),
                    elevation: 8,
                    shadowColor: Colors.black.withValues(alpha: 0.25),
                  ),
                  child: Text(
                    l10n?.confirmLocation ?? 'Confirm Location',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  /// Handle back button press - show confirmation if location was activated
  Future<void> _handleBackButton() async {
    if (!_locationActivated && !_hasLocationChanged) {
      // No location activated or changed, just go back
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    // Show confirmation dialog
    final l10n = AppLocalizations.of(context);
    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            l10n?.proceedOrDiscard ?? 'Proceed or Discard?',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          content: Text(
            _locationActivated
                ? (l10n?.proceedOrDiscardMessage ?? 'You have activated location services. Do you want to proceed with the selected location or discard the changes?')
                : (l10n?.locationEditedMessage ?? 'You have edited the location. Do you want to proceed with the selected location or discard the changes?'),
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false), // Discard
              child: Text(
                l10n?.discard ?? 'Discard',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.red[600],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true), // Proceed
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[600],
                foregroundColor: Colors.white,
              ),
              child: Text(
                l10n?.proceed ?? 'Proceed',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldProceed == true && mounted) {
      // Proceed - confirm location and return result
      _confirmLocation();
    } else if (shouldProceed == false && mounted) {
      // Discard - just go back without confirming
      Navigator.of(context).pop();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // When app resumes, check if location services are now enabled
    if (state == AppLifecycleState.resumed) {
      _checkLocationAndRefresh();
    }
  }

  /// Check if location is enabled and refresh map to current location
  Future<void> _checkLocationAndRefresh() async {
    try {
      // Check if location services are enabled
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);
      await locationProvider.checkLocationStatus();

      // If location is enabled and we have permission, refresh map to current location
      if (locationProvider.isLocationEnabled && locationProvider.hasPermission) {
        debugPrint('📍 MapLocationPicker: Location activated, refreshing map to current location');
        setState(() {
          _locationActivated = true; // Mark that location was activated
        });
        await _getCurrentLocationAndUpdateMap();
      }
    } catch (e) {
      debugPrint('❌ MapLocationPicker: Error checking location status: $e');
    }
  }

  @override
  void dispose() {
    // Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);

    // Clean up performance optimizations
    _debounceTimer?.cancel();
    _addressUpdateTimer?.cancel();
    _addressTimeoutTimer?.cancel();
    _searchDebounceTimer?.cancel();
    _fadeController.dispose();

    // Clean up controllers
    _mapController?.dispose();
    _addressController.removeListener(_onAddressTextChanged);
    _addressController.dispose();
    _addressFocusNode.removeListener(_onAddressFocusChanged);
    _addressFocusNode.dispose();

    // Clean up autocomplete service
    _autocompleteService.dispose();

    // Clear cache
    _addressCache.clear();

    super.dispose();
  }
}
