import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../home_screen.dart';
import '../l10n/app_localizations.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../widgets/app_header.dart';

class ReviewTasksScreen extends StatefulWidget {
  final List<Task> tasks;
  const ReviewTasksScreen({required this.tasks, super.key});

  @override
  State<ReviewTasksScreen> createState() => _ReviewTasksScreenState();
}

class _ReviewTasksScreenState extends State<ReviewTasksScreen> {
  bool _submitting = false;

  Future<void> _confirmAndCreate() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final prepared = widget.tasks
          .map((t) => t.copyWith(id: t.id.replaceFirst('local-', '')))
          .toList();
      await _createTasksWithRetry(prepared);
      if (!mounted) return;
      unawaited(Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '${AppLocalizations.of(context)?.failedToCreateTasks ?? 'Failed to create tasks: {error}'}'
                  .replaceAll('{error}', e.toString()))));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _createTasksWithRetry(List<Task> tasks) async {
    try {
      // Create tasks individually since we removed multi-task logic
      for (final task in tasks) {
        await TaskService.instance.createTask(task);
      }
      return;
    } on PostgrestException catch (e) {
      final msg = e.message.toLowerCase();
      final details = e.details?.toString().toLowerCase() ?? '';
      final code = e.code?.toLowerCase() ?? '';
      final looksExpired = msg.contains('jwt expired') ||
          details.contains('unauthorized') ||
          code == 'pgrst303';
      if (!looksExpired) rethrow;
      // Refresh session and retry once
      await Supabase.instance.client.auth.refreshSession();
      for (final task in tasks) {
        await TaskService.instance.createTask(task);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasks = widget.tasks;
    // PERFORMANCE FIX: Convert ListView(children) to ListView.builder for virtualization
    // This prevents building all items upfront and enables lazy loading
    final children = <Widget>[
      SafeArea(
          bottom: false,
          child: AppHeader(
              title: AppLocalizations.of(context)?.reviewIfriliTasks ??
                  'Review Ifrili Tasks')),
      const SizedBox(height: 12),
      if (tasks.isEmpty) ...[
        Center(
          child: Column(
            children: [
              const SizedBox(height: 48),
              Icon(Icons.assignment_turned_in,
                  size: 72, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text(
                  AppLocalizations.of(context)?.noDraftTasksToReview ??
                      'No draft tasks to review',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700, fontSize: 16)),
            ],
          ),
        ),
      ] else ...[
        _reviewGroupCard(tasks),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _confirmAndCreate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFd47b00),
                  foregroundColor: Colors.white,
                  elevation: 10,
                  shadowColor: const Color(0xFFd47b00).withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25.5)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle),
                label: Text(
                    _submitting
                        ? (AppLocalizations.of(context)?.creating ??
                            'Creating...')
                        : (AppLocalizations.of(context)?.confirmCreateTasks ??
                            'Confirm & Create'),
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed:
              _submitting ? null : () => Navigator.of(context).pop(false),
          child: Text(
              AppLocalizations.of(context)?.backToEdit ?? 'Back to edit',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700, fontSize: 14)),
        ),
      ],
    ];

    return Scaffold(
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: children.length,
        itemBuilder: (context, index) => children[index],
      ),
    );
  }

  Widget _reviewGroupCard(List<Task> tasks) {
    return Card(
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      shadowColor: Colors.black.withValues(alpha: 0.12),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
                AppLocalizations.of(context)?.reviewIfriliTasks ??
                    'Review Ifrili Tasks',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 16),

            // Tasks Description Section
            Text(
                AppLocalizations.of(context)?.tasksDescription ??
                    'Tasks Description:',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Text(
                tasks.map((t) => t.description).join('\n'),
                style: GoogleFonts.poppins(fontSize: 14),
              ),
            ),
            const SizedBox(height: 16),

            // Tasks Locations Section
            Text(
                AppLocalizations.of(context)?.tasksLocations ??
                    'Tasks Locations:',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 8),
            ...tasks.map((t) => _buildAllLocationsForTask(t)),
            const SizedBox(height: 16),

            // Contact Phone Section
            Text(AppLocalizations.of(context)?.contactPhone ?? 'Contact Phone:',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Text(
                _formatPhoneNumbers(tasks.first),
                style: GoogleFonts.poppins(fontSize: 14),
              ),
            ),
            const SizedBox(height: 16),

            // Images Preview Section
            Text(
                AppLocalizations.of(context)?.imagesPreview ??
                    'Images Preview:',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Center(
                child: Text(
                  AppLocalizations.of(context)?.noImages ?? 'No images',
                  style: GoogleFonts.poppins(
                      fontSize: 14, color: Colors.grey[600]),
                ),
              ),
            ),
          ],
        ),
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
      return AppLocalizations.of(context)?.noPhoneProvided ??
          'No phone provided';
    }

    return phones.join('\n');
  }

  Widget _buildAllLocationsForTask(Task task) {
    final locations = <_LocationInfo>[];

    // Add primary location
    locations.add(_LocationInfo(
      purpose: task.locationPurpose ??
          (AppLocalizations.of(context)?.locationPurpose ?? 'Location purpose'),
      address: task.locationName,
    ));

    // Add additional locations from additionalLocations field
    if (task.additionalLocations != null &&
        task.additionalLocations!.isNotEmpty) {
      for (final loc in task.additionalLocations!) {
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
                fontSize: 13,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationInfo {
  final String purpose;
  final String address;

  _LocationInfo({required this.purpose, required this.address});
}
