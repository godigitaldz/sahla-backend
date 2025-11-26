import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/delivery_man_request.dart';
import '../../services/auth_service.dart';
import '../../services/delivery_man_request_service.dart';
import '../app_header.dart';

class AdminDeliveryManApprovalScreen extends StatefulWidget {
  const AdminDeliveryManApprovalScreen({super.key});

  @override
  State<AdminDeliveryManApprovalScreen> createState() =>
      _AdminDeliveryManApprovalScreenState();
}

class _AdminDeliveryManApprovalScreenState
    extends State<AdminDeliveryManApprovalScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late DeliveryManRequestService _deliveryManRequestService;
  late AuthService _authService;

  final TextEditingController _searchController = TextEditingController();
  Timer? _autoRefreshTimer;

  // Multi-select state
  bool _isSelecting = false;
  final Set<String> _selectedRequestIds = {};

  // Pagination
  final ScrollController _scrollController = ScrollController();

  // Search debouncing
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _deliveryManRequestService = context.read<DeliveryManRequestService>();
    _authService = context.read<AuthService>();
    // Load data when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // First check database setup
      _deliveryManRequestService.checkDatabaseSetup();
      // Then load delivery man requests
      _loadDeliveryManRequests();

      // Set up infinite scroll listener
      _scrollController.addListener(_onScroll);

      // Start auto-refresh every 30 seconds
      _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
        if (mounted) {
          _loadDeliveryManRequests();
        }
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _autoRefreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDeliveryManRequests() async {
    try {
      await _deliveryManRequestService.loadDeliveryManRequests();
    } catch (e) {
      if (mounted) {
        // Check if it's a database table issue
        if (e.toString().contains('relation') &&
            e.toString().contains('does not exist')) {
          _showErrorDialog(
            'Database tables not found. Please run database migrations first.\n\n'
            'Error: ${e.toString()}',
          );
        } else {
          _showErrorDialog(_getUserFriendlyError(e.toString()));
        }
      }
    }
  }

  Future<void> _approveDeliveryManRequest(DeliveryManRequest request) async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      _showSnackBar('Authentication error', Colors.red);
      return;
    }

    // Confirm approval
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Delivery Man Request'),
        content: Text('Approve ${request.userName} as delivery man?'),
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

    try {
      final success =
          await _deliveryManRequestService.approveDeliveryManRequest(
        request.id,
        currentUser.id,
        currentUser.name ?? 'Admin',
      );

      if (success) {
        _showSnackBar(
            'Delivery man request approved successfully', Colors.green);

        // Immediately update the local state to reflect the change
        if (mounted) {
          setState(() {});
        }

        // Force refresh data to update the UI
        await _deliveryManRequestService.forceRefresh();
      } else {
        _showErrorDialog(
            'Failed to approve delivery man request. Please try again.');
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(
            'Failed to approve delivery man request: ${_getUserFriendlyError(e.toString())}');
      }
    }
  }

  Future<void> _rejectDeliveryManRequest(
      DeliveryManRequest request, String reason) async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      _showSnackBar('Authentication error', Colors.red);
      return;
    }

    try {
      final success = await _deliveryManRequestService.rejectDeliveryManRequest(
        request.id,
        currentUser.id,
        currentUser.name ?? 'Admin',
        reason,
      );

      if (success) {
        _showSnackBar('Delivery man request rejected', Colors.orange);

        // Immediately update the local state to reflect the change
        if (mounted) {
          setState(() {});
        }

        // Force refresh data to update the UI
        await _deliveryManRequestService.forceRefresh();
      } else {
        _showErrorDialog(
            'Failed to reject delivery man request. Please try again.');
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(
            'Failed to reject delivery man request: ${_getUserFriendlyError(e.toString())}');
      }
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

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(_getUserFriendlyError(error)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _getUserFriendlyError(String error) {
    // Permission and authorization errors
    if (error.contains('permission') ||
        error.contains('unauthorized') ||
        error.contains('forbidden')) {
      return 'You do not have permission to perform this action. Please contact an administrator if you need access.';
    }

    // Network and connectivity errors
    else if (error.contains('network') ||
        error.contains('connection') ||
        error.contains('timeout')) {
      return 'Network error. Please check your internet connection and try again.';
    }

    // Database and data errors
    else if (error.contains('not found') ||
        error.contains('404') ||
        error.contains('no data')) {
      return 'The requested data could not be found. Please refresh and try again.';
    }

    // Server errors
    else if (error.contains('server') ||
        error.contains('500') ||
        error.contains('internal')) {
      return 'Server error occurred. Please try again later or contact support if the problem persists.';
    }

    // Database constraint errors
    else if (error.contains('duplicate') ||
        error.contains('unique') ||
        error.contains('constraint')) {
      return 'This action cannot be completed due to a data constraint. Please check your input and try again.';
    }

    // Authentication errors
    else if (error.contains('auth') ||
        error.contains('token') ||
        error.contains('session')) {
      return 'Authentication error. Please sign in again and try again.';
    }

    // Validation errors
    else if (error.contains('invalid') ||
        error.contains('validation') ||
        error.contains('format')) {
      return 'Invalid data provided. Please check your input and try again.';
    }

    // Rate limiting
    else if (error.contains('rate limit') || error.contains('too many')) {
      return 'Too many requests. Please wait a moment and try again.';
    }

    // Default fallback
    return 'An unexpected error occurred. Please try again or contact support if the problem continues.';
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      _deliveryManRequestService.filterRequests(query);
    });
  }

  void _onSortChanged(String sortOption) {
    _deliveryManRequestService.sortRequests(sortOption);
  }

  void _clearSearch() {
    _searchController.clear();
    _deliveryManRequestService.clearFilters();
  }

  String _getSortLabel(String sortOption) {
    switch (sortOption) {
      case 'newest':
        return 'Newest First';
      case 'oldest':
        return 'Oldest First';
      case 'name':
        return 'By Name';
      default:
        return 'Newest First';
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreRequests();
    }
  }

  Future<void> _loadMoreRequests() async {
    if (!_deliveryManRequestService.hasMorePages ||
        _deliveryManRequestService.isLoading) {
      return;
    }

    try {
      await _deliveryManRequestService.loadMoreRequests();
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Failed to load more requests: ${e.toString()}');
      }
    }
  }

  void _clearSelection() {
    setState(() {
      _selectedRequestIds.clear();
      _isSelecting = false;
    });
  }

  void _showDeliveryManRequestDetails(DeliveryManRequest request) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildDeliveryManRequestDetailsModal(request),
    );
  }

  void _showRejectDialog(DeliveryManRequest request) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Delivery Man Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Reject ${request.userName}\'s delivery man application?'),
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
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please provide a rejection reason'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              Navigator.pop(context);
              _rejectDeliveryManRequest(request, reason);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryManRequestDetailsModal(DeliveryManRequest request) {
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
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Delivery Man Request Details',
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
                  _buildDetailSection('Personal Information', [
                    _buildDetailRow('Full Name', request.fullName),
                    _buildDetailRow('Phone', request.phone),
                    _buildDetailRow('Address', request.address),
                  ]),
                  const SizedBox(height: 20),
                  _buildDetailSection('Vehicle Information', [
                    _buildDetailRow('Vehicle Type', request.vehicleType),
                    _buildDetailRow('Plate Number', request.plateNumber),
                    _buildDetailRow('Has Valid License',
                        request.hasValidLicense ? 'Yes' : 'No'),
                    _buildDetailRow(
                        'Has Vehicle', request.hasVehicle ? 'Yes' : 'No'),
                  ]),
                  const SizedBox(height: 20),
                  _buildDetailSection('Availability', [
                    _buildDetailRow('Availability Type', request.availability),
                    _buildDetailRow('Available Weekends',
                        request.isAvailableWeekends ? 'Yes' : 'No'),
                    _buildDetailRow('Available Evenings',
                        request.isAvailableEvenings ? 'Yes' : 'No'),
                    if (request.experience != null &&
                        request.experience!.isNotEmpty)
                      _buildDetailRow('Experience', request.experience!),
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
                      _approveDeliveryManRequest(request);
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
    return Consumer<DeliveryManRequestService>(
      builder: (context, service, child) {
        final totalRequests = service.deliveryManRequests.length;
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

  Widget _buildEmptyState(String message, IconData icon, Color color,
      {String? actionText, VoidCallback? onActionPressed}) {
    return Container(
      color: Colors.grey[50],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: color,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            if (actionText != null && onActionPressed != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onActionPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                ),
                child: Text(actionText),
              ),
            ],
          ],
        ),
      ),
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
                'The database tables for delivery man requests are not set up yet.\n\n'
                'Please run the database migrations to create the required tables:\n'
                '• delivery_man_requests\n'
                '• delivery_personnel\n\n'
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
                  _loadDeliveryManRequests();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
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

  Widget _buildDeliveryManRequestCard(DeliveryManRequest request) {
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
        onTap: () => _showDeliveryManRequestDetails(request),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(isTablet ? 20 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with avatar, name, and status
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

                  // Name and basic info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.fullName,
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
                    // Vehicle info row
                    Row(
                      children: [
                        Icon(
                          Icons.motorcycle,
                          size: isTablet ? 20 : 18,
                          color: Colors.blue[600],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            request.vehicleType,
                            style: GoogleFonts.poppins(
                              fontSize: isTablet ? 14 : 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        if (request.plateNumber.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              request.plateNumber,
                              style: GoogleFonts.poppins(
                                fontSize: isTablet ? 12 : 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue[700],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Availability info row
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: isTablet ? 20 : 18,
                          color: Colors.green[600],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            request.availability,
                            style: GoogleFonts.poppins(
                              fontSize: isTablet ? 14 : 13,
                              color: Colors.black87,
                            ),
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
                        onPressed: () => _approveDeliveryManRequest(request),
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

  Color _getStatusColor(DeliveryManRequestStatus status) {
    switch (status) {
      case DeliveryManRequestStatus.pending:
        return Colors.orange;
      case DeliveryManRequestStatus.approved:
        return Colors.green;
      case DeliveryManRequestStatus.rejected:
        return Colors.red;
    }
  }

  IconData _getStatusIcon(DeliveryManRequestStatus status) {
    switch (status) {
      case DeliveryManRequestStatus.pending:
        return Icons.pending;
      case DeliveryManRequestStatus.approved:
        return Icons.check;
      case DeliveryManRequestStatus.rejected:
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
                      : 'Delivery Man Approvals',
                  onBack: _isSelecting
                      ? _clearSelection
                      : () => Navigator.pop(context),
                  includeSafeArea: false,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ),

          // Search and filter controls
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                // Search bar
                TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search by name, email, vehicle...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: _clearSearch,
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),

                // Sort dropdown
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Sort Options',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: _onSortChanged,
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                            value: 'newest', child: Text('Newest First')),
                        const PopupMenuItem(
                            value: 'oldest', child: Text('Oldest First')),
                        const PopupMenuItem(
                            value: 'name', child: Text('By Name')),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _getSortLabel(
                                  _deliveryManRequestService.selectedSort),
                              style: GoogleFonts.poppins(fontSize: 12),
                            ),
                            const Icon(Icons.arrow_drop_down, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
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
                color: Colors.blue[100],
              ),
              labelColor: Colors.blue[800],
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
                Consumer<DeliveryManRequestService>(
                  builder: (context, deliveryManRequestService, child) {
                    final requests = deliveryManRequestService.pendingRequests;

                    // Check for database errors
                    if (deliveryManRequestService.error != null) {
                      if (deliveryManRequestService.error!
                              .contains('relation') &&
                          deliveryManRequestService.error!
                              .contains('does not exist')) {
                        return _buildDatabaseErrorState();
                      }
                    }

                    if (deliveryManRequestService.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (requests.isEmpty) {
                      return _buildEmptyState(
                        'No pending delivery man requests\nAll caught up!',
                        Icons.pending_actions,
                        Colors.orange,
                        actionText: 'Refresh',
                        onActionPressed: _loadDeliveryManRequests,
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () async {
                        await deliveryManRequestService.forceRefresh();
                      },
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        itemCount: requests.length +
                            (deliveryManRequestService.hasMorePages ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == requests.length) {
                            return Container(
                              padding: const EdgeInsets.all(16),
                              child: deliveryManRequestService.isLoading
                                  ? const Center(
                                      child: CircularProgressIndicator(),
                                    )
                                  : const Center(
                                      child: Text(
                                        'No more requests',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                            );
                          }
                          final request = requests[index];
                          return _buildDeliveryManRequestCard(request);
                        },
                      ),
                    );
                  },
                ),

                // Approved tab
                Consumer<DeliveryManRequestService>(
                  builder: (context, deliveryManRequestService, child) {
                    final requests = deliveryManRequestService.approvedRequests;

                    if (requests.isEmpty) {
                      return _buildEmptyState(
                        'No approved delivery man requests yet\nCheck back later for new approvals!',
                        Icons.check_circle_outline,
                        Colors.green,
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () async {
                        await deliveryManRequestService.forceRefresh();
                      },
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        itemCount: requests.length +
                            (deliveryManRequestService.hasMorePages ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == requests.length) {
                            return Container(
                              padding: const EdgeInsets.all(16),
                              child: deliveryManRequestService.isLoading
                                  ? const Center(
                                      child: CircularProgressIndicator(),
                                    )
                                  : const Center(
                                      child: Text(
                                        'No more requests',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                            );
                          }
                          final request = requests[index];
                          return _buildDeliveryManRequestCard(request);
                        },
                      ),
                    );
                  },
                ),

                // Rejected tab
                Consumer<DeliveryManRequestService>(
                  builder: (context, deliveryManRequestService, child) {
                    final requests = deliveryManRequestService.rejectedRequests;

                    if (requests.isEmpty) {
                      return _buildEmptyState(
                        'No rejected delivery man requests\nAll applications have been reviewed!',
                        Icons.cancel_outlined,
                        Colors.red,
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () async {
                        await deliveryManRequestService.forceRefresh();
                      },
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        itemCount: requests.length +
                            (deliveryManRequestService.hasMorePages ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == requests.length) {
                            return Container(
                              padding: const EdgeInsets.all(16),
                              child: deliveryManRequestService.isLoading
                                  ? const Center(
                                      child: CircularProgressIndicator(),
                                    )
                                  : const Center(
                                      child: Text(
                                        'No more requests',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                            );
                          }
                          final request = requests[index];
                          return _buildDeliveryManRequestCard(request);
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
}
