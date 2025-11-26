import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';

class SectorAwareTextField extends StatelessWidget {
  final String sector;
  final String fieldType;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final String? hintText;
  final IconData? icon;
  final TextInputType? keyboardType;
  final int? maxLines;
  final List<TextInputFormatter>? inputFormatters;
  final bool readOnly;
  final VoidCallback? onTap;

  const SectorAwareTextField({
    required this.sector,
    required this.fieldType,
    required this.controller,
    super.key,
    this.validator,
    this.hintText,
    this.icon,
    this.keyboardType,
    this.maxLines,
    this.inputFormatters,
    this.readOnly = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final entityLabel = _getEntityLabel();
    final fieldLabel = _getFieldLabel(entityLabel);
    final fieldHint = hintText ?? _getFieldHint(entityLabel);
    final fieldIcon = icon ?? _getFieldIcon();

    // Use localized labels for specific field types
    String localizedLabel = fieldLabel;
    if (fieldType == 'name') {
      localizedLabel = '${AppLocalizations.of(context)!.restaurantName} *';
    } else if (fieldType == 'phone') {
      localizedLabel = '${AppLocalizations.of(context)!.restaurantPhone} *';
    }

    return Semantics(
      label: '$localizedLabel input field',
      hint: fieldHint,
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        inputFormatters: inputFormatters,
        readOnly: readOnly,
        onTap: onTap,
        decoration: InputDecoration(
          labelText: localizedLabel,
          hintText: fieldHint,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
            borderSide: BorderSide(color: Colors.orange[600]!, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
            borderSide: BorderSide(color: Colors.red[400]!),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
            borderSide: BorderSide(color: Colors.red[600]!, width: 2),
          ),
          prefixIcon: Icon(fieldIcon),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        validator: validator,
      ),
    );
  }

  String _getEntityLabel() {
    switch (sector) {
      case 'grocery':
        return 'Grocery';
      case 'handyman':
        return 'Handyman';
      default:
        return 'Restaurant';
    }
  }

  String _getFieldLabel(String entityLabel) {
    switch (fieldType) {
      case 'name':
        return '$entityLabel Name *';
      case 'phone':
        return '$entityLabel Phone *';
      case 'description':
        return '$entityLabel Description';
      case 'address':
        return '$entityLabel Address *';
      default:
        return fieldType;
    }
  }

  String _getFieldHint(String entityLabel) {
    switch (fieldType) {
      case 'name':
        return 'Enter your ${entityLabel.toLowerCase()} name';
      case 'phone':
        return 'Enter your ${entityLabel.toLowerCase()} phone';
      case 'description':
        return 'Describe your ${entityLabel.toLowerCase()}';
      case 'address':
        return 'Enter your ${entityLabel.toLowerCase()} address';
      default:
        return 'Enter $fieldType';
    }
  }

  IconData _getFieldIcon() {
    switch (fieldType) {
      case 'name':
        return _getEntityIcon();
      case 'phone':
        return Icons.edit;
      case 'description':
        return Icons.description;
      case 'address':
        return Icons.location_on;
      default:
        return Icons.edit;
    }
  }

  IconData _getEntityIcon() {
    switch (sector) {
      case 'grocery':
        return Icons.local_grocery_store;
      case 'handyman':
        return Icons.build;
      default:
        return Icons.restaurant;
    }
  }
}

class SectorAwareDropdown<T> extends StatelessWidget {
  final String sector;
  final String fieldType;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final Function(T?)? onChanged;
  final String? Function(T?)? validator;
  final String? hintText;
  final IconData? icon;

  const SectorAwareDropdown({
    required this.sector,
    required this.fieldType,
    required this.value,
    required this.items,
    super.key,
    this.onChanged,
    this.validator,
    this.hintText,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final entityLabel = _getEntityLabel();
    final fieldLabel = _getFieldLabel(entityLabel);
    final fieldHint = hintText ?? _getFieldHint(entityLabel);
    final fieldIcon = icon ?? _getFieldIcon();

    // Use localized hint for wilaya
    String localizedHint = fieldHint;
    if (fieldType == 'wilaya') {
      localizedHint = AppLocalizations.of(context)!.selectYourWilaya;
    }

    return Semantics(
      label: '$fieldLabel dropdown',
      hint: localizedHint,
      child: DropdownButtonFormField<T>(
        initialValue: value,
        items: items,
        onChanged: onChanged,
        validator: validator,
        decoration: InputDecoration(
          labelText: fieldLabel,
          hintText: localizedHint,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
            borderSide: BorderSide(color: Colors.orange[600]!, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
            borderSide: BorderSide(color: Colors.red[400]!),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
            borderSide: BorderSide(color: Colors.red[600]!, width: 2),
          ),
          prefixIcon: Icon(fieldIcon),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  String _getEntityLabel() {
    switch (sector) {
      case 'grocery':
        return 'Grocery';
      case 'handyman':
        return 'Handyman';
      default:
        return 'Restaurant';
    }
  }

  String _getFieldLabel(String entityLabel) {
    switch (fieldType) {
      case 'wilaya':
        return 'Wilaya *';
      case 'grocery_type':
        return 'Grocery Type *';
      case 'service_type':
        return 'Service Type *';
      default:
        return fieldType;
    }
  }

  String _getFieldHint(String entityLabel) {
    switch (fieldType) {
      case 'wilaya':
        return 'Select your wilaya';
      case 'grocery_type':
        return 'Select grocery type';
      case 'service_type':
        return 'Select service type';
      default:
        return 'Select $fieldType';
    }
  }

  IconData _getFieldIcon() {
    switch (fieldType) {
      case 'wilaya':
        return Icons.location_city;
      case 'grocery_type':
        return Icons.category;
      case 'service_type':
        return Icons.build;
      default:
        return Icons.arrow_drop_down;
    }
  }
}
