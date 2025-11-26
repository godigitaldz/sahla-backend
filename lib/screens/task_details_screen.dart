import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../models/task.dart';
import '../services/auth_service.dart';
import '../services/integrated_task_delivery_service.dart';
import '../services/task_service.dart';
import '../widgets/app_header.dart';

class TaskDetailsScreen extends StatefulWidget {
  final String taskId;
  const TaskDetailsScreen({required this.taskId, super.key});

  @override
  State<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen> {
  Task? _task;
  bool _loading = true;
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  bool _isOfferMode = false;
  final TextEditingController _offerController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    TaskService.instance.onTaskChanged(widget.taskId).listen((t) {
      if (mounted) setState(() => _task = t);
    });
  }

  Future<void> _load() async {
    try {
      final list = await TaskService.instance.getMyTasks();
      final t = list.firstWhere((e) => e.id == widget.taskId,
          orElse: () =>
              list.isNotEmpty ? list.first : throw Exception('Not found'));
      if (!mounted) return;
      setState(() {
        _task = t;
        _loading = false;
        _updateMarkers();
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _updateMarkers() {
    if (_task == null) return;

    _markers.clear();

    // Add primary location marker
    final task = _task!; // Safe to use ! here since we checked for null above
    _markers.add(Marker(
      markerId: MarkerId('${task.id}_primary'),
      position: LatLng(task.latitude, task.longitude),
      infoWindow: InfoWindow(
        title: task.locationPurpose ??
            (AppLocalizations.of(context)?.locationPurpose ??
                'Primary Location'),
        snippet: task.locationName,
      ),
    ));

    // Add additional location markers
    if (task.additionalLocations != null &&
        task.additionalLocations!.isNotEmpty) {
      for (int i = 0; i < task.additionalLocations!.length; i++) {
        final loc = task.additionalLocations![i];

        // Handle both old and new key formats
        final latValue = loc['lat'] ?? loc['latitude'];
        final lngValue = loc['lng'] ?? loc['longitude'];

        if (latValue != null && lngValue != null) {
          try {
            final lat = double.parse(latValue.toString());
            final lng = double.parse(lngValue.toString());

            _markers.add(Marker(
              markerId: MarkerId('${_task!.id}_additional_$i'),
              position: LatLng(lat, lng),
              infoWindow: InfoWindow(
                title: loc['purpose'] ??
                    (AppLocalizations.of(context)?.locationPurpose ??
                        'Additional Location'),
                snippet: loc['address'] ??
                    (AppLocalizations.of(context)?.unknownAddress ??
                        'Unknown address'),
              ),
            ));
          } catch (e) {
            // Skip this marker if parsing fails
            debugPrint('Failed to parse location $i: $e');
          }
        }
      }
    }

    // Fit map to show all markers
    _fitMapToAllMarkers();
  }

  Future<void> _fitMapToAllMarkers() async {
    if (_mapController == null || _markers.isEmpty) return;

    final points = _markers.map((marker) => marker.position).toList();
    final bounds = _calculateBoundsFromPoints(points);

    await _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100.0),
    );
  }

  LatLngBounds _calculateBoundsFromPoints(List<LatLng> points) {
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _loading || _task == null
          ? const Center(child: CircularProgressIndicator())
          : Builder(
              builder: (context) {
                return Column(
                  children: [
                    // Fixed App Header
                    SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                        child: AppHeader(
                            title: AppLocalizations.of(context)?.taskDetails ??
                                'Task Details'),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Scrollable Content Area
                    Expanded(
                      child: Stack(
                        children: [
                          // Scrollable content
                          SingleChildScrollView(
                            child: Column(
                              children: [
                                // Map Card - Simple tap to view form
                                Container(
                                  margin: EdgeInsets.symmetric(
                                      horizontal: screenWidth * 0.05),
                                  child: _buildMapCard(),
                                ),

                                const SizedBox(height: 16),

                                // Task Info Card
                                Container(
                                  margin: EdgeInsets.symmetric(
                                      horizontal: screenWidth * 0.05),
                                  child: _buildTaskInfoCard(),
                                ),

                                const SizedBox(
                                    height:
                                        200), // Space to scroll under bottom container
                              ],
                            ),
                          ),

                          // Fixed Bottom Container (Process Panel)
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: _buildTaskProcessPanel(),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildMapCard() {
    return GestureDetector(
      onTap: _showMapView,
      child: Container(
        height: 120, // Fixed height for the card
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Map Icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.map,
                  color: Colors.orange[600],
                  size: 30,
                ),
              ),

              const SizedBox(width: 16),

              // Map Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      AppLocalizations.of(context)?.taskLocations ??
                          'Task Locations',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppLocalizations.of(context)?.tapToViewMapWithLocations ??
                          'Tap to view map with all locations',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${AppLocalizations.of(context)?.locationCount ?? '{count} location{plural}'}'
                          .replaceAll('{count}', '${_getLocationCount()}')
                          .replaceAll(
                              '{plural}', _getLocationCount() > 1 ? 's' : ''),
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.orange[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Arrow Icon
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey[400],
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _getLocationCount() {
    int count = 1; // Primary location
    if (_task!.additionalLocations != null &&
        _task!.additionalLocations!.isNotEmpty) {
      count += _task!.additionalLocations!.length;
    }
    return count;
  }

  void _showMapView() {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => _MapViewScreen(task: _task!),
        ),
      );
    } catch (e) {
      debugPrint('Failed to open map view: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${AppLocalizations.of(context)?.failedToOpenMapView ?? 'Failed to open map view: {error}'}'
                      .replaceAll('{error}', e.toString()))),
        );
      }
    }
  }

  Widget _buildTaskProcessPanel() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFd47b00), // Orange bottom panel
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12), // Reduced padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Task Status Header
              Row(
                children: [
                  const Icon(Icons.task_alt,
                      color: Colors.white, size: 20), // Reduced icon size
                  const SizedBox(width: 8), // Reduced spacing
                  Text(
                    AppLocalizations.of(context)?.taskProcess ?? 'Task Process',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16, // Reduced font size
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12), // Reduced spacing

              // Task Status Steps
              _buildTaskStatusSteps(),

              // Cost Negotiation Section (if applicable)
              if (_shouldShowCostNegotiation()) ...[
                const SizedBox(height: 12), // Reduced spacing
                _buildCostNegotiationSection(),
              ],

              // Delivery Man Info Section (if task is assigned)
              if (_shouldShowDeliveryManInfo()) ...[
                const SizedBox(height: 12), // Reduced spacing
                _buildDeliveryManInfoSection(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskStatusSteps() {
    if (_task == null) return const SizedBox.shrink();
    final status = _task!.status;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatusStep(
            icon: Icons.pending,
            label: AppLocalizations.of(context)?.pending ?? 'Pending',
            isActive: status == TaskStatus.pending,
            isCompleted: false,
          ),
          _buildStatusConnector(),
          _buildStatusStep(
            icon: Icons.monetization_on,
            label: AppLocalizations.of(context)?.costReview ?? 'Cost Review',
            isActive: status == TaskStatus.costReview,
            isCompleted: status == TaskStatus.costReview ||
                status == TaskStatus.costProposed ||
                status == TaskStatus.costAccepted ||
                status == TaskStatus.assigned ||
                status == TaskStatus.completed,
          ),
          _buildStatusConnector(),
          _buildStatusStep(
            icon: Icons.handshake,
            label: AppLocalizations.of(context)?.costAgreed ?? 'Cost Agreed',
            isActive: status == TaskStatus.costProposed ||
                status == TaskStatus.costAccepted,
            isCompleted: status == TaskStatus.costAccepted ||
                status == TaskStatus.assigned ||
                status == TaskStatus.completed,
          ),
          _buildStatusConnector(),
          _buildStatusStep(
            icon: Icons.assignment,
            label: AppLocalizations.of(context)?.assigned ?? 'Assigned',
            isActive: status == TaskStatus.assigned,
            isCompleted:
                status == TaskStatus.assigned || status == TaskStatus.completed,
          ),
          _buildStatusConnector(),
          _buildStatusStep(
            icon: Icons.check_circle,
            label: AppLocalizations.of(context)?.completed ?? 'Completed',
            isActive: status == TaskStatus.completed,
            isCompleted: status == TaskStatus.completed,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusStep({
    required IconData icon,
    required String label,
    required bool isActive,
    required bool isCompleted,
  }) {
    return Column(
      children: [
        Container(
          width: 32, // Reduced from 40
          height: 32, // Reduced from 40
          decoration: BoxDecoration(
            color: isCompleted || isActive
                ? Colors.white
                : Colors.white.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: isCompleted || isActive
                ? const Color(0xFFd47b00)
                : Colors.white.withValues(alpha: 0.5),
            size: 16, // Reduced from 20
          ),
        ),
        const SizedBox(height: 4), // Reduced from 8
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 10, // Reduced from 12
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusConnector() {
    return Container(
      width: 20, // Reduced from 30
      height: 2,
      color: Colors.white.withValues(alpha: 0.3),
    );
  }

  Widget _buildTaskInfoCard() {
    return SingleChildScrollView(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12), // Reduced from 16
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Text(AppLocalizations.of(context)?.taskDetails ?? 'Task Details',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w800,
                      fontSize: 16)), // Reduced from 18
              const SizedBox(height: 12), // Reduced from 16

              // Task Description Section
              Text(
                  AppLocalizations.of(context)?.taskDescription ??
                      'Task Description:',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 13)), // Reduced from 14
              const SizedBox(height: 6), // Reduced from 8
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10), // Reduced from 12
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Text(
                  _task!.description,
                  style: GoogleFonts.poppins(fontSize: 13), // Reduced from 14
                ),
              ),
              const SizedBox(height: 12), // Reduced from 16

              // Task Locations Section
              Text(
                  AppLocalizations.of(context)?.taskLocationsSection ??
                      'Task Locations:',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 13)), // Reduced from 14
              const SizedBox(height: 6), // Reduced from 8
              _buildAllLocationsForTask(),
              const SizedBox(height: 12), // Reduced from 16

              // Contact Phone Section
              Text(
                  AppLocalizations.of(context)?.contactPhone ??
                      'Contact Phone:',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 13)), // Reduced from 14
              const SizedBox(height: 6), // Reduced from 8
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10), // Reduced from 12
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Text(
                  _formatPhoneNumbers(),
                  style: GoogleFonts.poppins(fontSize: 13), // Reduced from 14
                ),
              ),
              const SizedBox(height: 12), // Reduced from 16

              // Images Preview Section (if any)
              if (_task!.imageUrl != null) ...[
                Text(
                    AppLocalizations.of(context)?.imagesPreview ??
                        'Images Preview:',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 13)), // Reduced from 14
                const SizedBox(height: 6), // Reduced from 8
                Container(
                  height: 80, // Reduced from 100
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: NetworkImage(_task!.imageUrl!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 12), // Reduced from 16
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAllLocationsForTask() {
    final locations = <_LocationInfo>[];

    // Add primary location
    locations.add(_LocationInfo(
      purpose: _task!.locationPurpose ??
          (AppLocalizations.of(context)?.locationPurpose ?? 'Location purpose'),
      address: _task!.locationName,
    ));

    // Add additional locations from additionalLocations field
    if (_task!.additionalLocations != null &&
        _task!.additionalLocations!.isNotEmpty) {
      for (final loc in _task!.additionalLocations!) {
        locations.add(_LocationInfo(
          purpose: loc['purpose'] ??
              (AppLocalizations.of(context)?.locationPurpose ??
                  'Location purpose'),
          address: loc['address'] ??
              (AppLocalizations.of(context)?.unknownAddress ??
                  'Unknown address'),
        ));
      }
    }

    return Column(
      children: locations.asMap().entries.map((entry) {
        final index = entry.key;
        final location = entry.value;
        final isCompleted = _isLocationCompleted(index);
        return _buildLocationItem(location, index, isCompleted);
      }).toList(),
    );
  }

  Widget _buildLocationItem(
      _LocationInfo location, int index, bool isCompleted) {
    final locationNote = _getLocationNote(index);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isCompleted ? Colors.green[50] : Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCompleted ? Colors.green[300]! : Colors.grey[200]!,
        ),
      ),
      child: Row(
        children: [
          // Completion status icon
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isCompleted ? Colors.green : Colors.grey[300],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isCompleted ? Icons.check : Icons.location_on,
              color: Colors.white,
              size: 12,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  location.purpose,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    color: isCompleted ? Colors.green[700] : Colors.black,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  location.address,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: isCompleted ? Colors.green[600] : Colors.grey[600],
                  ),
                ),
                // Location note (if exists)
                if (locationNote != null && locationNote.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.note,
                          size: 10,
                          color: Colors.blue[600],
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            locationNote,
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: Colors.blue[700],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isLocationCompleted(int locationIndex) {
    // Check if this location is marked as completed in the task's completion tracking
    if (_task?.locationCompletions == null) return false;
    return _task!.locationCompletions!.contains(locationIndex);
  }

  String? _getLocationNote(int locationIndex) {
    // Get the note for a specific location index
    if (_task?.locationNotes == null) return null;
    return _task!.locationNotes!['location_$locationIndex'] as String?;
  }

  String _formatPhoneNumbers() {
    final phones = <String>[];

    if (_task!.contactPhone != null && _task!.contactPhone!.isNotEmpty) {
      phones.add(_task!.contactPhone!);
    }

    if (_task!.contactPhone2 != null && _task!.contactPhone2!.isNotEmpty) {
      phones.add(_task!.contactPhone2!);
    }

    if (phones.isEmpty) {
      return 'No phone provided';
    }

    return phones.join('\n');
  }

  bool _shouldShowCostNegotiation() {
    return _task!.status == TaskStatus.costReview ||
        _task!.status == TaskStatus.costProposed ||
        _task!.status == TaskStatus.userCounterProposed ||
        _task!.status == TaskStatus.costAccepted;
  }

  bool _shouldShowDeliveryManInfo() {
    return _task!.status == TaskStatus.assigned;
  }

  Widget _buildDeliveryManInfoSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          // Delivery man logo in left edge
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.local_shipping,
              color: Colors.white,
              size: 20,
            ),
          ),

          const SizedBox(width: 12),

          // Delivery man info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Delivery man name as title
                Text(
                  _task!.deliveryManName ?? 'Delivery Man',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                // Vehicle info as subtitle
                Text(
                  _getVehicleInfo(),
                  style: GoogleFonts.poppins(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Call button in right edge
          ElevatedButton(
            onPressed: _callDeliveryMan,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.phone, size: 14),
                const SizedBox(width: 4),
                Text(
                  'Call',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getVehicleInfo() {
    final parts = <String>[];

    if (_task!.vehicleBrand != null && _task!.vehicleBrand!.isNotEmpty) {
      parts.add(_task!.vehicleBrand!);
    }
    if (_task!.vehicleModel != null && _task!.vehicleModel!.isNotEmpty) {
      parts.add(_task!.vehicleModel!);
    }
    if (_task!.vehicleColor != null && _task!.vehicleColor!.isNotEmpty) {
      parts.add(_task!.vehicleColor!);
    }
    if (_task!.vehicleYear != null) {
      parts.add(_task!.vehicleYear.toString());
    }

    if (parts.isEmpty) {
      return 'Vehicle info not available';
    }

    return parts.join(' ');
  }

  Future<void> _callDeliveryMan() async {
    final phoneNumber = _task!.deliveryManPhone;

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
          content: Text('No phone number available for delivery man',
              style: GoogleFonts.poppins()),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Widget _buildCostNegotiationSection() {
    final status = _task!.status;

    if (status == TaskStatus.costReview) {
      return _buildCostReviewSection();
    } else if (status == TaskStatus.costProposed) {
      return _buildCostProposedSection();
    } else if (status == TaskStatus.userCounterProposed) {
      return _buildUserCounterProposedSection();
    } else if (status == TaskStatus.costAccepted) {
      return _buildCostAcceptedSection();
    }

    return const SizedBox.shrink();
  }

  Widget _buildCostReviewSection() {
    return Container(
      padding: const EdgeInsets.all(12), // Reduced from 16
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.monetization_on,
                  color: Colors.white, size: 16), // Reduced from 20
              const SizedBox(width: 6), // Reduced from 8
              Text(
                'Cost Review',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 14, // Reduced from 16
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6), // Reduced from 8
          Text(
            'Delivery man is reviewing your task and will propose a cost soon.',
            style: GoogleFonts.poppins(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 12, // Reduced from 14
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCostProposedSection() {
    return Container(
      padding: const EdgeInsets.all(12), // Reduced from 16
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cost display and buttons in one row
          Row(
            children: [
              // Reject button
              ElevatedButton(
                onPressed: _rejectCost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[600],
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Reject',
                  style: GoogleFonts.poppins(
                      fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),

              const SizedBox(width: 8),

              // Cost display/input in the middle
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                  child: _isOfferMode
                      ?
                      // Editable cost field
                      TextField(
                          controller: _offerController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Enter your offer',
                            hintStyle: GoogleFonts.poppins(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 16,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                        )
                      :
                      // Display cost
                      Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Proposed Cost',
                              style: GoogleFonts.poppins(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 10,
                              ),
                            ),
                            Text(
                              '${_task!.proposedCost?.toStringAsFixed(0) ?? '0'} DZD',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(width: 8),

              // Accept button
              ElevatedButton(
                onPressed: _acceptCost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Accept',
                  style: GoogleFonts.poppins(
                      fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8), // Reduced from 12
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isOfferMode ? _sendOffer : _enableOfferMode,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8), // Reduced padding
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                _isOfferMode ? 'Send your offer' : 'Offer your fare',
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600), // Reduced font size
              ),
            ),
          ),
          if (_task!.costNotes != null && _task!.costNotes!.isNotEmpty) ...[
            const SizedBox(height: 6), // Reduced from 8
            Text(
              'Notes: ${_task!.costNotes}',
              style: GoogleFonts.poppins(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 11, // Reduced from 12
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUserCounterProposedSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // First row: Reject - Price field - Update
          Row(
            children: [
              // Reject button
              ElevatedButton(
                onPressed: _rejectUserCounterOffer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[600],
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Reject',
                  style: GoogleFonts.poppins(
                      fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),

              const SizedBox(width: 8),

              // Price field in the middle
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Your Counter Offer',
                        style: GoogleFonts.poppins(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 10,
                        ),
                      ),
                      Text(
                        '${_task!.userCounterCost?.toStringAsFixed(0) ?? '0'} DZD',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Update button
              ElevatedButton(
                onPressed: _updateUserCounterOffer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[600],
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Update',
                  style: GoogleFonts.poppins(
                      fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Subtitle: Waiting for delivery man reply
          Text(
            'Waiting for delivery man reply',
            style: GoogleFonts.poppins(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),

          const SizedBox(height: 8),

          // Second row: Accept delivery man's offer button (full width)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _acceptDeliveryManOffer,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Accept delivery man\'s offer',
                style: GoogleFonts.poppins(
                    fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),

          if (_task!.userCounterNotes != null &&
              _task!.userCounterNotes!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Notes: ${_task!.userCounterNotes}',
              style: GoogleFonts.poppins(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCostAcceptedSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
      ),
      child: Row(
        children: [
          // Delivery man logo (centered left edge)
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.orange[600],
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person,
              color: Colors.white,
              size: 24,
            ),
          ),

          const SizedBox(width: 12),

          // Delivery man info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Delivery man name (title style)
                Text(
                  _task!.deliveryManName ?? 'Delivery Man',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                // Vehicle info (subtitle)
                Text(
                  _buildVehicleInfo(),
                  style: GoogleFonts.poppins(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Call button (right edge)
          Container(
            decoration: BoxDecoration(
              color: Colors.green[600],
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.phone, color: Colors.white, size: 20),
              onPressed: _callDeliveryMan,
            ),
          ),
        ],
      ),
    );
  }

  String _buildVehicleInfo() {
    final parts = <String>[];
    if (_task!.vehicleBrand != null) parts.add(_task!.vehicleBrand!);
    if (_task!.vehicleModel != null) parts.add(_task!.vehicleModel!);
    if (_task!.vehicleColor != null) parts.add(_task!.vehicleColor!);
    if (_task!.vehicleYear != null) parts.add(_task!.vehicleYear.toString());

    return parts.isNotEmpty ? parts.join(' ') : 'Vehicle info not available';
  }

  Future<void> _acceptCost() async {
    try {
      await TaskService.instance.acceptProposedCost(_task!.id);

      // Refresh task data to get updated status and delivery man info
      await _load();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Cost accepted! Task assigned successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to accept cost: $e')),
        );
      }
    }
  }

  Future<void> _rejectCost() async {
    try {
      await TaskService.instance.rejectProposedCost(_task!.id);

      // Refresh task data to get updated status
      await _load();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Cost rejected. Delivery man can propose a new cost.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reject cost: $e')),
        );
      }
    }
  }

  void _enableOfferMode() {
    setState(() {
      _isOfferMode = true;
      _offerController.text = _task!.proposedCost?.toStringAsFixed(0) ?? '';
    });
  }

  Future<void> _sendOffer() async {
    final costText = _offerController.text.trim();
    if (costText.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter your offer')),
        );
      }
      return;
    }

    final cost = double.tryParse(costText);
    if (cost == null || cost <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid offer')),
        );
      }
      return;
    }

    try {
      // Use real backend logic to send counter-offer
      await IntegratedTaskDeliveryService.instance.userProposeCounterOffer(
        taskId: _task!.id,
        userId:
            Provider.of<AuthService>(context, listen: false).currentUser?.id ??
                '',
        counterCost: cost,
        notes: null,
      );

      // Refresh task data to get updated counter offer
      await _load();

      setState(() {
        _isOfferMode = false;
        _offerController.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Your counter-offer of ${cost.toStringAsFixed(0)} DZD has been sent to the delivery man')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send counter-offer: $e')),
        );
      }
    }
  }

  Future<void> _rejectUserCounterOffer() async {
    try {
      // Cancel the user's counter offer and reset to cost_proposed status
      await IntegratedTaskDeliveryService.instance.cancelCostNegotiation(
        taskId: _task!.id,
        cancelledBy: 'user',
        cancelledById:
            Provider.of<AuthService>(context, listen: false).currentUser?.id ??
                '',
      );

      // Refresh task data to get updated status
      await _load();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Counter offer rejected. Waiting for delivery man\'s response.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reject counter offer: $e')),
        );
      }
    }
  }

  Future<void> _updateUserCounterOffer() async {
    // Show dialog to update the counter offer
    final costController = TextEditingController(
      text: _task!.userCounterCost?.toStringAsFixed(0) ?? '',
    );
    final notesController = TextEditingController(
      text: _task!.userCounterNotes ?? '',
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Update Counter Offer',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Update your counter offer:',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: costController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Your Counter Offer (DZD)',
                hintText: 'Enter your counter offer...',
                prefixText: 'DZD ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Notes (Optional)',
                hintText: 'Add any notes about your counter offer...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[600],
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Update',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (result == true) {
      final costText = costController.text.trim();
      if (costText.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter your counter offer')),
          );
        }
        return;
      }

      final cost = double.tryParse(costText);
      if (cost == null || cost <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter a valid counter offer')),
          );
        }
        return;
      }

      try {
        // Update the user's counter offer
        // ignore: use_build_context_synchronously
        final authService = Provider.of<AuthService>(context, listen: false);
        await IntegratedTaskDeliveryService.instance.userProposeCounterOffer(
          taskId: _task!.id,
          userId: authService.currentUser!.id,
          counterCost: cost,
          notes: notesController.text.trim().isNotEmpty
              ? notesController.text.trim()
              : null,
        );

        // Refresh task data to get updated counter offer
        await _load();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Counter offer updated to ${cost.toStringAsFixed(0)} DZD')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update counter offer: $e')),
          );
        }
      }
    }
  }

  Future<void> _acceptDeliveryManOffer() async {
    try {
      // Accept the delivery man's proposed cost
      await IntegratedTaskDeliveryService.instance.acceptProposedCost(
        taskId: _task!.id,
        userId:
            Provider.of<AuthService>(context, listen: false).currentUser?.id ??
                '',
      );

      // Refresh task data to get updated status and delivery man info
      await _load();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Delivery man\'s offer accepted! Task assigned successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to accept delivery man\'s offer: $e')),
        );
      }
    }
  }
}

class _LocationInfo {
  final String purpose;
  final String address;
  _LocationInfo({required this.purpose, required this.address});
}

class _MapViewScreen extends StatefulWidget {
  final Task task;

  const _MapViewScreen({required this.task});

  @override
  State<_MapViewScreen> createState() => _MapViewScreenState();
}

class _MapViewScreenState extends State<_MapViewScreen> {
  GoogleMapController? _mapController;
  // ignore: prefer_final_fields
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _updateMarkers();
  }

  void _updateMarkers() {
    _markers.clear();

    // Add primary location marker
    _markers.add(
      Marker(
        markerId: const MarkerId('primary'),
        position: LatLng(widget.task.latitude, widget.task.longitude),
        infoWindow: InfoWindow(
          title: widget.task.locationPurpose ?? 'Primary Location',
          snippet: widget.task.locationName,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      ),
    );

    // Add additional location markers
    if (widget.task.additionalLocations != null &&
        widget.task.additionalLocations!.isNotEmpty) {
      for (int i = 0; i < widget.task.additionalLocations!.length; i++) {
        final loc = widget.task.additionalLocations![i];

        // Handle both old and new key formats
        final latValue = loc['lat'] ?? loc['latitude'];
        final lngValue = loc['lng'] ?? loc['longitude'];

        if (latValue != null && lngValue != null) {
          try {
            final lat = double.parse(latValue.toString());
            final lng = double.parse(lngValue.toString());

            _markers.add(
              Marker(
                markerId: MarkerId('additional_$i'),
                position: LatLng(lat, lng),
                infoWindow: InfoWindow(
                  title: loc['purpose'] ??
                      (AppLocalizations.of(context)?.locationPurpose ??
                          'Additional Location'),
                  snippet: loc['address'] ??
                      (AppLocalizations.of(context)?.unknownAddress ??
                          'Unknown address'),
                ),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueBlue),
              ),
            );
          } catch (e) {
            // Skip this marker if parsing fails
            debugPrint('Failed to parse location $i: $e');
          }
        }
      }
    }

    setState(() {});
  }

  void _fitMapToAllMarkers() {
    if (_mapController == null || _markers.isEmpty) return;

    try {
      final points = _markers.map((marker) => marker.position).toList();
      if (points.isEmpty) return;

      final bounds = _calculateBoundsFromPoints(points);

      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100.0),
      );
    } catch (e) {
      debugPrint('Failed to fit map to markers: $e');
      // Fallback to primary location
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(widget.task.latitude, widget.task.longitude),
            zoom: 15,
          ),
        ),
      );
    }
  }

  LatLngBounds _calculateBoundsFromPoints(List<LatLng> points) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Stack(
        children: [
          // Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(widget.task.latitude, widget.task.longitude),
              zoom: 15,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              _fitMapToAllMarkers();
            },
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false, // Disabled to use custom button
            zoomControlsEnabled: false, // Disabled to use custom zoom buttons
            mapToolbarEnabled: false,
          ),

          // Orange 600 container with back arrow
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.orange[600],
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: IconButton(
                icon:
                    const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // Custom circular orange location button (moved lower)
          Positioned(
            top: MediaQuery.of(context).padding.top + 80,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.orange[600],
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.my_location,
                    color: Colors.white, size: 24),
                onPressed: _goToMyLocation,
              ),
            ),
          ),

          // Zoom all button above cards (fit content width)
          Positioned(
            bottom: 140,
            left: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.orange[600],
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _fitMapToAllMarkers,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.zoom_out_map,
                            color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Show All Locations',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Plus and minus buttons above cards (raised more, smaller size)
          Positioned(
            bottom: 160,
            right: 16,
            child: Column(
              children: [
                // Plus button
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.orange[600],
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.add, color: Colors.white, size: 20),
                    onPressed: () {
                      if (_mapController != null) {
                        _mapController!.animateCamera(CameraUpdate.zoomIn());
                      }
                    },
                    padding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 8),
                // Minus button
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.orange[600],
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon:
                        const Icon(Icons.remove, color: Colors.white, size: 20),
                    onPressed: () {
                      if (_mapController != null) {
                        _mapController!.animateCamera(CameraUpdate.zoomOut());
                      }
                    },
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),

          // Multi-location cards with horizontal scroll
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: SizedBox(
                height: 120,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Row(
                    children: _buildLocationCards(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _goToMyLocation() {
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(widget.task.latitude, widget.task.longitude),
            zoom: 15,
          ),
        ),
      );
    }
  }

  List<Widget> _buildLocationCards() {
    final cards = <Widget>[];

    // Add primary location card
    cards.add(
      _buildLocationCard(
        title: widget.task.locationPurpose ?? 'Primary Location',
        address: widget.task.locationName,
        isPrimary: true,
        onTap: () =>
            _goToLocation(LatLng(widget.task.latitude, widget.task.longitude)),
      ),
    );

    // Add additional location cards
    if (widget.task.additionalLocations != null &&
        widget.task.additionalLocations!.isNotEmpty) {
      for (int i = 0; i < widget.task.additionalLocations!.length; i++) {
        final loc = widget.task.additionalLocations![i];

        // Handle both old and new key formats
        final latValue = loc['lat'] ?? loc['latitude'];
        final lngValue = loc['lng'] ?? loc['longitude'];

        if (latValue != null && lngValue != null) {
          try {
            final lat = double.parse(latValue.toString());
            final lng = double.parse(lngValue.toString());

            cards.add(
              _buildLocationCard(
                title: loc['purpose'] ?? 'Additional Location',
                address: loc['address'] ?? 'Unknown address',
                isPrimary: false,
                onTap: () => _goToLocation(LatLng(lat, lng)),
              ),
            );
          } catch (e) {
            // Skip invalid locations
          }
        }
      }
    }

    return cards;
  }

  Widget _buildLocationCard({
    required String title,
    required String address,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isPrimary ? Colors.orange[600] : Colors.blue[600],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              address,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _goToLocation(LatLng location) {
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: location,
            zoom: 16,
          ),
        ),
      );
    }
  }
}
