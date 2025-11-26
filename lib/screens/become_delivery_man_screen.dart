import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/delivery_man_constants.dart';
import '../l10n/app_localizations.dart';
import '../services/delivery_man_request_service.dart';
import '../widgets/pill_dropdown.dart';

class BecomeDeliveryManScreen extends StatefulWidget {
  const BecomeDeliveryManScreen({super.key});

  @override
  State<BecomeDeliveryManScreen> createState() =>
      _BecomeDeliveryManScreenState();
}

class _BecomeDeliveryManScreenState extends State<BecomeDeliveryManScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _vehicleTypeController = TextEditingController();
  final _vehicleModelController = TextEditingController();
  final _vehicleYearController = TextEditingController();
  final _vehicleColorController = TextEditingController();
  final _plateNumberController = TextEditingController();
  final _experienceController = TextEditingController();

  String _selectedVehicleType = 'Motorcycle';
  String _selectedAvailability = 'Full-time';
  bool _hasValidLicense = false;
  bool _hasVehicle = false;
  bool _isAvailableWeekends = false;
  bool _isAvailableEvenings = false;
  bool _isLoading = false;

  Timer? _autoSaveTimer;

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _fullNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _vehicleTypeController.dispose();
    _vehicleModelController.dispose();
    _vehicleYearController.dispose();
    _vehicleColorController.dispose();
    _plateNumberController.dispose();
    _experienceController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadDraftData();
    _startAutoSave();
  }

  void _startAutoSave() {
    // Auto-save every 30 seconds when form is valid
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_formKey.currentState?.validate() ?? false) {
        _saveFormDraft();
      }
    });
  }

  Future<void> _loadDraftData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _fullNameController.text = prefs.getString('delivery_draft_name') ?? '';
        _phoneController.text = prefs.getString('delivery_draft_phone') ?? '';
        _addressController.text =
            prefs.getString('delivery_draft_address') ?? '';
        _vehicleModelController.text =
            prefs.getString('delivery_draft_model') ?? '';
        _vehicleYearController.text =
            prefs.getString('delivery_draft_year') ?? '';
        _vehicleColorController.text =
            prefs.getString('delivery_draft_color') ?? '';
        _plateNumberController.text =
            prefs.getString('delivery_draft_plate') ?? '';
        _experienceController.text =
            prefs.getString('delivery_draft_experience') ?? '';

        _selectedVehicleType =
            prefs.getString('delivery_draft_vehicle_type') ?? 'Motorcycle';
        _selectedAvailability =
            prefs.getString('delivery_draft_availability') ?? 'Full-time';

        _hasValidLicense = prefs.getBool('delivery_draft_has_license') ?? false;
        _hasVehicle = prefs.getBool('delivery_draft_has_vehicle') ?? false;
        _isAvailableWeekends =
            prefs.getBool('delivery_draft_weekends') ?? false;
        _isAvailableEvenings =
            prefs.getBool('delivery_draft_evenings') ?? false;
      });
    } catch (e) {
      // Ignore errors when loading draft
    }
  }

  Future<void> _saveFormDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('delivery_draft_name', _fullNameController.text);
      await prefs.setString('delivery_draft_phone', _phoneController.text);
      await prefs.setString('delivery_draft_address', _addressController.text);
      await prefs.setString(
          'delivery_draft_model', _vehicleModelController.text);
      await prefs.setString('delivery_draft_year', _vehicleYearController.text);
      await prefs.setString(
          'delivery_draft_color', _vehicleColorController.text);
      await prefs.setString(
          'delivery_draft_plate', _plateNumberController.text);
      await prefs.setString(
          'delivery_draft_experience', _experienceController.text);

      await prefs.setString(
          'delivery_draft_vehicle_type', _selectedVehicleType);
      await prefs.setString(
          'delivery_draft_availability', _selectedAvailability);

      await prefs.setBool('delivery_draft_has_license', _hasValidLicense);
      await prefs.setBool('delivery_draft_has_vehicle', _hasVehicle);
      await prefs.setBool('delivery_draft_weekends', _isAvailableWeekends);
      await prefs.setBool('delivery_draft_evenings', _isAvailableEvenings);
    } catch (e) {
      // Ignore errors when saving draft
    }
  }

  Future<void> _clearDraftData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('delivery_draft_name');
      await prefs.remove('delivery_draft_phone');
      await prefs.remove('delivery_draft_address');
      await prefs.remove('delivery_draft_model');
      await prefs.remove('delivery_draft_year');
      await prefs.remove('delivery_draft_color');
      await prefs.remove('delivery_draft_plate');
      await prefs.remove('delivery_draft_experience');
      await prefs.remove('delivery_draft_vehicle_type');
      await prefs.remove('delivery_draft_availability');
      await prefs.remove('delivery_draft_has_license');
      await prefs.remove('delivery_draft_has_vehicle');
      await prefs.remove('delivery_draft_weekends');
      await prefs.remove('delivery_draft_evenings');
    } catch (e) {
      // Ignore errors when clearing draft
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _clearDraftData();
    setState(() {
      _selectedVehicleType = 'Motorcycle';
      _selectedAvailability = 'Full-time';
      _hasValidLicense = false;
      _hasVehicle = false;
      _isAvailableWeekends = false;
      _isAvailableEvenings = false;
    });
  }

  String _getUserFriendlyError(String error) {
    // Handle specific error types
    if (error.contains('network') || error.contains('connection')) {
      return DeliveryManConstants.errorMessages['network_error']!;
    }
    if (error.contains('server') || error.contains('timeout')) {
      return DeliveryManConstants.errorMessages['server_error']!;
    }
    if (error.contains('duplicate') || error.contains('already')) {
      return DeliveryManConstants.errorMessages['duplicate_application']!;
    }
    // Return original error if no specific mapping found
    return 'An unexpected error occurred. Please try again.';
  }

  // Input sanitization for security
  String _sanitizeInput(String input) {
    return input
        .trim()
        .replaceAll(RegExp('<script.*?</script>', caseSensitive: false), '')
        .replaceAll(RegExp('[<>]'), '');
  }

  Future<void> _showConfirmationDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            AppLocalizations.of(context)?.submitApplicationConfirmation ??
                'Submit Application?'),
        content: Text(AppLocalizations.of(context)
                ?.confirmApplicationSubmission ??
            'Are you sure you want to submit your delivery application? Make sure all information is correct.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context)?.cancel ?? 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: DeliveryManConstants.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: Text(AppLocalizations.of(context)?.submit ?? 'Submit'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _submitApplication();
    }
  }

  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate requirements
    if (!_hasValidLicense) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              AppLocalizations.of(context)?.validationLicenseRequired ??
                  'You must have a valid driving license'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!_hasVehicle) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              AppLocalizations.of(context)?.validationVehicleRequired ??
                  'You must have a reliable vehicle'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final deliveryManRequestService =
          context.read<DeliveryManRequestService>();

      final result = await deliveryManRequestService.submitDeliveryManRequest(
        fullName: _sanitizeInput(_fullNameController.text),
        phone: _sanitizeInput(_phoneController.text),
        address: _sanitizeInput(_addressController.text),
        vehicleType: _selectedVehicleType,
        plateNumber: _sanitizeInput(_plateNumberController.text),
        vehicleModel: _sanitizeInput(_vehicleModelController.text),
        vehicleYear: _sanitizeInput(_vehicleYearController.text),
        vehicleColor: _sanitizeInput(_vehicleColorController.text),
        availability: _selectedAvailability,
        experience: _experienceController.text.trim().isNotEmpty
            ? _sanitizeInput(_experienceController.text)
            : null,
        hasValidLicense: _hasValidLicense,
        hasVehicle: _hasVehicle,
        isAvailableWeekends: _isAvailableWeekends,
        isAvailableEvenings: _isAvailableEvenings,
      );

      if (mounted) {
        if (result.isRight) {
          await _clearDraftData(); // Clear draft after successful submission
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context)
                        ?.applicationSubmittedSuccessfully ??
                    'Application submitted successfully! We\'ll review it within 24-48 hours.'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_getUserFriendlyError(result.left.message)),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_getUserFriendlyError(e.toString())),
            backgroundColor: Colors.red,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Main content with proper safe area handling
          SafeArea(
            top: false, // We handle top padding manually for floating header
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top +
                    80, // Increased spacing between header and container
                left: 20,
                right: 20,
                bottom: 20,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome Header Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            DeliveryManConstants.primaryColor,
                            DeliveryManConstants.primaryColor
                                .withValues(alpha: 0.8)
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.delivery_dining,
                            size: 48,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppLocalizations.of(context)
                                          ?.joinOurDeliveryTeam ??
                                      'Join Our Delivery Team!',
                                  style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  AppLocalizations.of(context)
                                          ?.earnMoneyHelpingPeople ??
                                      'Earn money while helping people get their food',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Personal Information Section
                    Text(
                      AppLocalizations.of(context)?.personalInformation ??
                          'Personal Information',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Full Name
                    TextFormField(
                      controller: _fullNameController,
                      decoration: InputDecoration(
                        labelText:
                            AppLocalizations.of(context)?.fullNameRequired ??
                                'Full Name *',
                        hintText:
                            AppLocalizations.of(context)?.enterYourFullName ??
                                'Enter your full name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        prefixIcon: const Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return AppLocalizations.of(context)
                                  ?.validationNameRequired ??
                              'Please enter your full name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Phone Number
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(
                            DeliveryManConstants.maxPhoneLength),
                      ],
                      decoration: InputDecoration(
                        labelText:
                            AppLocalizations.of(context)?.phoneNumberRequired ??
                                'Phone Number *',
                        hintText: AppLocalizations.of(context)
                                ?.enterYourPhoneNumber ??
                            'Enter your phone number',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        prefixIcon: const Icon(Icons.phone),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return AppLocalizations.of(context)
                                  ?.validationPhoneRequired ??
                              'Please enter your phone number';
                        }

                        // Remove any non-digit characters for validation
                        final digitsOnly =
                            value.replaceAll(RegExp(r'[^\d]'), '');

                        if (digitsOnly.length < 10) {
                          return AppLocalizations.of(context)
                                  ?.validationPhoneInvalid ??
                              'Please enter a valid phone number (at least 10 digits)';
                        }

                        // Optional: Validate phone number format
                        if (!RegExp(r'^[\d\s\+\-\(\)]{10,15}$')
                            .hasMatch(value)) {
                          return AppLocalizations.of(context)
                                  ?.validationPhoneFormat ??
                              'Please enter a valid phone number format';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Address
                    TextFormField(
                      controller: _addressController,
                      decoration: InputDecoration(
                        labelText:
                            AppLocalizations.of(context)?.addressRequired ??
                                'Address *',
                        hintText: AppLocalizations.of(context)
                                ?.enterYourCurrentAddress ??
                            'Enter your current address',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        prefixIcon: const Icon(Icons.location_on),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return AppLocalizations.of(context)
                                  ?.validationAddressRequired ??
                              'Please enter your address';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 24),

                    // Vehicle Information Section
                    Text(
                      AppLocalizations.of(context)?.vehicleInformation ??
                          'Vehicle Information',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Vehicle Type
                    PillDropdown<String>(
                      label:
                          AppLocalizations.of(context)?.vehicleTypeRequired ??
                              'Vehicle Type *',
                      value: _selectedVehicleType,
                      items:
                          DeliveryManConstants.vehicleTypes.map((String type) {
                        return DropdownMenuItem<String>(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedVehicleType = newValue!;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return AppLocalizations.of(context)
                                  ?.validationVehicleTypeRequired ??
                              'Please select a vehicle type';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Vehicle Model
                    TextFormField(
                      controller: _vehicleModelController,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)
                                ?.vehicleModelRequired ??
                            'Vehicle Model *',
                        hintText: AppLocalizations.of(context)
                                ?.enterYourVehicleModel ??
                            'Enter your vehicle model',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        prefixIcon: const Icon(Icons.two_wheeler),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return AppLocalizations.of(context)
                                  ?.validationVehicleModelRequired ??
                              'Please enter your vehicle model';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Vehicle Year
                    TextFormField(
                      controller: _vehicleYearController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      decoration: InputDecoration(
                        labelText:
                            AppLocalizations.of(context)?.vehicleYearRequired ??
                                'Vehicle Year *',
                        hintText: AppLocalizations.of(context)
                                ?.enterYourVehicleYear ??
                            'Enter your vehicle year',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        prefixIcon: const Icon(Icons.calendar_today),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return AppLocalizations.of(context)
                                  ?.validationVehicleYearRequired ??
                              'Please enter your vehicle year';
                        }
                        final year = int.tryParse(value);
                        final currentYear = DateTime.now().year;
                        if (year == null ||
                            year < DeliveryManConstants.minVehicleYear ||
                            year > currentYear + 1) {
                          return AppLocalizations.of(context)
                                  ?.errorInvalidYear ??
                              DeliveryManConstants.getInvalidYearError();
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Vehicle Color
                    TextFormField(
                      controller: _vehicleColorController,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)
                                ?.vehicleColorRequired ??
                            'Vehicle Color *',
                        hintText: AppLocalizations.of(context)
                                ?.enterYourVehicleColor ??
                            'Enter your vehicle color',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        prefixIcon: const Icon(Icons.palette),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return AppLocalizations.of(context)
                                  ?.validationVehicleColorRequired ??
                              'Please enter your vehicle color';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Plate Number
                    TextFormField(
                      controller: _plateNumberController,
                      decoration: InputDecoration(
                        labelText:
                            AppLocalizations.of(context)?.plateNumberRequired ??
                                'Plate Number *',
                        hintText: AppLocalizations.of(context)
                                ?.enterYourVehiclePlateNumber ??
                            'Enter your vehicle plate number',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        prefixIcon: const Icon(Icons.credit_card),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return AppLocalizations.of(context)
                                  ?.validationPlateNumberRequired ??
                              'Please enter your plate number';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 24),

                    // Availability Section
                    Text(
                      AppLocalizations.of(context)?.availability ??
                          'Availability',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Availability Type
                    PillDropdown<String>(
                      label:
                          AppLocalizations.of(context)?.availabilityRequired ??
                              'Availability *',
                      value: _selectedAvailability,
                      items: DeliveryManConstants.availabilityOptions
                          .map((String option) {
                        return DropdownMenuItem<String>(
                          value: option,
                          child: Text(option),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedAvailability = newValue!;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return AppLocalizations.of(context)
                                  ?.validationAvailabilityRequired ??
                              'Please select your availability';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Experience
                    TextFormField(
                      controller: _experienceController,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)
                                ?.previousExperienceOptional ??
                            'Previous Experience (Optional)',
                        hintText: AppLocalizations.of(context)
                                ?.describePreviousExperience ??
                            'Describe any previous delivery or customer service experience',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        prefixIcon: const Icon(Icons.work_history),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Requirements Section
                    Text(
                      AppLocalizations.of(context)?.requirements ??
                          'Requirements',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Requirements checkboxes
                    CheckboxListTile(
                      title: Text(AppLocalizations.of(context)
                              ?.haveValidDrivingLicense ??
                          'I have a valid driving license'),
                      value: _hasValidLicense,
                      onChanged: (bool? value) {
                        setState(() {
                          _hasValidLicense = value!;
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),

                    CheckboxListTile(
                      title: Text(
                          AppLocalizations.of(context)?.haveReliableVehicle ??
                              'I have a reliable vehicle'),
                      value: _hasVehicle,
                      onChanged: (bool? value) {
                        setState(() {
                          _hasVehicle = value!;
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),

                    CheckboxListTile(
                      title: Text(
                          AppLocalizations.of(context)?.availableOnWeekends ??
                              'Available on weekends'),
                      value: _isAvailableWeekends,
                      onChanged: (bool? value) {
                        setState(() {
                          _isAvailableWeekends = value!;
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),

                    CheckboxListTile(
                      title: Text(
                          AppLocalizations.of(context)?.availableInEvenings ??
                              'Available in evenings'),
                      value: _isAvailableEvenings,
                      onChanged: (bool? value) {
                        setState(() {
                          _isAvailableEvenings = value!;
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),

                    const SizedBox(height: 24),

                    // Benefits Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: DeliveryManConstants.primaryColor
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                            color: DeliveryManConstants.primaryColor
                                .withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context)?.benefitsOfJoining ??
                                'Benefits of Joining',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: DeliveryManConstants.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildBenefitItem(
                              Icons.attach_money,
                              AppLocalizations.of(context)
                                      ?.flexibleEarningOpportunities ??
                                  'Flexible earning opportunities'),
                          _buildBenefitItem(
                              Icons.schedule,
                              AppLocalizations.of(context)
                                      ?.workOnYourOwnSchedule ??
                                  'Work on your own schedule'),
                          _buildBenefitItem(
                              Icons.location_on,
                              AppLocalizations.of(context)
                                      ?.deliverInYourLocalArea ??
                                  'Deliver in your local area'),
                          _buildBenefitItem(
                              Icons.support_agent,
                              AppLocalizations.of(context)?.supportTeam ??
                                  '24/7 support team'),
                          _buildBenefitItem(
                              Icons.trending_up,
                              AppLocalizations.of(context)
                                      ?.performanceBonuses ??
                                  'Performance bonuses'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Action Buttons
                    Row(
                      children: [
                        // Reset Button
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isLoading ? null : _resetForm,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                  color: DeliveryManConstants.primaryColor),
                              foregroundColor:
                                  DeliveryManConstants.primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: Text(
                              AppLocalizations.of(context)?.resetForm ??
                                  'Reset Form',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Submit Button
                        Expanded(
                          child: ElevatedButton(
                            onPressed:
                                _isLoading ? null : _showConfirmationDialog,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  DeliveryManConstants.primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                              elevation: 4,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white)
                                : Text(
                                    AppLocalizations.of(context)
                                            ?.submitApplication ??
                                        'Submit Application',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Terms and conditions
                    Text(
                      AppLocalizations.of(context)?.termsAndConditions ??
                          'By submitting this application, you agree to our terms and conditions and privacy policy.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Floating Header with safe area spacing
          Positioned(
            top: MediaQuery.of(context).padding.top + 8, // Reduced spacing
            left: 16,
            right: 16,
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Back Button
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios,
                          color: Colors.black87, size: 18),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Title
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)?.becomeDeliveryMan ??
                          'Become Delivery Man',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: DeliveryManConstants.primaryColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: DeliveryManConstants.primaryColor.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
