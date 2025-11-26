import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/location_provider.dart';
import '../../screens/map_location_picker_screen.dart';
import '../../services/url_resolver_service.dart';

class LocationSelectionWidget extends StatefulWidget {
  final String? selectedAddress;
  final double? latitude;
  final double? longitude;
  final Function(String address, double lat, double lng) onLocationSelected;
  final String entityLabel;
  final String? Function(String?)? validator;

  const LocationSelectionWidget({
    required this.onLocationSelected,
    super.key,
    this.selectedAddress,
    this.latitude,
    this.longitude,
    this.entityLabel = 'Restaurant',
    this.validator,
  });

  @override
  State<LocationSelectionWidget> createState() =>
      _LocationSelectionWidgetState();
}

class _LocationSelectionWidgetState extends State<LocationSelectionWidget> {
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _mapsUrlController = TextEditingController();
  final DebouncedLocationDetector _debouncedDetector =
      DebouncedLocationDetector();

  bool _isDetectingLocation = false;
  bool _isProcessingMapsUrl = false;

  @override
  void initState() {
    super.initState();
    if (widget.selectedAddress != null) {
      _addressController.text = widget.selectedAddress!;
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    _mapsUrlController.dispose();
    _debouncedDetector.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${widget.entityLabel} Address *',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),

        // Address display field (read-only)
        Semantics(
          label: '${widget.entityLabel.toLowerCase()} address input field',
          hint: 'Select your ${widget.entityLabel.toLowerCase()} location',
          child: TextFormField(
            controller: _addressController,
            readOnly: true,
            decoration: InputDecoration(
              hintText:
                  'Select your ${widget.entityLabel.toLowerCase()} location',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.location_on),
              suffixIcon: widget.selectedAddress != null
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : null,
            ),
            validator: widget.validator,
          ),
        ),

        const SizedBox(height: 12),

        // Action buttons
        Column(
          children: [
            // First row: Current Location and Select on Map
            Row(
              children: [
                // Detect current location button
                Expanded(
                  child: Semantics(
                    button: true,
                    label: 'Use current location to detect address',
                    child: ElevatedButton.icon(
                      onPressed:
                          _isDetectingLocation ? null : _detectCurrentLocation,
                      icon: _isDetectingLocation
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.my_location, size: 16),
                      label: Text(
                        _isDetectingLocation
                            ? 'Detecting...'
                            : 'Use Current Location',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[800],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Select on map button
                Expanded(
                  child: Semantics(
                    button: true,
                    label: 'Open map to select location',
                    child: ElevatedButton.icon(
                      onPressed: _openMapPicker,
                      icon: const Icon(Icons.map, size: 16),
                      label: Text(
                        'Select on Map',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.grey[800],
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                          side: BorderSide(color: Colors.grey[300]!, width: 1),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Google Maps URL input and button
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Or paste Google Maps link:',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Paste any Google Maps URL - we\'ll handle shortened links automatically',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.auto_fix_high,
                          size: 14, color: Colors.green[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Supports: goo.gl, maps.app.goo.gl, bit.ly, and other shortened URLs',
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                            color: Colors.green[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // URL input field
                    Expanded(
                      child: Semantics(
                        label: 'Google Maps URL input field',
                        hint: 'Paste any Google Maps URL (shortened or full)',
                        child: TextField(
                          controller: _mapsUrlController,
                          decoration: InputDecoration(
                            hintText:
                                'Paste any Google Maps URL (shortened or full)',
                            hintStyle: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[400],
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          style: GoogleFonts.poppins(fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Process URL button
                    SizedBox(
                      width: 100,
                      height: 36,
                      child: Semantics(
                        button: true,
                        label: 'Process Google Maps URL to get location',
                        child: ElevatedButton.icon(
                          onPressed: _isProcessingMapsUrl
                              ? null
                              : _processGoogleMapsUrl,
                          icon: _isProcessingMapsUrl
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.link, size: 14),
                          label: Text(
                            _isProcessingMapsUrl
                                ? 'Resolving...'
                                : 'Get Location',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[800],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),

        // Location info display
        if (widget.selectedAddress != null && widget.latitude != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green[600],
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Location set: ${widget.latitude!.toStringAsFixed(6)}, ${widget.longitude!.toStringAsFixed(6)}',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.green[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _detectCurrentLocation() async {
    setState(() {
      _isDetectingLocation = true;
    });

    try {
      final locationProvider =
          Provider.of<LocationProvider>(context, listen: false);

      // Check if location services are enabled
      if (!locationProvider.isLocationEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                  'Location services are disabled. Please enable them in settings.'),
              backgroundColor: Colors.orange[700],
              action: SnackBarAction(
                label: 'Settings',
                textColor: Colors.white,
                onPressed: () => locationProvider.openLocationSettings(),
              ),
            ),
          );
        }
        return;
      }

      // Request permission if needed
      if (!locationProvider.hasPermission) {
        final granted = await locationProvider.requestPermission();
        if (!granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                    'Location permission is required to detect your address'),
                backgroundColor: Colors.red,
                action: SnackBarAction(
                  label: 'Settings',
                  textColor: Colors.white,
                  onPressed: () => locationProvider.openAppSettings(),
                ),
              ),
            );
          }
          return;
        }
      }

      // Show progress indicator with timeout
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Detecting your location...'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Get current location with timeout
      final success = await locationProvider.getCurrentLocation();

      if (success && locationProvider.currentLocation != null) {
        final location = locationProvider.currentLocation!;
        final address = locationProvider.getFormattedAddress();

        final selectedAddress = address ??
            '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}';

        setState(() {
          _addressController.text = selectedAddress;
        });

        widget.onLocationSelected(
            selectedAddress, location.latitude, location.longitude);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('📍 Location detected: $selectedAddress'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                  'Failed to detect location. Please check your GPS and try again.'),
              backgroundColor: Colors.red,
              action: SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: _detectCurrentLocation,
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Location detection error: $e');

      // Provide specific error messages based on error type
      String errorMessage = 'Unable to detect location';
      if (e.toString().contains('timeout')) {
        errorMessage = 'Location detection timed out. Please try again.';
      } else if (e.toString().contains('permission')) {
        errorMessage = 'Location permission denied.';
      } else if (e.toString().contains('service')) {
        errorMessage = 'Location services are not available.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _detectCurrentLocation,
            ),
          ),
        );
      }
    } finally {
      setState(() {
        _isDetectingLocation = false;
      });
    }
  }

  Future<void> _openMapPicker() async {
    try {
      final locationProvider =
          Provider.of<LocationProvider>(context, listen: false);

      // Check if location services are enabled
      if (!locationProvider.isLocationEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                  'Location services are disabled. Please enable them to use the map.'),
              backgroundColor: Colors.orange[700],
              action: SnackBarAction(
                label: 'Settings',
                textColor: Colors.white,
                onPressed: () => locationProvider.openLocationSettings(),
              ),
            ),
          );
        }
        return;
      }

      // Request permission if needed
      if (!locationProvider.hasPermission) {
        final granted = await locationProvider.requestPermission();
        if (!granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                    'Location permission is required to use the map picker'),
                backgroundColor: Colors.red,
                action: SnackBarAction(
                  label: 'Settings',
                  textColor: Colors.white,
                  onPressed: () => locationProvider.openAppSettings(),
                ),
              ),
            );
          }
          return;
        }
      }

      // Open map picker if permissions are granted
      if (mounted) {
        final result = await Navigator.push<Map<String, dynamic>>(
          context,
          MaterialPageRoute(
            builder: (context) => MapLocationPickerScreen(
              initialLatitude: widget.latitude,
              initialLongitude: widget.longitude,
            ),
          ),
        );

        if (result != null) {
          final address = result['address'];
          final latitude = result['latitude'];
          final longitude = result['longitude'];

          setState(() {
            _addressController.text = address;
          });

          widget.onLocationSelected(address, latitude, longitude);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location selected from map!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Map picker error: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening map: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _processGoogleMapsUrl() async {
    final url = _mapsUrlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a Google Maps URL'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isProcessingMapsUrl = true;
    });

    try {
      debugPrint('Processing Google Maps URL: $url');

      // Use URL resolver service to handle shortened URLs automatically
      final urlResolver = UrlResolverService();
      String? finalUrl = url;

      // Check if it's a shortened URL and resolve it
      if (urlResolver.isShortenedUrl(url)) {
        debugPrint('Detected shortened URL, resolving...');
        finalUrl = await urlResolver.resolveGoogleMapsUrl(url);

        if (finalUrl == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Could not resolve shortened URL. Please try the full Google Maps URL.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }

        debugPrint('Resolved URL: $finalUrl');
      }

      // Extract coordinates from the resolved URL
      final coordinates = await _extractCoordinatesFromUrl(finalUrl);

      if (coordinates != null) {
        final latitude = coordinates['latitude']!;
        final longitude = coordinates['longitude']!;

        debugPrint('Extracted coordinates: $latitude, $longitude');

        // Validate coordinates are in Algeria (rough bounds)
        if (latitude >= 18.0 &&
            latitude <= 38.0 &&
            longitude >= -9.0 &&
            longitude <= 12.0) {
          // Get address from coordinates
          await _getAddressFromCoordinates(latitude, longitude);

          debugPrint('Address set: ${_addressController.text}');

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location extracted from Google Maps URL! 📍'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Coordinates are outside Algeria. Please select a location within Algeria.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Invalid Google Maps URL. Please check the URL format.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error processing URL: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing URL: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isProcessingMapsUrl = false;
      });
    }
  }

  Future<Map<String, double>?> _extractCoordinatesFromUrl(String url) async {
    try {
      debugPrint('Parsing URL: $url');

      // Handle different Google Maps URL formats
      final uri = Uri.parse(url);

      // Format 1: https://maps.google.com/maps?q=36.7538,3.0588
      if (uri.queryParameters.containsKey('q')) {
        final q = uri.queryParameters['q']!;
        debugPrint('Found q parameter: $q');
        final coords = q.split(',');
        if (coords.length == 2) {
          final lat = double.tryParse(coords[0]);
          final lng = double.tryParse(coords[1]);
          if (lat != null && lng != null) {
            debugPrint('Extracted coordinates from q: $lat, $lng');
            return {'latitude': lat, 'longitude': lng};
          }
        }
      }

      // Format 2: https://maps.google.com/maps/@36.7538,3.0588,15z
      if (uri.path.contains('@')) {
        final pathParts = uri.path.split('@');
        if (pathParts.length > 1) {
          final coordsPart =
              pathParts[1].split(',')[0]; // Get first part before comma
          final coords = coordsPart.split(',');
          if (coords.length >= 2) {
            final lat = double.tryParse(coords[0]);
            final lng = double.tryParse(coords[1]);
            if (lat != null && lng != null) {
              debugPrint('Extracted coordinates from @: $lat, $lng');
              return {'latitude': lat, 'longitude': lng};
            }
          }
        }
      }

      // Format 3: Direct coordinates in path
      final pathSegments = uri.pathSegments;
      for (final segment in pathSegments) {
        if (segment.contains(',')) {
          final coords = segment.split(',');
          if (coords.length == 2) {
            final lat = double.tryParse(coords[0]);
            final lng = double.tryParse(coords[1]);
            if (lat != null && lng != null) {
              debugPrint('Extracted coordinates from path: $lat, $lng');
              return {'latitude': lat, 'longitude': lng};
            }
          }
        }
      }

      // Format 4: Handle URLs with place names that might contain coordinates
      final fullPath = uri.path;
      debugPrint('Full path for coordinate extraction: $fullPath');

      // Try both encoded and decoded versions
      final decodedPath = Uri.decodeComponent(fullPath);
      debugPrint('Decoded path for coordinate extraction: $decodedPath');

      // Pattern for @coordinates
      final coordPattern = RegExp(r'@(-?\d+\.?\d*),(-?\d+\.?\d*)');
      final match = coordPattern.firstMatch(fullPath) ??
          coordPattern.firstMatch(decodedPath);

      if (match != null) {
        final lat = double.tryParse(match.group(1)!);
        final lng = double.tryParse(match.group(2)!);
        if (lat != null && lng != null) {
          debugPrint('Extracted coordinates from regex: $lat, $lng');
          return {'latitude': lat, 'longitude': lng};
        }
      }

      // Format 5: Handle new Google Maps URL format with encoded coordinates
      final newFormatPattern = RegExp(r'@(-?\d+\.?\d*),(-?\d+\.?\d*),');
      final newFormatMatch = newFormatPattern.firstMatch(fullPath) ??
          newFormatPattern.firstMatch(decodedPath);
      if (newFormatMatch != null) {
        final lat = double.tryParse(newFormatMatch.group(1)!);
        final lng = double.tryParse(newFormatMatch.group(2)!);
        if (lat != null && lng != null) {
          debugPrint('Extracted coordinates from new format: $lat, $lng');
          return {'latitude': lat, 'longitude': lng};
        }
      }

      // Format 5b: Handle URLs with @coordinates pattern (more flexible)
      final flexiblePattern = RegExp(r'@(-?\d+\.?\d*),(-?\d+\.?\d*)');
      final flexibleMatch = flexiblePattern.firstMatch(fullPath) ??
          flexiblePattern.firstMatch(decodedPath);
      if (flexibleMatch != null) {
        final lat = double.tryParse(flexibleMatch.group(1)!);
        final lng = double.tryParse(flexibleMatch.group(2)!);
        if (lat != null && lng != null) {
          debugPrint('Extracted coordinates from flexible pattern: $lat, $lng');
          return {'latitude': lat, 'longitude': lng};
        }
      }

      // Format 6: Handle URLs with data parameters containing coordinates
      if (uri.queryParameters.containsKey('data')) {
        final dataParam = uri.queryParameters['data']!;
        final dataCoordPattern = RegExp(r'!3d(-?\d+\.?\d*)!4d(-?\d+\.?\d*)');
        final dataMatch = dataCoordPattern.firstMatch(dataParam);
        if (dataMatch != null) {
          final lat = double.tryParse(dataMatch.group(1)!);
          final lng = double.tryParse(dataMatch.group(2)!);
          if (lat != null && lng != null) {
            debugPrint('Extracted coordinates from data parameter: $lat, $lng');
            return {'latitude': lat, 'longitude': lng};
          }
        }
      }

      // Format 7: Fallback - look for coordinates anywhere in the full URL
      debugPrint('Trying fallback pattern on full URL: $url');
      final fallbackPattern = RegExp(r'@(-?\d+\.?\d*),(-?\d+\.?\d*)');
      final fallbackMatch = fallbackPattern.firstMatch(url);
      if (fallbackMatch != null) {
        final lat = double.tryParse(fallbackMatch.group(1)!);
        final lng = double.tryParse(fallbackMatch.group(2)!);
        if (lat != null && lng != null) {
          debugPrint('Extracted coordinates from fallback pattern: $lat, $lng');
          return {'latitude': lat, 'longitude': lng};
        }
      }

      debugPrint('No coordinates found in URL');
      return null;
    } catch (e) {
      debugPrint('Error parsing URL: $e');
      return null;
    }
  }

  Future<void> _getAddressFromCoordinates(
      double latitude, double longitude) async {
    try {
      debugPrint('Getting address for coordinates: $latitude, $longitude');

      final placemarks =
          await GeocodingPlatform.instance?.placemarkFromCoordinates(
                latitude,
                longitude,
              ) ??
              [];

      debugPrint('Found ${placemarks.length} placemarks');

      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final address = [
          placemark.street,
          placemark.locality,
          placemark.administrativeArea,
          placemark.country,
        ].where((part) => part != null && part.isNotEmpty).join(', ');

        debugPrint('Generated address: $address');

        final selectedAddress =
            address.isNotEmpty ? address : '$latitude, $longitude';

        setState(() {
          _addressController.text = selectedAddress;
        });

        widget.onLocationSelected(selectedAddress, latitude, longitude);

        debugPrint('Final selected address: $selectedAddress');
      } else {
        debugPrint('No placemarks found, using coordinates as address');
        final selectedAddress = '$latitude, $longitude';
        setState(() {
          _addressController.text = selectedAddress;
        });
        widget.onLocationSelected(selectedAddress, latitude, longitude);
      }
    } catch (e) {
      debugPrint('Error getting address: $e');
      final selectedAddress = '$latitude, $longitude';
      setState(() {
        _addressController.text = selectedAddress;
      });
      widget.onLocationSelected(selectedAddress, latitude, longitude);
    }
  }
}

/// Debounced location detection to prevent multiple rapid calls
class DebouncedLocationDetector {
  Timer? _debounceTimer;
  final Duration _debounceDelay = const Duration(milliseconds: 500);

  void detectLocation(Function() callback) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDelay, callback);
  }

  void dispose() {
    _debounceTimer?.cancel();
  }
}
