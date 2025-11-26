import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_localizations.dart';
import '../models/task.dart';
import '../services/auth_service.dart';
import '../widgets/app_header.dart';
import 'review_tasks_screen.dart';

class CreateTaskScreen extends StatefulWidget {
  const CreateTaskScreen({super.key});

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationPurposeController =
      TextEditingController();
  final TextEditingController _phone1Controller = TextEditingController();
  final TextEditingController _phone2Controller = TextEditingController();
  bool _isSecondPhonePrimary = false;
  late VoidCallback _phone2Listener;
  DateTime? _scheduledAt;

  final Completer<GoogleMapController> _mapController =
      Completer<GoogleMapController>();
  Marker? _selectedMarker;
  String _resolvedAddress = '';
  // Support multiple locations per task (no limit)
  final List<_TaskLocation> _extraLocations = <_TaskLocation>[];

  // Image upload state
  File? _selectedImage;
  String? _imageUrl;
  String? _imagePath;
  bool _isUploadingImage = false;

  // Loading and animation states
  bool _isInitializing = true;
  bool _isMapLoading = true;
  bool _isSubmitting = false;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Performance optimization
  Timer? _debounceTimer;
  String? _cachedPhonePrefill;
  late TextStyle _cachedTextStyle;
  late TextStyle _cachedHintStyle;
  Task? _buildTaskFromFormIfValid({String? keepId}) {
    // Allow submission if there's a selected marker OR if there are added locations
    if (_selectedMarker == null && _extraLocations.isEmpty) return null;

    // We validate only requireds here; full form validation might block multi-submit unnecessarily.
    final auth = Provider.of<AuthService>(context, listen: false);
    final userId = auth.currentUser?.id ?? '';

    // Determine the primary location - use first added location if available, otherwise use dropped pin
    LatLng pos;
    String locationName;
    String locationPurpose;

    if (_extraLocations.isNotEmpty) {
      // Use the first added location as primary
      final firstLocation = _extraLocations.first;
      pos = LatLng(firstLocation.lat, firstLocation.lng);
      locationName = firstLocation.label;
      locationPurpose =
          firstLocation.purpose; // Use the purpose from the first location
    } else {
      // Use the dropped pin as primary
      if (_selectedMarker == null) {
        // If no marker is selected and no extra locations, return null
        return null;
      }
      pos = _selectedMarker!.position;
      locationName = _resolvedAddress.isNotEmpty
          ? _resolvedAddress
          : 'Lat ${pos.latitude.toStringAsFixed(5)}, Lng ${pos.longitude.toStringAsFixed(5)}';
      locationPurpose = _locationPurposeController.text.trim();
    }

    // Use only the actual description without appending locations
    final String description = _descriptionController.text.trim();

    // Prepare additional locations data
    List<Map<String, dynamic>> additionalLocations = [];
    if (_extraLocations.length > 1) {
      // Skip the first one since it's now the primary
      additionalLocations = _extraLocations
          .skip(1)
          .map((loc) => {
                'purpose': loc.purpose,
                'address': loc.label,
                'lat': loc.lat,
                'lng': loc.lng,
              })
          .toList();
    }

    return Task(
      id: keepId ?? 'local-${DateTime.now().microsecondsSinceEpoch}',
      description: description,
      locationName: locationName,
      locationPurpose: locationPurpose,
      latitude: pos.latitude,
      longitude: pos.longitude,
      status: _scheduledAt != null ? TaskStatus.scheduled : TaskStatus.pending,
      scheduledAt: _scheduledAt,
      userId: userId,
      deliveryManId: null,
      contactPhone: _isSecondPhonePrimary
          ? (_phone2Controller.text.trim().isNotEmpty
              ? _phone2Controller.text.trim()
              : null)
          : (_phone1Controller.text.trim().isNotEmpty
              ? _phone1Controller.text.trim()
              : null),
      contactPhone2: _isSecondPhonePrimary
          ? (_phone1Controller.text.trim().isNotEmpty
              ? _phone1Controller.text.trim()
              : null)
          : (_phone2Controller.text.trim().isNotEmpty
              ? _phone2Controller.text.trim()
              : null),
      additionalLocations:
          additionalLocations.isNotEmpty ? additionalLocations : null,
      imageUrl: _imageUrl,
      imagePath: _imagePath,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  static const LatLng _defaultCenter = LatLng(36.752887, 3.042048); // Algiers

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
        await _uploadImage();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _uploadImage() async {
    if (_selectedImage == null) return;

    setState(() {
      _isUploadingImage = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final auth = Provider.of<AuthService>(context, listen: false);
      final userId = auth.currentUser?.id ?? '';

      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'task_${userId}_$timestamp.jpg';
      final filePath = 'tasks/$userId/$fileName';

      // Upload to Supabase Storage
      await supabase.storage
          .from('task-images')
          .uploadBinary(filePath, await _selectedImage!.readAsBytes());

      // Get public URL
      final imageUrl =
          supabase.storage.from('task-images').getPublicUrl(filePath);

      setState(() {
        _imageUrl = imageUrl;
        _imagePath = filePath;
        _isUploadingImage = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image uploaded successfully')),
        );
      }
    } catch (e) {
      setState(() {
        _isUploadingImage = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${AppLocalizations.of(context)?.errorUploadingImage ?? 'Error uploading image: {error}'}'
                      .replaceAll('{error}', e.toString()))),
        );
      }
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
      _imageUrl = null;
      _imagePath = null;
    });
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDate: now,
    );
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))));
    if (time == null) return;
    setState(() {
      _scheduledAt =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _reverseGeocode(LatLng pos) async {
    try {
      final placemarks =
          await geocoding.placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        setState(() {
          _resolvedAddress = [p.name, p.street, p.locality, p.country]
              .where((e) => (e ?? '').toString().isNotEmpty)
              .join(', ');
          // Address resolved automatically
        });
      }
    } catch (e) {
      debugPrint('Reverse geocoding failed: $e');
    }
  }

  Future<void> _onMapLongPress(LatLng pos) async {
    setState(() {
      _selectedMarker =
          Marker(markerId: const MarkerId('selected'), position: pos);
    });
    await _reverseGeocode(pos);
  }

  Future<void> _resetMapAndLabel() async {
    setState(() {
      _selectedMarker = null;
      // Clear form data
      _resolvedAddress = '';
      _locationPurposeController.clear();
    });
    if (_mapController.isCompleted) {
      try {
        final controller = await _mapController.future;
        // ignore: use_build_context_synchronously
        await controller.animateCamera(
          CameraUpdate.newCameraPosition(
              const CameraPosition(target: _defaultCenter, zoom: 12)),
        );
      } catch (_) {}
    }
  }

  void _addCurrentLocationAsExtra() {
    if (_selectedMarker == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context)?.dropPinOnMapFirst ??
                'Drop a pin on the map first')),
      );
      return;
    }
    final pos = _selectedMarker!.position;
    final label = _resolvedAddress.isNotEmpty
        ? _resolvedAddress
        : 'Lat ${pos.latitude.toStringAsFixed(5)}, Lng ${pos.longitude.toStringAsFixed(5)}';

    setState(() {
      _extraLocations.add(_TaskLocation(
          label: label,
          purpose: _locationPurposeController.text.trim().isNotEmpty
              ? _locationPurposeController.text.trim()
              : AppLocalizations.of(context)?.locationPurpose ??
                  'Location purpose',
          lat: pos.latitude,
          lng: pos.longitude));
    });

    _resetMapAndLabel();
  }

  void _removeExtraLocation(int index) {
    if (index < 0 || index >= _extraLocations.length) return;
    setState(() {
      _extraLocations.removeAt(index);
    });
  }

  Future<void> _submitTask() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedMarker == null && _extraLocations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              AppLocalizations.of(context)?.pleaseDropPinOrAddLocations ??
                  'Please drop a pin on the map or add locations')));
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final task = _buildTaskFromFormIfValid();
    if (task == null) {
      setState(() {
        _isSubmitting = false;
      });
      return;
    }

    // Add smooth navigation transition
    final confirmed = await Navigator.of(context).push<bool>(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            ReviewTasksScreen(tasks: [task]),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;
          final tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)?.taskCreatedSuccessfully ??
              'Task created successfully'),
          backgroundColor: const Color(0xFFd47b00),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      setState(() {
        _descriptionController.clear();
        _locationPurposeController.clear();
        _phone1Controller.clear();
        _phone2Controller.clear();
        _isSecondPhonePrimary = false;
        _scheduledAt = null;
        _selectedImage = null;
        _imageUrl = null;
        _imagePath = null;
        _extraLocations.clear();
        _selectedMarker = null;
        _resolvedAddress = '';
        _isSubmitting = false;
      });
    } else {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    // Cache text styles for performance
    _cachedTextStyle =
        GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.w600);
    _cachedHintStyle = GoogleFonts.poppins(
        color: Colors.grey[500], fontWeight: FontWeight.w600);

    // Initialize animation controllers
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    // Add debounced listener to second phone controller
    _phone2Listener = () {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            // Trigger rebuild when second phone text changes
          });
        }
      });
    };
    _phone2Controller.addListener(_phone2Listener);

    // Initialize screen with delay for smooth loading
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      setState(() {
        _isInitializing = false;
      });
      await _fadeController.forward();
      await _slideController.forward();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _phone2Controller.removeListener(_phone2Listener);
    _phone1Controller.dispose();
    _phone2Controller.dispose();
    _descriptionController.dispose();
    _locationPurposeController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    // Prefill phone from current user if available (once) - optimized
    if (_cachedPhonePrefill == null) {
      final authPrefill =
          Provider.of<AuthService>(context, listen: false).currentUser;
      if (authPrefill?.phone != null && authPrefill!.phone!.isNotEmpty) {
        _cachedPhonePrefill = authPrefill.phone!;
        if (_phone1Controller.text.isEmpty) {
          _phone1Controller.text = _cachedPhonePrefill!;
        }
      }
    }

    return Scaffold(
      body: _isInitializing
          ? _buildSkeletonScreen()
          : FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppHeader(
                          title:
                              AppLocalizations.of(context)?.createIfriliTask ??
                                  'Create Ifrili Task'),
                      const SizedBox(height: 12),
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            RepaintBoundary(
                              child: _shadowField(
                                child: TextFormField(
                                  controller: _descriptionController,
                                  cursorColor: const Color(0xFFd47b00),
                                  style: _cachedTextStyle,
                                  decoration: _input(
                                      AppLocalizations.of(context)
                                              ?.describeYourNeed ??
                                          'Describe your need'),
                                  maxLines: 3,
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                          ? (AppLocalizations.of(context)
                                                  ?.required ??
                                              'Required')
                                          : null,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Phone numbers section under description
                            _shadowField(
                              child: Column(
                                children: [
                                  // Primary phone (hidden if second phone is primary)
                                  if (!_isSecondPhonePrimary)
                                    RepaintBoundary(
                                      child: TextFormField(
                                        controller: _phone1Controller,
                                        keyboardType: TextInputType.phone,
                                        cursorColor: const Color(0xFFd47b00),
                                        style: _cachedTextStyle,
                                        decoration: _input(
                                            AppLocalizations.of(context)
                                                    ?.phoneNumber ??
                                                'Phone number'),
                                      ),
                                    ),
                                  if (!_isSecondPhonePrimary)
                                    const SizedBox(height: 8),

                                  // Second phone
                                  RepaintBoundary(
                                    child: TextFormField(
                                      controller: _phone2Controller,
                                      keyboardType: TextInputType.phone,
                                      cursorColor: const Color(0xFFd47b00),
                                      style: _cachedTextStyle,
                                      decoration: _input(_isSecondPhonePrimary
                                          ? (AppLocalizations.of(context)
                                                  ?.phoneNumber ??
                                              'Phone number')
                                          : (AppLocalizations.of(context)
                                                  ?.secondPhoneOptional ??
                                              'Second phone (optional)')),
                                    ),
                                  ),

                                  // Toggle option for second phone as primary
                                  if (_phone2Controller.text.trim().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Row(
                                        children: [
                                          Checkbox(
                                            value: _isSecondPhonePrimary,
                                            onChanged: (value) {
                                              setState(() {
                                                _isSecondPhonePrimary =
                                                    value ?? false;
                                              });
                                            },
                                            activeColor:
                                                const Color(0xFFd47b00),
                                          ),
                                          Expanded(
                                            child: Text(
                                              AppLocalizations.of(context)
                                                      ?.useSecondPhoneAsPrimary ??
                                                  'Use second phone as primary',
                                              style: GoogleFonts.poppins(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            RepaintBoundary(
                              child: _shadowField(
                                child: TextFormField(
                                  controller: _locationPurposeController,
                                  cursorColor: const Color(0xFFd47b00),
                                  style: _cachedTextStyle,
                                  decoration: _input(
                                      AppLocalizations.of(context)
                                              ?.locationPurpose ??
                                          'Location purpose'),
                                  maxLines: 2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Extra location controls
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black,
                                    elevation: 6,
                                    shadowColor:
                                        Colors.black.withValues(alpha: 0.12),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(25.5)),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 10),
                                  ),
                                  onPressed: _addCurrentLocationAsExtra,
                                  icon: const Icon(
                                      Icons.add_location_alt_rounded,
                                      size: 18),
                                  label: Text(
                                    AppLocalizations.of(context)
                                            ?.addAnotherLocation ??
                                        'Add another location',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${AppLocalizations.of(context)?.added ?? 'Added'}: ${_extraLocations.length + (_selectedMarker != null ? 1 : 0)}',
                                  style: GoogleFonts.inter(
                                      color: Colors.grey[700], fontSize: 12),
                                ),
                              ],
                            ),
                            if (_extraLocations.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children:
                                      _extraLocations.asMap().entries.map((e) {
                                    final idx = e.key;
                                    final loc = e.value;
                                    return InputChip(
                                      label: Text(loc.purpose,
                                          style: GoogleFonts.poppins(
                                              fontSize: 12)),
                                      onDeleted: () =>
                                          _removeExtraLocation(idx),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            // Image upload section
                            _buildImageUploadSection(),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.grey[900],
                                      elevation: 8,
                                      shadowColor:
                                          Colors.black.withValues(alpha: 0.15),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(25.5)),
                                    ),
                                    onPressed: _pickDateTime,
                                    icon: const Icon(Icons.event),
                                    label: Text(
                                      _scheduledAt == null
                                          ? (AppLocalizations.of(context)
                                                  ?.pickDateTime ??
                                              'Pick date & time')
                                          : _scheduledAt.toString(),
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      RepaintBoundary(
                        child: SizedBox(
                          height: 260,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              children: [
                                GoogleMap(
                                  initialCameraPosition: const CameraPosition(
                                      target: _defaultCenter, zoom: 12),
                                  myLocationEnabled: true,
                                  myLocationButtonEnabled: true,
                                  zoomControlsEnabled: true,
                                  mapToolbarEnabled: false,
                                  onMapCreated: (c) {
                                    _mapController.complete(c);
                                    setState(() {
                                      _isMapLoading = false;
                                    });
                                  },
                                  markers: {
                                    if (_selectedMarker != null)
                                      _selectedMarker!,
                                  },
                                  onLongPress: _onMapLongPress,
                                  onTap: _onMapLongPress,
                                  gestureRecognizers: <Factory<
                                      OneSequenceGestureRecognizer>>{
                                    Factory<PanGestureRecognizer>(
                                        () => PanGestureRecognizer()),
                                    Factory<ScaleGestureRecognizer>(
                                        () => ScaleGestureRecognizer()),
                                    Factory<TapGestureRecognizer>(
                                        () => TapGestureRecognizer()),
                                    Factory<LongPressGestureRecognizer>(
                                        () => LongPressGestureRecognizer()),
                                  },
                                ),
                                if (_isMapLoading)
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const CircularProgressIndicator(
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    Color(0xFFd47b00)),
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'Loading map...',
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_resolvedAddress.isNotEmpty)
                        Row(
                          children: [
                            const Icon(Icons.place, color: Colors.grey),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(_resolvedAddress,
                                    style: GoogleFonts.inter())),
                          ],
                        ),
                      const SizedBox(height: 16),
                      RepaintBoundary(
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isSubmitting
                                      ? Colors.grey[400]
                                      : const Color(0xFFd47b00),
                                  foregroundColor: Colors.white,
                                  elevation: 10,
                                  shadowColor: const Color(0xFFd47b00)
                                      .withValues(alpha: 0.5),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(25.5)),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 14),
                                ),
                                onPressed: _isSubmitting ? null : _submitTask,
                                icon: _isSubmitting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        ),
                                      )
                                    : const Icon(Icons.send),
                                label: Text(
                                  _isSubmitting
                                      ? (AppLocalizations.of(context)
                                              ?.creating ??
                                          'Creating...')
                                      : (AppLocalizations.of(context)
                                              ?.createTaskButton ??
                                          'Create Task'),
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  InputDecoration _input(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: _cachedHintStyle,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25.5),
          borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25.5),
          borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25.5),
          borderSide: const BorderSide(color: Color(0xFFd47b00), width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  // Skeleton loading widgets
  Widget _buildSkeletonField() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonMap() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        height: 260,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildSkeletonButton() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25.5),
        ),
      ),
    );
  }

  Widget _buildSkeletonScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppHeader(title: 'Create Ifrili Task'),
          const SizedBox(height: 12),
          _buildSkeletonField(),
          const SizedBox(height: 12),
          _buildSkeletonField(),
          const SizedBox(height: 12),
          _buildSkeletonField(),
          const SizedBox(height: 12),
          _buildSkeletonField(),
          const SizedBox(height: 16),
          _buildSkeletonMap(),
          const SizedBox(height: 16),
          _buildSkeletonButton(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildImageUploadSection() {
    return _shadowField(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25.5),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)?.taskImageOptional ??
                  'Task Image (Optional)',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                color: Colors.grey[700],
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            if (_selectedImage != null || _imageUrl != null) ...[
              // Show selected image
              Container(
                height: 96,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: _selectedImage != null
                      ? Image.file(
                          _selectedImage!,
                          fit: BoxFit.cover,
                        )
                      : _imageUrl != null
                          ? Image.network(
                              _imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.error),
                            )
                          : const Icon(Icons.image),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.edit, size: 16),
                      label: Text(
                        AppLocalizations.of(context)?.changeImage ??
                            'Change Image',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange[50],
                        foregroundColor: Colors.orange[900],
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _removeImage,
                      icon: const Icon(Icons.delete, size: 16),
                      label: Text(
                        AppLocalizations.of(context)?.remove ?? 'Remove',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[50],
                        foregroundColor: Colors.red[900],
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Show upload button
              Container(
                height: 96,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: Colors.grey[300]!, style: BorderStyle.solid),
                ),
                child: InkWell(
                  onTap: _isUploadingImage ? null : _pickImage,
                  borderRadius: BorderRadius.circular(18),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isUploadingImage) ...[
                        const CircularProgressIndicator(),
                        const SizedBox(height: 8),
                        Text(
                          AppLocalizations.of(context)?.uploading ??
                              'Uploading...',
                          style: GoogleFonts.poppins(
                            color: Colors.grey[600],
                            fontSize: 11,
                          ),
                        ),
                      ] else ...[
                        Icon(
                          Icons.add_photo_alternate,
                          size: 28,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppLocalizations.of(context)?.addImage ?? 'Add Image',
                          style: GoogleFonts.poppins(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          AppLocalizations.of(context)
                                  ?.tapToSelectFromGallery ??
                              'Tap to select from gallery',
                          style: GoogleFonts.poppins(
                            color: Colors.grey[500],
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _shadowField({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _TaskLocation {
  final String label;
  final String purpose;
  final double lat;
  final double lng;
  const _TaskLocation(
      {required this.label,
      required this.purpose,
      required this.lat,
      required this.lng});
}
