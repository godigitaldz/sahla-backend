import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_localizations.dart';
import '../models/restaurant_form_state.dart';
import '../services/connectivity_service.dart';
import '../services/form_analytics_service.dart';
import '../services/form_draft_service.dart';
import '../services/form_persistence_service.dart';
import '../services/restaurant_request_service.dart';
import '../services/security_service.dart';
import '../services/services_catalog_service.dart';
import '../utils/input_sanitizer.dart';
import '../widgets/become_restaurant_owner_screen/image_upload_widget.dart';
import '../widgets/become_restaurant_owner_screen/location_selection_widget.dart';
import '../widgets/become_restaurant_owner_screen/progressive_form_widget.dart';
import '../widgets/become_restaurant_owner_screen/sector_aware_form_fields.dart';
import '../widgets/become_restaurant_owner_screen/working_hours_widget.dart';
import '../widgets/pill_dropdown.dart';

class BecomeRestaurantOwnerScreen extends StatefulWidget {
  const BecomeRestaurantOwnerScreen({super.key});

  @override
  State<BecomeRestaurantOwnerScreen> createState() =>
      _BecomeRestaurantOwnerScreenState();
}

class _BecomeRestaurantOwnerScreenState
    extends State<BecomeRestaurantOwnerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _restaurantNameController = TextEditingController();
  final _restaurantDescriptionController = TextEditingController();
  final _restaurantPhoneController = TextEditingController();
  final _facebookController = TextEditingController();
  final _instagramController = TextEditingController();
  final _tiktokController = TextEditingController();

  // Form state management
  RestaurantFormState _formState = const RestaurantFormState();

  // Working hours state
  final Map<String, Map<String, String?>> _workingHours = {};

  // Location state
  String? _selectedAddress;
  double? _selectedLatitude;
  double? _selectedLongitude;

  // Image state
  File? _restaurantLogo;
  String? _uploadedLogoUrl;
  bool _isUploadingLogo = false;

  // Sector and services
  List<ServiceOption> _availableServices = const [];
  String? _selectedGroceryType;

  // Canonical wilaya keys used as stable values in dropdowns
  static const List<String> _wilayaKeys = [
    'adrar',
    'chlef',
    'laghouat',
    'oumElBouaghi',
    'batna',
    'bejaia',
    'biskra',
    'bechar',
    'blida',
    'bouira',
    'tamanrasset',
    'tebessa',
    'tlemcen',
    'tiaret',
    'tiziOuzou',
    'algiers',
    'djelfa',
    'jijel',
    'setif',
    'saida',
    'skikda',
    'sidiBelAbbes',
    'annaba',
    'guelma',
    'constantine',
    'medea',
    'mostaganem',
    'msila',
    'mascara',
    'ouargla',
    'oran',
    'elBayadh',
    'illizi',
    'bordjBouArreridj',
    'boumerdes',
    'elTarf',
    'tindouf',
    'tissemsilt',
    'elOued',
    'khenchela',
    'soukAhras',
    'tipaza',
    'mila',
    'ainDefla',
    'naama',
    'ainTemouchent',
    'ghardaia',
    'relizane',
    'elMghair',
    'elMenia',
  ];

  // Progressive form
  int _currentStep = 0;
  List<String> _getLocalizedSteps(BuildContext context) => [
        AppLocalizations.of(context)!.serviceAndBasicInfo,
        AppLocalizations.of(context)!.location,
        AppLocalizations.of(context)!.workingHours,
        AppLocalizations.of(context)!.additionalDetails,
      ];

  // Services
  final ConnectivityService _connectivityService = ConnectivityService();
  final RestaurantRequestService _restaurantRequestService =
      RestaurantRequestService();
  bool _isOnline = true;
  bool _isSubmitting = false;

  // Form persistence
  Timer? _autoSaveTimer;
  bool _hasUnsavedChanges = false;
  bool _hasTrackedInitialStep = false;

  // Localized grocery type methods

  List<String> _getLocalizedGroceryTypes(BuildContext context) {
    return [
      AppLocalizations.of(context)!.superMarket,
      AppLocalizations.of(context)!.boucherie,
      AppLocalizations.of(context)!.patisserie,
      AppLocalizations.of(context)!.fruitsVegetables,
      AppLocalizations.of(context)!.bakery,
      AppLocalizations.of(context)!.seafood,
      AppLocalizations.of(context)!.dairy,
      AppLocalizations.of(context)!.other,
    ];
  }

  List<DropdownMenuItem<String>> _getWilayaDropdownItems(BuildContext context) {
    return _wilayaKeys.map((key) {
      String displayText;
      switch (key) {
        case 'adrar':
          displayText = AppLocalizations.of(context)!.adrar;
          break;
        case 'chlef':
          displayText = AppLocalizations.of(context)!.chlef;
          break;
        case 'laghouat':
          displayText = AppLocalizations.of(context)!.laghouat;
          break;
        case 'oumElBouaghi':
          displayText = AppLocalizations.of(context)!.oumElBouaghi;
          break;
        case 'batna':
          displayText = AppLocalizations.of(context)!.batna;
          break;
        case 'bejaia':
          displayText = AppLocalizations.of(context)!.bejaia;
          break;
        case 'biskra':
          displayText = AppLocalizations.of(context)!.biskra;
          break;
        case 'bechar':
          displayText = AppLocalizations.of(context)!.bechar;
          break;
        case 'blida':
          displayText = AppLocalizations.of(context)!.blida;
          break;
        case 'bouira':
          displayText = AppLocalizations.of(context)!.bouira;
          break;
        case 'tamanrasset':
          displayText = AppLocalizations.of(context)!.tamanrasset;
          break;
        case 'tebessa':
          displayText = AppLocalizations.of(context)!.tebessa;
          break;
        case 'tlemcen':
          displayText = AppLocalizations.of(context)!.tlemcen;
          break;
        case 'tiaret':
          displayText = AppLocalizations.of(context)!.tiaret;
          break;
        case 'tiziOuzou':
          displayText = AppLocalizations.of(context)!.tiziOuzou;
          break;
        case 'algiers':
          displayText = AppLocalizations.of(context)!.algiers;
          break;
        case 'djelfa':
          displayText = AppLocalizations.of(context)!.djelfa;
          break;
        case 'jijel':
          displayText = AppLocalizations.of(context)!.jijel;
          break;
        case 'setif':
          displayText = AppLocalizations.of(context)!.setif;
          break;
        case 'saida':
          displayText = AppLocalizations.of(context)!.saida;
          break;
        case 'skikda':
          displayText = AppLocalizations.of(context)!.skikda;
          break;
        case 'sidiBelAbbes':
          displayText = AppLocalizations.of(context)!.sidiBelAbbes;
          break;
        case 'annaba':
          displayText = AppLocalizations.of(context)!.annaba;
          break;
        case 'guelma':
          displayText = AppLocalizations.of(context)!.guelma;
          break;
        case 'constantine':
          displayText = AppLocalizations.of(context)!.constantine;
          break;
        case 'medea':
          displayText = AppLocalizations.of(context)!.medea;
          break;
        case 'mostaganem':
          displayText = AppLocalizations.of(context)!.mostaganem;
          break;
        case 'msila':
          displayText = AppLocalizations.of(context)!.msila;
          break;
        case 'mascara':
          displayText = AppLocalizations.of(context)!.mascara;
          break;
        case 'ouargla':
          displayText = AppLocalizations.of(context)!.ouargla;
          break;
        case 'oran':
          displayText = AppLocalizations.of(context)!.oran;
          break;
        case 'elBayadh':
          displayText = AppLocalizations.of(context)!.elBayadh;
          break;
        case 'illizi':
          displayText = AppLocalizations.of(context)!.illizi;
          break;
        case 'bordjBouArreridj':
          displayText = AppLocalizations.of(context)!.bordjBouArreridj;
          break;
        case 'boumerdes':
          displayText = AppLocalizations.of(context)!.boumerdes;
          break;
        case 'elTarf':
          displayText = AppLocalizations.of(context)!.elTarf;
          break;
        case 'tindouf':
          displayText = AppLocalizations.of(context)!.tindouf;
          break;
        case 'tissemsilt':
          displayText = AppLocalizations.of(context)!.tissemsilt;
          break;
        case 'elOued':
          displayText = AppLocalizations.of(context)!.elOued;
          break;
        case 'khenchela':
          displayText = AppLocalizations.of(context)!.khenchela;
          break;
        case 'soukAhras':
          displayText = AppLocalizations.of(context)!.soukAhras;
          break;
        case 'tipaza':
          displayText = AppLocalizations.of(context)!.tipaza;
          break;
        case 'mila':
          displayText = AppLocalizations.of(context)!.mila;
          break;
        case 'ainDefla':
          displayText = AppLocalizations.of(context)!.ainDefla;
          break;
        case 'naama':
          displayText = AppLocalizations.of(context)!.naama;
          break;
        case 'ainTemouchent':
          displayText = AppLocalizations.of(context)!.ainTemouchent;
          break;
        case 'ghardaia':
          displayText = AppLocalizations.of(context)!.ghardaia;
          break;
        case 'relizane':
          displayText = AppLocalizations.of(context)!.relizane;
          break;
        case 'elMghair':
          displayText = AppLocalizations.of(context)!.elMghair;
          break;
        case 'elMenia':
          displayText = AppLocalizations.of(context)!.elMenia;
          break;
        default:
          displayText = key;
          break;
      }

      return DropdownMenuItem<String>(
        value: key, // Use the key as the unique value
        child: Text(displayText),
      );
    }).toList();
  }

  String _getWilayaDisplayText(String wilayaKey, BuildContext context) {
    switch (wilayaKey) {
      case 'adrar':
        return AppLocalizations.of(context)!.adrar;
      case 'chlef':
        return AppLocalizations.of(context)!.chlef;
      case 'laghouat':
        return AppLocalizations.of(context)!.laghouat;
      case 'oumElBouaghi':
        return AppLocalizations.of(context)!.oumElBouaghi;
      case 'batna':
        return AppLocalizations.of(context)!.batna;
      case 'bejaia':
        return AppLocalizations.of(context)!.bejaia;
      case 'biskra':
        return AppLocalizations.of(context)!.biskra;
      case 'bechar':
        return AppLocalizations.of(context)!.bechar;
      case 'blida':
        return AppLocalizations.of(context)!.blida;
      case 'bouira':
        return AppLocalizations.of(context)!.bouira;
      case 'tamanrasset':
        return AppLocalizations.of(context)!.tamanrasset;
      case 'tebessa':
        return AppLocalizations.of(context)!.tebessa;
      case 'tlemcen':
        return AppLocalizations.of(context)!.tlemcen;
      case 'tiaret':
        return AppLocalizations.of(context)!.tiaret;
      case 'tiziOuzou':
        return AppLocalizations.of(context)!.tiziOuzou;
      case 'algiers':
        return AppLocalizations.of(context)!.algiers;
      case 'djelfa':
        return AppLocalizations.of(context)!.djelfa;
      case 'jijel':
        return AppLocalizations.of(context)!.jijel;
      case 'setif':
        return AppLocalizations.of(context)!.setif;
      case 'saida':
        return AppLocalizations.of(context)!.saida;
      case 'skikda':
        return AppLocalizations.of(context)!.skikda;
      case 'sidiBelAbbes':
        return AppLocalizations.of(context)!.sidiBelAbbes;
      case 'annaba':
        return AppLocalizations.of(context)!.annaba;
      case 'guelma':
        return AppLocalizations.of(context)!.guelma;
      case 'constantine':
        return AppLocalizations.of(context)!.constantine;
      case 'medea':
        return AppLocalizations.of(context)!.medea;
      case 'mostaganem':
        return AppLocalizations.of(context)!.mostaganem;
      case 'msila':
        return AppLocalizations.of(context)!.msila;
      case 'mascara':
        return AppLocalizations.of(context)!.mascara;
      case 'ouargla':
        return AppLocalizations.of(context)!.ouargla;
      case 'oran':
        return AppLocalizations.of(context)!.oran;
      case 'elBayadh':
        return AppLocalizations.of(context)!.elBayadh;
      case 'illizi':
        return AppLocalizations.of(context)!.illizi;
      case 'bordjBouArreridj':
        return AppLocalizations.of(context)!.bordjBouArreridj;
      case 'boumerdes':
        return AppLocalizations.of(context)!.boumerdes;
      case 'elTarf':
        return AppLocalizations.of(context)!.elTarf;
      case 'tindouf':
        return AppLocalizations.of(context)!.tindouf;
      case 'tissemsilt':
        return AppLocalizations.of(context)!.tissemsilt;
      case 'elOued':
        return AppLocalizations.of(context)!.elOued;
      case 'khenchela':
        return AppLocalizations.of(context)!.khenchela;
      case 'soukAhras':
        return AppLocalizations.of(context)!.soukAhras;
      case 'tipaza':
        return AppLocalizations.of(context)!.tipaza;
      case 'mila':
        return AppLocalizations.of(context)!.mila;
      case 'ainDefla':
        return AppLocalizations.of(context)!.ainDefla;
      case 'naama':
        return AppLocalizations.of(context)!.naama;
      case 'ainTemouchent':
        return AppLocalizations.of(context)!.ainTemouchent;
      case 'ghardaia':
        return AppLocalizations.of(context)!.ghardaia;
      case 'relizane':
        return AppLocalizations.of(context)!.relizane;
      case 'elMghair':
        return AppLocalizations.of(context)!.elMghair;
      case 'elMenia':
        return AppLocalizations.of(context)!.elMenia;
      default:
        return wilayaKey;
    }
  }

  @override
  void initState() {
    super.initState();
    FormPerformanceTracker.trackFormLoadTime();
    _initializeServices();
    _loadServices();
    _loadSavedFormState();
    _startAutoSave();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Track initial step after dependencies are available (only once)
    if (!_hasTrackedInitialStep) {
      FormAnalytics.trackFormStep(_getLocalizedSteps(context)[_currentStep]);
      _hasTrackedInitialStep = true;
    }
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _connectivityService.dispose();
    _restaurantNameController.dispose();
    _restaurantDescriptionController.dispose();
    _restaurantPhoneController.dispose();
    _facebookController.dispose();
    _instagramController.dispose();
    _tiktokController.dispose();
    super.dispose();
  }

  Future<void> _loadServices() async {
    try {
      final service = ServicesCatalogService(Supabase.instance.client);
      final list = await service.fetchAvailableServices();
      if (list.isNotEmpty) {
        setState(() {
          _availableServices = list;
          if (!_availableServices.any((s) => s.key == _formState.sector)) {
            _formState =
                _formState.copyWith(sector: _availableServices.first.key);
          }
        });
      }
    } catch (_) {
      // Silent fallback: keep hardcoded options
    }
  }

  Future<void> _initializeServices() async {
    try {
      await _connectivityService.initialize();
      _connectivityService.connectivityStream.listen((isOnline) {
        if (mounted) {
          setState(() {
            _isOnline = isOnline;
          });

          if (isOnline && _hasUnsavedChanges) {
            _showSnackBar(
                AppLocalizations.of(context)!.connectionRestored, Colors.green);
          } else if (!isOnline) {
            _showSnackBar(AppLocalizations.of(context)!.noInternetConnection,
                Colors.orange);
          }
        }
      });
    } catch (e) {
      debugPrint('❌ Error initializing services: $e');
    }
  }

  Future<void> _loadSavedFormState() async {
    try {
      final savedState = await FormPersistenceService.loadFormState();
      if (savedState != null) {
        final formStateMap = savedState['formState'] as Map<String, dynamic>;
        final currentStep = savedState['currentStep'] as int;

        // Store context before async operations
        final currentContext = context;

        // Restore form state
        _formState = RestaurantFormState.fromMap(formStateMap);
        // Normalize wilaya: ensure it's a canonical key; otherwise clear
        if (!_wilayaKeys.contains(_formState.wilaya)) {
          _formState = _formState.copyWith(wilaya: '');
        }

        // Restore form fields
        _restaurantNameController.text = _formState.restaurantName;
        _restaurantDescriptionController.text = _formState.description;
        _restaurantPhoneController.text = _formState.phone;
        _facebookController.text = _formState.facebook ?? '';
        _instagramController.text = _formState.instagram ?? '';
        _tiktokController.text = _formState.tiktok ?? '';

        // Restore location
        _selectedAddress = _formState.address;
        _selectedLatitude = _formState.latitude;
        _selectedLongitude = _formState.longitude;

        // Restore working hours
        _workingHours.clear();
        _workingHours.addAll(
            Map<String, Map<String, String?>>.from(_formState.workingHours));

        // Restore current step
        if (mounted) {
          // ignore: use_build_context_synchronously
          final steps = _getLocalizedSteps(currentContext);
          if (currentStep < steps.length) {
            _currentStep = currentStep;
          }

          _showSnackBar(
              // ignore: use_build_context_synchronously
              AppLocalizations.of(currentContext)!
                  .formRestoredFromPreviousSession,
              Colors.blue);
        }
      }
    } catch (e) {
      debugPrint('Error restoring form state: $e');
    }
  }

  void _startAutoSave() {
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_hasUnsavedChanges) {
        _autoSaveForm();
      }
    });
  }

  Future<void> _autoSaveForm() async {
    try {
      final formData = _getFormData();
      await FormPersistenceService.autoSaveForm(formData);
      await FormDraftService.autoSaveDraft(formData, _currentStep);

      if (mounted) {
        setState(() {
          _hasUnsavedChanges = false;
        });
      }
    } catch (e) {
      debugPrint('Error auto-saving form: $e');
    }
  }

  Map<String, dynamic> _getFormData() {
    return {
      'restaurantName': _restaurantNameController.text,
      'description': _restaurantDescriptionController.text,
      'phone': _restaurantPhoneController.text,
      'address': _selectedAddress,
      'wilaya': _formState.wilaya,
      'sector': _formState.sector,
      'workingHours': _workingHours,
      'latitude': _selectedLatitude,
      'longitude': _selectedLongitude,
      'logoUrl': _uploadedLogoUrl,
      'facebook': _facebookController.text,
      'instagram': _instagramController.text,
      'tiktok': _tiktokController.text,
    };
  }

  List<ServiceOption> _effectiveServices() {
    if (_availableServices.isNotEmpty) return _availableServices;
    return [
      ServiceOption(
          key: 'restaurant',
          name: AppLocalizations.of(context)!.restaurants,
          icon: 'restaurant'),
      ServiceOption(
          key: 'grocery',
          name: AppLocalizations.of(context)!.grocery,
          icon: 'local_grocery_store'),
      ServiceOption(
          key: 'handyman',
          name: AppLocalizations.of(context)!.handyman,
          icon: 'build'),
      ServiceOption(
          key: 'home_food',
          name: AppLocalizations.of(context)!.homeFood,
          icon: 'home'),
    ];
  }

  void _onStepChanged(int step) {
    setState(() {
      _currentStep = step;
    });
    FormAnalytics.trackFormStep(_getLocalizedSteps(context)[step]);
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _submitRestaurantRequest() async {
    if (_isSubmitting) return;

    // Validate all steps
    for (int i = 0; i < _getLocalizedSteps(context).length; i++) {
      if (!_validateStep(i)) {
        _onStepChanged(i);
        return;
      }
    }

    if (!_isOnline) {
      _showSnackBar(AppLocalizations.of(context)!.pleaseCheckInternetConnection,
          Colors.red);
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    // Store localized strings before async operation
    final successMessage =
        AppLocalizations.of(context)!.restaurantRequestSubmittedSuccessfully;
    final failureMessage = AppLocalizations.of(context)!.failedToSubmitRequest;
    final errorMessage = AppLocalizations.of(context)!.errorOccurred;

    try {
      // Convert working hours to jsonb format for submission
      final openingHoursJsonb =
          _convertWorkingHoursToJsonb(_workingHours, 'opening');
      final closingHoursJsonb =
          _convertWorkingHoursToJsonb(_workingHours, 'closing');

      // Debug: Log submission data
      debugPrint('📝 Submitting restaurant request with data:');
      debugPrint(
          '   Restaurant Name: ${_restaurantNameController.text.trim()}');
      debugPrint('   Logo URL: $_uploadedLogoUrl');
      debugPrint('   Address: ${_selectedAddress ?? ''}');
      debugPrint('   Phone: ${_restaurantPhoneController.text.trim()}');
      debugPrint('   Wilaya: ${_formState.wilaya}');
      debugPrint('   Opening Hours (JSONB): $openingHoursJsonb');
      debugPrint('   Closing Hours (JSONB): $closingHoursJsonb');
      debugPrint('   Latitude: $_selectedLatitude');
      debugPrint('   Longitude: $_selectedLongitude');

      // Submit restaurant request
      final result = await _restaurantRequestService.submitRestaurantRequest(
        restaurantName: _restaurantNameController.text.trim(),
        restaurantDescription: _restaurantDescriptionController.text.trim(),
        restaurantAddress: _selectedAddress ?? '',
        restaurantPhone: _restaurantPhoneController.text.trim(),
        wilaya: _getWilayaDisplayText(_formState.wilaya, context),
        openingHoursJsonb: openingHoursJsonb,
        closingHoursJsonb: closingHoursJsonb,
        logoUrl: _uploadedLogoUrl,
        latitude: _selectedLatitude,
        longitude: _selectedLongitude,
        // Social media fields
        instagram: _instagramController.text.trim().isNotEmpty
            ? _instagramController.text.trim()
            : null,
        facebook: _facebookController.text.trim().isNotEmpty
            ? _facebookController.text.trim()
            : null,
        tiktok: _tiktokController.text.trim().isNotEmpty
            ? _tiktokController.text.trim()
            : null,
        // Additional restaurant fields
        email: null, // Can be added later if needed
        addressLine2: null, // Can be added later if needed
        city: _getWilayaDisplayText(
            _formState.wilaya, context), // Use wilaya as city for now
        state: _getWilayaDisplayText(
            _formState.wilaya, context), // Use wilaya as state for now
        postalCode: null, // Can be added later if needed
        coverImageUrl: null, // Can be added later if needed
      );

      if (result.isRight) {
        // Success
        _showSnackBar(successMessage, Colors.green);

        // Clear form data
        _clearForm();

        // Navigate back or show success screen
        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        // Error
        final error = result.left;
        _showSnackBar('$failureMessage: ${error.message}', Colors.red);
      }
    } catch (e) {
      _showSnackBar(errorMessage(e.toString()), Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _clearForm() {
    _restaurantNameController.clear();
    _restaurantDescriptionController.clear();
    _restaurantPhoneController.clear();
    _facebookController.clear();
    _instagramController.clear();
    _tiktokController.clear();

    setState(() {
      _formState = const RestaurantFormState();
      _selectedAddress = null;
      _selectedLatitude = null;
      _selectedLongitude = null;
      _restaurantLogo = null;
      _uploadedLogoUrl = null;
      _workingHours.clear();
      _currentStep = 0;
    });
  }

  /// Convert working hours to jsonb format for database storage
  Map<String, dynamic> _convertWorkingHoursToJsonb(
      Map<String, Map<String, String?>> workingHours, String type) {
    final days = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday'
    ];
    final Map<String, dynamic> result = {};

    for (final day in days) {
      final dayData = workingHours[day];
      if (dayData != null && dayData['isOpen'] == 'true') {
        result[day] = {
          'isOpen': true,
          'open': dayData['open'] ?? '08:00',
          'close': dayData['close'] ?? '22:00',
          'hasBreak': dayData['hasBreak'] == 'true',
          'breakStart': dayData['breakStart'],
          'breakEnd': dayData['breakEnd'],
        };
      } else {
        result[day] = {
          'isOpen': false,
          'open': null,
          'close': null,
          'hasBreak': false,
          'breakStart': null,
          'breakEnd': null,
        };
      }
    }

    return result;
  }

  // Step validation methods
  bool _validateStep(int step) {
    switch (step) {
      case 0: // Service & Basic Info
        return _validateServiceAndBasicInfo();
      case 1: // Location
        return _validateLocation();
      case 2: // Working Hours
        return _validateWorkingHours();
      case 3: // Additional Details
        return _validateAdditionalDetails();
      default:
        return false;
    }
  }

  bool _validateServiceAndBasicInfo() {
    // Check service selection
    if (_formState.sector.isEmpty) {
      _showSnackBar(
          AppLocalizations.of(context)!.pleaseSelectServiceType, Colors.red);
      return false;
    }

    // Check restaurant name
    if (_restaurantNameController.text.trim().isEmpty) {
      _showSnackBar(
          AppLocalizations.of(context)!.pleaseEnterRestaurantName, Colors.red);
      return false;
    }

    // Check wilaya
    if (_formState.wilaya.isEmpty) {
      _showSnackBar(
          AppLocalizations.of(context)!.pleaseSelectWilaya, Colors.red);
      return false;
    }

    // Check phone
    if (_restaurantPhoneController.text.trim().isEmpty) {
      _showSnackBar(
          AppLocalizations.of(context)!.pleaseEnterRestaurantPhone, Colors.red);
      return false;
    }

    // Check grocery type if applicable
    if (_formState.sector == 'grocery' &&
        (_selectedGroceryType == null || _selectedGroceryType!.isEmpty)) {
      _showSnackBar(
          AppLocalizations.of(context)!.pleaseSelectGroceryType, Colors.red);
      return false;
    }

    return true;
  }

  bool _validateLocation() {
    if (_selectedAddress == null || _selectedAddress!.isEmpty) {
      _showSnackBar(AppLocalizations.of(context)!.pleaseSelectRestaurantAddress,
          Colors.red);
      return false;
    }
    return true;
  }

  bool _validateWorkingHours() {
    if (_workingHours.isEmpty) {
      _showSnackBar(AppLocalizations.of(context)!.pleaseConfigureWorkingHours,
          Colors.red);
      return false;
    }
    return true;
  }

  bool _validateAdditionalDetails() {
    // Additional details step is optional, so always return true
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            // Top safe space
            const SizedBox(height: 10),

            // Connectivity status indicator
            if (!_isOnline)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.orange,
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context)!.noInternetConnection,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),

            // Back button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.grey[700],
                      padding: const EdgeInsets.all(12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.becomeRestaurantOwner,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Main form content
            Expanded(
              child: ProgressiveFormWidget(
                steps: _getLocalizedSteps(context),
                currentStep: _currentStep,
                onStepChanged: _onStepChanged,
                validateStep: _validateStep,
                onSubmit: _submitRestaurantRequest,
                isSubmitting: _isSubmitting,
                child: Form(
                  key: _formKey,
                  child: _buildStepContent(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildServiceTypeStep();
      case 1:
        return _buildLocationStep();
      case 2:
        return _buildWorkingHoursStep();
      case 3:
        return _buildAdditionalDetailsStep();
      default:
        return _buildServiceTypeStep();
    }
  }

  Widget _buildServiceTypeStep() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Services dropdown
            PillDropdown<String>(
              hint: AppLocalizations.of(context)!.selectService,
              value: _formState.sector,
              items: _effectiveServices()
                  .map((s) => DropdownMenuItem<String>(
                        value: s.key,
                        child: Text.rich(
                          TextSpan(
                            children: [
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Icon(_iconFromString(s.icon),
                                    size: 18, color: Colors.black87),
                              ),
                              TextSpan(
                                text: '  ${s.name}',
                                style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _formState = _formState.copyWith(sector: val));
                  FormAnalytics.trackSectorSelection(val);
                }
              },
              validator: (value) => (value == null || value.isEmpty)
                  ? AppLocalizations.of(context)!.pleaseSelectService
                  : null,
            ),

            const SizedBox(height: 16),

            // Logo Upload
            ImageUploadWidget(
              currentImageUrl: _uploadedLogoUrl,
              currentImageFile: _restaurantLogo,
              bucketName: 'restaurant-logos',
              entityLabel: _formState.entityLabel,
              isLoading: _isUploadingLogo,
              onImageSelected: (url, file) async {
                setState(() {
                  _isUploadingLogo = true;
                });

                try {
                  // Debug: Check if URL is valid
                  debugPrint('🖼️ Logo upload callback received:');
                  debugPrint('   URL: $url');
                  debugPrint('   File: ${file.path}');

                  if (url.isEmpty) {
                    throw Exception(
                        'Logo URL is empty - upload may have failed');
                  }

                  setState(() {
                    _uploadedLogoUrl = url;
                    _restaurantLogo = file;
                    _isUploadingLogo = false;
                  });

                  _showSnackBar(
                      AppLocalizations.of(context)!.logoUploadedSuccessfully,
                      Colors.green);
                  debugPrint('✅ Logo state updated successfully');
                } catch (e) {
                  debugPrint('❌ Logo upload error: $e');
                  setState(() {
                    _isUploadingLogo = false;
                  });
                  _showSnackBar('Failed to upload logo: $e', Colors.red);
                }
              },
              onImageRemoved: () {
                setState(() {
                  _uploadedLogoUrl = null;
                  _restaurantLogo = null;
                  _isUploadingLogo = false;
                });
                _showSnackBar('Logo removed', Colors.orange);
              },
            ),

            const SizedBox(height: 16),

            // Grocery Type (if applicable)
            if (_formState.sector == 'grocery') ...[
              SectorAwareDropdown<String>(
                sector: _formState.sector,
                fieldType: 'grocery_type',
                value: _selectedGroceryType,
                items: _getLocalizedGroceryTypes(context)
                    .map((t) => DropdownMenuItem<String>(
                          value: t,
                          child: Text(t),
                        ))
                    .toList(),
                onChanged: (val) => setState(() => _selectedGroceryType = val),
                validator: (val) {
                  if (_formState.sector == 'grocery' &&
                      (val == null || val.isEmpty)) {
                    return AppLocalizations.of(context)!
                        .pleaseSelectGroceryType;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
            ],

            // Restaurant Name
            SectorAwareTextField(
              sector: _formState.sector,
              fieldType: 'name',
              controller: _restaurantNameController,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  FormAnalytics.trackValidationError(
                      'restaurant_name', 'required');
                  return AppLocalizations.of(context)!
                      .pleaseEnterRestaurantName;
                }
                if (!InputSanitizer.isValidRestaurantName(value)) {
                  FormAnalytics.trackValidationError(
                      'restaurant_name', 'invalid_format');
                  return AppLocalizations.of(context)!.pleaseEnterValidName;
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Wilaya
            SectorAwareDropdown<String>(
              sector: _formState.sector,
              fieldType: 'wilaya',
              value: _formState.wilaya.isEmpty ? null : _formState.wilaya,
              items: _getWilayaDropdownItems(context),
              onChanged: (wilaya) {
                if (wilaya != null) {
                  setState(() {
                    _formState = _formState.copyWith(wilaya: wilaya);
                  });
                }
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  FormAnalytics.trackValidationError('wilaya', 'required');
                  return AppLocalizations.of(context)!.pleaseSelectWilaya;
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Phone
            SectorAwareTextField(
              sector: _formState.sector,
              fieldType: 'phone',
              controller: _restaurantPhoneController,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  FormAnalytics.trackValidationError('phone', 'required');
                  return AppLocalizations.of(context)!
                      .pleaseEnterRestaurantPhone;
                }
                if (!InputSanitizer.isValidPhoneNumber(value)) {
                  FormAnalytics.trackValidationError('phone', 'invalid_format');
                  return AppLocalizations.of(context)!.pleaseEnterValidPhone;
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationStep() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            LocationSelectionWidget(
              selectedAddress: _selectedAddress,
              latitude: _selectedLatitude,
              longitude: _selectedLongitude,
              entityLabel: _formState.entityLabel,
              onLocationSelected: (address, lat, lng) {
                setState(() {
                  _selectedAddress = address;
                  _selectedLatitude = lat;
                  _selectedLongitude = lng;
                });

                // Validate coordinates
                if (!SecurityService.validateLocationCoordinates(lat, lng)) {
                  _showSnackBar(
                      'Please select a location within Algeria', Colors.orange);
                  return;
                }

                FormAnalytics.trackLocationMethod('manual', success: true);
              },
              validator: (value) {
                if (_selectedAddress == null || _selectedAddress!.isEmpty) {
                  FormAnalytics.trackValidationError('address', 'required');
                  return AppLocalizations.of(context)!
                      .pleaseSelectRestaurantAddress;
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkingHoursStep() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            WorkingHoursWidget(
              workingHours: _workingHours,
              onChanged: (hours) {
                setState(() {
                  _workingHours.clear();
                  _workingHours.addAll(hours);
                });

                // Validate working hours
                if (!SecurityService.validateWorkingHours(hours)) {
                  _showSnackBar(
                      'Please fix working hours conflicts', Colors.orange);
                  return;
                }

                FormAnalytics.trackWorkingHoursConfiguration(
                  hours.values.any((day) => day['isOpen'] == 'true')
                      ? 'different'
                      : 'common',
                  hours.values.where((day) => day['isOpen'] == 'true').length,
                );
              },
              validator: (value) {
                if (_workingHours.isEmpty) {
                  FormAnalytics.trackValidationError(
                      'working_hours', 'required');
                  return AppLocalizations.of(context)!
                      .pleaseConfigureWorkingHours;
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdditionalDetailsStep() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppLocalizations.of(context)!.socialMediaOptional,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),

            // Social Media Fields
            SectorAwareTextField(
              sector: _formState.sector,
              fieldType: 'facebook',
              controller: _facebookController,
              keyboardType: TextInputType.url,
              validator: (value) {
                if (value != null &&
                    value.isNotEmpty &&
                    !InputSanitizer.isValidUrl(value)) {
                  FormAnalytics.trackValidationError(
                      'facebook_url', 'invalid_format');
                  return AppLocalizations.of(context)!.pleaseEnterValidUrl;
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            SectorAwareTextField(
              sector: _formState.sector,
              fieldType: 'instagram',
              controller: _instagramController,
              keyboardType: TextInputType.url,
              validator: (value) {
                if (value != null &&
                    value.isNotEmpty &&
                    !InputSanitizer.isValidUrl(value)) {
                  FormAnalytics.trackValidationError(
                      'instagram_url', 'invalid_format');
                  return AppLocalizations.of(context)!.pleaseEnterValidUrl;
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            SectorAwareTextField(
              sector: _formState.sector,
              fieldType: 'tiktok',
              controller: _tiktokController,
              keyboardType: TextInputType.url,
              validator: (value) {
                if (value != null &&
                    value.isNotEmpty &&
                    !InputSanitizer.isValidUrl(value)) {
                  FormAnalytics.trackValidationError(
                      'tiktok_url', 'invalid_format');
                  return AppLocalizations.of(context)!.pleaseEnterValidUrl;
                }
                return null;
              },
            ),

            const SizedBox(height: 24),

            // Benefits Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.benefitsOfJoining,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildBenefitItem(Icons.people,
                      AppLocalizations.of(context)!.reachThousandsOfFoodLovers),
                  _buildBenefitItem(
                      Icons.analytics,
                      AppLocalizations.of(context)!
                          .detailedAnalyticsAndInsights),
                  _buildBenefitItem(Icons.support_agent,
                      AppLocalizations.of(context)!.customerSupport),
                  _buildBenefitItem(Icons.payment,
                      AppLocalizations.of(context)!.securePaymentProcessing),
                  _buildBenefitItem(Icons.delivery_dining,
                      AppLocalizations.of(context)!.deliveryPartnerIntegration),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Terms and conditions
            Text(
              AppLocalizations.of(context)!.termsAndConditions,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFromString(String name) {
    switch (name) {
      case 'restaurant':
        return Icons.restaurant;
      case 'local_grocery_store':
        return Icons.local_grocery_store;
      case 'build':
        return Icons.build;
      case 'home':
        return Icons.home_filled;
      default:
        return Icons.apps;
    }
  }
}
