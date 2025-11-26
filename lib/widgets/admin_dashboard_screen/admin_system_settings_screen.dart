import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/auth_service.dart';
import '../../services/system_config_service.dart';
import '../app_header.dart';

class AdminSystemSettingsScreen extends StatefulWidget {
  const AdminSystemSettingsScreen({super.key});

  @override
  State<AdminSystemSettingsScreen> createState() =>
      _AdminSystemSettingsScreenState();
}

class _AdminSystemSettingsScreenState extends State<AdminSystemSettingsScreen> {
  // Services
  final SystemConfigService _systemConfigService = SystemConfigService();
  final AuthService _authService = AuthService();

  // System Settings State
  bool _isLoading = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    try {
      // First try to load from database
      final dbAvailable = await _systemConfigService.isDatabaseAvailable();
      if (dbAvailable) {
        await _systemConfigService.loadFromDatabase();
      } else {
        // Fallback to local settings
        await _systemConfigService.initialize();
        // Try to initialize database with current settings
        await _systemConfigService.initializeDatabase();
      }
    } catch (e) {
      _showSnackBar('Error loading settings: $e', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);

    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        _showSnackBar('Authentication error', Colors.red);
        return;
      }

      // Save all settings through the service
      await _systemConfigService
          .updateMaxDeliveryRadius(_systemConfigService.maxDeliveryRadius);
      await _systemConfigService
          .updateMaxRestaurantRadius(_systemConfigService.maxRestaurantRadius);
      await _systemConfigService
          .updateOrderTimeout(_systemConfigService.orderTimeout);
      await _systemConfigService
          .updateMaxRetryAttempts(_systemConfigService.maxRetryAttempts);

      // Update service fee with admin ID for service integration
      await _systemConfigService.updateServiceFee(
          _systemConfigService.serviceFee, currentUser.id);

      // Update other settings
      await _systemConfigService.updateCacheSettings(
        enabled: _systemConfigService.cacheEnabled,
        expiryHours: _systemConfigService.cacheExpiryHours,
        autoClear: _systemConfigService.autoClearCache,
      );

      await _systemConfigService.updateSecuritySettings(
        sessionTimeout: _systemConfigService.sessionTimeout,
        timeoutMinutes: _systemConfigService.sessionTimeoutMinutes,
      );

      await _systemConfigService.updatePerformanceSettings(
        imageOptimization: _systemConfigService.imageOptimization,
        lazyLoading: _systemConfigService.lazyLoading,
        maxImageSize: _systemConfigService.maxImageSize,
        cdnEnabled: _systemConfigService.cdnEnabled,
      );

      // Save to database
      final dbAvailable = await _systemConfigService.isDatabaseAvailable();
      if (dbAvailable) {
        final success = await _systemConfigService.saveToDatabase();
        if (success) {
          _showSnackBar(
              'Settings saved to database and locally!', Colors.green);
        } else {
          _showSnackBar(
              'Settings saved locally (database save failed)', Colors.orange);
        }
      } else {
        _showSnackBar(
            'Settings saved locally (database unavailable)', Colors.orange);
      }

      setState(() => _hasChanges = false);
    } catch (e) {
      _showSnackBar('Error saving settings: $e', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resetToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to Defaults'),
        content: const Text(
            'Are you sure you want to reset all settings to their default values? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _hasChanges = true;
      });
      await _systemConfigService.resetToDefaults();
      _showSnackBar('Settings reset to defaults', Colors.orange);
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

  void _onSettingChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  Future<void> _refreshFromDatabase() async {
    setState(() => _isLoading = true);

    try {
      await _systemConfigService.refreshFromDatabase();
      _showSnackBar('Settings refreshed from database', Colors.green);
      setState(() => _hasChanges = false);
    } catch (e) {
      _showSnackBar('Error refreshing from database: $e', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // Header
          Container(
            color: Colors.grey[50],
            child: SafeArea(
              top: true,
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: AppHeader(
                        title: 'System Settings',
                        onBack: () {
                          if (_hasChanges) {
                            _showUnsavedChangesDialog();
                          } else {
                            Navigator.pop(context);
                          }
                        },
                        includeSafeArea: false,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                    IconButton(
                      onPressed: _refreshFromDatabase,
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Refresh from Database',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.blue.withValues(alpha: 0.1),
                        foregroundColor: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _hasChanges ? _saveSettings : null,
                                icon: const Icon(Icons.save),
                                label: const Text('Save Changes'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      _hasChanges ? Colors.green : Colors.grey,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _resetToDefaults,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Reset to Defaults'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Fee Configuration Section
                        _buildSectionCard(
                          title: 'Fee Configuration',
                          icon: Icons.attach_money,
                          children: [
                            _buildInputTile(
                              title: 'Service Fee',
                              subtitle: 'Platform service fee in DA',
                              value: _systemConfigService.serviceFee,
                              min: 0.1,
                              max: 10.0,
                              unit: 'DA',
                              onChanged: (value) {
                                _systemConfigService.updateServiceFee(
                                    value, _authService.currentUser?.id ?? '');
                                _onSettingChanged();
                              },
                            ),
                            _buildDistanceBasedFeeSection(),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // System Configuration
                        _buildSectionCard(
                          title: 'System Configuration',
                          icon: Icons.settings,
                          children: [
                            _buildInputTile(
                              title: 'Max Delivery Radius',
                              subtitle: 'Maximum delivery radius in km',
                              value: _systemConfigService.maxDeliveryRadius
                                  .toDouble(),
                              min: 10,
                              max: 100,
                              unit: 'km',
                              onChanged: (value) {
                                _systemConfigService
                                    .updateMaxDeliveryRadius(value.round());
                                _onSettingChanged();
                              },
                            ),
                            _buildInputTile(
                              title: 'Max Restaurant Radius',
                              subtitle: 'Maximum restaurant radius in km',
                              value: _systemConfigService.maxRestaurantRadius
                                  .toDouble(),
                              min: 5,
                              max: 50,
                              unit: 'km',
                              onChanged: (value) {
                                _systemConfigService
                                    .updateMaxRestaurantRadius(value.round());
                                _onSettingChanged();
                              },
                            ),
                            _buildInputTile(
                              title: 'Order Timeout (minutes)',
                              subtitle: 'Maximum time to complete an order',
                              value:
                                  _systemConfigService.orderTimeout.toDouble(),
                              min: 15,
                              max: 120,
                              unit: 'min',
                              onChanged: (value) {
                                _systemConfigService
                                    .updateOrderTimeout(value.round());
                                _onSettingChanged();
                              },
                            ),
                            _buildInputTile(
                              title: 'Max Retry Attempts',
                              subtitle:
                                  'Maximum retry attempts for failed operations',
                              value: _systemConfigService.maxRetryAttempts
                                  .toDouble(),
                              min: 1,
                              max: 10,
                              unit: 'attempts',
                              onChanged: (value) {
                                _systemConfigService
                                    .updateMaxRetryAttempts(value.round());
                                _onSettingChanged();
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Performance Settings
                        _buildSectionCard(
                          title: 'Performance Settings',
                          icon: Icons.speed,
                          children: [
                            _buildSwitchTile(
                              title: 'Image Optimization',
                              subtitle:
                                  'Automatically optimize uploaded images',
                              value: _systemConfigService.imageOptimization,
                              onChanged: (value) {
                                _systemConfigService.updatePerformanceSettings(
                                    imageOptimization: value);
                                _onSettingChanged();
                              },
                            ),
                            _buildSwitchTile(
                              title: 'Lazy Loading',
                              subtitle: 'Load content as needed',
                              value: _systemConfigService.lazyLoading,
                              onChanged: (value) {
                                _systemConfigService.updatePerformanceSettings(
                                    lazyLoading: value);
                                _onSettingChanged();
                              },
                            ),
                            _buildInputTile(
                              title: 'Max Image Size (MB)',
                              subtitle: 'Maximum size for uploaded images',
                              value:
                                  _systemConfigService.maxImageSize.toDouble(),
                              min: 1,
                              max: 20,
                              unit: 'MB',
                              onChanged: (value) {
                                _systemConfigService.updatePerformanceSettings(
                                    maxImageSize: value.round());
                                _onSettingChanged();
                              },
                            ),
                            _buildSwitchTile(
                              title: 'CDN Enabled',
                              subtitle: 'Use Content Delivery Network',
                              value: _systemConfigService.cdnEnabled,
                              onChanged: (value) {
                                _systemConfigService.updatePerformanceSettings(
                                    cdnEnabled: value);
                                _onSettingChanged();
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 100), // Bottom padding
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFd47b00).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: const Color(0xFFd47b00),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: enabled ? Colors.black87 : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: enabled ? Colors.grey[600] : Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: enabled ? onChanged : null,
            activeColor: const Color(0xFFd47b00),
          ),
        ],
      ),
    );
  }

  Widget _buildInputTile({
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required String unit,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: value.toStringAsFixed(1),
            keyboardType: TextInputType.number,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: 'Enter value',
              suffix: Text(unit, style: GoogleFonts.inter(fontSize: 14)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: Color(0xFFd47b00), width: 2),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (text) {
              final newValue = double.tryParse(text);
              if (newValue != null && newValue >= min && newValue <= max) {
                onChanged(newValue);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDistanceBasedFeeSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Distance-Based Delivery Fee',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Configure delivery fees based on distance ranges',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _addNewRange,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Range'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFd47b00),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._systemConfigService.deliveryFeeRanges
              .asMap()
              .entries
              .map((entry) {
            final index = entry.key;
            final range = entry.value;
            return _buildFeeRangeTile(
              title: 'Range ${index + 1}',
              subtitle: 'Up to ${range.maxDistance.toStringAsFixed(1)} km',
              value: range.fee,
              maxDistance: range.maxDistance,
              onChanged: (newFee) {
                final updatedRanges = List<DeliveryFeeRange>.from(
                    _systemConfigService.deliveryFeeRanges);
                updatedRanges[index] = DeliveryFeeRange(
                  maxDistance: range.maxDistance,
                  fee: newFee,
                );
                _systemConfigService.updateDeliveryFeeRanges(updatedRanges);
                _onSettingChanged();
              },
              onDistanceChanged: (newDistance) {
                final updatedRanges = List<DeliveryFeeRange>.from(
                    _systemConfigService.deliveryFeeRanges);
                updatedRanges[index] = DeliveryFeeRange(
                  maxDistance: newDistance,
                  fee: range.fee,
                );
                _systemConfigService.updateDeliveryFeeRanges(updatedRanges);
                _onSettingChanged();
              },
              onEdit: () => _editRange(index),
              onDelete: () => _deleteRange(index),
            );
          }),
          const SizedBox(height: 16),
          _buildInputTile(
            title: 'Extra Range Fee',
            subtitle: 'Fee per 100m beyond last range',
            value: _systemConfigService.extraRangeFee,
            min: 1.0,
            max: 20.0,
            unit: 'DA',
            onChanged: (value) {
              _systemConfigService.updateExtraRangeFee(value);
              _onSettingChanged();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFeeRangeTile({
    required String title,
    required String subtitle,
    required double value,
    required double maxDistance,
    required ValueChanged<double> onChanged,
    required ValueChanged<double> onDistanceChanged,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit, size: 18),
                    tooltip: 'Edit Range',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.blue.withValues(alpha: 0.1),
                      foregroundColor: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete, size: 18),
                    tooltip: 'Delete Range',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.red.withValues(alpha: 0.1),
                      foregroundColor: Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: maxDistance.toStringAsFixed(1),
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Distance (km)',
                    suffix: Text('km', style: GoogleFonts.inter(fontSize: 12)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onChanged: (value) {
                    final newDistance = double.tryParse(value);
                    if (newDistance != null && newDistance > 0) {
                      onDistanceChanged(newDistance);
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  initialValue: value.toStringAsFixed(0),
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Fee (DA)',
                    suffix: Text('DA', style: GoogleFonts.inter(fontSize: 12)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onChanged: (value) {
                    final newFee = double.tryParse(value);
                    if (newFee != null && newFee >= 0) {
                      onChanged(newFee);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Add new range
  void _addNewRange() {
    showDialog(
      context: context,
      builder: (context) => _RangeEditDialog(
        title: 'Add New Range',
        initialDistance: 5.0,
        initialFee: 50.0,
        onSave: (distance, fee) {
          final newRanges = List<DeliveryFeeRange>.from(
              _systemConfigService.deliveryFeeRanges);
          newRanges.add(DeliveryFeeRange(maxDistance: distance, fee: fee));
          _systemConfigService.updateDeliveryFeeRanges(newRanges);
          _onSettingChanged();
        },
      ),
    );
  }

  // Edit existing range
  void _editRange(int index) {
    final range = _systemConfigService.deliveryFeeRanges[index];
    showDialog(
      context: context,
      builder: (context) => _RangeEditDialog(
        title: 'Edit Range ${index + 1}',
        initialDistance: range.maxDistance,
        initialFee: range.fee,
        onSave: (distance, fee) {
          final updatedRanges = List<DeliveryFeeRange>.from(
              _systemConfigService.deliveryFeeRanges);
          updatedRanges[index] =
              DeliveryFeeRange(maxDistance: distance, fee: fee);
          _systemConfigService.updateDeliveryFeeRanges(updatedRanges);
          _onSettingChanged();
        },
      ),
    );
  }

  // Delete range
  void _deleteRange(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Range'),
        content: Text('Are you sure you want to delete Range ${index + 1}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final updatedRanges = List<DeliveryFeeRange>.from(
                  _systemConfigService.deliveryFeeRanges);
              updatedRanges.removeAt(index);
              _systemConfigService.updateDeliveryFeeRanges(updatedRanges);
              _onSettingChanged();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showUnsavedChangesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text(
            'You have unsaved changes. Do you want to save them before leaving?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Discard'),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              navigator.pop();
              await _saveSettings();
              if (mounted) {
                navigator.pop();
              }
            },
            child: const Text('Save & Exit'),
          ),
        ],
      ),
    );
  }
}

// Range edit dialog widget
class _RangeEditDialog extends StatefulWidget {
  final String title;
  final double initialDistance;
  final double initialFee;
  final Function(double distance, double fee) onSave;

  const _RangeEditDialog({
    required this.title,
    required this.initialDistance,
    required this.initialFee,
    required this.onSave,
  });

  @override
  State<_RangeEditDialog> createState() => _RangeEditDialogState();
}

class _RangeEditDialogState extends State<_RangeEditDialog> {
  late TextEditingController _distanceController;
  late TextEditingController _feeController;

  @override
  void initState() {
    super.initState();
    _distanceController =
        TextEditingController(text: widget.initialDistance.toStringAsFixed(1));
    _feeController =
        TextEditingController(text: widget.initialFee.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _distanceController.dispose();
    _feeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _distanceController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Max Distance (km)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _feeController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Fee (DA)',
              border: OutlineInputBorder(),
            ),
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
            final distance = double.tryParse(_distanceController.text);
            final fee = double.tryParse(_feeController.text);

            if (distance != null && fee != null && distance > 0 && fee >= 0) {
              widget.onSave(distance, fee);
              Navigator.pop(context);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please enter valid distance and fee values'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
