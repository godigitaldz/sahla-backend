// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../home_screen.dart';
import '../models/delivery_personnel.dart';
import '../models/order.dart';
import '../models/task.dart';
import '../services/auth_service.dart';
import '../services/comprehensive_earnings_service.dart';
import '../services/comprehensive_maps_service.dart';
import '../services/delivery_service.dart';
import '../services/integrated_task_delivery_service.dart';
import '../services/location_tracking_service.dart';
import '../services/logging_service.dart';
import '../services/order_assignment_service.dart';
import '../services/order_service.dart';
// Removed legacy order_tracking_service import
import '../services/order_tracking_service.dart';
import '../services/street_view_service.dart';
import '../utils/price_formatter.dart';
import '../widgets/app_header.dart';
import '../widgets/delivery_map_dashboard_screen/delivery_bottom_navigation.dart';
import '../widgets/delivery_map_dashboard_screen/delivery_map_overlay.dart';
// DISABLED: Order-related import
// import '../widgets/enhanced_delivery_order_card.dart';
import '../widgets/delivery_map_dashboard_screen/geolocation_service_widget.dart';
import '../widgets/delivery_map_dashboard_screen/map_order_card.dart';
import '../widgets/delivery_map_dashboard_screen/map_order_header.dart';
import '../widgets/delivery_map_dashboard_screen/orders_filter_tab_bar.dart';

class DeliveryMapDashboardScreen extends StatefulWidget {
  const DeliveryMapDashboardScreen({super.key});

  @override
  State<DeliveryMapDashboardScreen> createState() =>
      _DeliveryMapDashboardScreenState();
}

class _DeliveryMapDashboardScreenState extends State<DeliveryMapDashboardScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  DeliveryPersonnel? _deliveryPerson;
  final bool _isFollowingDeliveryPerson = true;
  // DISABLED: Order-related state (kept as empty to avoid compilation errors)
  List<Order> _activeOrders = [];
  List<Order> _availableOrders = [];
  List<Order> _completedOrders = [];
  List<Task> _availableTasks = [];
  List<Task> _activeTasks = [];
  List<Task> _completedTasks = [];
  bool _isOnline = false;
  bool _isAvailable = false;
  int _currentBottomNavIndex = 0; // 0: Map, 1: Orders, 2: Earnings, 3: Profile
  int _ordersFilterIndex = 0; // 0: Available, 1: Active, 2: Completed

  // Earnings data
  Map<String, dynamic>? _walletInfo;
  List<Map<String, dynamic>> _creditTransactions = [];
  List<Map<String, dynamic>> _pendingServiceFees = [];
  List<Map<String, dynamic>> _dailyEarnings = [];

  // Map related
  GoogleMapController? _mapController;
  LatLng? _currentLocation;
  Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  // Enhanced map features from pick location screen
  MapType _currentMapType = MapType.normal;
  String? _mapStyle;

  // DISABLED: Order-related map variables (kept as null to avoid compilation errors)
  LatLng? _selectedOrderLocation;
  Order? _selectedOrder;
  Task? _selectedTask;
  double _proposedCost = 500.0; // Default proposed cost

  // Task mode UI state
  bool _isTaskHeaderExpanded = false;
  bool _isTaskDescriptionExpanded = false;

  // Task card expandable sections state - using Map to track per-task expansion
  // ignore: prefer_final_fields
  Map<String, Map<String, bool>> _taskExpansionStates = {};

  // Profile editing state
  bool _isEditingProfile = false;
  final TextEditingController _deliveryNameController = TextEditingController();
  final TextEditingController _workPhoneController = TextEditingController();
  final TextEditingController _vehicleBrandController = TextEditingController();
  final TextEditingController _vehicleModelController = TextEditingController();
  final TextEditingController _vehicleYearController = TextEditingController();
  final TextEditingController _vehicleColorController = TextEditingController();
  final TextEditingController _vehiclePlateController = TextEditingController();
  String? _selectedWilaya;
  String? _selectedProvince;
  File? _selectedImage;
  final ImagePicker _imagePicker = ImagePicker();

  // Algerian Wilayas and Provinces
  final Map<String, List<String>> _wilayaProvinces = {
    'Adrar': ['Adrar', 'Reggane', 'Timimoun', 'Aoulef'],
    'Chlef': ['Chlef', 'Ténès', 'El Karimia', 'Oued Fodda'],
    'Laghouat': ['Laghouat', 'Aflou', 'Ksar El Hirane', 'Hassi R\'Mel'],
    'Oum El Bouaghi': ['Oum El Bouaghi', 'Aïn Beïda', 'Ksar Sbahi', 'Meskiana'],
    'Batna': ['Batna', 'Barika', 'Merouana', 'Tazoult'],
    'Béjaïa': ['Béjaïa', 'Akbou', 'El Kseur', 'Sidi Aïch'],
    'Biskra': ['Biskra', 'Ouled Djellal', 'Sidi Okba', 'Zeribet El Oued'],
    'Béchar': ['Béchar', 'Abadla', 'Béni Abbès', 'Taghit'],
    'Blida': ['Blida', 'Boufarik', 'Bouïra', 'Larbaâ'],
    'Bouira': ['Bouira', 'El Asnam', 'Hadjout', 'Sour El Ghozlane'],
    'Tamanrasset': ['Tamanrasset', 'Abalessa', 'In Guezzam', 'Tin Zaouatine'],
    'Tébessa': ['Tébessa', 'Bir El Ater', 'Morsott', 'Negrine'],
    'Tlemcen': ['Tlemcen', 'Beni Snous', 'Ghazaouet', 'Hennaya'],
    'Tiaret': ['Tiaret', 'Aïn Deheb', 'Mahdia', 'Sougueur'],
    'Tizi Ouzou': ['Tizi Ouzou', 'Azazga', 'Boghni', 'Draâ El Mizan'],
    'Alger': ['Alger', 'Bab Ezzouar', 'Bordj El Kiffan', 'Dar El Beïda'],
    'Djelfa': ['Djelfa', 'Aïn Oussera', 'Hassi Bahbah', 'Messad'],
    'Jijel': ['Jijel', 'El Ancer', 'El Milia', 'Taher'],
    'Sétif': ['Sétif', 'Aïn Arnat', 'El Eulma', 'Hammam Guergour'],
    'Saïda': ['Saïda', 'Aïn El Hadjar', 'El Bayadh', 'Youb'],
    'Skikda': ['Skikda', 'Azzaba', 'Collo', 'El Harrouch'],
    'Sidi Bel Abbès': [
      'Sidi Bel Abbès',
      'Aïn Témouchent',
      'Ben Badis',
      'Tlemcen'
    ],
    'Annaba': ['Annaba', 'El Bouni', 'El Hadjar', 'Seraïdi'],
    'Guelma': ['Guelma', 'Bouchegouf', 'Hammam Debagh', 'Oued Zenati'],
    'Constantine': ['Constantine', 'Aïn Abid', 'El Khroub', 'Hamma Bouziane'],
    'Médéa': ['Médéa', 'Berrouaghia', 'Bouïra', 'Sidi Naâmane'],
    'Mostaganem': ['Mostaganem', 'Aïn Nouïssy', 'Hassi Mameche', 'Sidi Ali'],
    'M\'Sila': ['M\'Sila', 'Aïn El Hadjel', 'Bou Saâda', 'Ouled Derradj'],
    'Mascara': ['Mascara', 'Aïn Fekan', 'El Bordj', 'Mohammedia'],
    'Ouargla': ['Ouargla', 'El Hadjira', 'Hassi Messaoud', 'N\'Goussa'],
    'Oran': ['Oran', 'Aïn El Turk', 'Es Senia', 'Gdyel'],
    'El Bayadh': ['El Bayadh', 'Bougtob', 'Brezina', 'Rogassa'],
    'Illizi': ['Illizi', 'Bordj Omar Driss', 'Djanet', 'In Amenas'],
    'Bordj Bou Arreridj': [
      'Bordj Bou Arreridj',
      'Aïn Taghrout',
      'El Hamadia',
      'Ras El Oued'
    ],
    'Boumerdès': ['Boumerdès', 'Boudouaou', 'Dellys', 'Khemis El Khechna'],
    'El Tarf': ['El Tarf', 'Ben M\'Hidi', 'Bouteldja', 'Chefia'],
    'Tindouf': ['Tindouf', 'Oum El Assel', 'Zaouiet Kounta'],
    'Tissemsilt': ['Tissemsilt', 'Ammari', 'Bordj Bounaama', 'Lazharia'],
    'El Oued': ['El Oued', 'Bayadha', 'Debila', 'Hassi Khalifa'],
    'Khenchela': ['Khenchela', 'Aïn Beïda', 'Babar', 'El Hamma'],
    'Souk Ahras': ['Souk Ahras', 'Aïn Zana', 'M\'Daourouch', 'Sedrata'],
    'Tipaza': ['Tipaza', 'Ahmar El Aïn', 'Bou Ismaïl', 'Kolea'],
    'Mila': ['Mila', 'Aïn Beïda', 'Chelghoum Laïd', 'Grarem Gouga'],
    'Aïn Defla': ['Aïn Defla', 'Bordj Emir Khaled', 'El Amra', 'Hammam Righa'],
    'Naâma': ['Naâma', 'Aïn Sefra', 'Mécheria', 'Tiout'],
    'Aïn Témouchent': [
      'Aïn Témouchent',
      'Beni Saf',
      'El Malah',
      'Hammam Bou Hadjar'
    ],
    'Ghardaïa': ['Ghardaïa', 'Berriane', 'El Guerrara', 'Metlili'],
    'Relizane': ['Relizane', 'Ammi Moussa', 'El H\'Madna', 'Zemmoura'],
  };

  // Getter to indicate the field is used
  Task? get selectedTask => _selectedTask;

  // Helper methods for per-task expansion state
  bool _isTaskFieldExpanded(String taskId, String field) {
    return _taskExpansionStates[taskId]?[field] ?? false;
  }

  void _toggleTaskFieldExpansion(String taskId, String field) {
    setState(() {
      _taskExpansionStates[taskId] ??= {};
      _taskExpansionStates[taskId]![field] =
          !_isTaskFieldExpanded(taskId, field);
    });
  }

  // Animation controllers
  late AnimationController _slideController;
  late AnimationController _fadeController;

  // Real-time subscription
  StreamSubscription? _ordersSubscription;
  StreamSubscription? _locationSubscription;

  // DISABLED: Order tracking services (kept as null to avoid compilation errors)
  final OrderTrackingService? _orderTrackingService = null;

  // Integrated task-delivery service
  final IntegratedTaskDeliveryService _integratedService =
      IntegratedTaskDeliveryService.instance;

  // Comprehensive earnings service
  final ComprehensiveEarningsService _earningsService =
      ComprehensiveEarningsService();

  // Location tracking service
  final LocationTrackingService _locationTrackingService =
      LocationTrackingService();
  final LoggingService _logger = LoggingService();

  // Default location (Algiers, Algeria)
  static const LatLng _defaultLocation = LatLng(36.7538, 3.0588);

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _setupRealTimeUpdates();
    _loadDashboardDataOptimized();
    // Defer non-critical initialization to background
    _initializeNonCriticalServices();
    _initializeProfileControllers();
    // Initialize comprehensive map tracking
    _initializeComprehensiveMapTracking();
  }

  void _initializeProfileControllers() {
    // Initialize controllers with current values when delivery person is loaded
    if (_deliveryPerson != null) {
      _deliveryNameController.text = _deliveryPerson!.deliveryName ?? '';
      _workPhoneController.text = _deliveryPerson!.workPhone ?? '';
      _vehicleBrandController.text = _deliveryPerson!.vehicleBrand ?? '';
      _vehicleModelController.text = _deliveryPerson!.vehicleModel ?? '';
      _vehicleYearController.text =
          _deliveryPerson!.vehicleYear?.toString() ?? '';
      _vehicleColorController.text = _deliveryPerson!.vehicleColor ?? '';
      _vehiclePlateController.text = _deliveryPerson!.vehiclePlate ?? '';
      _selectedWilaya = _deliveryPerson!.wilaya;
      _selectedProvince = _deliveryPerson!.province;
    }
  }

  void _initializeAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideController.forward();
    _fadeController.forward();
  }

  void _setupRealTimeUpdates() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;

    if (currentUser != null) {
      // Listen for order assignments to this delivery person
      _ordersSubscription = Supabase.instance.client
          .from('orders')
          .stream(primaryKey: ['id']).listen((List<Map<String, dynamic>> data) {
        debugPrint(
            'Real-time update: Orders changed for delivery person ${currentUser.id}');

        // Check if any orders are assigned to this delivery person
        // We need to get the delivery_personnel.id for this user_id
        _checkForRelevantOrders(data, currentUser.id);
      });

      // Setup polling as backup for real-time updates
      _startOrderPolling();

      // Listen for task assignments to this delivery person
      Supabase.instance.client
          .from('tasks')
          .stream(primaryKey: ['id']).listen((List<Map<String, dynamic>> data) {
        debugPrint(
            'Real-time update: Tasks changed for delivery person ${currentUser.id}');

        final relevantTasks = data
            .where((task) => task['delivery_man_id'] == currentUser.id)
            .toList();

        if (relevantTasks.isNotEmpty && mounted) {
          debugPrint(
              '🔄 Real-time update triggered: ${relevantTasks.length} relevant tasks');
          _loadDashboardDataBackground();
        }
      });
    }
  }

  void _startOrderPolling() {
    // Poll every 5 seconds to check for order updates
    Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      _pollForOrderUpdates();
    });
  }

  Future<void> _pollForOrderUpdates() async {
    try {
      if (_deliveryPerson == null) return;

      // Check if there are new active orders
      final activeOrdersCount = _activeOrders.length;
      await _loadActiveOrders();

      // If the count changed, trigger UI update
      if (mounted && _activeOrders.length != activeOrdersCount) {
        debugPrint('🔄 Polling detected order changes, updating UI...');
        setState(() {
          // Trigger UI update
        });
      }
    } catch (e) {
      debugPrint('Error polling for order updates: $e');
    }
  }

  Future<void> _checkForRelevantOrders(
      List<Map<String, dynamic>> orders, String userId) async {
    try {
      // Get the delivery_personnel.id for this user_id
      final deliveryPersonnelResponse = await Supabase.instance.client
          .from('delivery_personnel')
          .select('id')
          .eq('user_id', userId)
          .single();

      if (deliveryPersonnelResponse.isNotEmpty) {
        final deliveryPersonnelId = deliveryPersonnelResponse['id'];

        final relevantOrders = orders
            .where(
                (order) => order['delivery_person_id'] == deliveryPersonnelId)
            .toList();

        if (relevantOrders.isNotEmpty && mounted) {
          debugPrint(
              '🔄 Real-time update triggered: ${relevantOrders.length} relevant orders');
          await _loadDashboardDataBackground();
          if (mounted) {
            setState(() {
              // Trigger UI update
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking for relevant orders: $e');
    }
  }

  Future<void> _initializeLocationTracking() async {
    try {
      // Set default location immediately for faster UI
      setState(() {
        _currentLocation = _defaultLocation;
      });

      // Initialize location tracking service in background
      await _locationTrackingService.initialize().then((_) async {
        // Request permissions and get location in background
        await _requestLocationPermissionsAndGetLocation();
      }).catchError((e) {
        debugPrint('Error initializing location tracking service: $e');
      });
    } catch (e) {
      debugPrint('Error initializing location tracking: $e');
      setState(() {
        _currentLocation = _defaultLocation;
      });
    }
  }

  Future<void> _requestLocationPermissionsAndGetLocation() async {
    try {
      // Request location permissions
      await _requestLocationPermissions();

      // Get current GPS location
      await _getCurrentGPSLocation();

      // Subscribe to real-time location updates
      _subscribeToLocationUpdates();
    } catch (e) {
      debugPrint('Error in background location setup: $e');
    }
  }

  Future<void> _requestLocationPermissions() async {
    try {
      // Check if location services are enabled
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('📍 Delivery Dashboard: Location services are disabled.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                  'Location services are disabled. Please enable them to track your location.'),
              action: SnackBarAction(
                label: 'Enable',
                onPressed: () async {
                  await Geolocator.openLocationSettings();
                },
              ),
            ),
          );
        }
        return;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('📍 Delivery Dashboard: Location permissions are denied');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Location permission is required to track your delivery location.'),
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint(
            '📍 Delivery Dashboard: Location permissions are permanently denied');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                  'Location permission is permanently denied. Please enable it in settings.'),
              action: SnackBarAction(
                label: 'Open Settings',
                onPressed: () async {
                  await Geolocator.openAppSettings();
                },
              ),
            ),
          );
        }
        return;
      }

      debugPrint('✅ Delivery Dashboard: Location permissions granted');

      // If permission is granted, ensure location services are enabled
      final serviceEnabledAfterPermission =
          await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabledAfterPermission) {
        debugPrint(
            '📍 Delivery Dashboard: Location services still disabled after permission grant');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                  'Please enable location services to track your location.'),
              action: SnackBarAction(
                label: 'Enable',
                onPressed: () async {
                  await Geolocator.openLocationSettings();
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint(
          '❌ Delivery Dashboard: Error requesting location permissions: $e');
    }
  }

  Future<void> _getCurrentGPSLocation() async {
    try {
      // Get current position using new API with faster timeout
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy:
              LocationAccuracy.medium, // Reduced accuracy for faster response
          timeLimit: Duration(seconds: 5), // Reduced timeout
        ),
      );

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });

      debugPrint(
          'GPS Location obtained: ${position.latitude}, ${position.longitude}');

      // Automatically focus camera on delivery person's location
      if (_isFollowingDeliveryPerson && _mapController != null) {
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(_currentLocation!, 15.0),
        );
        debugPrint('📍 Camera focused on delivery person location from GPS');
      }

      // Start location tracking and store in database
      if (_deliveryPerson != null) {
        await _locationTrackingService.startLocationTracking(
          deliveryPersonId: _deliveryPerson!.userId,
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
          speed: position.speed,
          heading: position.heading,
        );
      }

      // Start continuous location updates
      _startLocationUpdates();

      // Subscribe to real-time location updates
      if (_deliveryPerson != null) {
        _locationTrackingService
            .subscribeToLocationUpdates(_deliveryPerson!.userId);
        debugPrint('📍 Subscribed to real-time location updates');
      }
    } catch (e) {
      debugPrint('Error getting GPS location: $e');
      setState(() {
        _currentLocation = _defaultLocation;
      });
    }
  }

  void _startLocationUpdates() {
    if (_deliveryPerson == null) return;

    // Listen to location changes
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    ).listen((Position position) {
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);

          // Automatically focus camera on delivery person's location updates
          if (_isFollowingDeliveryPerson && _mapController != null) {
            _mapController!.animateCamera(
              CameraUpdate.newLatLngZoom(_currentLocation!, 15.0),
            );
          }
        });

        // Update location in database
        _locationTrackingService.updateLocation(
          deliveryPersonId: _deliveryPerson!.userId,
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
          speed: position.speed,
          heading: position.heading,
        );

        // Update map markers with fresh location
        _updateMapMarkersBackground();

        // If no task/order is selected, auto-locate to delivery person
        if (_selectedTask == null && _selectedOrder == null) {
          _autoLocateToDeliveryPerson();
        }
      }
    });
  }

  void _subscribeToLocationUpdates() {
    if (_deliveryPerson == null) return;

    _locationTrackingService
        .subscribeToLocationUpdates(_deliveryPerson!.userId);

    // Listen to location updates
    _locationTrackingService.addListener(() {
      if (mounted) {
        final recentLocations = _locationTrackingService.recentLocations;
        if (recentLocations.isNotEmpty) {
          final latestLocation = recentLocations.last;
          setState(() {
            _currentLocation =
                LatLng(latestLocation.latitude, latestLocation.longitude);
          });

          // Automatically focus camera on delivery person's location updates
          if (_isFollowingDeliveryPerson && _mapController != null) {
            _mapController!.animateCamera(
              CameraUpdate.newLatLngZoom(_currentLocation!, 15.0),
            );
            debugPrint(
                '📍 Camera focused on delivery person location from recent updates');
          }

          // Update map markers with fresh location
          _updateMapMarkersBackground();

          // If no task/order is selected, auto-locate to delivery person
          if (_selectedTask == null && _selectedOrder == null) {
            _autoLocateToDeliveryPerson();
          }
        }
      }
    });
  }

  void _autoLocateToDeliveryPerson() {
    if (_mapController == null || _currentLocation == null) return;

    _mapController!.animateCamera(
      CameraUpdate.newLatLngZoom(_currentLocation!, 15.0),
    );
  }

  void _zoomOutToAllLocations() {
    if (_mapController == null || _selectedTask == null) return;

    // Get all task locations
    final List<LatLng> taskLocations = [];

    // Add main task location
    taskLocations
        .add(LatLng(_selectedTask!.latitude, _selectedTask!.longitude));

    // Add additional locations if they exist
    if (_selectedTask!.additionalLocations != null) {
      for (final location in _selectedTask!.additionalLocations!) {
        taskLocations.add(LatLng(location['lat'], location['lng']));
      }
    }

    // Add delivery man's current location
    if (_currentLocation != null) {
      taskLocations.add(_currentLocation!);
    }

    // Fit map to show all locations
    _fitMapToLocations(taskLocations);
  }

  void _focusOnDeliveryManLocation() {
    if (_mapController == null || _currentLocation == null) return;

    try {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_currentLocation!, 16.0),
      );
    } catch (e) {
      debugPrint('Error focusing on delivery man location: $e');
    }
  }

  Future<void> _openGoogleMaps() async {
    try {
      LatLng? targetLocation;

      if (_selectedOrder != null) {
        // For orders, use delivery address
        final lat = _selectedOrder!.deliveryAddress.latitude;
        final lng = _selectedOrder!.deliveryAddress.longitude;

        if (lat != null && lng != null) {
          targetLocation = LatLng(lat, lng);
        }
      } else if (_selectedTask != null) {
        // For tasks, use task location
        final lat = _selectedTask!.latitude;
        final lng = _selectedTask!.longitude;

        targetLocation = LatLng(lat, lng);
      }

      if (targetLocation != null) {
        final url =
            'https://www.google.com/maps/dir/?api=1&destination=${targetLocation.latitude},${targetLocation.longitude}&travelmode=driving';
        if (await canLaunchUrl(Uri.parse(url))) {
          await launchUrl(Uri.parse(url));
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not open Google Maps'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location not available'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error opening Google Maps: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error opening Google Maps'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _fitMapToLocations(List<LatLng> locations) {
    if (_mapController == null || locations.isEmpty) return;

    try {
      if (locations.length == 1) {
        // If only one location, just center on it
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(locations.first, 15.0),
        );
        return;
      }

      // Calculate bounds for multiple locations
      double minLat = locations.first.latitude;
      double maxLat = locations.first.latitude;
      double minLng = locations.first.longitude;
      double maxLng = locations.first.longitude;

      for (final location in locations) {
        minLat = math.min(minLat, location.latitude);
        maxLat = math.max(maxLat, location.latitude);
        minLng = math.min(minLng, location.longitude);
        maxLng = math.max(maxLng, location.longitude);
      }

      // Add padding to the bounds
      final latPadding = (maxLat - minLat) * 0.1;
      final lngPadding = (maxLng - minLng) * 0.1;

      final bounds = LatLngBounds(
        southwest: LatLng(minLat - latPadding, minLng - lngPadding),
        northeast: LatLng(maxLat + latPadding, maxLng + lngPadding),
      );

      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100.0), // 100px padding
      );
    } catch (e) {
      debugPrint('Error fitting map to locations: $e');
    }
  }

  Future<void> _navigateToSpecificLocation(int locationIndex) async {
    if (_selectedTask == null) return;

    try {
      LatLng targetLocation;

      if (locationIndex == 0) {
        // Primary location
        targetLocation =
            LatLng(_selectedTask!.latitude, _selectedTask!.longitude);
      } else {
        // Additional location
        if (_selectedTask!.additionalLocations == null ||
            locationIndex - 1 >= _selectedTask!.additionalLocations!.length) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location not found')),
            );
          }
          return;
        }

        final additionalLocation =
            _selectedTask!.additionalLocations![locationIndex - 1];
        final latValue =
            additionalLocation['lat'] ?? additionalLocation['latitude'];
        final lngValue =
            additionalLocation['lng'] ?? additionalLocation['longitude'];

        if (latValue == null || lngValue == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Invalid location coordinates')),
            );
          }
          return;
        }

        targetLocation = LatLng(latValue.toDouble(), lngValue.toDouble());
      }

      // Create route from current location to target location
      await _createRouteToLocation(targetLocation);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Route displayed on map')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating route: $e')),
        );
      }
    }
  }

  Future<void> _createRouteToLocation(LatLng targetLocation) async {
    if (_currentLocation == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Current location not available')),
        );
      }
      return;
    }

    try {
      // Clear existing polylines
      setState(() {
        _polylines.clear();
      });

      // Create a simple straight-line route (you can enhance this with Google Directions API later)
      final routePoints = <LatLng>[
        _currentLocation!,
        targetLocation,
      ];

      // Create polyline for the route
      final polyline = Polyline(
        polylineId: const PolylineId('navigation_route'),
        points: routePoints,
        color: Colors.blue[600]!,
        width: 4,
        patterns: [
          PatternItem.dash(20),
          PatternItem.gap(10)
        ], // Dashed line for navigation
      );

      // Add polyline to the map
      setState(() {
        _polylines.add(polyline);
      });

      // Fit map to show both locations
      final bounds = LatLngBounds(
        southwest: LatLng(
          math.min(_currentLocation!.latitude, targetLocation.latitude),
          math.min(_currentLocation!.longitude, targetLocation.longitude),
        ),
        northeast: LatLng(
          math.max(_currentLocation!.latitude, targetLocation.latitude),
          math.max(_currentLocation!.longitude, targetLocation.longitude),
        ),
      );

      // Add padding to bounds
      final latPadding =
          (bounds.northeast.latitude - bounds.southwest.latitude) * 0.1;
      final lngPadding =
          (bounds.northeast.longitude - bounds.southwest.longitude) * 0.1;

      final paddedBounds = LatLngBounds(
        southwest: LatLng(
          bounds.southwest.latitude - latPadding,
          bounds.southwest.longitude - lngPadding,
        ),
        northeast: LatLng(
          bounds.northeast.latitude + latPadding,
          bounds.northeast.longitude + lngPadding,
        ),
      );

      // Animate camera to show the route
      if (_mapController != null) {
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(paddedBounds, 100.0),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating route: $e')),
        );
      }
    }
  }

  void _clearRoute() {
    setState(() {
      _polylines.clear();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Route cleared')),
      );
    }
  }

  void _toggleMapType() {
    setState(() {
      _currentMapType = _currentMapType == MapType.normal
          ? MapType.satellite
          : MapType.normal;
    });
  }

  Future<void> _initializeOrderTracking() async {
    try {
      // DISABLED: Order tracking initialization
      // await _orderTrackingService?.initialize();
      // await _enhancedTrackingService?.initialize();

      // DISABLED: Order tracking listener
      // _orderTrackingService?.addListener(_onOrderTrackingUpdate);
    } catch (e) {
      debugPrint('Error initializing order tracking: $e');
    }
  }

  Future<void> _initializeEarningsService() async {
    await _earningsService.initialize();
  }

  Future<void> _loadEarningsData() async {
    if (_deliveryPerson == null) {
      debugPrint('❌ Cannot load earnings data: Delivery person is null');
      return;
    }

    try {
      debugPrint(
          '💰 Loading earnings data for delivery person: ${_deliveryPerson!.id}');

      // Load wallet info - create default if not exists
      _walletInfo =
          await _earningsService.getWalletInfo(_deliveryPerson!.userId);
      if (_walletInfo == null) {
        debugPrint('📊 No wallet found, creating default wallet data');
        _walletInfo = {
          'current_balance': 0.0,
          'credit_balance': 0.0,
          'total_earned': 0.0,
          'total_service_fees_paid': 0.0,
        };
      }

      // Load credit transactions
      _creditTransactions = await _earningsService.getCreditTransactions(
        deliveryPersonId: _deliveryPerson!.userId,
        limit: 5, // Reduced from 10 for faster loading
      );
      debugPrint('📈 Loaded ${_creditTransactions.length} credit transactions');

      // Load pending service fees
      _pendingServiceFees =
          await _earningsService.getPendingServiceFees(_deliveryPerson!.userId);
      debugPrint(
          '⚠️ Loaded ${_pendingServiceFees.length} pending service fees');

      // Load daily earnings
      _dailyEarnings = await _earningsService.getDailyEarnings(
        deliveryPersonId: _deliveryPerson!.userId,
        days: 3, // Reduced from 7 for faster loading
      );
      debugPrint('📊 Loaded ${_dailyEarnings.length} daily earnings records');

      // Load earnings summary in background (non-blocking)
      await _earningsService
          .getEarningsSummary(
        deliveryPersonId: _deliveryPerson!.userId,
        startDate: DateTime.now().subtract(const Duration(days: 30)),
        endDate: DateTime.now(),
      )
          .then((summary) {
        debugPrint('📊 Earnings summary loaded in background');
      }).catchError((e) {
        debugPrint('Error loading earnings summary: $e');
      });

      debugPrint('✅ Earnings data loaded successfully');
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('❌ Error loading earnings data: $e');
      // Set default values on error
      _walletInfo = {
        'current_balance': 0.0,
        'credit_balance': 0.0,
        'total_earned': 0.0,
        'total_service_fees_paid': 0.0,
      };
      _creditTransactions = [];
      _pendingServiceFees = [];
      _dailyEarnings = [];

      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _loadDashboardDataOptimized() async {
    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUser = authService.currentUser;

      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final deliveryService =
          Provider.of<DeliveryService>(context, listen: false);

      // ✅ PERFORMANCE: Load delivery person profile first (essential)
      _deliveryPerson =
          await deliveryService.getDeliveryPersonByUserId(currentUser.id);

      if (_deliveryPerson != null) {
        _isOnline = _deliveryPerson!.isOnline;
        _isAvailable = _deliveryPerson!.isAvailable;

        // Show UI immediately with basic data
        setState(() => _isLoading = false);

        // ✅ PERFORMANCE: Load essential data in parallel
        await Future.wait([
          // ENABLED: Order loading for new enhanced order cards
          _loadActiveOrders(),
          _loadAvailableOrders(),
          _loadActiveTasks(),
        ]);

        // Initialize location tracking (essential for map)
        await _initializeLocationTracking();

        // Update map markers
        _updateMapMarkers();

        // ✅ PERFORMANCE: Load non-essential data in background
        unawaited(_loadNonEssentialDataInBackground());
      }
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadNonEssentialDataInBackground() async {
    try {
      // Load completed tasks only (orders disabled)
      await Future.wait([
        // DISABLED: Order loading
        // _loadCompletedOrders(),
        _loadAvailableTasks(),
        _loadCompletedTasks(),
      ]);

      // Load earnings data (non-critical for initial display)
      await _loadEarningsData();

      // Update map markers with all data
      _updateMapMarkers();
    } catch (e) {
      debugPrint('Error loading non-essential data: $e');
    }
  }

  Future<void> _initializeNonCriticalServices() async {
    // Initialize non-critical services in background
    try {
      await Future.wait([
        _initializeOrderTracking(),
        _initializeEarningsService(),
      ]);
    } catch (e) {
      debugPrint('Error initializing non-critical services: $e');
    }
  }

  Future<void> _loadDashboardDataBackground() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUser = authService.currentUser;

      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final deliveryService =
          Provider.of<DeliveryService>(context, listen: false);

      // Load delivery person profile
      _deliveryPerson =
          await deliveryService.getDeliveryPersonByUserId(currentUser.id);

      if (_deliveryPerson != null) {
        _isOnline = _deliveryPerson!.isOnline;
        _isAvailable = _deliveryPerson!.isAvailable;

        // DISABLED: Order loading
        await _loadActiveOrdersBackground();
        await _loadAvailableOrdersBackground();
        await _loadCompletedOrdersBackground();

        // Load tasks
        await _loadAvailableTasksBackground();
        await _loadActiveTasksBackground();
        await _loadCompletedTasksBackground();

        // Load earnings data
        await _loadEarningsDataBackground();

        // Update map markers without setState
        _updateMapMarkersBackground();

        // Trigger UI update after background data load
        if (mounted) {
          setState(() {
            // Trigger UI rebuild with new data
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading dashboard data in background: $e');
    }
  }

  // DISABLED: Order loading method
  Future<void> _loadActiveOrders() async {
    // ENABLED: Order logic restored for new enhanced order cards
    try {
      if (_deliveryPerson == null) return;

      debugPrint(
          '🔍 Loading active orders for delivery person: ${_deliveryPerson!.userId}');

      // Get the delivery_personnel.id for this user_id
      final deliveryPersonnelResponse = await Supabase.instance.client
          .from('delivery_personnel')
          .select('id')
          .eq('user_id', _deliveryPerson!.userId)
          .single();

      if (deliveryPersonnelResponse.isEmpty) {
        debugPrint(
            '❌ Delivery personnel record not found for user: ${_deliveryPerson!.userId}');
        return;
      }

      final deliveryPersonnelId = deliveryPersonnelResponse['id'];
      debugPrint('📋 Found delivery personnel ID: $deliveryPersonnelId');

      // Get active orders for this delivery person from orders table
      final activeOrdersResponse = await Supabase.instance.client
          .from('orders')
          .select('''
            *,
            restaurants!inner(*)
          ''')
          .eq('delivery_person_id', deliveryPersonnelId)
          .inFilter('status', ['preparing', 'ready', 'picked_up'])
          .order('created_at', ascending: false);

      final activeOrders = activeOrdersResponse.map((json) {
        // Debug: Check restaurant data in JSON
        debugPrint('🔍 Order JSON Debug:');
        debugPrint('  - Order ID: ${json['id']}');
        debugPrint('  - Restaurants key: ${json['restaurants']}');
        debugPrint('  - Restaurant key: ${json['restaurant']}');

        final order = Order.fromJson(json);
        debugPrint('  - Parsed restaurant: ${order.restaurant}');
        debugPrint('  - Parsed restaurant name: ${order.restaurant?.name}');
        return order;
      }).toList();

      debugPrint('📦 Found ${activeOrders.length} active orders');
      for (final order in activeOrders) {
        debugPrint(
            '  - Order ${order.id}: status=${order.status}, order_number=${order.orderNumber}');
      }

      setState(() {
        _activeOrders = activeOrders;
      });

      debugPrint('Loaded ${activeOrders.length} active orders');

      // Debug customer data
      for (final order in activeOrders) {
        debugPrint(
            'Order ${order.id} - Customer: ${order.customer?.name ?? 'No name'}, Phone: ${order.customer?.phone ?? 'No phone'}, Image: ${order.customer?.profileImage ?? 'No image'}');
      }
    } catch (e) {
      debugPrint('Error loading active orders: $e');
    }
  }

  // DISABLED: Order loading method
  Future<void> _loadAvailableOrders() async {
    // ENABLED: Order logic restored for new enhanced order cards
    try {
      debugPrint('🔍 Loading available orders...');

      // Get orders that are available for acceptance (not assigned to anyone)
      final availableOrdersResponse = await Supabase.instance.client
          .from('orders')
          .select('''
            *,
            restaurants!inner(*)
          ''')
          .isFilter('delivery_person_id', null)
          .inFilter('status', ['preparing', 'ready'])
          .order('created_at', ascending: false);

      final availableOrders =
          availableOrdersResponse.map((json) => Order.fromJson(json)).toList();

      debugPrint('📦 Found ${availableOrders.length} available orders');
      for (final order in availableOrders) {
        debugPrint(
            '  - Order ${order.id}: status=${order.status}, order_number=${order.orderNumber}');
      }

      setState(() {
        _availableOrders = availableOrders;
      });

      debugPrint(
          'Loaded ${availableOrders.length} available orders for acceptance');

      // Debug customer data
      for (final order in availableOrders) {
        debugPrint(
            'Available Order ${order.id} - Customer: ${order.customer?.name ?? 'No name'}, Phone: ${order.customer?.phone ?? 'No phone'}, Image: ${order.customer?.profileImage ?? 'No image'}');
      }
    } catch (e) {
      debugPrint('Error loading available orders: $e');
    }
  }

  // DISABLED: Order loading method

  Future<void> _loadAvailableTasks() async {
    try {
      // Load tasks from multiple sources
      final availableTasks =
          await _integratedService.getAvailableTasksForDelivery();
      final costProposedTasks =
          await _integratedService.getCostProposedTasksForDelivery();
      final userCounterProposedTasks =
          await _integratedService.getUserCounterProposedTasksForDelivery();

      // Combine all available tasks
      final allAvailableTasks = <Task>[];
      allAvailableTasks.addAll(availableTasks);
      allAvailableTasks.addAll(costProposedTasks);
      allAvailableTasks.addAll(userCounterProposedTasks);

      setState(() {
        _availableTasks = allAvailableTasks;
      });
      debugPrint(
          'Loaded ${allAvailableTasks.length} available tasks (${availableTasks.length} available + ${costProposedTasks.length} cost proposed + ${userCounterProposedTasks.length} user counter proposed)');
    } catch (e) {
      debugPrint('Error loading available tasks: $e');
    }
  }

  Future<void> _loadActiveTasks() async {
    try {
      if (_deliveryPerson == null) return;

      debugPrint(
          '🔍 Loading active tasks for delivery person: ${_deliveryPerson!.userId}');
      final activeTasks = await _integratedService
          .getActiveTasksForDelivery(_deliveryPerson!.userId);
      debugPrint('📋 Found ${activeTasks.length} active tasks');
      for (final task in activeTasks) {
        debugPrint(
            '  - Task ${task.id}: status=${task.status}, delivery_man_id=${task.deliveryManId}');
      }
      setState(() {
        _activeTasks = activeTasks;
      });
      debugPrint('Loaded ${activeTasks.length} active tasks');
    } catch (e) {
      debugPrint('Error loading active tasks: $e');
    }
  }

  Future<void> _loadCompletedTasks() async {
    try {
      if (_deliveryPerson == null) return;

      final completedTasks = await _integratedService
          .getCompletedTasksForDelivery(_deliveryPerson!.userId);
      setState(() {
        _completedTasks = completedTasks;
      });
      debugPrint('Loaded ${completedTasks.length} completed tasks');
    } catch (e) {
      debugPrint('Error loading completed tasks: $e');
    }
  }

  void _updateMapMarkers() {
    final markers = <Marker>{};
    final polylines = <Polyline>{};

    // Add current location marker
    if (_currentLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: _currentLocation!,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: const InfoWindow(title: 'Your Location'),
        ),
      );
    }

    // Handle selected order with status-based map behavior
    if (_selectedOrder != null) {
      _updateSelectedOrderMapView(markers, polylines);
    } else {
      // Default behavior for non-selected orders
      _updateDefaultOrderMarkers(markers, polylines);
    }

    setState(() {
      _markers = markers;
      _polylines.clear();
      _polylines.addAll(polylines);
    });
  }

  void _updateSelectedOrderMapView(
      Set<Marker> markers, Set<Polyline> polylines) {
    final order = _selectedOrder!;
    final trackingData = _orderTrackingService?.getOrderTrackingData(order.id);
    final currentStep = trackingData?.currentStep ?? OrderStep.accepted;

    switch (currentStep) {
      case OrderStep.accepted:
        // When reviewing order - show full route from current location to restaurant then to user
        _buildFullRouteMapView(order, trackingData, markers, polylines);
        break;
      case OrderStep.headingToRestaurant:
      case OrderStep.arrivedAtRestaurant:
        // When going for pickup - show route from current location to restaurant
        _buildPickupRouteMapView(order, trackingData, markers, polylines);
        break;
      case OrderStep.pickedUp:
      case OrderStep.headingToCustomer:
      case OrderStep.arrivedAtCustomer:
        // When going for delivery - show route from restaurant to user
        _buildDeliveryRouteMapView(order, trackingData, markers, polylines);
        break;
      case OrderStep.delivered:
        // Show completed delivery markers
        _buildDeliveredMapView(order, trackingData, markers, polylines);
        break;
    }
  }

  void _buildFullRouteMapView(Order order, OrderTrackingData? trackingData,
      Set<Marker> markers, Set<Polyline> polylines) {
    // Add restaurant marker
    if (trackingData?.restaurantLocation != null) {
      markers.add(
        Marker(
          markerId: MarkerId('restaurant_${order.id}'),
          position: trackingData!.restaurantLocation!,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: InfoWindow(
            title: 'Restaurant',
            snippet: _selectedOrder?.restaurant?.name ??
                order.restaurant?.name ??
                'Restaurant',
          ),
        ),
      );
    }

    // Add customer marker
    if (trackingData?.customerLocation != null) {
      markers.add(
        Marker(
          markerId: MarkerId('customer_${order.id}'),
          position: trackingData!.customerLocation!,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
          infoWindow: InfoWindow(
            title: 'Customer',
            snippet: order.customer?.name ?? 'Customer',
          ),
        ),
      );
    }

    // Add full route polyline (current -> restaurant -> customer)
    if (trackingData?.routePoints.isNotEmpty == true) {
      polylines.add(
        Polyline(
          polylineId: PolylineId('full_route_${order.id}'),
          points: trackingData!.routePoints,
          color: Colors.orange[600]!,
          width: 5,
          patterns: [],
        ),
      );
    }

    // Fit map to show full route
    _fitMapToFullRoute(trackingData);
  }

  void _buildPickupRouteMapView(Order order, OrderTrackingData? trackingData,
      Set<Marker> markers, Set<Polyline> polylines) {
    // Add restaurant marker
    if (trackingData?.restaurantLocation != null) {
      markers.add(
        Marker(
          markerId: MarkerId('restaurant_${order.id}'),
          position: trackingData!.restaurantLocation!,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: InfoWindow(
            title: 'Restaurant',
            snippet: _selectedOrder?.restaurant?.name ??
                order.restaurant?.name ??
                'Restaurant',
          ),
        ),
      );
    }

    // Add route polyline (current -> restaurant)
    if (trackingData?.routePoints.isNotEmpty == true) {
      polylines.add(
        Polyline(
          polylineId: PolylineId('pickup_route_${order.id}'),
          points: trackingData!.routePoints,
          color: Colors.orange[600]!,
          width: 5,
          patterns: [],
        ),
      );
    }

    // Fit map to show pickup route
    _fitMapToPickupRoute(trackingData);
  }

  void _buildDeliveryRouteMapView(Order order, OrderTrackingData? trackingData,
      Set<Marker> markers, Set<Polyline> polylines) {
    // Add restaurant marker (already visited)
    if (trackingData?.restaurantLocation != null) {
      markers.add(
        Marker(
          markerId: MarkerId('restaurant_${order.id}'),
          position: trackingData!.restaurantLocation!,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(
            title: 'Restaurant (Picked Up)',
            snippet: _selectedOrder?.restaurant?.name ??
                order.restaurant?.name ??
                'Restaurant',
          ),
        ),
      );
    }

    // Add customer marker
    if (trackingData?.customerLocation != null) {
      markers.add(
        Marker(
          markerId: MarkerId('customer_${order.id}'),
          position: trackingData!.customerLocation!,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
          infoWindow: InfoWindow(
            title: 'Customer',
            snippet: order.customer?.name ?? 'Customer',
          ),
        ),
      );
    }

    // Add delivery route polyline (restaurant -> customer)
    if (trackingData?.routePoints.isNotEmpty == true) {
      polylines.add(
        Polyline(
          polylineId: PolylineId('delivery_route_${order.id}'),
          points: trackingData!.routePoints,
          color: Colors.orange[600]!,
          width: 5,
          patterns: [],
        ),
      );
    }

    // Fit map to show delivery route
    _fitMapToDeliveryRoute(trackingData);
  }

  void _buildDeliveredMapView(Order order, OrderTrackingData? trackingData,
      Set<Marker> markers, Set<Polyline> polylines) {
    // Add completed markers
    if (trackingData?.restaurantLocation != null) {
      markers.add(
        Marker(
          markerId: MarkerId('restaurant_${order.id}'),
          position: trackingData!.restaurantLocation!,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(
            title: 'Restaurant (Completed)',
            snippet: _selectedOrder?.restaurant?.name ??
                order.restaurant?.name ??
                'Restaurant',
          ),
        ),
      );
    }

    if (trackingData?.customerLocation != null) {
      markers.add(
        Marker(
          markerId: MarkerId('customer_${order.id}'),
          position: trackingData!.customerLocation!,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(
            title: 'Customer (Delivered)',
            snippet: order.customer?.name ?? 'Customer',
          ),
        ),
      );
    }

    // Show completed route
    if (trackingData?.routePoints.isNotEmpty == true) {
      polylines.add(
        Polyline(
          polylineId: PolylineId('completed_route_${order.id}'),
          points: trackingData!.routePoints,
          color: Colors.green[600]!,
          width: 5,
          patterns: [],
        ),
      );
    }
  }

  void _updateDefaultOrderMarkers(
      Set<Marker> markers, Set<Polyline> polylines) {
    // Add active order markers
    for (int i = 0; i < _activeOrders.length; i++) {
      final order = _activeOrders[i];
      final trackingData =
          _orderTrackingService?.getOrderTrackingData(order.id);

      if (trackingData != null) {
        // Add restaurant marker
        if (trackingData.restaurantLocation != null) {
          markers.add(
            Marker(
              markerId: MarkerId('restaurant_${order.id}'),
              position: trackingData.restaurantLocation!,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueOrange),
              infoWindow: InfoWindow(
                title: 'Restaurant',
                snippet: _selectedOrder?.restaurant?.name ??
                    order.restaurant?.name ??
                    'Restaurant',
              ),
            ),
          );
        }

        // Add customer marker
        if (trackingData.customerLocation != null) {
          markers.add(
            Marker(
              markerId: MarkerId('customer_${order.id}'),
              position: trackingData.customerLocation!,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueViolet),
              infoWindow: InfoWindow(
                title: 'Customer',
                snippet: order.customer?.name ?? 'Customer',
              ),
            ),
          );
        }
      }
    }

    // Add available order markers
    for (int i = 0; i < _availableOrders.length; i++) {
      final order = _availableOrders[i];
      if (order.deliveryAddress.isNotEmpty) {
        final lat = order.deliveryAddress['latitude'] as double?;
        final lng = order.deliveryAddress['longitude'] as double?;

        if (lat != null && lng != null) {
          markers.add(
            Marker(
              markerId: MarkerId('available_order_${order.id}'),
              position: LatLng(lat, lng),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueGreen),
              infoWindow: InfoWindow(
                title: 'Order #${order.orderNumber}',
                snippet: 'Available',
              ),
              onTap: () => _onOrderMarkerTapped(order),
            ),
          );
        }
      }
    }

    // Add active task markers
    for (int i = 0; i < _activeTasks.length; i++) {
      final task = _activeTasks[i];
      markers.add(
        Marker(
          markerId: MarkerId('active_task_${task.id}'),
          position: LatLng(task.latitude, task.longitude),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: InfoWindow(
            title: 'Task #${task.id.substring(0, 8)}...',
            snippet: 'Active Task',
          ),
          onTap: () => _onTaskMarkerTapped(task),
        ),
      );
    }

    // Add available task markers
    for (int i = 0; i < _availableTasks.length; i++) {
      final task = _availableTasks[i];
      markers.add(
        Marker(
          markerId: MarkerId('available_task_${task.id}'),
          position: LatLng(task.latitude, task.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: InfoWindow(
            title: 'Task #${task.id.substring(0, 8)}...',
            snippet: 'Ifrili Task',
          ),
          onTap: () => _onTaskMarkerTapped(task),
        ),
      );
    }

    // Add completed order markers
    for (int i = 0; i < _completedOrders.length; i++) {
      final order = _completedOrders[i];
      if (order.deliveryAddress.isNotEmpty) {
        final lat = order.deliveryAddress['latitude'] as double?;
        final lng = order.deliveryAddress['longitude'] as double?;

        if (lat != null && lng != null) {
          markers.add(
            Marker(
              markerId: MarkerId('completed_order_${order.id}'),
              position: LatLng(lat, lng),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueGreen),
              infoWindow: InfoWindow(
                title: 'Order #${order.orderNumber}',
                snippet: 'Completed',
              ),
              onTap: () => _onOrderMarkerTapped(order),
            ),
          );
        }
      }
    }

    // Add completed task markers
    for (int i = 0; i < _completedTasks.length; i++) {
      final task = _completedTasks[i];
      markers.add(
        Marker(
          markerId: MarkerId('completed_task_${task.id}'),
          position: LatLng(task.latitude, task.longitude),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(
            title: 'Task #${task.id.substring(0, 8)}...',
            snippet: 'Completed Task',
          ),
          onTap: () => _onTaskMarkerTapped(task),
        ),
      );
    }
  }

  void _fitMapToFullRoute(OrderTrackingData? trackingData) {
    if (_mapController == null || trackingData == null) return;

    final bounds = _calculateBoundsForFullRoute(trackingData);
    if (bounds != null) {
      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
    }
  }

  void _fitMapToPickupRoute(OrderTrackingData? trackingData) {
    if (_mapController == null || trackingData == null) return;

    final bounds = _calculateBoundsForPickupRoute(trackingData);
    if (bounds != null) {
      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
    }
  }

  void _fitMapToDeliveryRoute(OrderTrackingData? trackingData) {
    if (_mapController == null || trackingData == null) return;

    final bounds = _calculateBoundsForDeliveryRoute(trackingData);
    if (bounds != null) {
      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
    }
  }

  LatLngBounds? _calculateBoundsForFullRoute(OrderTrackingData trackingData) {
    final points = <LatLng>[];

    if (_currentLocation != null) points.add(_currentLocation!);
    if (trackingData.restaurantLocation != null) {
      points.add(trackingData.restaurantLocation!);
    }
    if (trackingData.customerLocation != null) {
      points.add(trackingData.customerLocation!);
    }

    if (points.length < 2) return null;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      minLat = minLat < point.latitude ? minLat : point.latitude;
      maxLat = maxLat > point.latitude ? maxLat : point.latitude;
      minLng = minLng < point.longitude ? minLng : point.longitude;
      maxLng = maxLng > point.longitude ? maxLng : point.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  LatLngBounds? _calculateBoundsForPickupRoute(OrderTrackingData trackingData) {
    final points = <LatLng>[];

    if (_currentLocation != null) points.add(_currentLocation!);
    if (trackingData.restaurantLocation != null) {
      points.add(trackingData.restaurantLocation!);
    }

    if (points.length < 2) return null;

    return LatLngBounds(
      southwest: LatLng(
        _currentLocation!.latitude < trackingData.restaurantLocation!.latitude
            ? _currentLocation!.latitude
            : trackingData.restaurantLocation!.latitude,
        _currentLocation!.longitude < trackingData.restaurantLocation!.longitude
            ? _currentLocation!.longitude
            : trackingData.restaurantLocation!.longitude,
      ),
      northeast: LatLng(
        _currentLocation!.latitude > trackingData.restaurantLocation!.latitude
            ? _currentLocation!.latitude
            : trackingData.restaurantLocation!.latitude,
        _currentLocation!.longitude > trackingData.restaurantLocation!.longitude
            ? _currentLocation!.longitude
            : trackingData.restaurantLocation!.longitude,
      ),
    );
  }

  LatLngBounds? _calculateBoundsForDeliveryRoute(
      OrderTrackingData trackingData) {
    if (trackingData.restaurantLocation == null ||
        trackingData.customerLocation == null) {
      return null;
    }

    return LatLngBounds(
      southwest: LatLng(
        trackingData.restaurantLocation!.latitude <
                trackingData.customerLocation!.latitude
            ? trackingData.restaurantLocation!.latitude
            : trackingData.customerLocation!.latitude,
        trackingData.restaurantLocation!.longitude <
                trackingData.customerLocation!.longitude
            ? trackingData.restaurantLocation!.longitude
            : trackingData.customerLocation!.longitude,
      ),
      northeast: LatLng(
        trackingData.restaurantLocation!.latitude >
                trackingData.customerLocation!.latitude
            ? trackingData.restaurantLocation!.latitude
            : trackingData.customerLocation!.latitude,
        trackingData.restaurantLocation!.longitude >
                trackingData.customerLocation!.longitude
            ? trackingData.restaurantLocation!.longitude
            : trackingData.customerLocation!.longitude,
      ),
    );
  }

  void _onOrderMarkerTapped(Order order) {
    // Don't allow selection of completed orders
    if (order.status == OrderStatus.delivered) {
      return;
    }

    setState(() {
      _selectedOrder = order;
      _currentBottomNavIndex = 0; // Switch to map view
      if (order.deliveryAddress.isNotEmpty) {
        final lat = order.deliveryAddress['latitude'] as double?;
        final lng = order.deliveryAddress['longitude'] as double?;
        if (lat != null && lng != null) {
          _selectedOrderLocation = LatLng(lat, lng);
        }
      }
    });

    // Move camera to selected order
    if (_selectedOrderLocation != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(_selectedOrderLocation!),
      );
    }
  }

  void _onTaskMarkerTapped(Task task) {
    // Don't allow selection of completed tasks
    if (task.status == TaskStatus.completed) {
      return;
    }

    setState(() {
      _selectedTask = task;
      _currentBottomNavIndex = 0; // Switch to map view
      _isTaskHeaderExpanded = false;
      _isTaskDescriptionExpanded = false;
    });

    // Update map camera to show all task locations
    _updateMapCamera();
  }

  void _updateMapCamera() {
    if (_mapController == null) return;

    try {
      // If a specific order or task is selected, use their specific camera logic
      if (_selectedOrder != null) {
        // Order-specific camera logic is handled in _updateSelectedOrderMapView
        return;
      }

      if (_selectedTask != null) {
        // Task-specific camera logic - show all task locations
        _fitMapToTaskLocations();
        return;
      }

      // Default behavior: fit map to show all markers (delivery person + all tasks/orders)
      _fitMapToAllMarkers();
    } catch (e) {
      debugPrint('Error updating map camera: $e');
    }
  }

  void _fitMapToTaskLocations() {
    if (_mapController == null || _selectedTask == null) return;

    final List<LatLng> points = [];

    // Add current location
    if (_currentLocation != null) {
      points.add(_currentLocation!);
    }

    // Add primary task location
    points.add(LatLng(_selectedTask!.latitude, _selectedTask!.longitude));

    // Add additional task locations
    if (_selectedTask!.additionalLocations != null) {
      for (final loc in _selectedTask!.additionalLocations!) {
        final latValue = loc['lat'] ?? loc['latitude'];
        final lngValue = loc['lng'] ?? loc['longitude'];
        if (latValue != null && lngValue != null) {
          try {
            final lat = double.parse(latValue.toString());
            final lng = double.parse(lngValue.toString());
            points.add(LatLng(lat, lng));
          } catch (e) {
            // Skip invalid coordinates
          }
        }
      }
    }

    if (points.isNotEmpty) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(
          _getBoundsFromLatLngList(points),
          80.0, // padding
        ),
      );
    }
  }

  LatLngBounds _getBoundsFromLatLngList(List<LatLng> list) {
    double? x0, x1, y0, y1;
    for (final LatLng latLng in list) {
      if (x0 == null) {
        x0 = x1 = latLng.latitude;
        y0 = y1 = latLng.longitude;
      } else {
        if (latLng.latitude > x1!) x1 = latLng.latitude;
        if (latLng.latitude < x0) x0 = latLng.latitude;
        if (latLng.longitude > y1!) y1 = latLng.longitude;
        if (latLng.longitude < y0!) y0 = latLng.longitude;
      }
    }
    return LatLngBounds(
        northeast: LatLng(x1!, y1!), southwest: LatLng(x0!, y0!));
  }

  void _fitMapToAllMarkers() {
    if (_mapController == null) return;

    final List<LatLng> points = [];

    // Add current location
    if (_currentLocation != null) {
      points.add(_currentLocation!);
    }

    // Add all available order locations
    for (final order in _availableOrders) {
      final lat = order.deliveryAddress['latitude'] as double?;
      final lng = order.deliveryAddress['longitude'] as double?;
      if (lat != null && lng != null) {
        points.add(LatLng(lat, lng));
      }
    }

    // Add all active task locations
    for (final task in _activeTasks) {
      points.add(LatLng(task.latitude, task.longitude));
    }

    // Add all available task locations
    for (final task in _availableTasks) {
      points.add(LatLng(task.latitude, task.longitude));
    }

    // Add all completed order locations
    for (final order in _completedOrders) {
      final lat = order.deliveryAddress['latitude'] as double?;
      final lng = order.deliveryAddress['longitude'] as double?;
      if (lat != null && lng != null) {
        points.add(LatLng(lat, lng));
      }
    }

    // Add all completed task locations
    for (final task in _completedTasks) {
      points.add(LatLng(task.latitude, task.longitude));
    }

    // If we have points, fit the map to show all of them
    if (points.isNotEmpty) {
      final bounds = _calculateBoundsFromPoints(points);
      if (bounds != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 100),
        );
      }
    } else if (_currentLocation != null) {
      // Fallback to current location if no other points
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_currentLocation!, 15.0),
      );
    }
  }

  LatLngBounds? _calculateBoundsFromPoints(List<LatLng> points) {
    if (points.isEmpty) return null;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  // Order acceptance method - RE-ENABLED
  Future<void> _acceptOrder(Order order) async {
    if (_deliveryPerson == null) {
      debugPrint('❌ Cannot accept order: Delivery person is null');
      return;
    }

    if (!_deliveryPerson!.isOnline || !_deliveryPerson!.isAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'You must be online and available to accept orders.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red[600],
          ),
        );
      }
      return;
    }

    try {
      // Start performance timer for order acceptance
      _logger.startPerformanceTimer('order_acceptance', metadata: {
        'order_id': order.id,
        'delivery_person_id': _deliveryPerson?.userId,
        'restaurant_id': order.restaurantId,
      });

      // Log order acceptance start
      _logger.logUserAction(
        'order_acceptance_started',
        userId: _deliveryPerson?.userId,
        data: {
          'order_id': order.id,
          'restaurant_id': order.restaurantId,
          'customer_id': order.customerId,
          'order_total': order.totalAmount,
          'delivery_fee': order.deliveryFee,
        },
      );

      setState(() => _isLoading = true);

      // Use OrderAssignmentService for consistent behavior
      final orderAssignmentService = OrderAssignmentService();
      final success = await orderAssignmentService.acceptOrderByDeliveryPerson(
        orderId: order.id,
        deliveryPersonId: _deliveryPerson!.userId,
      );

      if (success) {
        // Ensure delivery person remains available after accepting order
        try {
          await Supabase.instance.client.from('delivery_personnel').update(
              {'is_available': true}).eq('user_id', _deliveryPerson!.userId);
          debugPrint(
              '✅ Delivery person availability maintained after order acceptance');
        } catch (e) {
          debugPrint('⚠️ Could not update delivery person availability: $e');
        }

        // Update local state
        setState(() {
          _availableOrders.removeWhere((o) => o.id == order.id);
          // Create a new Order instance with updated status
          final updatedOrder = Order(
            id: order.id,
            restaurantId: order.restaurantId,
            customerId: order.customerId,
            deliveryPersonId: _deliveryPerson!.userId,
            orderNumber: order.orderNumber,
            status: OrderStatus.ready,
            paymentStatus: order.paymentStatus,
            subtotal: order.subtotal,
            deliveryFee: order.deliveryFee,
            taxAmount: order.taxAmount,
            serviceFee: order.serviceFee,
            discountAmount: order.discountAmount,
            totalAmount: order.totalAmount,
            paymentMethod: order.paymentMethod,
            deliveryAddress: order.deliveryAddress,
            specialInstructions: order.specialInstructions,
            estimatedDeliveryTime: order.estimatedDeliveryTime,
            actualDeliveryTime: order.actualDeliveryTime,
            appliedPromoCodeId: order.appliedPromoCodeId,
            appliedPromoCode: order.appliedPromoCode,
            createdAt: order.createdAt,
            updatedAt: DateTime.now(),
            restaurant: order.restaurant,
            customer: order.customer,
            deliveryPerson: order.deliveryPerson,
            orderItems: order.orderItems,
          );
          _activeOrders.insert(0, updatedOrder);
          _selectedOrder = updatedOrder;
        });

        // Update map markers
        _updateMapMarkers();

        // Log successful order acceptance
        _logger.logUserAction(
          'order_accepted_successfully',
          userId: _deliveryPerson?.userId,
          data: {
            'order_id': order.id,
            'restaurant_id': order.restaurantId,
            'customer_id': order.customerId,
            'order_total': order.totalAmount,
            'delivery_fee': order.deliveryFee,
            'acceptance_time': DateTime.now().toIso8601String(),
          },
        );

        // Log business metrics for order acceptance
        _logger.logLocationMetrics(
          deliveryPersonId: _deliveryPerson?.userId ?? '',
          latitude: _currentLocation?.latitude ?? 0,
          longitude: _currentLocation?.longitude ?? 0,
          additionalData: {
            'operation': 'order_acceptance',
            'order_id': order.id,
            'restaurant_id': order.restaurantId,
            'customer_id': order.customerId,
            'order_total': order.totalAmount,
            'delivery_fee': order.deliveryFee,
            'acceptance_time': DateTime.now().toIso8601String(),
          },
        );

        _logger.endPerformanceTimer('order_acceptance',
            details: 'Order accepted successfully');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Order ${order.orderNumber} accepted successfully',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.green[600],
            ),
          );
        }
      } else {
        throw Exception('Failed to accept order');
      }
    } catch (e) {
      _logger.error(
        'Failed to accept order',
        tag: 'ORDER',
        error: e,
        additionalData: {
          'order_id': order.id,
          'delivery_person_id': _deliveryPerson?.userId,
          'restaurant_id': order.restaurantId,
        },
      );

      _logger.endPerformanceTimer('order_acceptance',
          details: 'Order acceptance failed');

      debugPrint('Error accepting order: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error accepting order: ${e.toString()}',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // New order action methods for map view
  Future<void> _refuseOrder(Order order) async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Order #${order.orderNumber} refused',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red[600],
          ),
        );
      }

      // Remove from available orders
      setState(() {
        _availableOrders.removeWhere((o) => o.id == order.id);
        _selectedOrder = null;
        _selectedOrderLocation = null;
      });

      _updateMapMarkers();
    } catch (e) {
      debugPrint('Error refusing order: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error refusing order: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    }
  }

  Future<void> _markAsPickedUp(Order order) async {
    try {
      setState(() => _isLoading = true);

      // Update order status to picked_up
      await Supabase.instance.client.from('orders').update({
        'status': 'picked_up',
        'actual_pickup_time': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String()
      }).eq('id', order.id);

      // Update local state - use same pattern as _acceptOrder
      setState(() {
        final orderIndex = _activeOrders.indexWhere((o) => o.id == order.id);
        if (orderIndex != -1) {
          // Create a new Order instance with updated status
          final updatedOrder = Order(
            id: order.id,
            restaurantId: order.restaurantId,
            customerId: order.customerId,
            deliveryPersonId: order.deliveryPersonId,
            orderNumber: order.orderNumber,
            status: OrderStatus.pickedUp,
            paymentStatus: order.paymentStatus,
            subtotal: order.subtotal,
            deliveryFee: order.deliveryFee,
            taxAmount: order.taxAmount,
            serviceFee: order.serviceFee,
            discountAmount: order.discountAmount,
            totalAmount: order.totalAmount,
            paymentMethod: order.paymentMethod,
            deliveryAddress: order.deliveryAddress,
            specialInstructions: order.specialInstructions,
            estimatedDeliveryTime: order.estimatedDeliveryTime,
            actualDeliveryTime: order.actualDeliveryTime,
            appliedPromoCodeId: order.appliedPromoCodeId,
            appliedPromoCode: order.appliedPromoCode,
            createdAt: order.createdAt,
            updatedAt: DateTime.now(),
            restaurant: order.restaurant,
            customer: order.customer,
            deliveryPerson: order.deliveryPerson,
            orderItems: order.orderItems,
          );
          _activeOrders[orderIndex] = updatedOrder;
          _selectedOrder = updatedOrder;
        }
      });

      // Update map markers
      _updateMapMarkers();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Order #${order.orderNumber} marked as picked up!',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green[600],
          ),
        );
      }
    } catch (e) {
      debugPrint('Error marking order as picked up: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error marking order as picked up: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsDelivered(Order order) async {
    // Show Street View verification dialog first
    final verified = await _showStreetViewVerificationDialog(order);
    if (!verified) {
      return; // User cancelled or verification failed
    }

    try {
      // Start performance timer for delivery completion
      _logger.startPerformanceTimer('delivery_completion', metadata: {
        'order_id': order.id,
        'delivery_person_id': _deliveryPerson?.userId,
        'restaurant_id': order.restaurantId,
      });

      // Log delivery completion start
      _logger.logUserAction(
        'delivery_completion_started',
        userId: _deliveryPerson?.userId,
        data: {
          'order_id': order.id,
          'restaurant_id': order.restaurantId,
          'customer_id': order.customerId,
          'order_total': order.totalAmount,
          'delivery_fee': order.deliveryFee,
        },
      );

      setState(() => _isLoading = true);

      // Update order status to delivered
      await Supabase.instance.client.from('orders').update({
        'status': 'delivered',
        'actual_delivery_time': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String()
      }).eq('id', order.id);

      // Move from active to completed - use same pattern as _acceptOrder
      setState(() {
        _activeOrders.removeWhere((o) => o.id == order.id);

        // Create a new Order instance with updated status
        final completedOrder = Order(
          id: order.id,
          restaurantId: order.restaurantId,
          customerId: order.customerId,
          deliveryPersonId: order.deliveryPersonId,
          orderNumber: order.orderNumber,
          status: OrderStatus.delivered,
          paymentStatus: order.paymentStatus,
          subtotal: order.subtotal,
          deliveryFee: order.deliveryFee,
          taxAmount: order.taxAmount,
          serviceFee: order.serviceFee,
          discountAmount: order.discountAmount,
          totalAmount: order.totalAmount,
          paymentMethod: order.paymentMethod,
          deliveryAddress: order.deliveryAddress,
          specialInstructions: order.specialInstructions,
          estimatedDeliveryTime: order.estimatedDeliveryTime,
          actualDeliveryTime: DateTime.now(),
          appliedPromoCodeId: order.appliedPromoCodeId,
          appliedPromoCode: order.appliedPromoCode,
          createdAt: order.createdAt,
          updatedAt: DateTime.now(),
          restaurant: order.restaurant,
          customer: order.customer,
          deliveryPerson: order.deliveryPerson,
          orderItems: order.orderItems,
        );

        _completedOrders.insert(0, completedOrder);
        _selectedOrder = null;
        _selectedOrderLocation = null;

        // Stop location tracking for this delivery
        if (_deliveryPerson != null) {
          _locationTrackingService
              .stopLocationTracking(_deliveryPerson!.userId);
          debugPrint('📍 Location tracking stopped for delivery completion');
        }
      });

      // Update map markers
      _updateMapMarkers();

      // Log successful delivery completion
      _logger.logUserAction(
        'delivery_completed_successfully',
        userId: _deliveryPerson?.userId,
        data: {
          'order_id': order.id,
          'restaurant_id': order.restaurantId,
          'customer_id': order.customerId,
          'order_total': order.totalAmount,
          'delivery_fee': order.deliveryFee,
          'completion_time': DateTime.now().toIso8601String(),
        },
      );

      // Log business metrics for delivery completion
      _logger.logLocationMetrics(
        deliveryPersonId: _deliveryPerson?.userId ?? '',
        latitude: _currentLocation?.latitude ?? 0,
        longitude: _currentLocation?.longitude ?? 0,
        additionalData: {
          'operation': 'delivery_completion',
          'order_id': order.id,
          'restaurant_id': order.restaurantId,
          'customer_id': order.customerId,
          'order_total': order.totalAmount,
          'delivery_fee': order.deliveryFee,
          'completion_time': DateTime.now().toIso8601String(),
        },
      );

      _logger.endPerformanceTimer('delivery_completion',
          details: 'Delivery completed successfully');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Order #${order.orderNumber} marked as delivered!',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green[600],
          ),
        );
      }
    } catch (e) {
      _logger.error(
        'Failed to mark order as delivered',
        tag: 'DELIVERY',
        error: e,
        additionalData: {
          'order_id': order.id,
          'delivery_person_id': _deliveryPerson?.userId,
          'restaurant_id': order.restaurantId,
        },
      );

      _logger.endPerformanceTimer('delivery_completion',
          details: 'Delivery completion failed');

      debugPrint('Error marking order as delivered: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error marking order as delivered: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Show Street View verification dialog for delivery completion
  Future<bool> _showStreetViewVerificationDialog(Order order) async {
    // Check if we have delivery address coordinates
    if (order.deliveryAddress['latitude'] == null ||
        order.deliveryAddress['longitude'] == null) {
      // No coordinates available, proceed without verification
      return true;
    }

    final deliveryLocation = LatLng(
      order.deliveryAddress['latitude'],
      order.deliveryAddress['longitude'],
    );

    // Check if Street View is available
    final isStreetViewAvailable =
        await StreetViewService.isStreetViewAvailable(deliveryLocation);

    if (!isStreetViewAvailable) {
      // Street View not available, proceed without verification
      return true;
    }

    // Generate Street View URL
    final streetViewUrl = StreetViewService.generateOrderVerificationStreetView(
      location: deliveryLocation,
      width: 400,
      height: 300,
    );

    // Show verification dialog
    if (!mounted) return false;
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(
                    Icons.streetview,
                    color: Color(0xFFd47b00),
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Delivery Verification',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Please verify you are at the correct delivery location:',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          streetViewUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[100],
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.streetview,
                                    color: Colors.grey[400],
                                    size: 48,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Street View unavailable',
                                    style: GoogleFonts.poppins(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.blue[600],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Order #${order.orderNumber}\n${order.deliveryAddress['fullAddress'] ?? 'Delivery Address'}',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.blue[800],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFd47b00),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Confirm Delivery',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<void> _toggleOnlineStatus() async {
    if (_deliveryPerson == null) return;

    try {
      final deliveryService =
          Provider.of<DeliveryService>(context, listen: false);
      final bool newAvailable = !_isAvailable;

      debugPrint('🔄 Toggling availability:');
      debugPrint('  - Delivery Person ID: ${_deliveryPerson!.id}');
      debugPrint('  - Current Available: $_isAvailable');
      debugPrint('  - New Available: $newAvailable');
      debugPrint('  - Current Online: $_isOnline');

      final success = await deliveryService.updateDeliveryPersonStatus(
        deliveryPersonId:
            _deliveryPerson!.id, // Use delivery_personnel.id, not user_id
        isAvailable: newAvailable,
        isOnline: _isOnline, // Keep online status unchanged
      );

      debugPrint('✅ Database update result: $success');

      if (success) {
        setState(() {
          _isAvailable = newAvailable;
        });
        await _loadDashboardDataOptimized();
      }
    } catch (e) {
      debugPrint('Error toggling availability status: $e');
    }
  }

  // Widget methods continue...

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Exit Delivery Dashboard'),
          content: const Text(
              'Are you sure you want to exit the delivery dashboard?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Exit dashboard
              },
              child: const Text('Exit'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GeolocationServiceWrapper(
      enableDebugMode: false, // Set to true for debugging
      onLocationUpdate: () {
        // Handle location updates for delivery map dashboard
        if (_mapController != null && _currentLocation != null) {
          _updateMapElements();
        }
      },
      onError: (error) {
        // Handle geolocation errors silently
        // Error handling can be implemented here if needed
      },
      child: PopScope(
        canPop: false, // Prevent system back button from navigating away
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          // Handle back button press - show confirmation dialog
          _showExitConfirmation();
        },
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
            systemNavigationBarColor: Colors.white,
            systemNavigationBarIconBrightness: Brightness.dark,
          ),
          child: Scaffold(
            backgroundColor: Colors.grey[50],
            body: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _deliveryPerson == null
                    ? _buildNoProfileView()
                    : _buildMapDashboard(),
          ),
        ),
      ),
    );
  }

  void _updateMapElements() {
    // Update map elements when location changes
    if (_mapController != null && _currentLocation != null) {
      // Update map camera to follow current location
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(_currentLocation!.latitude, _currentLocation!.longitude),
        ),
      );
    }
  }

  Widget _buildMapDashboard() {
    return Stack(
      children: [
        // Main Content based on selected tab - extends into status bar
        Positioned.fill(
          child: _buildMainContent(),
        ),

        // Top Overlay (only show on map tab) - positioned with safe area
        if (_currentBottomNavIndex == 0)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: _selectedOrder != null
                  ? GestureDetector(
                      onTap: () {
                        // Block taps from reaching the map
                      },
                      child: _buildMapOrderHeader(),
                    )
                  : _selectedTask != null
                      ? GestureDetector(
                          onTap: () {
                            // Block taps from reaching the map
                          },
                          child: _buildTaskInfoHeader(),
                        )
                      : DeliveryMapOverlay(
                          isOnline: _isOnline,
                          isAvailable: _isAvailable,
                          onToggleOnline: _toggleOnlineStatus,
                          activeOrdersCount:
                              _activeOrders.length + _activeTasks.length,
                          availableOrdersCount:
                              _availableOrders.length + _availableTasks.length,
                          onBackPressed: () {
                            // Navigate to home screen
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                  builder: (context) => const HomeScreen()),
                              (route) => false, // Remove all previous routes
                            );
                          },
                        ),
            ),
          ),

        // Google Maps Button for Order (positioned above order card)
        if (_currentBottomNavIndex == 0 && _selectedOrder != null)
          Positioned(
            bottom: 200, // Position above the order card
            left: 16,
            child: _buildGoogleMapsButton(),
          ),

        // Enhanced Order Card for Map View
        if (_currentBottomNavIndex == 0 && _selectedOrder != null)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: MapOrderCard(
              order: _selectedOrder!,
              onRefuse: () => _refuseOrder(_selectedOrder!),
              onAccept: () => _acceptOrder(_selectedOrder!),
              onMarkPickedUp: () => _markAsPickedUp(_selectedOrder!),
              onMarkDelivered: () => _markAsDelivered(_selectedOrder!),
            ),
          ),

        // Google Maps Button for Task (positioned above task card)
        if (_currentBottomNavIndex == 0 && _selectedTask != null)
          Positioned(
            bottom: 200, // Position above the task card
            left: 16,
            child: _buildGoogleMapsButton(),
          ),

        // Selected Task Card (only show on map tab)
        if (_currentBottomNavIndex == 0 && _selectedTask != null)
          Positioned(
            bottom: 0, // Extend to bottom of screen
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: MediaQuery.of(context).size.width *
                    0.90, // 90% of screen width
                child: GestureDetector(
                  onTap: () {
                    // Block taps from reaching the map
                    // This prevents map interactions when tapping the task card area
                  },
                  child: _buildTaskInfoCard(),
                ),
              ),
            ),
          ),

        // Bottom Navigation (hide when in task map view mode or when order is selected)
        if (!(_currentBottomNavIndex == 0 && _selectedTask != null) &&
            _selectedOrder == null)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: DeliveryBottomNavigation(
                selectedIndex: _currentBottomNavIndex,
                onItemTapped: (index) {
                  setState(() {
                    _currentBottomNavIndex = index;
                  });
                },
                activeOrdersCount: _activeOrders.length + _activeTasks.length,
                availableOrdersCount:
                    _availableOrders.length + _availableTasks.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMainContent() {
    switch (_currentBottomNavIndex) {
      case 0:
        return _buildMapView();
      case 1:
        // Hide orders view container when an order is selected in map view
        if (_selectedOrder != null) {
          return const SizedBox.shrink();
        }
        return _buildOrdersView();
      case 2:
        return _buildEarningsView();
      case 3:
        // Load profile data when navigating to profile section
        if (_deliveryPerson != null) {
          _initializeProfileControllers();
          // Refresh delivery person data to get updated profile image
          _loadDeliveryPerson();
        }
        return _buildProfileView();
      default:
        return _buildMapView();
    }
  }

  Widget _buildLocationFocusButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FloatingActionButton(
        mini: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFFd47b00),
        onPressed: _focusOnDeliveryManLocation,
        heroTag: 'location_focus_main', // Unique Hero tag
        child: const Icon(Icons.my_location, size: 20),
      ),
    );
  }

  Widget _buildGoogleMapsButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _openGoogleMaps,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Google Maps Icon
                const Icon(
                  Icons.map_outlined,
                  color: Color(0xFF4285F4), // Google Blue
                  size: 16,
                ),
                const SizedBox(width: 6),
                // Google Maps Text
                Text(
                  'Google Maps',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMapView() {
    return Stack(
      children: [
        SizedBox(
          height: double.infinity,
          child: GoogleMap(
            onMapCreated: (GoogleMapController controller) {
              try {
                _mapController = controller;
                _updateMapCamera();
              } catch (e) {
                debugPrint('Error initializing map controller: $e');
              }
            },
            initialCameraPosition: CameraPosition(
              target: _currentLocation ?? _defaultLocation,
              zoom: _selectedTask != null
                  ? 12.0
                  : 15.0, // Zoom out when task is selected
            ),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
            mapToolbarEnabled: false,
            mapType: _currentMapType,
            style: _mapStyle,
            onCameraMove: (CameraPosition position) {
              // Camera moved - could add zoom tracking here if needed
            },
            buildingsEnabled: true,
            trafficEnabled: false,
            compassEnabled: true,
            onTap: (LatLng position) {
              setState(() {
                _selectedOrder = null;
                _selectedOrderLocation = null;
                _selectedTask = null;
                _isTaskHeaderExpanded = false;
                _isTaskDescriptionExpanded = false;
              });
            },
          ),
        ),

        // Location focus button (always visible)
        Positioned(
          right: 16,
          bottom: 120, // Position above bottom navigation
          child: _buildLocationFocusButton(),
        ),

        // Map type toggle button (always visible)
        Positioned(
          right: 16,
          bottom: 180, // Position above location focus button
          child: FloatingActionButton(
            mini: true,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            onPressed: _toggleMapType,
            heroTag: 'map_type_toggle_main', // Unique Hero tag
            child: Icon(
                _currentMapType == MapType.normal ? Icons.satellite : Icons.map,
                size: 20),
          ),
        ),

        // Map control buttons (only show when a task is selected)
        if (_selectedTask != null)
          Positioned(
            right: 16,
            bottom: _isTaskHeaderExpanded ? 450 : 200, // Simplified positioning
            child: Column(
              children: [
                // Focus on delivery man location button
                FloatingActionButton(
                  mini: true,
                  backgroundColor:
                      Colors.orange[600], // Changed from blue to orange
                  foregroundColor: Colors.white,
                  onPressed: _focusOnDeliveryManLocation,
                  heroTag: 'location_focus_task', // Unique Hero tag
                  child: const Icon(Icons.my_location, size: 20),
                ),
                const SizedBox(height: 8),
                // Zoom out to show all locations button
                FloatingActionButton(
                  mini: true,
                  backgroundColor: Colors.white, // Changed from green to white
                  foregroundColor:
                      Colors.black, // Changed text color to black for contrast
                  onPressed: _zoomOutToAllLocations,
                  heroTag: 'zoom_out_task', // Unique Hero tag
                  child: const Icon(Icons.zoom_out_map, size: 20),
                ),
                const SizedBox(height: 8),
                // Clear route button (only show if there's a route)
                if (_polylines.isNotEmpty)
                  FloatingActionButton(
                    mini: true,
                    backgroundColor: Colors.red[600],
                    foregroundColor: Colors.white,
                    onPressed: _clearRoute,
                    heroTag: 'clear_route_task', // Unique Hero tag
                    child: const Icon(Icons.clear, size: 20),
                  ),
                if (_polylines.isNotEmpty) const SizedBox(height: 8),
                // Map type toggle button
                FloatingActionButton(
                  mini: true,
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  onPressed: _toggleMapType,
                  heroTag: 'map_type_toggle_task', // Unique Hero tag
                  child: Icon(
                      _currentMapType == MapType.normal
                          ? Icons.satellite
                          : Icons.map,
                      size: 20),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildOrdersView() {
    return Container(
      color: Colors.grey[50],
      child: SafeArea(
        child: Column(
          children: [
            // App Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: AppHeader(
                title: 'Orders',
                onBack: () {
                  setState(() {
                    _currentBottomNavIndex = 0;
                  });
                },
                trailingAction: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFd47b00).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_activeOrders.length + _availableOrders.length + _completedOrders.length + _activeTasks.length + _availableTasks.length + _completedTasks.length}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFd47b00),
                    ),
                  ),
                ),
              ),
            ),

            // Filter Tab Bar
            OrdersFilterTabBar(
              selectedIndex: _ordersFilterIndex,
              onTabSelected: (index) {
                setState(() {
                  _ordersFilterIndex = index;
                });
              },
              availableCount: _availableOrders.length + _availableTasks.length,
              activeCount: _activeOrders.length + _activeTasks.length,
              completedCount: _completedOrders.length + _completedTasks.length,
            ),

            const SizedBox(height: 16),

            // Orders List
            Expanded(
              child: _buildOrdersList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersList() {
    List<dynamic> itemsToShow = [];

    switch (_ordersFilterIndex) {
      case 0: // Available
        itemsToShow = [..._availableOrders, ..._availableTasks];
        break;
      case 1: // Active
        itemsToShow = [..._activeOrders, ..._activeTasks];
        break;
      case 2: // Completed
        itemsToShow = [..._completedOrders, ..._completedTasks];
        break;
    }

    if (itemsToShow.isEmpty) {
      return _buildEmptyOrdersState();
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 +
            MediaQuery.of(context).padding.bottom +
            80, // Add bottom padding for safe area and bottom nav
      ),
      itemCount: itemsToShow.length,
      itemBuilder: (context, index) {
        final item = itemsToShow[index];
        final isActive = _ordersFilterIndex == 1;

        if (item is Order) {
          return MapOrderCard(
            order: item,
            onAccept: () {
              setState(() {
                // Remove from available, add to active
                _availableOrders.removeWhere((o) => o.id == item.id);
                _activeOrders.insert(0, item);
                _selectedOrder = item;
                _isAvailable = false;
              });
              _updateMapMarkers();
            },
            onMarkPickedUp: () {
              setState(() {});
              _updateMapMarkers();
            },
            onMarkDelivered: () {
              setState(() {
                _selectedOrder = item;
                _currentBottomNavIndex = 0; // Switch to map view
              });
            },
          );
        } else if (item is Task) {
          return _buildTaskCard(item, isActive: isActive);
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildEarningsView() {
    return Container(
      color: Colors.grey[50],
      child: SafeArea(
        child: Column(
          children: [
            // App Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: AppHeader(
                title: 'Earnings',
                onBack: () {
                  setState(() {
                    _currentBottomNavIndex = 0;
                  });
                },
                trailingAction: IconButton(
                  onPressed: _loadEarningsData,
                  icon: Icon(
                    Icons.refresh,
                    color: Colors.orange[600],
                  ),
                ),
              ),
            ),

            // Earnings Content
            Expanded(
              child: _walletInfo == null
                  ? _buildEarningsLoading()
                  : _buildEarningsContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEarningsLoading() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildEarningsContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Wallet Summary Cards
          _buildWalletSummaryCards(),
          const SizedBox(height: 24),

          // Service Fees Section
          _buildServiceFeesSection(),
          const SizedBox(height: 24),

          // App Bank Account Section
          _buildAppBankAccountSection(),
          const SizedBox(height: 24),

          // Recent Transactions
          _buildRecentTransactions(),
          const SizedBox(height: 24),

          // Daily Earnings Chart
          _buildDailyEarningsChart(),
          const SizedBox(height: 24),

          // Enhanced Comprehensive Earnings Analytics
          _buildComprehensiveEarningsAnalytics(),
        ],
      ),
    );
  }

  Widget _buildWalletSummaryCards() {
    final currentBalance = (_walletInfo?['current_balance'] ?? 0.0).toDouble();
    final creditBalance = (_walletInfo?['credit_balance'] ?? 0.0).toDouble();
    final totalEarned = (_walletInfo?['total_earned'] ?? 0.0).toDouble();
    final totalServiceFeesPaid =
        (_walletInfo?['total_service_fees_paid'] ?? 0.0).toDouble();

    return Column(
      children: [
        // Current Balance Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16), // Reduced by 20% (20 * 0.8)
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet,
                    color: Colors.orange[600],
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Current Balance',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${currentBalance.toStringAsFixed(2)} DA',
                style: GoogleFonts.poppins(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Current earnings balance',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 13), // Reduced by 20% (16 * 0.8)

        // Credit Balance and Stats Row
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.credit_card,
                          color: Colors.blue[600],
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Credit Balance',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${creditBalance.toStringAsFixed(2)} DA',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.trending_up,
                          color: Colors.green[600],
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Total Earned',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${totalEarned.toStringAsFixed(2)} DA',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Service Fees Owed to App
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                Icons.account_balance,
                color: Colors.orange[600],
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Service Fees Owed to App (15%)',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const Spacer(),
              Text(
                '${totalServiceFeesPaid.toStringAsFixed(2)} DA',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAppBankAccountSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance,
                color: Colors.blue[600],
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'App Bank Account (Service Fee Payments)',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bank Name: BNA (Banque Nationale d\'Algérie)',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[800],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Account Number: 1234567890123456',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.blue[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Account Holder: Ifrili Delivery App',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.blue[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Transfer service fees to this account and upload receipt',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.blue[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceFeesSection() {
    if (_pendingServiceFees.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber,
                color: Colors.orange[600],
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pending Service Fees (Owed to App)',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._pendingServiceFees
              .take(3)
              .map((fee) => _buildServiceFeeItem(fee)),
          if (_pendingServiceFees.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '+ ${_pendingServiceFees.length - 3} more pending fees',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildServiceFeeItem(Map<String, dynamic> fee) {
    final amount = (fee['service_fee_amount'] ?? 0.0).toDouble();
    final orderNumber = fee['order_number'] ?? 'N/A';
    final taskTitle = fee['task_title'] ?? 'N/A';
    final title = orderNumber != 'N/A' ? 'Order #$orderNumber' : taskTitle;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                Text(
                  'Service Fee to App (15%)',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${amount.toStringAsFixed(2)} DA',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.red[600],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _payServiceFee(fee['id']),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange[600],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Pay to App',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactions() {
    if (_creditTransactions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Transactions',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 12),
          ..._creditTransactions
              .take(5)
              .map((transaction) => _buildTransactionItem(transaction)),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> transaction) {
    final amount = (transaction['amount'] ?? 0.0).toDouble();
    final description = transaction['description'] ?? 'Transaction';
    final createdAt = DateTime.parse(transaction['created_at']);
    final isPositive = amount >= 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isPositive ? Colors.green[100] : Colors.red[100],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              isPositive ? Icons.arrow_downward : Icons.arrow_upward,
              color: isPositive ? Colors.green[600] : Colors.red[600],
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                Text(
                  _formatDate(createdAt),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${isPositive ? '+' : ''}${amount.toStringAsFixed(2)} DA',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isPositive ? Colors.green[600] : Colors.red[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyEarningsChart() {
    if (_dailyEarnings.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily Earnings (Last 7 Days)',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children:
                  _dailyEarnings.map((day) => _buildChartBar(day)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartBar(Map<String, dynamic> day) {
    final netEarnings = (day['net_earnings'] ?? 0.0).toDouble();
    final maxEarnings = _dailyEarnings.fold(
        0.0,
        (max, d) => (d['net_earnings'] ?? 0.0).toDouble() > max
            ? (d['net_earnings'] ?? 0.0).toDouble()
            : max);
    final height = maxEarnings > 0 ? (netEarnings / maxEarnings) * 100 : 0.0;
    final date = DateTime.parse(day['date']);
    final dayName = _getDayName(date.weekday);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          '${netEarnings.toStringAsFixed(0)}',
          style: GoogleFonts.poppins(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 20,
          height: height,
          decoration: BoxDecoration(
            color: Colors.orange[600],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          dayName,
          style: GoogleFonts.poppins(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference < 7) {
      return '$difference days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _getDayName(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }

  Future<void> _payServiceFee(String serviceFeeId) async {
    if (_deliveryPerson == null) return;

    try {
      final success = await _earningsService.payServiceFee(
        deliveryPersonId: _deliveryPerson!.userId,
        serviceFeeId: serviceFeeId,
        paymentMethod: 'credit',
      );

      if (success) {
        await _loadEarningsData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Service fee paid successfully!',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.green[600],
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Insufficient credit balance. Please add credit first.',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.red[600],
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error paying service fee: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to pay service fee. Please try again.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    }
  }

  Widget _buildProfileView() {
    return Container(
      color: Colors.grey[50],
      child: SafeArea(
        child: Column(
          children: [
            // App Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: AppHeader(
                title: 'Profile',
                onBack: () {
                  setState(() {
                    _currentBottomNavIndex = 0;
                  });
                },
                trailingAction: _isEditingProfile
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _isEditingProfile = false;
                              });
                              // Reset to original values without refreshing all data
                              if (_deliveryPerson != null) {
                                _initializeProfileControllers();
                              }
                            },
                            icon: const Icon(Icons.close, size: 16),
                            label: Text(
                              'Cancel',
                              style: GoogleFonts.poppins(fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _saveProfileChanges,
                            icon: const Icon(Icons.save, size: 16),
                            label: Text(
                              'Save',
                              style: GoogleFonts.poppins(fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[600],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              minimumSize: const Size(0, 32),
                            ),
                          ),
                        ],
                      )
                    : TextButton.icon(
                        onPressed: () {
                          // Ensure profile data is loaded before entering edit mode
                          if (_deliveryPerson != null) {
                            _initializeProfileControllers();
                          }
                          setState(() {
                            _isEditingProfile = true;
                          });
                        },
                        icon: const Icon(Icons.edit, size: 16),
                        label: Text(
                          'Edit',
                          style: GoogleFonts.poppins(fontSize: 12),
                        ),
                      ),
              ),
            ),

            // Profile Content (including logo section)
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  16 +
                      MediaQuery.of(context).padding.bottom +
                      80, // Add bottom padding for safe area and bottom nav
                ),
                child: Column(
                  children: [
                    // Logo Section (now scrollable)
                    _buildLogoSection(),

                    const SizedBox(height: 16), // Reduced by 20% (20 * 0.8)

                    // Business Info Section
                    _buildBusinessInfoSection(),

                    const SizedBox(height: 16), // Reduced by 20% (20 * 0.8)

                    // Vehicle Info Section
                    _buildVehicleInfoSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapOrderHeader() {
    if (_selectedOrder == null) return const SizedBox.shrink();

    final trackingData =
        _orderTrackingService?.getOrderTrackingData(_selectedOrder!.id);
    final distanceToDestination = trackingData?.distanceToDestination;
    final etaToDestination = trackingData?.estimatedTimeToDestination;

    return MapOrderHeader(
      order: _selectedOrder!,
      restaurantLocation: trackingData?.restaurantLocation,
      deliveryLocation: trackingData?.customerLocation,
      distanceToRestaurant: distanceToDestination,
      distanceToDelivery: distanceToDestination,
      etaToRestaurant: etaToDestination,
      etaToDelivery: etaToDestination,
      onBack: () {
        setState(() {
          _selectedOrder = null;
          _selectedOrderLocation = null;
        });
      },
    );
  }

  Widget _buildTaskInfoHeader() {
    if (_selectedTask == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[600],
        borderRadius: BorderRadius.circular(20), // Full rounded corners
        boxShadow: [
          // Main shadow
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 25,
            offset: const Offset(0, 12),
            spreadRadius: 0,
          ),
          // Secondary shadow for depth
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 40,
            offset: const Offset(0, 20),
            spreadRadius: 0,
          ),
          // Tertiary shadow for floating effect
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 60,
            offset: const Offset(0, 30),
            spreadRadius: 0,
          ),
          // Highlight shadow for 3D effect
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.8),
            blurRadius: 1,
            offset: const Offset(0, -1),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          // Header row with back button, task ID, and expand button
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    // Back button
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedTask = null;
                          _isTaskHeaderExpanded = false;
                          _isTaskDescriptionExpanded = false;
                        });
                      },
                      child: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Task ID and Status
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            'TASK-${_selectedTask!.id.substring(0, 8).toUpperCase()}',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _getTaskStatusText(_selectedTask!.status),
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Expand/Collapse button
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isTaskHeaderExpanded = !_isTaskHeaderExpanded;
                        });
                      },
                      child: Icon(
                        _isTaskHeaderExpanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ],
                ),
                // Task completion buttons (only for assigned tasks when not expanded)
                if (!_isTaskHeaderExpanded &&
                    _selectedTask!.status == TaskStatus.assigned) ...[
                  const SizedBox(height: 24),
                  _buildTaskCompletionButtonsInHeader(),
                ],
              ],
            ),
          ),
          // Expandable locations list
          if (_isTaskHeaderExpanded) _buildExpandableLocationsList(),
        ],
      ),
    );
  }

  Widget _buildExpandableLocationsList() {
    final locations = <_LocationInfo>[];

    // Add primary location
    locations.add(_LocationInfo(
      purpose: _selectedTask!.locationPurpose ?? 'Primary Location',
      address: _selectedTask!.locationName,
      coordinates:
          'Lat ${_selectedTask!.latitude.toStringAsFixed(5)}, Lng ${_selectedTask!.longitude.toStringAsFixed(5)}',
    ));

    // Add additional locations
    if (_selectedTask!.additionalLocations != null &&
        _selectedTask!.additionalLocations!.isNotEmpty) {
      for (final loc in _selectedTask!.additionalLocations!) {
        final latValue = loc['lat'] ?? loc['latitude'];
        final lngValue = loc['lng'] ?? loc['longitude'];
        String coordinates = '';
        if (latValue != null && lngValue != null) {
          coordinates =
              'Lat ${latValue.toStringAsFixed(5)}, Lng ${lngValue.toStringAsFixed(5)}';
        }

        locations.add(_LocationInfo(
          purpose: loc['purpose'] ?? 'Additional Location',
          address: loc['address'] ?? 'Unknown address',
          coordinates: coordinates,
        ));
      }
    }

    return Column(
      children: [
        ...locations.asMap().entries.map((entry) {
          final index = entry.key;
          final location = entry.value;
          final isCompleted = _isLocationCompleted(index);

          return Container(
            margin:
                EdgeInsets.only(bottom: index < locations.length - 1 ? 8 : 0),
            child: _buildLocationItemInHeader(location, index, isCompleted),
          );
        }),
      ],
    );
  }

  Widget _buildLocationItemInHeader(
      _LocationInfo location, int index, bool isCompleted) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Check icon
              Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? Colors.green
                      : Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              // Location purpose
              Expanded(
                child: Text(
                  location.purpose,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              // Action buttons (only for assigned tasks)
              if (_selectedTask!.status == TaskStatus.assigned) ...[
                // Add Note button
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: TextButton(
                    onPressed: () => _showAddNoteDialog(index),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Add Note',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                // Navigate button
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: TextButton(
                    onPressed: () => _navigateToSpecificLocation(index),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Navigate',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                // Mark as Done button
                TextButton(
                  onPressed:
                      isCompleted ? null : () => _markLocationAsDone(index),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    isCompleted ? 'Done' : 'Mark as Done',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          // Address
          Padding(
            padding: const EdgeInsets.only(
                left: 52), // Align with text after check icon
            child: Text(
              location.address,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isLocationCompleted(int locationIndex) {
    // Check if this location is marked as completed in the task's completion tracking
    if (_selectedTask?.locationCompletions == null) return false;
    return _selectedTask!.locationCompletions!.contains(locationIndex);
  }

  void _showAddNoteDialog(int locationIndex) {
    final TextEditingController noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Add Note for Location',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          content: TextField(
            controller: noteController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Enter your note about this location...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: GoogleFonts.poppins()),
            ),
            ElevatedButton(
              onPressed: () async {
                if (noteController.text.trim().isNotEmpty) {
                  await _addLocationNote(
                      locationIndex, noteController.text.trim());
                  Navigator.of(context).pop();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[600],
                foregroundColor: Colors.white,
              ),
              child: Text('Save Note', style: GoogleFonts.poppins()),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addLocationNote(int locationIndex, String note) async {
    try {
      // Update the task with the location note
      await _integratedService.addLocationNote(
        taskId: _selectedTask!.id,
        locationIndex: locationIndex,
        note: note,
      );

      // Refresh the task data
      await _refreshTaskData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Note added successfully', style: GoogleFonts.poppins()),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Failed to add note: $e', style: GoogleFonts.poppins()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _markLocationAsDone(int locationIndex) async {
    try {
      // Mark the location as completed
      await _integratedService.markLocationAsCompleted(
        taskId: _selectedTask!.id,
        locationIndex: locationIndex,
      );

      // Refresh the task data
      await _refreshTaskData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location marked as completed',
                style: GoogleFonts.poppins()),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mark location as done: $e',
                style: GoogleFonts.poppins()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _refreshTaskData() async {
    try {
      final updatedTask =
          await _integratedService.getTaskById(_selectedTask!.id);
      if (updatedTask != null && mounted) {
        setState(() {
          _selectedTask = updatedTask;
        });
      }
    } catch (e) {
      debugPrint('Failed to refresh task data: $e');
    }
  }

  Widget _buildTaskInfoCard() {
    if (_selectedTask == null) return const SizedBox.shrink();

    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      margin: EdgeInsets.only(bottom: bottomPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          // Main shadow
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 25,
            offset: const Offset(0, 12),
            spreadRadius: 0,
          ),
          // Secondary shadow for depth
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 40,
            offset: const Offset(0, 20),
            spreadRadius: 0,
          ),
          // Tertiary shadow for floating effect
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 60,
            offset: const Offset(0, 30),
            spreadRadius: 0,
          ),
          // Highlight shadow for 3D effect
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.8),
            blurRadius: 1,
            offset: const Offset(0, -1),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Task number and status
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header (task name and close icon removed)
                const SizedBox.shrink(),
                const SizedBox(height: 12),

                // Expandable task description
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isTaskDescriptionExpanded = !_isTaskDescriptionExpanded;
                    });
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Description',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF2E2E2E),
                            ),
                          ),
                        ),
                        Icon(
                          _isTaskDescriptionExpanded
                              ? Icons.expand_less
                              : Icons.expand_more,
                          color: Colors.grey[600],
                        ),
                      ],
                    ),
                  ),
                ),
                // Expandable description content
                if (_isTaskDescriptionExpanded)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Text(
                      _selectedTask!.description,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: const Color(0xFF666666),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Propose cost container (floating 3D shadowed orange 600)
          if (_selectedTask!.status == TaskStatus.pending)
            _buildProposeCostContainer(),

          // Cost proposed container (when task has cost proposal)
          if (_selectedTask!.status == TaskStatus.costProposed)
            _buildCostProposedContainer(),

          // User counter proposed container (when user has made a counter offer)
          if (_selectedTask!.status == TaskStatus.userCounterProposed)
            _buildUserCounterProposedContainer(),

          // User info container (when task is assigned)
          if (_selectedTask!.status == TaskStatus.assigned)
            _buildUserInfoContainer(),
        ],
      ),
    );
  }

  Widget _buildTaskCompletionButtonsInHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          // Cancel Task button (red) with countdown
          Expanded(
            flex: 1,
            child: _buildCancelTaskButton(),
          ),
          const SizedBox(width: 12),
          // Complete Task button (green)
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: () => _completeTask(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 4,
                shadowColor: Colors.green[600]!.withValues(alpha: 0.4),
              ),
              child: Text(
                'Task Completed',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelTaskButton() {
    return StatefulBuilder(
      builder: (context, setState) {
        return ElevatedButton(
          onPressed: _cancelCountdown > 0
              ? null
              : () => _startCancelCountdown(setState),
          style: ElevatedButton.styleFrom(
            backgroundColor:
                _cancelCountdown > 0 ? Colors.grey[400] : Colors.red[600],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            elevation: 8,
            shadowColor: Colors.red[600]!.withValues(alpha: 0.4),
          ),
          child: Text(
            _cancelCountdown > 0 ? 'Cancel ($_cancelCountdown)' : 'Cancel Task',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      },
    );
  }

  int _cancelCountdown = 0;
  Timer? _cancelTimer;

  void _startCancelCountdown(StateSetter setState) {
    _cancelCountdown = 5;
    _cancelTimer?.cancel();
    _cancelTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cancelCountdown > 0) {
        setState(() {
          _cancelCountdown--;
        });
      } else {
        timer.cancel();
        _cancelTask();
      }
    });
  }

  Future<void> _completeTask() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final deliveryPersonId = authService.currentUser?.id;

      if (deliveryPersonId == null) {
        throw Exception('User not authenticated');
      }

      // Complete the task
      await _integratedService.completeTask(
        taskId: _selectedTask!.id,
        deliveryPersonId: deliveryPersonId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Task completed successfully!',
                style: GoogleFonts.poppins()),
            backgroundColor: Colors.green,
          ),
        );

        // Clear the selected task and return to map view
        setState(() {
          _selectedTask = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to complete task: $e',
                style: GoogleFonts.poppins()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _cancelTask() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final deliveryPersonId = authService.currentUser?.id;

      if (deliveryPersonId == null) {
        throw Exception('User not authenticated');
      }

      // Cancel the task assignment
      await _integratedService.cancelCostReview(
        taskId: _selectedTask!.id,
        deliveryPersonId: deliveryPersonId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Task cancelled successfully',
                style: GoogleFonts.poppins()),
            backgroundColor: Colors.orange,
          ),
        );

        // Clear the selected task and return to map view
        setState(() {
          _selectedTask = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Failed to cancel task: $e', style: GoogleFonts.poppins()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildProposeCostContainer() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate available width for responsive layout
          final availableWidth = constraints.maxWidth;
          final isCompactMode = availableWidth < 400;

          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Reject button (red) - flexible width
              Flexible(
                flex: isCompactMode ? 2 : 3,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedTask = null;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[600],
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: isCompactMode ? 8 : 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    'Reject',
                    style: GoogleFonts.poppins(
                      fontSize: isCompactMode ? 12 : 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              SizedBox(width: isCompactMode ? 8 : 12),

              // Price field with +/- controls - flexible width
              Flexible(
                flex: isCompactMode ? 4 : 5,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompactMode ? 8 : 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Minus button
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _proposedCost =
                                (_proposedCost - 10).clamp(0, 10000);
                          });
                        },
                        child: Container(
                          padding: EdgeInsets.all(isCompactMode ? 4 : 6),
                          decoration: BoxDecoration(
                            color: Colors.orange[600],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            Icons.remove,
                            color: Colors.white,
                            size: isCompactMode ? 8 : 10,
                          ),
                        ),
                      ),

                      SizedBox(width: isCompactMode ? 6 : 8),

                      // Price display - flexible text
                      Flexible(
                        child: Text(
                          '${_proposedCost.toStringAsFixed(0)} DZD',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: isCompactMode ? 12 : 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      SizedBox(width: isCompactMode ? 6 : 8),

                      // Plus button
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _proposedCost =
                                (_proposedCost + 10).clamp(0, 10000);
                          });
                        },
                        child: Container(
                          padding: EdgeInsets.all(isCompactMode ? 4 : 6),
                          decoration: BoxDecoration(
                            color: Colors.orange[600],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            Icons.add,
                            color: Colors.white,
                            size: isCompactMode ? 8 : 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(width: isCompactMode ? 8 : 12),

              // Send offer button (orange 600) - flexible width
              Flexible(
                flex: isCompactMode ? 3 : 4,
                child: ElevatedButton(
                  onPressed: () async {
                    // Use the current proposed cost directly
                    try {
                      // Validate required data
                      if (_selectedTask == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('No task selected')),
                        );
                        return;
                      }

                      if (_deliveryPerson == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Delivery person not found')),
                        );
                        return;
                      }

                      debugPrint(
                          'Starting cost review for task: ${_selectedTask!.id}');
                      debugPrint(
                          'Delivery person ID: ${_deliveryPerson!.userId}');
                      debugPrint('Proposed cost: $_proposedCost');

                      // Store ScaffoldMessenger before async operations
                      final scaffoldMessenger = ScaffoldMessenger.of(context);

                      // Start cost review and propose cost
                      await _integratedService.startCostReview(
                        taskId: _selectedTask!.id,
                        deliveryPersonId: _deliveryPerson!.userId,
                      );

                      debugPrint('Cost review started successfully');

                      await _integratedService.proposeCost(
                        taskId: _selectedTask!.id,
                        deliveryPersonId: _deliveryPerson!.userId,
                        cost: _proposedCost,
                        notes: null, // No additional notes for direct offer
                      );

                      debugPrint('Cost proposed successfully');

                      setState(() {
                        // Keep the task selected to stay in map view
                        // Update the task status to reflect the new state
                        _selectedTask = _selectedTask!.copyWith(
                          status: TaskStatus.costProposed,
                          proposedCost: _proposedCost,
                          costProposedAt: DateTime.now(),
                          costProposedBy: _deliveryPerson!.userId,
                        );
                      });

                      if (mounted) {
                        scaffoldMessenger.showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Cost proposed successfully! Waiting for user response.')),
                        );
                      }
                    } catch (e) {
                      debugPrint('Error proposing cost: $e');
                      if (mounted) {
                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        scaffoldMessenger.showSnackBar(
                          SnackBar(content: Text('Failed to propose cost: $e')),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[600],
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: isCompactMode ? 8 : 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    isCompactMode ? 'Send' : 'Send Offer',
                    style: GoogleFonts.poppins(
                      fontSize: isCompactMode ? 12 : 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCostProposedContainer() {
    // Initialize proposed cost with task's current proposed cost
    if (_selectedTask!.proposedCost != null && _proposedCost == 500.0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _proposedCost = _selectedTask!.proposedCost!;
        });
      });
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate available width for responsive layout
          final availableWidth = constraints.maxWidth;
          final isCompactMode = availableWidth < 400;

          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Drop from task button (red) - flexible width
              Flexible(
                flex: isCompactMode ? 2 : 3,
                child: ElevatedButton(
                  onPressed: () async {
                    try {
                      await _integratedService.cancelCostReview(
                        taskId: _selectedTask!.id,
                        deliveryPersonId: _deliveryPerson!.userId,
                      );

                      setState(() {
                        _selectedTask = null;
                      });

                      if (mounted) {
                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        scaffoldMessenger.showSnackBar(
                          const SnackBar(content: Text('Dropped from task')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        scaffoldMessenger.showSnackBar(
                          SnackBar(
                              content: Text('Failed to drop from task: $e')),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[600],
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: isCompactMode ? 8 : 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    isCompactMode ? 'Drop' : 'Drop Task',
                    style: GoogleFonts.poppins(
                      fontSize: isCompactMode ? 12 : 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              SizedBox(width: isCompactMode ? 8 : 12),

              // Price field with +/- controls - flexible width
              Flexible(
                flex: isCompactMode ? 4 : 5,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompactMode ? 8 : 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Minus button
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _proposedCost =
                                (_proposedCost - 10).clamp(0, 10000);
                          });
                        },
                        child: Container(
                          padding: EdgeInsets.all(isCompactMode ? 4 : 6),
                          decoration: BoxDecoration(
                            color: Colors.orange[600],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            Icons.remove,
                            color: Colors.white,
                            size: isCompactMode ? 8 : 10,
                          ),
                        ),
                      ),

                      SizedBox(width: isCompactMode ? 6 : 8),

                      // Price display - flexible text
                      Flexible(
                        child: Text(
                          '${_proposedCost.toStringAsFixed(0)} DZD',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: isCompactMode ? 12 : 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      SizedBox(width: isCompactMode ? 6 : 8),

                      // Plus button
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _proposedCost =
                                (_proposedCost + 10).clamp(0, 10000);
                          });
                        },
                        child: Container(
                          padding: EdgeInsets.all(isCompactMode ? 4 : 6),
                          decoration: BoxDecoration(
                            color: Colors.orange[600],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            Icons.add,
                            color: Colors.white,
                            size: isCompactMode ? 8 : 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(width: isCompactMode ? 8 : 12),

              // Update offer button (orange 600) - flexible width
              Flexible(
                flex: isCompactMode ? 3 : 4,
                child: ElevatedButton(
                  onPressed: () async {
                    try {
                      // Update the cost proposal with new amount
                      await _integratedService.updateCostProposal(
                        taskId: _selectedTask!.id,
                        deliveryPersonId: _deliveryPerson!.userId,
                        cost: _proposedCost,
                        notes: null,
                      );

                      setState(() {
                        // Update the task with new proposed cost
                        _selectedTask = _selectedTask!.copyWith(
                          proposedCost: _proposedCost,
                          costProposedAt: DateTime.now(),
                        );
                      });

                      if (mounted) {
                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        scaffoldMessenger.showSnackBar(
                          const SnackBar(
                              content: Text('Offer updated successfully!')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        scaffoldMessenger.showSnackBar(
                          SnackBar(content: Text('Failed to update offer: $e')),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[600],
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: isCompactMode ? 8 : 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    isCompactMode ? 'Update' : 'Update Offer',
                    style: GoogleFonts.poppins(
                      fontSize: isCompactMode ? 12 : 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildUserCounterProposedContainer() {
    // Initialize proposed cost with user's counter offer
    if (_selectedTask!.userCounterCost != null && _proposedCost == 500.0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _proposedCost = _selectedTask!.userCounterCost!;
        });
      });
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          // First row: Drop task - Price field - Update offer
          LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth;
              final isCompactMode = availableWidth < 400;

              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Drop task button (red) - flexible width
                  Flexible(
                    flex: isCompactMode ? 2 : 3,
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          await _integratedService.cancelCostReview(
                            taskId: _selectedTask!.id,
                            deliveryPersonId: _deliveryPerson!.userId,
                          );

                          setState(() {
                            _selectedTask = null;
                          });

                          if (mounted) {
                            final scaffoldMessenger =
                                ScaffoldMessenger.of(context);
                            scaffoldMessenger.showSnackBar(
                              const SnackBar(
                                  content: Text('Dropped from task')),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            final scaffoldMessenger =
                                ScaffoldMessenger.of(context);
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                  content:
                                      Text('Failed to drop from task: $e')),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[600],
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: isCompactMode ? 8 : 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        isCompactMode ? 'Drop' : 'Drop Task',
                        style: GoogleFonts.poppins(
                          fontSize: isCompactMode ? 12 : 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(width: isCompactMode ? 8 : 12),

                  // Price field with +/- controls - flexible width
                  Flexible(
                    flex: isCompactMode ? 4 : 5,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isCompactMode ? 8 : 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Minus button
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _proposedCost =
                                    (_proposedCost - 10).clamp(0, 10000);
                              });
                            },
                            child: Container(
                              padding: EdgeInsets.all(isCompactMode ? 4 : 6),
                              decoration: BoxDecoration(
                                color: Colors.orange[600],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Icon(
                                Icons.remove,
                                color: Colors.white,
                                size: isCompactMode ? 8 : 10,
                              ),
                            ),
                          ),

                          SizedBox(width: isCompactMode ? 6 : 8),

                          // Price display - flexible text
                          Flexible(
                            child: Text(
                              '${_proposedCost.toStringAsFixed(0)} DZD',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: isCompactMode ? 12 : 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                          SizedBox(width: isCompactMode ? 6 : 8),

                          // Plus button
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _proposedCost =
                                    (_proposedCost + 10).clamp(0, 10000);
                              });
                            },
                            child: Container(
                              padding: EdgeInsets.all(isCompactMode ? 4 : 6),
                              decoration: BoxDecoration(
                                color: Colors.orange[600],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Icon(
                                Icons.add,
                                color: Colors.white,
                                size: isCompactMode ? 8 : 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(width: isCompactMode ? 8 : 12),

                  // Update offer button (orange 600) - flexible width
                  Flexible(
                    flex: isCompactMode ? 3 : 4,
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          // Update the cost proposal with new amount
                          await _integratedService.updateCostProposal(
                            taskId: _selectedTask!.id,
                            deliveryPersonId: _deliveryPerson!.userId,
                            cost: _proposedCost,
                            notes: null,
                          );

                          setState(() {
                            // Update the task with new proposed cost
                            _selectedTask = _selectedTask!.copyWith(
                              proposedCost: _proposedCost,
                              costProposedAt: DateTime.now(),
                            );
                          });

                          if (mounted) {
                            final scaffoldMessenger =
                                ScaffoldMessenger.of(context);
                            scaffoldMessenger.showSnackBar(
                              const SnackBar(
                                  content: Text('Offer updated successfully!')),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            final scaffoldMessenger =
                                ScaffoldMessenger.of(context);
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                  content: Text('Failed to update offer: $e')),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange[600],
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: isCompactMode ? 8 : 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        isCompactMode ? 'Update' : 'Update Offer',
                        style: GoogleFonts.poppins(
                          fontSize: isCompactMode ? 12 : 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 12),

          // Second row: Accept offer button (full width)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                try {
                  // Accept the user's counter offer
                  await _integratedService.acceptUserCounterOffer(
                    taskId: _selectedTask!.id,
                    deliveryPersonId: _deliveryPerson!.userId,
                  );

                  setState(() {
                    _selectedTask = null;
                  });

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text('Counter offer accepted! Task assigned.')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Failed to accept counter offer: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                'Accept Offer',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Enhanced restaurant address logic using restaurant_id and restaurant data
  String _getRestaurantAddress() {
    if (_selectedOrder?.restaurant != null) {
      final restaurant = _selectedOrder!.restaurant!;
      final addressParts = [
        restaurant.addressLine1,
        restaurant.addressLine2,
        restaurant.city,
        restaurant.state,
      ].where((part) => part != null && part.isNotEmpty).toList();

      if (addressParts.isNotEmpty) {
        return addressParts.join(', ');
      }
    }
    return 'Restaurant location';
  }

  /// Enhanced restaurant name logic using restaurant_id
  String _getRestaurantName() {
    if (_selectedOrder?.restaurant != null) {
      return _selectedOrder!.restaurant!.name;
    }
    return 'Restaurant';
  }

  /// Enhanced restaurant phone logic using restaurant_id
  String _getRestaurantPhone() {
    if (_selectedOrder?.restaurant != null) {
      return _selectedOrder!.restaurant!.phone;
    }
    return '';
  }

  /// Enhanced delivery address logic using delivery_address JSONB column
  String _getCustomerAddress() {
    if (_selectedOrder?.deliveryAddress.isNotEmpty == true) {
      return _selectedOrder!.deliveryAddress['fullAddress'] ??
          _selectedOrder!.deliveryAddress['address'] ??
          _selectedOrder!.deliveryAddressString;
    }
    return 'Customer location';
  }

  /// Enhanced delivery address using DeliveryAddress model
  String _getDeliveryAddressFromModel() {
    if (_selectedOrder?.deliveryAddress != null) {
      final deliveryAddress = _selectedOrder!.deliveryAddress;
      return deliveryAddress.fullAddress;
    }
    return 'Customer location';
  }

  /// Enhanced customer name logic
  String _getCustomerName() {
    if (_selectedOrder?.customer != null) {
      return _selectedOrder!.customer!.name ?? 'Customer';
    }
    return 'Customer';
  }

  /// Enhanced customer phone logic
  String _getCustomerPhone() {
    if (_selectedOrder?.customer != null) {
      return _selectedOrder!.customer!.phone ?? '';
    }
    return '';
  }

  /// Launch phone dialer with the given phone number
  Future<void> _launchTel(String phoneNumber) async {
    try {
      final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        debugPrint('Could not launch phone dialer for: $phoneNumber');
      }
    } catch (e) {
      debugPrint('Error launching phone dialer: $e');
    }
  }

  Widget _buildEmptyOrdersState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_shipping_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 24),
          Text(
            'No Orders Yet',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'When you accept orders, they will appear here.',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNoProfileView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.delivery_dining,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 24),
          Text(
            'No Delivery Profile Found',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'You need to create a delivery profile to access this dashboard.',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              Navigator.pushNamed(context, '/become_delivery_man');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFd47b00),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Create Profile',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildOrderCard(Order order, {required bool isActive}) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      margin: EdgeInsets.only(bottom: 12 + bottomPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 32,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Don't allow selection of completed orders
            if (order.status == OrderStatus.delivered) {
              return;
            }

            setState(() {
              _selectedOrder = order;
              _currentBottomNavIndex = 0; // Switch to map view
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with Order ID and Status
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _getStatusColor(order.status)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getStatusIcon(order.status),
                        color: _getStatusColor(order.status),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Order #${order.orderNumber}',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF2E2E2E),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _getStatusText(order.status),
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: _getStatusColor(order.status),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      PriceFormatter.formatWithSettings(
                          context, order.totalAmount.toString()),
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFd47b00),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Customer Information Section
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withValues(alpha: 0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Customer Name
                      Row(
                        children: [
                          Icon(
                            Icons.person,
                            size: 14,
                            color: Colors.blue[600],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Customer: ${order.customer?.name ?? 'Unknown'}',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.blue[800],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Customer Phone
                      if (order.customer?.phone != null)
                        Row(
                          children: [
                            Icon(
                              Icons.phone,
                              size: 14,
                              color: Colors.blue[600],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              order.customer!.phone!,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.blue[800],
                              ),
                            ),
                          ],
                        ),
                      // Customer Location
                      if (order.customer?.location != null ||
                          order.customer?.address != null ||
                          order.customer?.wilaya != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            children: [
                              Icon(
                                Icons.my_location,
                                size: 14,
                                color: Colors.blue[600],
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  order.customer?.address != null
                                      ? '${order.customer!.address}${order.customer!.wilaya != null ? ', ${order.customer!.wilaya}' : ''}'
                                      : order.customer?.wilaya ??
                                          'Location not available',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: Colors.blue[800],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Delivery Address Section
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      size: 16,
                      color: Color(0xFFfc9d2d),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        // Try multiple possible field names for delivery address
                        () {
                          // Try multiple possible field names
                          String? address =
                              order.deliveryAddress['fullAddress'] ??
                                  order.deliveryAddress['address'] ??
                                  order.deliveryAddress['street'];

                          // If no direct address found, try to construct from components
                          if (address == null || address.isEmpty) {
                            final street =
                                order.deliveryAddress['street'] ?? '';
                            final city = order.deliveryAddress['city'] ?? '';
                            final wilaya =
                                order.deliveryAddress['wilaya'] ?? '';
                            final postalCode =
                                order.deliveryAddress['postal_code'] ?? '';

                            final components = [
                              street,
                              city,
                              wilaya,
                              postalCode
                            ]
                                .where((component) => component.isNotEmpty)
                                .toList();

                            if (components.isNotEmpty) {
                              address = components.join(', ');
                            }
                          }

                          return address?.trim().isNotEmpty == true
                              ? address!
                              : 'No delivery address';
                        }(),
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: const Color(0xFF2E2E2E),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Action Buttons (different for each section)
                if (_ordersFilterIndex == 0 &&
                    order.status == OrderStatus.preparing)
                  // Available section: Accept Order button (full rounded floating 3D shadowed)
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20), // Full rounded
                      boxShadow: [
                        // Main shadow for 3D effect
                        BoxShadow(
                          color: const Color(0xFFd47b00).withValues(alpha: 0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                          spreadRadius: 0,
                        ),
                        // Secondary shadow for depth
                        BoxShadow(
                          color:
                              const Color(0xFFd47b00).withValues(alpha: 0.15),
                          blurRadius: 25,
                          offset: const Offset(0, 12),
                          spreadRadius: 0,
                        ),
                        // Highlight shadow for 3D effect
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.8),
                          blurRadius: 1,
                          offset: const Offset(0, -1),
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          await _acceptOrder(order);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFd47b00),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          minimumSize: const Size(0, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(20), // Full rounded
                          ),
                          elevation:
                              0, // Remove default elevation to use custom shadow
                        ),
                        child: Text(
                          'Accept Order',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  )
                else if (_ordersFilterIndex == 1)
                  // Active section: Status-based buttons
                  _buildActiveSectionButton(order),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserInfoContainer() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          // User profile image
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.orange[600],
              borderRadius: BorderRadius.circular(25),
            ),
            child: const Icon(
              Icons.person,
              color: Colors.white,
              size: 24,
            ),
          ),

          const SizedBox(width: 16),

          // User name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedTask!.userName ?? 'Task Owner',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2E2E2E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Contact the task owner',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF666666),
                  ),
                ),
              ],
            ),
          ),

          // Call button
          ElevatedButton(
            onPressed: _callTaskOwner,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[600],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(12),
              shape: const CircleBorder(),
            ),
            child: const Icon(Icons.phone, size: 20),
          ),
        ],
      ),
    );
  }

  Future<void> _callTaskOwner() async {
    // Get the primary phone number from the task
    final phoneNumber =
        _selectedTask?.contactPhone ?? _selectedTask?.contactPhone2;

    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      try {
        final uri = Uri(scheme: 'tel', path: phoneNumber);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cannot place a call on this device',
                  style: GoogleFonts.poppins()),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Failed to open dialer', style: GoogleFonts.poppins()),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No phone number available for this task',
              style: GoogleFonts.poppins()),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Widget _buildTaskCard(Task task, {required bool isActive}) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      margin: EdgeInsets.only(bottom: 12 + bottomPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20), // Full rounded
        boxShadow: [
          // Main shadow for 3D effect
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 25,
            offset: const Offset(0, 12),
            spreadRadius: 0,
          ),
          // Secondary shadow for depth
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 40,
            offset: const Offset(0, 20),
            spreadRadius: 0,
          ),
          // Tertiary shadow for floating effect
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 60,
            offset: const Offset(0, 30),
            spreadRadius: 0,
          ),
          // Highlight shadow for 3D effect
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.8),
            blurRadius: 1,
            offset: const Offset(0, -1),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Don't allow selection of completed tasks
            if (task.status == TaskStatus.completed) {
              return;
            }

            setState(() {
              _selectedTask = task;
              // Always switch to map view to show task details
              _currentBottomNavIndex = 0; // Switch to map view
            });
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Task number --- Ifrili
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Task #${task.id.substring(0, 8).toUpperCase()}',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Text(
                        'Ifrili',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[600],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 13), // Reduced by 20% (16 * 0.8)

                // Contact info (expandable): name and phone
                _buildExpandableContactInfo(task),

                const SizedBox(height: 13), // Reduced by 20% (16 * 0.8)

                // Description expandable
                _buildExpandableDescription(task),

                const SizedBox(height: 13), // Reduced by 20% (16 * 0.8)

                // Task location expandable
                _buildExpandableTaskLocation(task),

                const SizedBox(height: 13), // Reduced by 20% (16 * 0.8)

                // Action Buttons based on status and section
                _buildTaskActionButtons(task, isActive),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandableContactInfo(Task task) {
    return GestureDetector(
      onTap: () {
        _toggleTaskFieldExpansion(task.id, 'contact');
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.blue[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Contact Info',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.blue[600],
                      ),
                    ),
                  ),
                  Icon(
                    _isTaskFieldExpanded(task.id, 'contact')
                        ? Icons.expand_less
                        : Icons.expand_more,
                    color: Colors.grey[600],
                    size: 20,
                  ),
                ],
              ),
            ),
            // Expandable content
            if (_isTaskFieldExpanded(task.id, 'contact')) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (task.userName != null) ...[
                      Text(
                        'Name: ${task.userName}',
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      'Phone: ${_formatPhoneNumbers(task)}',
                      style: GoogleFonts.poppins(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExpandableDescription(Task task) {
    return GestureDetector(
      onTap: () {
        _toggleTaskFieldExpansion(task.id, 'description');
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.description, size: 16, color: Colors.green[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Description',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.green[600],
                      ),
                    ),
                  ),
                  Icon(
                    _isTaskFieldExpanded(task.id, 'description')
                        ? Icons.expand_less
                        : Icons.expand_more,
                    color: Colors.grey[600],
                    size: 20,
                  ),
                ],
              ),
            ),
            // Expandable content
            if (_isTaskFieldExpanded(task.id, 'description')) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Waiting title for cost proposed tasks
                    if (task.status == TaskStatus.costProposed) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.hourglass_empty,
                                size: 16, color: Colors.orange[600]),
                            const SizedBox(width: 8),
                            Text(
                              'Waiting for User Response',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    // Task description
                    Text(
                      task.description,
                      style: GoogleFonts.poppins(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExpandableTaskLocation(Task task) {
    return GestureDetector(
      onTap: () {
        _toggleTaskFieldExpansion(task.id, 'location');
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.orange[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Task Location',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.orange[600],
                      ),
                    ),
                  ),
                  Icon(
                    _isTaskFieldExpanded(task.id, 'location')
                        ? Icons.expand_less
                        : Icons.expand_more,
                    color: Colors.grey[600],
                    size: 20,
                  ),
                ],
              ),
            ),
            // Expandable content
            if (_isTaskFieldExpanded(task.id, 'location')) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: _buildAllLocationsForTask(task),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTaskActionButtons(Task task, bool isActive) {
    if (_ordersFilterIndex == 0 &&
        (task.status == TaskStatus.pending ||
            task.status == TaskStatus.costReview ||
            task.status == TaskStatus.costProposed ||
            task.status == TaskStatus.costAccepted ||
            task.status == TaskStatus.userCounterProposed ||
            task.status == TaskStatus.deliveryCounterProposed)) {
      // Available section: Refuse and View buttons (2 buttons in line)
      return Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20), // Full rounded
                boxShadow: [
                  // Main shadow for 3D effect
                  BoxShadow(
                    color: Colors.red.withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                    spreadRadius: 0,
                  ),
                  // Secondary shadow for depth
                  BoxShadow(
                    color: Colors.red.withValues(alpha: 0.15),
                    blurRadius: 25,
                    offset: const Offset(0, 12),
                    spreadRadius: 0,
                  ),
                  // Highlight shadow for 3D effect
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.8),
                    blurRadius: 1,
                    offset: const Offset(0, -1),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () {
                  // TODO(sahla-app): Implement refuse logic
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Task refused')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[600],
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  minimumSize: const Size(0, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20), // Full rounded
                  ),
                  elevation: 0, // Remove default elevation to use custom shadow
                ),
                child: Text(
                  'Refuse',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20), // Full rounded
                boxShadow: [
                  // Main shadow for 3D effect
                  BoxShadow(
                    color: const Color(0xFFd47b00).withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                    spreadRadius: 0,
                  ),
                  // Secondary shadow for depth
                  BoxShadow(
                    color: const Color(0xFFd47b00).withValues(alpha: 0.15),
                    blurRadius: 25,
                    offset: const Offset(0, 12),
                    spreadRadius: 0,
                  ),
                  // Highlight shadow for 3D effect
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.8),
                    blurRadius: 1,
                    offset: const Offset(0, -1),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () {
                  // Don't allow selection of completed tasks
                  if (task.status == TaskStatus.completed) {
                    return;
                  }

                  setState(() {
                    _selectedTask = task;
                    _currentBottomNavIndex = 0; // Switch to map view
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFd47b00),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  minimumSize: const Size(0, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20), // Full rounded
                  ),
                  elevation: 0, // Remove default elevation to use custom shadow
                ),
                child: Text(
                  'View',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    } else if (_ordersFilterIndex == 1 && isActive) {
      // Active section: Complete Task and Send Note buttons (2 buttons in line)
      return Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20), // Full rounded
                boxShadow: [
                  // Main shadow for 3D effect
                  BoxShadow(
                    color: Colors.green.withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                    spreadRadius: 0,
                  ),
                  // Secondary shadow for depth
                  BoxShadow(
                    color: Colors.green.withValues(alpha: 0.15),
                    blurRadius: 25,
                    offset: const Offset(0, 12),
                    spreadRadius: 0,
                  ),
                  // Highlight shadow for 3D effect
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.8),
                    blurRadius: 1,
                    offset: const Offset(0, -1),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () async {
                  await _completeTask();
                },
                icon: const Icon(Icons.check_circle, size: 18),
                label: Text(
                  'Complete Task',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  minimumSize: const Size(0, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20), // Full rounded
                  ),
                  elevation: 0, // Remove default elevation to use custom shadow
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20), // Full rounded
                boxShadow: [
                  // Main shadow for 3D effect
                  BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                    spreadRadius: 0,
                  ),
                  // Secondary shadow for depth
                  BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.15),
                    blurRadius: 25,
                    offset: const Offset(0, 12),
                    spreadRadius: 0,
                  ),
                  // Highlight shadow for 3D effect
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.8),
                    blurRadius: 1,
                    offset: const Offset(0, -1),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () {
                  _showSendNoteDialog(task);
                },
                icon: const Icon(Icons.message, size: 18),
                label: Text(
                  'Send Note',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  minimumSize: const Size(0, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20), // Full rounded
                  ),
                  elevation: 0, // Remove default elevation to use custom shadow
                ),
              ),
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildAllLocationsForTask(Task task) {
    final locations = <_LocationInfo>[];

    // Add primary location
    locations.add(_LocationInfo(
      purpose: task.locationPurpose ?? 'Location purpose',
      address: task.locationName,
    ));

    // Add additional locations from additionalLocations field
    if (task.additionalLocations != null &&
        task.additionalLocations!.isNotEmpty) {
      for (final loc in task.additionalLocations!) {
        locations.add(_LocationInfo(
          purpose: loc['purpose'] ?? 'Location purpose',
          address: loc['address'] ?? 'Unknown address',
        ));
      }
    }

    return Column(
      children:
          locations.map((location) => _buildLocationItem(location)).toList(),
    );
  }

  Widget _buildLocationItem(_LocationInfo location) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Location purpose as title with icon
          Row(
            children: [
              Icon(Icons.location_on, size: 16, color: Colors.blue[600]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  location.purpose,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.blue[600],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Location address as subtitle
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: Text(
              location.address,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatPhoneNumbers(Task task) {
    final phones = <String>[];

    if (task.contactPhone != null && task.contactPhone!.isNotEmpty) {
      phones.add(task.contactPhone!);
    }

    if (task.contactPhone2 != null && task.contactPhone2!.isNotEmpty) {
      phones.add(task.contactPhone2!);
    }

    if (phones.isEmpty) {
      return 'No phone provided';
    }

    return phones.join('\n');
  }

  Widget _buildLogoSection() {
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            _showImagePickerDialog();
          },
          child: Container(
            width: 96, // Reduced by 20% (120 * 0.8)
            height: 96, // Reduced by 20% (120 * 0.8)
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 40,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Profile image
                Center(
                  child: _selectedImage != null
                      ? ClipOval(
                          child: Image.file(
                            _selectedImage!,
                            width: 96, // Reduced by 20%
                            height: 96, // Reduced by 20%
                            fit: BoxFit.cover,
                          ),
                        )
                      : _deliveryPerson?.user?.profileImage != null
                          ? ClipOval(
                              child: Image.network(
                                '${_deliveryPerson!.user!.profileImage!}?t=${DateTime.now().millisecondsSinceEpoch}',
                                width: 96, // Reduced by 20%
                                height: 96, // Reduced by 20%
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 96, // Reduced by 20%
                                    height: 96, // Reduced by 20%
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.person,
                                      color:
                                          Colors.grey[600], // Made more visible
                                      size:
                                          48, // Increased size for better visibility
                                    ),
                                  );
                                },
                              ),
                            )
                          : Container(
                              width: 96, // Reduced by 20%
                              height: 96, // Reduced by 20%
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.person,
                                color: Colors.grey[600], // Made more visible
                                size:
                                    48, // Increased size for better visibility
                              ),
                            ),
                ),
                // Camera icon overlay
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    width: 29, // Reduced by 20% (36 * 0.8)
                    height: 29, // Reduced by 20% (36 * 0.8)
                    decoration: BoxDecoration(
                      color: Colors.orange[600],
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 16, // Reduced by 20% (20 * 0.8)
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Tap to change photo',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  void _showImagePickerDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Select Profile Image',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text('Camera', style: GoogleFonts.poppins()),
              onTap: () {
                Navigator.of(context).pop();
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text('Gallery', style: GoogleFonts.poppins()),
              onTap: () {
                Navigator.of(context).pop();
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: Colors.red[600],
        ),
      );
    }
  }

  Widget _buildBusinessInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Title (outside container)
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              Icon(Icons.business,
                  color: Colors.blue[600],
                  size: 19), // Reduced by 20% (24 * 0.8)
              const SizedBox(width: 12),
              Text(
                'Business Info',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
        ),

        // Section Content
        Container(
          padding: const EdgeInsets.all(16), // Reduced by 20% (20 * 0.8)
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Delivery Name
              _buildFullWidthInputField(
                label: 'Delivery Name',
                controller: _deliveryNameController,
                isEditing: _isEditingProfile,
                icon: Icons.person,
              ),

              const SizedBox(height: 13), // Reduced by 20% (16 * 0.8)

              // Work Phone Number
              _buildFullWidthInputField(
                label: 'Work Phone Number',
                controller: _workPhoneController,
                isEditing: _isEditingProfile,
                icon: Icons.phone,
                keyboardType: TextInputType.phone,
              ),

              const SizedBox(height: 13), // Reduced by 20% (16 * 0.8)

              // Wilaya Dropdown
              _buildFullWidthDropdownField(
                label: 'Wilaya',
                value: _selectedWilaya,
                items: _wilayaProvinces.keys.toList(),
                onChanged: _isEditingProfile
                    ? (value) {
                        setState(() {
                          _selectedWilaya = value;
                          _selectedProvince =
                              null; // Reset province when wilaya changes
                        });
                      }
                    : null,
                icon: Icons.location_city,
              ),

              const SizedBox(height: 13), // Reduced by 20% (16 * 0.8)

              // Province Dropdown
              _buildFullWidthDropdownField(
                label: 'Province',
                value: _selectedProvince,
                items: _selectedWilaya != null
                    ? _wilayaProvinces[_selectedWilaya]!
                    : [],
                onChanged: _isEditingProfile && _selectedWilaya != null
                    ? (value) {
                        setState(() {
                          _selectedProvince = value;
                        });
                      }
                    : null,
                icon: Icons.location_on,
                enabled: _selectedWilaya != null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Title (outside container)
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              Icon(Icons.directions_car,
                  color: Colors.orange[600],
                  size: 19), // Reduced by 20% (24 * 0.8)
              const SizedBox(width: 12),
              Text(
                'Vehicle Info',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
        ),

        // Section Content
        Container(
          padding: const EdgeInsets.all(16), // Reduced by 20% (20 * 0.8)
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Brand
              _buildFullWidthInputField(
                label: 'Brand',
                controller: _vehicleBrandController,
                isEditing: _isEditingProfile,
                icon: Icons.branding_watermark,
              ),

              const SizedBox(height: 13), // Reduced by 20% (16 * 0.8)

              // Model
              _buildFullWidthInputField(
                label: 'Model',
                controller: _vehicleModelController,
                isEditing: _isEditingProfile,
                icon: Icons.model_training,
              ),

              const SizedBox(height: 13), // Reduced by 20% (16 * 0.8)

              // Year
              _buildFullWidthInputField(
                label: 'Year',
                controller: _vehicleYearController,
                isEditing: _isEditingProfile,
                icon: Icons.calendar_today,
                keyboardType: TextInputType.number,
              ),

              const SizedBox(height: 13), // Reduced by 20% (16 * 0.8)

              // Color
              _buildFullWidthInputField(
                label: 'Color',
                controller: _vehicleColorController,
                isEditing: _isEditingProfile,
                icon: Icons.palette,
              ),

              const SizedBox(height: 13), // Reduced by 20% (16 * 0.8)

              // License Plate
              _buildFullWidthInputField(
                label: 'License Plate',
                controller: _vehiclePlateController,
                isEditing: _isEditingProfile,
                icon: Icons.confirmation_number,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFullWidthInputField({
    required String label,
    required TextEditingController controller,
    required bool isEditing,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.grey[600], size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (isEditing)
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey[800],
            ),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              filled: true,
              fillColor: Colors.grey[50],
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Text(
              controller.text.isEmpty ? 'Not set' : controller.text,
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey[800],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFullWidthDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?>? onChanged,
    required IconData icon,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.grey[600], size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (onChanged != null && enabled)
          DropdownButtonFormField<String>(
            initialValue: value,
            onChanged: onChanged,
            items: items.map((String item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(
                  item,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.grey[800],
                  ),
                ),
              );
            }).toList(),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            isExpanded: true,
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: enabled ? Colors.grey[50] : Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Text(
              value ?? 'Not set',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: enabled ? Colors.grey[800] : Colors.grey[500],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _loadDeliveryPerson() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;

      final deliveryService =
          Provider.of<DeliveryService>(context, listen: false);
      _deliveryPerson =
          await deliveryService.getDeliveryPersonByUserId(currentUser.id);

      if (_deliveryPerson != null) {
        _isOnline = _deliveryPerson!.isOnline;
        _isAvailable = _deliveryPerson!.isAvailable;
        _initializeProfileControllers();
      }
    } catch (e) {
      debugPrint('Error loading delivery person: $e');
    }
  }

  Future<void> _saveProfileChanges() async {
    try {
      // Show loading indicator
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Update delivery personnel work and vehicle info
      final deliveryUpdates = {
        'delivery_name': _deliveryNameController.text,
        'work_phone': _workPhoneController.text,
        'wilaya': _selectedWilaya,
        'province': _selectedProvince,
        'vehicle_brand': _vehicleBrandController.text,
        'vehicle_model': _vehicleModelController.text,
        'vehicle_year': _vehicleYearController.text.isNotEmpty
            ? int.tryParse(_vehicleYearController.text)
            : null,
        'vehicle_color': _vehicleColorController.text,
        'vehicle_plate': _vehiclePlateController.text,
      };

      // Update delivery_personnel table only
      await Supabase.instance.client
          .from('delivery_personnel')
          .update(deliveryUpdates)
          .eq('id', _deliveryPerson!.id);

      // Handle image upload if selected (profile images stay in user_profiles as they're personal)
      if (_selectedImage != null) {
        final fileName = '${_deliveryPerson!.userId}/profile.jpg';

        // Upload to storage with proper folder structure
        await Supabase.instance.client.storage
            .from('profile-images')
            .upload(fileName, _selectedImage!,
                fileOptions: const FileOptions(
                  cacheControl: '3600',
                  upsert: true, // Allow overwriting existing files
                ));

        // Update profile image URL in user_profiles (personal info, not work-related)
        final imageUrl = Supabase.instance.client.storage
            .from('profile-images')
            .getPublicUrl(fileName);

        await Supabase.instance.client.from('user_profiles').update(
            {'profile_image': imageUrl}).eq('id', _deliveryPerson!.userId);
      }

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Profile updated successfully!',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green[600],
          ),
        );
      }

      // Exit editing mode
      setState(() {
        _isEditingProfile = false;
        _selectedImage = null; // Clear selected image to show database image
      });

      // Reload delivery person data
      await _loadDeliveryPerson();
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to update profile: ${e.toString()}',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    }
  }

  void _showSendNoteDialog(Task task) {
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Send Note',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Send a note to the task owner:',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter your note...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO(sahla-app): Implement send note logic
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Note sent successfully')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFd47b00),
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Send',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSectionButton(Order order) {
    switch (order.status) {
      case OrderStatus.preparing:
        // Show "Pick Up Order" button for preparing orders (restaurant hasn't marked as ready yet)
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20), // Full rounded
            boxShadow: [
              // Main shadow for 3D effect
              BoxShadow(
                color: const Color(0xFFd47b00).withValues(alpha: 0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
                spreadRadius: 0,
              ),
              // Secondary shadow for depth
              BoxShadow(
                color: const Color(0xFFd47b00).withValues(alpha: 0.15),
                blurRadius: 25,
                offset: const Offset(0, 12),
                spreadRadius: 0,
              ),
              // Highlight shadow for 3D effect
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.8),
                blurRadius: 1,
                offset: const Offset(0, -1),
                spreadRadius: 0,
              ),
            ],
          ),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await _markOrderAsPickedUp(order);
              },
              icon: const Icon(Icons.delivery_dining, size: 18),
              label: Text(
                'Mark as Picked Up',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFd47b00),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                minimumSize: const Size(0, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20), // Full rounded
                ),
                elevation: 0, // Remove default elevation to use custom shadow
              ),
            ),
          ),
        );

      case OrderStatus.ready:
        // Show "Picked Up" button for orders that are ready
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20), // Full rounded
            boxShadow: [
              // Main shadow for 3D effect
              BoxShadow(
                color: const Color(0xFFd47b00).withValues(alpha: 0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
                spreadRadius: 0,
              ),
              // Secondary shadow for depth
              BoxShadow(
                color: const Color(0xFFd47b00).withValues(alpha: 0.15),
                blurRadius: 25,
                offset: const Offset(0, 12),
                spreadRadius: 0,
              ),
              // Highlight shadow for 3D effect
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.8),
                blurRadius: 1,
                offset: const Offset(0, -1),
                spreadRadius: 0,
              ),
            ],
          ),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await _markOrderAsPickedUp(order);
              },
              icon: const Icon(Icons.delivery_dining, size: 18),
              label: Text(
                'Mark as Picked Up',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFd47b00),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                minimumSize: const Size(0, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20), // Full rounded
                ),
                elevation: 0, // Remove default elevation to use custom shadow
              ),
            ),
          ),
        );

      case OrderStatus.pickedUp:
        // Show "Delivered" button for orders that have been picked up
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20), // Full rounded
            boxShadow: [
              // Main shadow for 3D effect
              BoxShadow(
                color: Colors.green.withValues(alpha: 0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
                spreadRadius: 0,
              ),
              // Secondary shadow for depth
              BoxShadow(
                color: Colors.green.withValues(alpha: 0.15),
                blurRadius: 25,
                offset: const Offset(0, 12),
                spreadRadius: 0,
              ),
              // Highlight shadow for 3D effect
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.8),
                blurRadius: 1,
                offset: const Offset(0, -1),
                spreadRadius: 0,
              ),
            ],
          ),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await _markOrderAsDelivered(order);
              },
              icon: const Icon(Icons.check_circle, size: 18),
              label: Text(
                'Mark as Delivered',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                minimumSize: const Size(0, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20), // Full rounded
                ),
                elevation: 0, // Remove default elevation to use custom shadow
              ),
            ),
          ),
        );

      case OrderStatus.pending:
      case OrderStatus.confirmed:
      case OrderStatus.delivered:
      case OrderStatus.cancelled:
        // No button for these statuses
        return const SizedBox.shrink();
    }
  }

  Future<void> _markOrderAsPickedUp(Order order) async {
    try {
      final previousStatus = order.status;
      debugPrint(
          '🚚 Marking order ${order.id} as picked up (from ${order.status})');

      if (order.status == OrderStatus.preparing) {
        debugPrint(
            '⚡ Fast pickup: Skipping restaurant "ready" step for smoother delivery!');
      }

      // Prefer delivery-scoped update to satisfy RLS using assigned delivery_person_id
      final orderAssignmentService = OrderAssignmentService();
      final deliveryPersonId = _deliveryPerson?.id;

      bool success = false;
      if (deliveryPersonId != null) {
        success = await orderAssignmentService.markOrderPickedUpByDelivery(
          orderId: order.id,
          deliveryPersonId: deliveryPersonId,
        );
      } else {
        // Fallback to generic service if no delivery profile loaded
        final orderService = Provider.of<OrderService>(context, listen: false);
        final latest = await orderService.getOrderById(order.id);
        final currentStatus = latest?.status ?? order.status;
        if (currentStatus == OrderStatus.pickedUp) {
          success = true;
        } else {
          success = await orderService.updateOrderStatus(
            orderId: order.id,
            status: OrderStatus.pickedUp,
            notes: 'Order picked up by delivery personnel',
          );
        }
      }

      if (!success) {
        // Treat "no rows updated" as non-fatal; inform user and exit
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Couldn\'t update order now. Please try again.',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.red[600],
            ),
          );
        }
        return;
      }

      // Show success message
      if (mounted) {
        final wasEarlyPickup = previousStatus == OrderStatus.preparing;
        final message = wasEarlyPickup
            ? 'Order #${order.orderNumber} picked up early (restaurant still preparing)!'
            : 'Order #${order.orderNumber} marked as picked up!';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message,
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: const Color(0xFFd47b00),
          ),
        );

        // Refresh dashboard data
        await _loadDashboardDataOptimized();
      }

      debugPrint('✅ Order ${order.id} marked as picked up successfully');
    } catch (e) {
      debugPrint('❌ Error marking order as picked up: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to mark order as picked up: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    }
  }

  Future<void> _markOrderAsDelivered(Order order) async {
    try {
      debugPrint('✅ Marking order ${order.id} as delivered');

      bool success = false;
      final deliveryPersonId = _deliveryPerson?.id;
      if (deliveryPersonId != null) {
        // Prefer delivery-scoped update to satisfy RLS
        final orderAssignmentService = OrderAssignmentService();
        success = await orderAssignmentService.markOrderDeliveredByDelivery(
          orderId: order.id,
          deliveryPersonId: deliveryPersonId,
        );
      } else {
        // Fallback to generic service
        final orderService = Provider.of<OrderService>(context, listen: false);
        final latest = await orderService.getOrderById(order.id);
        final currentStatus = latest?.status ?? order.status;
        if (currentStatus == OrderStatus.delivered) {
          success = true;
        } else {
          success = await orderService.updateOrderStatus(
            orderId: order.id,
            status: OrderStatus.delivered,
            notes: 'Order delivered successfully by delivery personnel',
          );
        }
      }

      if (!success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Couldn\'t update order now. Please try again.',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.red[600],
            ),
          );
        }
        return;
      }

      // Update delivery person earnings (placeholder)
      if (_deliveryPerson != null) {
        debugPrint('💰 Order delivered - earnings update needed');
      }

      // Stop location tracking for this delivery
      if (_deliveryPerson != null) {
        await _locationTrackingService
            .stopLocationTracking(_deliveryPerson!.userId);
        debugPrint('📍 Location tracking stopped for delivery completion');
      }

      // Stop tracking this order if needed and refresh UI handled by caller
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Order #${order.orderNumber} delivered successfully!',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green[600],
          ),
        );

        // Refresh dashboard data
        await _loadDashboardDataOptimized();
      }

      debugPrint('✅ Order ${order.id} marked as delivered successfully');
    } catch (e) {
      debugPrint('❌ Error marking order as delivered: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to mark order as delivered: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    }
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.confirmed:
        return Colors.blue;
      case OrderStatus.preparing:
        return Colors.purple;
      case OrderStatus.ready:
        return const Color(0xFFd47b00);
      case OrderStatus.pickedUp:
        return const Color(0xFFd47b00);
      case OrderStatus.delivered:
        return const Color(0xFFd47b00);
      case OrderStatus.cancelled:
        return Colors.red;
    }
  }

  IconData _getStatusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Icons.schedule;
      case OrderStatus.confirmed:
        return Icons.check_circle;
      case OrderStatus.preparing:
        return Icons.restaurant;
      case OrderStatus.ready:
        return Icons.restaurant_menu;
      case OrderStatus.pickedUp:
        return Icons.local_shipping;
      case OrderStatus.delivered:
        return Icons.check_circle;
      case OrderStatus.cancelled:
        return Icons.cancel;
    }
  }

  String _getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.preparing:
        return 'Preparing';
      case OrderStatus.ready:
        return 'Ready for Pickup';
      case OrderStatus.pickedUp:
        return 'Out for Delivery';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  String _getTaskStatusText(TaskStatus status) {
    switch (status) {
      case TaskStatus.pending:
        return 'Pending';
      case TaskStatus.costReview:
        return 'Cost Review';
      case TaskStatus.costProposed:
        return 'Cost Proposed';
      case TaskStatus.costAccepted:
        return 'Cost Accepted';
      case TaskStatus.userCounterProposed:
        return 'Waiting User Response';
      case TaskStatus.deliveryCounterProposed:
        return 'Delivery Counter';
      case TaskStatus.negotiationFinalized:
        return 'Negotiation Finalized';
      case TaskStatus.assigned:
        return 'Assigned';
      case TaskStatus.completed:
        return 'Completed';
      case TaskStatus.scheduled:
        return 'Scheduled';
      case TaskStatus.expired:
        return 'Expired';
    }
  }

  // ignore: unused_element
  Widget _buildStatusBasedHeaderContent(OrderTrackingData? trackingData) {
    if (_selectedOrder == null) return const SizedBox.shrink();

    final order = _selectedOrder!;
    final currentStep = trackingData?.currentStep ?? OrderStep.accepted;

    switch (currentStep) {
      case OrderStep.accepted:
        // When reviewing order - show restaurant address and user address with full route info
        return _buildReviewingOrderHeader(order, trackingData);
      case OrderStep.headingToRestaurant:
      case OrderStep.arrivedAtRestaurant:
        // When going for pickup - show restaurant address and distance/ETA
        return _buildPickupOrderHeader(order, trackingData);
      case OrderStep.pickedUp:
      case OrderStep.headingToCustomer:
      case OrderStep.arrivedAtCustomer:
        // When going for delivery - show user address and distance/ETA
        return _buildDeliveryOrderHeader(order, trackingData);
      case OrderStep.delivered:
        return _buildDeliveredOrderHeader(order);
    }
  }

  Widget _buildReviewingOrderHeader(
      Order order, OrderTrackingData? trackingData) {
    // Enhanced header info using restaurant_id and delivery_address JSONB
    final restaurantAddress = _getRestaurantAddress();
    final restaurantName = _getRestaurantName();
    final restaurantPhone = _getRestaurantPhone();
    final userAddress = _getDeliveryAddressFromModel();
    final customerName = _getCustomerName();
    final customerPhone = _getCustomerPhone();
    final totalDistance = _calculateTotalDistance(trackingData);
    final totalETA = _calculateTotalETA(trackingData);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Enhanced Restaurant info using restaurant_id
        Row(
          children: [
            const Icon(
              Icons.restaurant,
              size: 16,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    restaurantName,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (restaurantAddress.isNotEmpty)
                    Text(
                      restaurantAddress,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (restaurantPhone.isNotEmpty)
              GestureDetector(
                onTap: () => _launchTel(restaurantPhone),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.phone,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        // Dot under restaurant row
        Row(
          children: [
            const SizedBox(width: 8), // Align with icon
            Text(
              '•',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Enhanced Customer info using delivery_address JSONB
        Row(
          children: [
            const Icon(
              Icons.person,
              size: 16,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customerName,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (userAddress.isNotEmpty)
                    Text(
                      userAddress,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (customerPhone.isNotEmpty)
              GestureDetector(
                onTap: () => _launchTel(customerPhone),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.phone,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        // Dot under user row
        Row(
          children: [
            const SizedBox(width: 8), // Align with icon
            Text(
              '•',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Total route info
        Text(
          'Total: ${totalDistance.toStringAsFixed(1)} km • ${totalETA.inMinutes} min',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }

  Widget _buildPickupOrderHeader(Order order, OrderTrackingData? trackingData) {
    // Enhanced pickup header using restaurant_id and delivery_address JSONB
    final restaurantAddress = _getRestaurantAddress();
    final restaurantName = _getRestaurantName();
    final restaurantPhone = _getRestaurantPhone();
    final distance = trackingData?.distanceToDestination;
    final eta = trackingData?.estimatedTimeToDestination;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Enhanced Restaurant info for pickup
        Row(
          children: [
            const Icon(
              Icons.restaurant,
              size: 16,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    restaurantName,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (restaurantAddress.isNotEmpty)
                    Text(
                      restaurantAddress,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (restaurantPhone.isNotEmpty)
              GestureDetector(
                onTap: () => _launchTel(restaurantPhone),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.phone,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        // Dot under restaurant row
        Row(
          children: [
            const SizedBox(width: 8), // Align with icon
            Text(
              '•',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Pickup • ${distance?.toStringAsFixed(1) ?? "0.0"} km • ${eta?.inMinutes ?? 0} min',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveryOrderHeader(
      Order order, OrderTrackingData? trackingData) {
    final userAddress = _getCustomerAddress();
    final customerName = order.customer?.name ?? 'Customer';
    final distance = trackingData?.distanceToDestination;
    final eta = trackingData?.estimatedTimeToDestination;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.person,
              size: 16,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                userAddress,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              customerName,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.8),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Dot under customer row
        Row(
          children: [
            const SizedBox(width: 8), // Align with icon
            Text(
              '•',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Delivery • ${distance?.toStringAsFixed(1) ?? "0.0"} km • ${eta?.inMinutes ?? 0} min',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveredOrderHeader(Order order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.check_circle,
              size: 16,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              'Order Delivered',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Order #${order.orderNumber} completed',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }

  double _calculateTotalDistance(OrderTrackingData? trackingData) {
    // Calculate total distance from current location to restaurant then to user
    if (trackingData == null) return 0.0;

    // For reviewing state, we need to calculate the total route distance
    // This is an approximation since we don't have separate distances
    final currentDistance = trackingData.distanceToDestination ?? 0.0;

    // If we're in accepted state, estimate the total journey
    if (trackingData.currentStep == OrderStep.accepted) {
      // Estimate total distance as 1.5x current distance (restaurant + customer)
      return currentDistance * 1.5;
    }

    return currentDistance;
  }

  Duration _calculateTotalETA(OrderTrackingData? trackingData) {
    // Calculate total ETA from current location to restaurant then to user
    if (trackingData == null) return Duration.zero;

    final currentETA = trackingData.estimatedTimeToDestination ?? Duration.zero;

    // If we're in accepted state, estimate the total journey time
    if (trackingData.currentStep == OrderStep.accepted) {
      // Estimate total time as 1.5x current ETA (restaurant + customer)
      return Duration(
        minutes: (currentETA.inMinutes * 1.5).round(),
      );
    }

    return currentETA;
  }

  // Background loading methods (no setState calls)
  // DISABLED: Order loading method
  Future<void> _loadActiveOrdersBackground() async {
    // ENABLED: Order logic restored for new enhanced order cards
    try {
      if (_deliveryPerson == null) return;

      // Get the delivery_personnel.id for this user_id
      final deliveryPersonnelResponse = await Supabase.instance.client
          .from('delivery_personnel')
          .select('id')
          .eq('user_id', _deliveryPerson!.userId)
          .single();

      if (deliveryPersonnelResponse.isEmpty) {
        debugPrint(
            '❌ Delivery personnel record not found for user: ${_deliveryPerson!.userId}');
        return;
      }

      final deliveryPersonnelId = deliveryPersonnelResponse['id'];

      final activeOrdersResponse = await Supabase.instance.client
          .from('orders')
          .select('''
            *,
            restaurants!inner(*)
          ''')
          .eq('delivery_person_id', deliveryPersonnelId)
          .inFilter('status', ['preparing', 'ready', 'picked_up'])
          .order('created_at', ascending: false);

      final activeOrders =
          activeOrdersResponse.map((json) => Order.fromJson(json)).toList();

      _activeOrders = activeOrders;
      debugPrint('Background: Loaded ${activeOrders.length} active orders');
    } catch (e) {
      debugPrint('Background: Error loading active orders: $e');
    }
  }

  // DISABLED: Order loading method
  Future<void> _loadAvailableOrdersBackground() async {
    // ENABLED: Order logic restored for new enhanced order cards
    try {
      if (_deliveryPerson == null) return;

      final availableOrdersResponse = await Supabase.instance.client
          .from('orders')
          .select('''
            *,
            restaurants!inner(*)
          ''')
          .isFilter('delivery_person_id', null)
          .inFilter('status', ['preparing', 'ready'])
          .order('created_at', ascending: false);

      final availableOrders =
          availableOrdersResponse.map((json) => Order.fromJson(json)).toList();

      _availableOrders = availableOrders;
      debugPrint(
          'Background: Loaded ${availableOrders.length} available orders');
    } catch (e) {
      debugPrint('Background: Error loading available orders: $e');
    }
  }

  // DISABLED: Order loading method
  Future<void> _loadCompletedOrdersBackground() async {
    // ENABLED: Order logic restored for new enhanced order cards
    try {
      if (_deliveryPerson == null) return;

      // Get the delivery_personnel.id for this user_id
      final deliveryPersonnelResponse = await Supabase.instance.client
          .from('delivery_personnel')
          .select('id')
          .eq('user_id', _deliveryPerson!.userId)
          .single();

      if (deliveryPersonnelResponse.isEmpty) {
        debugPrint(
            '❌ Delivery personnel record not found for user: ${_deliveryPerson!.userId}');
        return;
      }

      final deliveryPersonnelId = deliveryPersonnelResponse['id'];

      final completedOrdersResponse = await Supabase.instance.client
          .from('orders')
          .select('''
            *,
            restaurants!inner(*)
          ''')
          .eq('delivery_person_id', deliveryPersonnelId)
          .eq('status', 'delivered')
          .order('created_at', ascending: false);

      final completedOrders =
          completedOrdersResponse.map((json) => Order.fromJson(json)).toList();

      _completedOrders = completedOrders;
      debugPrint(
          'Background: Loaded ${completedOrders.length} completed orders');
    } catch (e) {
      debugPrint('Background: Error loading completed orders: $e');
    }
  }

  Future<void> _loadAvailableTasksBackground() async {
    try {
      final availableTasks =
          await _integratedService.getAvailableTasksForDelivery();
      final costProposedTasks =
          await _integratedService.getCostProposedTasksForDelivery();
      final userCounterProposedTasks =
          await _integratedService.getUserCounterProposedTasksForDelivery();

      final allAvailableTasks = <Task>[];
      allAvailableTasks.addAll(availableTasks);
      allAvailableTasks.addAll(costProposedTasks);
      allAvailableTasks.addAll(userCounterProposedTasks);

      _availableTasks = allAvailableTasks;
      debugPrint(
          'Background: Loaded ${allAvailableTasks.length} available tasks');
    } catch (e) {
      debugPrint('Background: Error loading available tasks: $e');
    }
  }

  Future<void> _loadActiveTasksBackground() async {
    try {
      if (_deliveryPerson == null) return;

      final activeTasks = await _integratedService
          .getActiveTasksForDelivery(_deliveryPerson!.userId);
      _activeTasks = activeTasks;
      debugPrint('Background: Loaded ${activeTasks.length} active tasks');
    } catch (e) {
      debugPrint('Background: Error loading active tasks: $e');
    }
  }

  Future<void> _loadCompletedTasksBackground() async {
    try {
      if (_deliveryPerson == null) return;

      final completedTasks = await _integratedService
          .getCompletedTasksForDelivery(_deliveryPerson!.userId);
      _completedTasks = completedTasks;
      debugPrint('Background: Loaded ${completedTasks.length} completed tasks');
    } catch (e) {
      debugPrint('Background: Error loading completed tasks: $e');
    }
  }

  Future<void> _loadEarningsDataBackground() async {
    try {
      if (_deliveryPerson == null) return;

      _walletInfo =
          await _earningsService.getWalletInfo(_deliveryPerson!.userId);
      _walletInfo ??= {
        'current_balance': 0.0,
        'credit_balance': 0.0,
        'total_earned': 0.0,
        'total_service_fees_paid': 0.0,
      };

      _creditTransactions = await _earningsService.getCreditTransactions(
        deliveryPersonId: _deliveryPerson!.userId,
        limit: 10,
      );

      _pendingServiceFees =
          await _earningsService.getPendingServiceFees(_deliveryPerson!.userId);
      _dailyEarnings = await _earningsService.getDailyEarnings(
        deliveryPersonId: _deliveryPerson!.userId,
        days: 7,
      );

      debugPrint('Background: Earnings data loaded successfully');
    } catch (e) {
      debugPrint('Background: Error loading earnings data: $e');
    }
  }

  void _updateMapMarkersBackground() {
    final markers = <Marker>{};
    final polylines = <Polyline>{};

    // Add current location marker
    if (_currentLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: _currentLocation!,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: const InfoWindow(title: 'Your Location'),
        ),
      );
    }

    // Handle selected order with status-based map behavior
    if (_selectedOrder != null) {
      _updateSelectedOrderMapView(markers, polylines);
    } else {
      // Default behavior for non-selected orders
      _updateDefaultOrderMarkers(markers, polylines);
    }

    // Update markers without setState
    _markers = markers;
    _polylines.clear();
    _polylines.addAll(polylines);

    debugPrint('Background: Updated ${_markers.length} map markers');
  }

  /// Enhanced map functionality with ComprehensiveMapsService
  Future<void> _loadComprehensiveMapInfo() async {
    if (_currentLocation == null) return;

    try {
      debugPrint('🗺️ Loading comprehensive map information...');

      // Get delivery area information
      final deliveryAreaInfo =
          await ComprehensiveMapsService.getDeliveryAreaInfo(
        center: _currentLocation!,
        radiusKm: 10.0, // 10km delivery radius
      );

      if (deliveryAreaInfo != null && mounted) {
        debugPrint('✅ Comprehensive map info loaded:');
        debugPrint(
            '   Delivery area: ${deliveryAreaInfo.areaKm2.toStringAsFixed(2)} km²');
        debugPrint(
            '   Nearby restaurants: ${deliveryAreaInfo.nearbyRestaurants.length}');
        debugPrint(
            '   Time zone: ${deliveryAreaInfo.timeZone?.timeZoneId ?? 'Unknown'}');
      }

      // If we have a selected order, get comprehensive delivery info
      if (_selectedOrder != null && _selectedOrder!.restaurant != null) {
        final restaurantLocation = LatLng(
          _selectedOrder!.restaurant!.latitude ?? 0.0,
          _selectedOrder!.restaurant!.longitude ?? 0.0,
        );

        final customerLocation = LatLng(
          _selectedOrder!.deliveryAddress['latitude'] ?? 0.0,
          _selectedOrder!.deliveryAddress['longitude'] ?? 0.0,
        );

        final deliveryInfo =
            await ComprehensiveMapsService.getCompleteDeliveryInfo(
          restaurantLocation: restaurantLocation,
          customerLocation: customerLocation,
          deliveryPersonLocation: _currentLocation,
          restaurantName: _selectedOrder!.restaurant!.name,
        );

        if (deliveryInfo != null && mounted) {
          debugPrint('✅ Comprehensive delivery info loaded:');
          debugPrint('   Delivery time: ${deliveryInfo.formattedDeliveryTime}');
          debugPrint('   Distance: ${deliveryInfo.formattedDistance}');
          debugPrint(
              '   Street View available: ${deliveryInfo.streetViewAvailable}');

          // Update UI with comprehensive information
          _updateDeliveryInfoUI(deliveryInfo);
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading comprehensive map info: $e');
    }
  }

  /// Update UI with comprehensive delivery information
  void _updateDeliveryInfoUI(dynamic deliveryInfo) {
    // This would update the UI with comprehensive delivery information
    // For now, just log the information
    debugPrint('📊 Updating UI with delivery info:');
    debugPrint(
        '   Estimated delivery time: ${deliveryInfo.formattedDeliveryTime}');
    debugPrint('   Distance to customer: ${deliveryInfo.formattedDistance}');
    debugPrint('   Street View available: ${deliveryInfo.streetViewAvailable}');
  }

  /// Initialize comprehensive map tracking
  Future<void> _initializeComprehensiveMapTracking() async {
    // Wait for initial location to be loaded
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      await _loadComprehensiveMapInfo();
    }
  }

  /// Enhanced comprehensive earnings analytics
  Widget _buildComprehensiveEarningsAnalytics() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Advanced Analytics',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 12),

        // Analytics Cards Row
        Row(
          children: [
            Expanded(
              child: _buildAnalyticsCard(
                title: 'Earnings Summary',
                icon: Icons.analytics,
                color: Colors.green,
                onTap: () => _showEarningsSummary(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildAnalyticsCard(
                title: 'Service Fee Analysis',
                icon: Icons.account_balance,
                color: Colors.blue,
                onTap: () => _showServiceFeeAnalysis(),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _buildAnalyticsCard(
                title: 'Performance Metrics',
                icon: Icons.trending_up,
                color: Colors.purple,
                onTap: () => _showPerformanceMetrics(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildAnalyticsCard(
                title: 'Add Credit',
                icon: Icons.add_circle,
                color: Colors.orange,
                onTap: () => _showAddCreditDialog(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAnalyticsCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show comprehensive earnings summary
  Future<void> _showEarningsSummary() async {
    if (_deliveryPerson == null) return;

    try {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final summary = await _earningsService.getEarningsSummary(
        deliveryPersonId: _deliveryPerson!.userId,
        startDate: DateTime.now().subtract(const Duration(days: 30)),
        endDate: DateTime.now(),
      );

      if (mounted) Navigator.of(context).pop();

      if (summary != null) {
        _showEarningsSummaryDialog(summary);
      } else {
        _showErrorDialog('Failed to load earnings summary');
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      _showErrorDialog('Error loading earnings summary: $e');
    }
  }

  /// Show service fee analysis
  void _showServiceFeeAnalysis() {
    final currentBalance = (_walletInfo?['current_balance'] ?? 0.0).toDouble();
    final totalServiceFeesPaid =
        (_walletInfo?['total_service_fees_paid'] ?? 0.0).toDouble();
    const serviceFeeRate = ComprehensiveEarningsService.serviceFeeRate;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Service Fee Analysis'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Service Fee Rate: ${(serviceFeeRate * 100).toStringAsFixed(1)}%'),
            Text(
                'Total Service Fees Paid: ${totalServiceFeesPaid.toStringAsFixed(2)} DA'),
            Text('Current Balance: ${currentBalance.toStringAsFixed(2)} DA'),
            const SizedBox(height: 8),
            Text(
              'The app takes ${(serviceFeeRate * 100).toStringAsFixed(1)}% of your gross earnings as service fee. This fee helps maintain the platform and provides you with delivery opportunities.',
              style: GoogleFonts.poppins(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Show performance metrics
  void _showPerformanceMetrics() {
    final totalEarned = (_walletInfo?['total_earned'] ?? 0.0).toDouble();
    final totalServiceFeesPaid =
        (_walletInfo?['total_service_fees_paid'] ?? 0.0).toDouble();
    final netEarnings = totalEarned - totalServiceFeesPaid;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Performance Metrics'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total Gross Earnings: ${totalEarned.toStringAsFixed(2)} DA'),
            Text(
                'Total Service Fees Paid: ${totalServiceFeesPaid.toStringAsFixed(2)} DA'),
            Text('Net Earnings: ${netEarnings.toStringAsFixed(2)} DA'),
            Text(
                'Efficiency Rate: ${totalEarned > 0 ? ((netEarnings / totalEarned) * 100).toStringAsFixed(1) : '0.0'}%'),
            const SizedBox(height: 8),
            Text(
              'Your efficiency rate shows how much of your gross earnings you keep after service fees.',
              style: GoogleFonts.poppins(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Show add credit dialog
  void _showAddCreditDialog() {
    final amountController = TextEditingController();
    String selectedPaymentMethod = 'bank_transfer';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Credit'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount (DA)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedPaymentMethod,
                decoration: const InputDecoration(
                  labelText: 'Payment Method',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'bank_transfer', child: Text('Bank Transfer')),
                  DropdownMenuItem(
                      value: 'credit_card', child: Text('Credit Card')),
                  DropdownMenuItem(
                      value: 'mobile_payment', child: Text('Mobile Payment')),
                ],
                onChanged: (value) {
                  setState(() {
                    selectedPaymentMethod = value!;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text);
                if (amount != null && amount > 0) {
                  Navigator.of(context).pop();
                  await _addCredit(amount, selectedPaymentMethod);
                }
              },
              child: const Text('Add Credit'),
            ),
          ],
        ),
      ),
    );
  }

  /// Add credit to wallet
  Future<void> _addCredit(double amount, String paymentMethod) async {
    if (_deliveryPerson == null) return;

    try {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final success = await _earningsService.addCredit(
        deliveryPersonId: _deliveryPerson!.userId,
        amount: amount,
        paymentMethod: paymentMethod,
        paymentReference: 'REF_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (mounted) Navigator.of(context).pop();

      if (success) {
        _showSuccessDialog('Credit added successfully!');
        await _loadEarningsData(); // Refresh data
      } else {
        _showErrorDialog('Failed to add credit');
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      _showErrorDialog('Error adding credit: $e');
    }
  }

  /// Show earnings summary dialog
  void _showEarningsSummaryDialog(Map<String, dynamic> summary) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Earnings Summary (30 Days)'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'Total Base Fee: ${summary['total_base_fee']?.toStringAsFixed(2) ?? '0.00'} DA'),
              Text(
                  'Total Distance Fee: ${summary['total_distance_fee']?.toStringAsFixed(2) ?? '0.00'} DA'),
              Text(
                  'Total Performance Bonus: ${summary['total_performance_bonus']?.toStringAsFixed(2) ?? '0.00'} DA'),
              Text(
                  'Total Tips: ${summary['total_tip']?.toStringAsFixed(2) ?? '0.00'} DA'),
              Text(
                  'Total Penalties: ${summary['total_penalty']?.toStringAsFixed(2) ?? '0.00'} DA'),
              const Divider(),
              Text(
                  'Total Gross Earnings: ${summary['total_earnings']?.toStringAsFixed(2) ?? '0.00'} DA'),
              Text(
                  'Total Service Fees: ${summary['total_service_fees']?.toStringAsFixed(2) ?? '0.00'} DA'),
              Text(
                  'Net Earnings: ${summary['net_earnings']?.toStringAsFixed(2) ?? '0.00'} DA'),
              const Divider(),
              Text('Total Deliveries: ${summary['total_deliveries'] ?? 0}'),
              Text(
                  'Average per Delivery: ${summary['average_earnings_per_delivery']?.toStringAsFixed(2) ?? '0.00'} DA'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Show success dialog
  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Success'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Show error dialog
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Unsubscribe from real-time location updates
    _locationTrackingService.unsubscribeFromLocationUpdates();
    debugPrint('📍 Unsubscribed from real-time location updates');

    // Stop location tracking
    if (_deliveryPerson != null) {
      _locationTrackingService.stopLocationTracking(_deliveryPerson!.userId);
      debugPrint('📍 Stopped location tracking');
    }

    // Dispose controllers
    _deliveryNameController.dispose();
    _workPhoneController.dispose();
    _vehicleBrandController.dispose();
    _vehicleModelController.dispose();
    _vehicleYearController.dispose();
    _vehicleColorController.dispose();
    _vehiclePlateController.dispose();

    // Dispose animation controllers
    _slideController.dispose();
    _fadeController.dispose();

    // Cancel subscriptions
    _ordersSubscription?.cancel();
    _locationSubscription?.cancel();

    // Cancel timers
    _cancelTimer?.cancel();

    super.dispose();
  }
}

class _LocationInfo {
  final String purpose;
  final String address;
  final String coordinates;
  _LocationInfo({
    required this.purpose,
    required this.address,
    this.coordinates = '',
  });
}
