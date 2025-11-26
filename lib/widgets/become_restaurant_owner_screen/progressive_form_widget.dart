import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/app_localizations.dart';

class ProgressiveFormWidget extends StatefulWidget {
  final List<String> steps;
  final int currentStep;
  final Function(int) onStepChanged;
  final Widget child;
  final bool Function(int step)? validateStep; // New validation function
  final VoidCallback? onSubmit; // Submit callback for last step
  final bool isSubmitting; // Loading state for submit button

  const ProgressiveFormWidget({
    required this.steps,
    required this.currentStep,
    required this.onStepChanged,
    required this.child,
    super.key,
    this.validateStep, // Optional validation function
    this.onSubmit, // Optional submit callback
    this.isSubmitting = false, // Default to false
  });

  @override
  State<ProgressiveFormWidget> createState() => _ProgressiveFormWidgetState();
}

class _ProgressiveFormWidgetState extends State<ProgressiveFormWidget> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Step content - wrapped in scrollable view
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 20),
            child: widget.child,
          ),
        ),

        // Unified bottom container with step indicator and navigation
        _buildUnifiedBottomContainer(),
      ],
    );
  }

  Widget _buildUnifiedBottomContainer() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          // Step indicator
          _buildStepIndicatorContent(),

          // Divider
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            color: Colors.grey[200],
          ),

          // Navigation buttons
          _buildNavigationButtonsContent(),
        ],
      ),
    );
  }

  Widget _buildStepIndicatorContent() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Progress bar
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(3),
            ),
            child: Row(
              children: widget.steps.asMap().entries.map((entry) {
                final index = entry.key;
                final isActive = index <= widget.currentStep;

                return Expanded(
                  child: Container(
                    margin: EdgeInsets.symmetric(
                        horizontal: index < widget.steps.length - 1 ? 1 : 0),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.orange[600] : Colors.transparent,
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: Colors.orange.withValues(alpha: 0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Step labels
          Row(
            children: widget.steps.asMap().entries.map((entry) {
              final index = entry.key;
              final stepName = entry.value;
              final isActive = index <= widget.currentStep;

              return Expanded(
                child: Column(
                  children: [
                    // Step circle
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isActive ? Colors.orange[600] : Colors.grey[300],
                        shape: BoxShape.circle,
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: Colors.orange.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: GoogleFonts.poppins(
                            color: isActive ? Colors.white : Colors.grey[600],
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Step name
                    Text(
                      stepName,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight:
                            isActive ? FontWeight.w600 : FontWeight.w400,
                        color: isActive ? Colors.orange[600] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtonsContent() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Previous button
          if (widget.currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () => widget.onStepChanged(widget.currentStep - 1),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey[300]!),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: Text(
                  AppLocalizations.of(context)!.previous,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

          if (widget.currentStep > 0) const SizedBox(width: 16),

          // Next button (only show if not on last step)
          if (widget.currentStep < widget.steps.length - 1)
            Expanded(
              flex: widget.currentStep > 0 ? 1 : 2,
              child: ElevatedButton(
                onPressed: () {
                  // Validate current step before proceeding
                  if (widget.validateStep != null) {
                    if (widget.validateStep!(widget.currentStep)) {
                      widget.onStepChanged(widget.currentStep + 1);
                    } else {
                      _showValidationError();
                    }
                  } else {
                    widget.onStepChanged(widget.currentStep + 1);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: Text(
                  AppLocalizations.of(context)!.next,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

          // Submit button (only show on last step)
          if (widget.currentStep == widget.steps.length - 1)
            Expanded(
              flex: widget.currentStep > 0 ? 1 : 2,
              child: ElevatedButton(
                onPressed: widget.isSubmitting ? null : widget.onSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: widget.isSubmitting
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            AppLocalizations.of(context)!.submitting,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        AppLocalizations.of(context)!.submit,
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

  void _showValidationError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            const Text('Please complete all required fields before proceeding'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
}

class FormStep {
  final String title;
  final String description;
  final Widget content;
  final bool isOptional;

  const FormStep({
    required this.title,
    required this.description,
    required this.content,
    this.isOptional = false,
  });
}
