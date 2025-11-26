import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/restaurant_request.dart';
import '../../services/admin_security_service.dart';
import '../../services/auth_service.dart';
import '../../services/realtime_service.dart';
import '../../services/restaurant_request_service.dart';
import '../../utils/working_hours_utils.dart';
import '../app_header.dart';

class AdminRestaurantApprovalScreen extends StatefulWidget {
  const AdminRestaurantApprovalScreen({super.key});

  @override
  State<AdminRestaurantApprovalScreen> createState() =>
      _AdminRestaurantApprovalScreenState();
}

class _AdminRestaurantApprovalScreenState
    extends State<AdminRestaurantApprovalScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  late RestaurantRequestService _restaurantRequestService;
  late AuthService _authService;

  // Performance optimization
  bool _isProcessing = false;
  final Set<String> _processingRequests = {};

  // Search and filtering
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedWilaya;

  // Multi-select state
  bool _isSelecting = false;
  final Set<String> _selectedRequestIds = {};

  // Services
  final RealtimeService _realtimeService = RealtimeService();
  final AdminSecurityService _securityService = AdminSecurityService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _restaurantRequestService = context.read<RestaurantRequestService>();
    _authService = context.read<AuthService>();

    // Load data when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Skip admin access verification for now (temporary fix)
      // TODO(admin): Implement proper user_roles table and admin role assignment
      /*
      final currentUser = _authService.currentUser;
      if (currentUser != null) {
        final hasAccess =
            await _securityService.verifyAdminAccess(currentUser.id);
        if (!hasAccess) {
          _showSnackBar('Access denied: Admin role required', Colors.red);
          if (mounted) {
            Navigator.pop(context);
          }
          return;
        }
      }
      */

      // Initialize services
      await _initializeServices();

      // Load data
      await _restaurantRequestService.checkDatabaseSetup();
      await _loadRestaurantRequests();
      await _loadAnalytics();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _realtimeService.dispose();
    _securityService.dispose();
    super.dispose();
  }

  Future<void> _loadRestaurantRequests() async {
    try {
      await _restaurantRequestService.loadRestaurantRequests();
    } catch (e) {
      if (mounted) {
        // Check if it's a database table issue
        if (e.toString().contains('relation') &&
            e.toString().contains('does not exist')) {
          _showSnackBar(
            'Database tables not found. Please run database migrations first.',
            Colors.red,
          );
        } else {
          _showSnackBar(
            'Failed to load restaurant requests: ${_getUserFriendlyError(e)}',
            Colors.red,
          );
        }
      }
    }
  }

  Future<void> _initializeServices() async {
    try {
      // Initialize real-time updates
      await _realtimeService.initialize();

      // Listen for real-time updates
      _realtimeService.restaurantUpdates.listen((update) {
        if (mounted) {
          setState(() {});
          _loadRestaurantRequests();
        }
      });
    } catch (e) {
      debugPrint('Error loading admin services: $e');
    }
  }

  Future<void> _loadAnalytics() async {
    try {
      // Analytics functionality is prepared but not currently used in UI
      // TODO(analytics): Implement analytics dashboard to display insights and performance score
      // final stats = AdminAnalyticsService.calculateStatistics(
      //   restaurantRequests: _restaurantRequestService.restaurantRequests,
      //   deliveryManRequests: [], // Add delivery man service if available
      // );
      // final insights = AdminAnalyticsService.generateInsights(stats);
      // final performanceScore = AdminAnalyticsService.calculatePerformanceScore(stats);
    } catch (e) {
      debugPrint('Error loading analytics: $e');
    }
  }

  /// Filter restaurant requests based on search query and wilaya
  List<RestaurantRequest> _filterRequests(List<RestaurantRequest> requests) {
    return requests.where((request) {
      // Search filter
      final matchesSearch = _searchQuery.isEmpty ||
          request.restaurantName
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          request.userName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          request.userEmail.toLowerCase().contains(_searchQuery.toLowerCase());

      // Wilaya filter
      final matchesWilaya = _selectedWilaya == null ||
          request.wilaya?.toLowerCase() == _selectedWilaya!.toLowerCase();

      return matchesSearch && matchesWilaya;
    }).toList();
  }

  /// Clear search and filters
  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _selectedWilaya = null;
      _searchController.clear();
    });
  }

  /// Multi-select operations
  // Note: Multi-select functionality is prepared but not currently used in UI
  // void _toggleSelection(String requestId) {
  //   setState(() {
  //     if (_selectedRequestIds.contains(requestId)) {
  //       _selectedRequestIds.remove(requestId);
  //     } else {
  //       _selectedRequestIds.add(requestId);
  //     }
  //     _isSelecting = _selectedRequestIds.isNotEmpty;
  //   });
  // }

  void _clearSelection() {
    setState(() {
      _selectedRequestIds.clear();
      _isSelecting = false;
    });
  }

  /// Bulk operations

  Future<void> _approveRestaurantRequest(RestaurantRequest request) async {
    // Prevent multiple rapid approvals
    if (_isProcessing || _processingRequests.contains(request.id)) {
      return;
    }

    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      _showSnackBar('Authentication error', Colors.red);
      return;
    }

    // Confirm approval
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Restaurant Request'),
        content: Text(
            'Approve ${request.userName} as restaurant owner for "${request.restaurantName}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Approve')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _isProcessing = true;
      _processingRequests.add(request.id);
    });

    try {
      final success = await _restaurantRequestService.approveRestaurantRequest(
        request.id,
        currentUser.id,
        currentUser.name ?? 'Admin',
      );

      if (success) {
        _showSnackBar('Restaurant request approved successfully', Colors.green);

        // Immediately update the local state to reflect the change
        if (mounted) {
          setState(() {});
        }

        // Reload data to refresh the UI
        await _loadRestaurantRequests();
      } else {
        final errorMessage = _restaurantRequestService.lastApprovalError ??
            'Unknown error occurred';
        _showSnackBar(
            'Failed to approve restaurant request: $errorMessage', Colors.red);
      }
    } catch (e) {
      debugPrint('❌ Admin screen approval error: $e');
      _showSnackBar(
          'Failed to approve restaurant request: ${_getUserFriendlyError(e)}',
          Colors.red);
    } finally {
      setState(() {
        _isProcessing = false;
        _processingRequests.remove(request.id);
      });
    }
  }

  Future<void> _rejectRestaurantRequest(
      RestaurantRequest request, String reason) async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      _showSnackBar('Authentication error', Colors.red);
      return;
    }

    try {
      final success = await _restaurantRequestService.rejectRestaurantRequest(
        request.id,
        currentUser.id,
        currentUser.name ?? 'Admin',
        reason,
      );

      if (success) {
        _showSnackBar('Restaurant request rejected', Colors.orange);

        // Immediately update the local state to reflect the change
        if (mounted) {
          setState(() {});
        }

        // Reload data to refresh the UI
        await _loadRestaurantRequests();
      } else {
        _showSnackBar('Failed to reject restaurant request', Colors.red);
      }
    } catch (e) {
      _showSnackBar(
          'Failed to reject restaurant request: ${_getUserFriendlyError(e)}',
          Colors.red);
    }
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

  /// Enhanced error handling with user-friendly messages
  String _getUserFriendlyError(dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('socket') || errorString.contains('network')) {
      return 'Network connection failed. Please check your internet connection.';
    }
    if (errorString.contains('timeout')) {
      return 'Request timed out. Please try again.';
    }
    if (errorString.contains('permission') ||
        errorString.contains('unauthorized')) {
      return 'Insufficient permissions. Please contact your administrator.';
    }
    if (errorString.contains('not found')) {
      return 'Request not found. It may have been already processed.';
    }
    if (errorString.contains('server') || errorString.contains('500')) {
      return 'Server error. Please try again later.';
    }

    return 'An unexpected error occurred. Please try again.';
  }

  void _showRestaurantRequestDetails(RestaurantRequest request) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildRestaurantRequestDetailsModal(request),
    );
  }

  void _showRejectDialog(RestaurantRequest request) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Restaurant Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                'Reject ${request.userName}\'s request for "${request.restaurantName}"?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason',
                hintText: 'Please provide a reason for rejection',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isNotEmpty) {
                Navigator.pop(context);
                _rejectRestaurantRequest(request, reasonController.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  Widget _buildRestaurantRequestDetailsModal(RestaurantRequest request) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Restaurant Request Details',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          const Divider(),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailSection('Restaurant Information', [
                    _buildDetailRow('Name', request.restaurantName),
                    _buildDetailRow(
                        'Wilaya', request.wilaya ?? 'Not specified'),
                    _buildDetailRow(
                        'Description', request.restaurantDescription),
                    _buildDetailRow('Address', request.restaurantAddress),
                    _buildDetailRow('Phone', request.restaurantPhone),
                    _buildDetailRow(
                        'Opening Hours',
                        _formatWorkingHours(
                            request.openingHours, request.closingHours)),
                    if (request.logoUrl != null)
                      _buildDetailRow('Logo', 'Uploaded'),
                  ]),
                  const SizedBox(height: 20),
                  _buildDetailSection('Applicant Information', [
                    _buildDetailRow('Name', request.userName),
                    _buildDetailRow('Email', request.userEmail),
                    _buildDetailRow(
                        'Applied On', _formatDate(request.createdAt)),
                  ]),
                ],
              ),
            ),
          ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _showRejectDialog(request);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _approveRestaurantRequest(request);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildStatsOverview() {
    return Consumer<RestaurantRequestService>(
      builder: (context, service, child) {
        final totalRequests = service.restaurantRequests.length;
        final pendingRequests = service.pendingRequests.length;
        final approvedRequests = service.approvedRequests.length;
        final rejectedRequests = service.rejectedRequests.length;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Total', totalRequests, Colors.blue),
              _buildStatItem('Pending', pendingRequests, Colors.orange),
              _buildStatItem('Approved', approvedRequests, Colors.green),
              _buildStatItem('Rejected', rejectedRequests, Colors.red),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildDatabaseErrorState() {
    return Container(
      color: Colors.grey[50],
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.storage,
                size: 64,
                color: Colors.red[400],
              ),
              const SizedBox(height: 16),
              Text(
                'Database Setup Required',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[700],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'The database tables for restaurant requests are not set up yet.\n\n'
                'Please run the database migrations to create the required tables:\n'
                '• restaurant_requests\n'
                '• restaurants\n\n'
                'Contact your administrator to set up the database.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  _loadRestaurantRequests();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRestaurantRequestCard(RestaurantRequest request) {
    final isSelected = _selectedRequestIds.contains(request.id);
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Card(
      margin: EdgeInsets.symmetric(
        horizontal: isTablet ? 24 : 16,
        vertical: 8,
      ),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isSelected
            ? const BorderSide(color: Colors.blue, width: 2)
            : BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: InkWell(
        onTap: () => _showRestaurantRequestDetails(request),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(isTablet ? 20 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with avatar, restaurant name, and status
              Row(
                children: [
                  // Status avatar
                  Container(
                    width: isTablet ? 56 : 48,
                    height: isTablet ? 56 : 48,
                    decoration: BoxDecoration(
                      color: _getStatusColor(request.status),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _getStatusColor(request.status)
                              .withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      _getStatusIcon(request.status),
                      color: Colors.white,
                      size: isTablet ? 28 : 24,
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Restaurant name and owner info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.restaurantName,
                          style: GoogleFonts.poppins(
                            fontSize: isTablet ? 18 : 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          request.userName,
                          style: GoogleFonts.poppins(
                            fontSize: isTablet ? 14 : 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Status badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(request.status)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _getStatusColor(request.status)
                            .withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      request.status.name.toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: isTablet ? 12 : 10,
                        fontWeight: FontWeight.w600,
                        color: _getStatusColor(request.status),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Details section
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  children: [
                    // Location info row
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: isTablet ? 20 : 18,
                          color: Colors.orange[600],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            request.wilaya ?? 'Location not specified',
                            style: GoogleFonts.poppins(
                              fontSize: isTablet ? 14 : 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        if (request.restaurantPhone.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.phone,
                                  size: isTablet ? 12 : 10,
                                  color: Colors.orange[700],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  request.restaurantPhone,
                                  style: GoogleFonts.poppins(
                                    fontSize: isTablet ? 12 : 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orange[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Description and date row
                    Row(
                      children: [
                        Icon(
                          Icons.description,
                          size: isTablet ? 20 : 18,
                          color: Colors.blue[600],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            request.restaurantDescription.isNotEmpty
                                ? request.restaurantDescription
                                : 'No description provided',
                            style: GoogleFonts.poppins(
                              fontSize: isTablet ? 14 : 13,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _formatDate(request.createdAt),
                          style: GoogleFonts.poppins(
                            fontSize: isTablet ? 12 : 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Action buttons (only for pending requests)
              if (request.isPending) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showRejectDialog(request),
                        icon: const Icon(Icons.close, size: 18),
                        label: Text(
                          'Reject',
                          style:
                              GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red[600],
                          side: BorderSide(color: Colors.red[300]!),
                          padding: EdgeInsets.symmetric(
                            vertical: isTablet ? 12 : 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _approveRestaurantRequest(request),
                        icon: const Icon(Icons.check, size: 18),
                        label: Text(
                          'Approve',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          padding: EdgeInsets.symmetric(
                            vertical: isTablet ? 12 : 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(RestaurantRequestStatus status) {
    switch (status) {
      case RestaurantRequestStatus.pending:
        return Colors.orange;
      case RestaurantRequestStatus.approved:
        return Colors.green;
      case RestaurantRequestStatus.rejected:
        return Colors.red;
    }
  }

  IconData _getStatusIcon(RestaurantRequestStatus status) {
    switch (status) {
      case RestaurantRequestStatus.pending:
        return Icons.pending;
      case RestaurantRequestStatus.approved:
        return Icons.check;
      case RestaurantRequestStatus.rejected:
        return Icons.close;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // Header with proper safe area handling
          Container(
            color: Colors.grey[50],
            child: SafeArea(
              top: true,
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: AppHeader(
                  title: _isSelecting
                      ? '${_selectedRequestIds.length} Selected'
                      : 'Restaurant Approvals',
                  onBack: _isSelecting
                      ? _clearSelection
                      : () => Navigator.pop(context),
                  includeSafeArea: false,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ),

          // Search and filter section
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Search field
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search restaurants, users, or emails...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: _clearFilters,
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),

                // Filter chips
                if (_searchQuery.isNotEmpty || _selectedWilaya != null) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (_searchQuery.isNotEmpty)
                        Chip(
                          label: Text('Search: "$_searchQuery"'),
                          onDeleted: () {
                            setState(() {
                              _searchQuery = '';
                              _searchController.clear();
                            });
                          },
                        ),
                      if (_selectedWilaya != null)
                        Chip(
                          label: Text('Wilaya: $_selectedWilaya'),
                          onDeleted: () {
                            setState(() {
                              _selectedWilaya = null;
                            });
                          },
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Statistics overview
          _buildStatsOverview(),

          // Tab bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                color: Colors.orange[100],
              ),
              labelColor: Colors.orange[800],
              unselectedLabelColor: Colors.grey[600],
              labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: 'Pending'),
                Tab(text: 'Approved'),
                Tab(text: 'Rejected'),
              ],
            ),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Pending tab
                Consumer<RestaurantRequestService>(
                  builder: (context, restaurantRequestService, child) {
                    final allRequests =
                        restaurantRequestService.pendingRequests;
                    final filteredRequests = _filterRequests(allRequests);

                    // Check for database errors
                    if (restaurantRequestService.error != null) {
                      if (restaurantRequestService.error!
                              .contains('relation') &&
                          restaurantRequestService.error!
                              .contains('does not exist')) {
                        return _buildDatabaseErrorState();
                      }
                    }

                    if (restaurantRequestService.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (filteredRequests.isEmpty) {
                      return Container(
                        color: Colors.grey[50],
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                allRequests.isEmpty
                                    ? Icons.restaurant_menu
                                    : Icons.search_off,
                                size: 64,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                allRequests.isEmpty
                                    ? 'No pending restaurant requests'
                                    : 'No requests match your search criteria',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                              if (allRequests.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: _clearFilters,
                                  child: const Text('Clear filters'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () async {
                        await restaurantRequestService.loadRestaurantRequests();
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        itemCount: filteredRequests.length,
                        itemBuilder: (context, index) {
                          final request = filteredRequests[index];
                          return _buildRestaurantRequestCard(request);
                        },
                      ),
                    );
                  },
                ),

                // Approved tab
                Consumer<RestaurantRequestService>(
                  builder: (context, restaurantRequestService, child) {
                    final allRequests =
                        restaurantRequestService.approvedRequests;
                    final filteredRequests = _filterRequests(allRequests);

                    if (filteredRequests.isEmpty) {
                      return Container(
                        color: Colors.grey[50],
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                allRequests.isEmpty
                                    ? Icons.check_circle_outline
                                    : Icons.search_off,
                                size: 64,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                allRequests.isEmpty
                                    ? 'No approved restaurant requests'
                                    : 'No requests match your search criteria',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                              if (allRequests.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: _clearFilters,
                                  child: const Text('Clear filters'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () async {
                        await restaurantRequestService.loadRestaurantRequests();
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        itemCount: filteredRequests.length,
                        itemBuilder: (context, index) {
                          final request = filteredRequests[index];
                          return _buildRestaurantRequestCard(request);
                        },
                      ),
                    );
                  },
                ),

                // Rejected tab
                Consumer<RestaurantRequestService>(
                  builder: (context, restaurantRequestService, child) {
                    final allRequests =
                        restaurantRequestService.rejectedRequests;
                    final filteredRequests = _filterRequests(allRequests);

                    if (filteredRequests.isEmpty) {
                      return Container(
                        color: Colors.grey[50],
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                allRequests.isEmpty
                                    ? Icons.cancel_outlined
                                    : Icons.search_off,
                                size: 64,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                allRequests.isEmpty
                                    ? 'No rejected restaurant requests'
                                    : 'No requests match your search criteria',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                              if (allRequests.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: _clearFilters,
                                  child: const Text('Clear filters'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () async {
                        await restaurantRequestService.loadRestaurantRequests();
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        itemCount: filteredRequests.length,
                        itemBuilder: (context, index) {
                          final request = filteredRequests[index];
                          return _buildRestaurantRequestCard(request);
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Format working hours using actual JSON data from the request
  String _formatWorkingHours(
      Map<String, dynamic> openingHours, Map<String, dynamic> closingHours) {
    debugPrint(
        '🕐 AdminRestaurantApprovalScreen._formatWorkingHours() called - openingHours: $openingHours, closingHours: $closingHours');

    try {
      // The hours are already in the correct jsonb format
      if (openingHours.isNotEmpty) {
        // Use WorkingHoursUtils to format the actual working hours
        final formattedHours =
            WorkingHoursUtils.formatWorkingHours(openingHours);

        debugPrint(
            '✅ AdminRestaurantApprovalScreen._formatWorkingHours() - formatted successfully');
        return formattedHours;
      }
    } catch (e) {
      debugPrint(
          '⚠️ AdminRestaurantApprovalScreen._formatWorkingHours() - formatting error: $e');
    }

    // Fallback to simple display if formatting fails
    return 'Working hours not specified';
  }
}
