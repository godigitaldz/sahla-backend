class RestaurantFormDraft {
  final String id;
  final Map<String, dynamic> formData;
  final int currentStep;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double completionPercentage;
  final bool isAutoSaved;

  const RestaurantFormDraft({
    required this.id,
    required this.formData,
    required this.currentStep,
    required this.createdAt,
    required this.updatedAt,
    required this.completionPercentage,
    this.isAutoSaved = false,
  });

  /// Create a new draft
  factory RestaurantFormDraft.create({
    required Map<String, dynamic> formData,
    required int currentStep,
    bool isAutoSaved = false,
  }) {
    final now = DateTime.now();
    return RestaurantFormDraft(
      id: 'draft_${now.millisecondsSinceEpoch}',
      formData: formData,
      currentStep: currentStep,
      createdAt: now,
      updatedAt: now,
      completionPercentage: _calculateCompletionPercentage(formData),
      isAutoSaved: isAutoSaved,
    );
  }

  /// Create from JSON
  factory RestaurantFormDraft.fromJson(Map<String, dynamic> json) {
    return RestaurantFormDraft(
      id: json['id'] as String,
      formData: Map<String, dynamic>.from(json['formData'] as Map),
      currentStep: json['currentStep'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      completionPercentage: (json['completionPercentage'] as num).toDouble(),
      isAutoSaved: json['isAutoSaved'] as bool? ?? false,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'formData': formData,
      'currentStep': currentStep,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'completionPercentage': completionPercentage,
      'isAutoSaved': isAutoSaved,
    };
  }

  /// Update draft with new data
  RestaurantFormDraft update({
    Map<String, dynamic>? formData,
    int? currentStep,
  }) {
    final now = DateTime.now();
    final newFormData = formData ?? this.formData;

    return RestaurantFormDraft(
      id: id,
      formData: newFormData,
      currentStep: currentStep ?? this.currentStep,
      createdAt: createdAt,
      updatedAt: now,
      completionPercentage: _calculateCompletionPercentage(newFormData),
      isAutoSaved: isAutoSaved,
    );
  }

  /// Check if draft is recent (within last 24 hours)
  bool get isRecent {
    final now = DateTime.now();
    final difference = now.difference(updatedAt);
    return difference.inHours < 24;
  }

  /// Check if draft is expired (older than 7 days)
  bool get isExpired {
    final now = DateTime.now();
    final difference = now.difference(updatedAt);
    return difference.inDays > 7;
  }

  /// Get formatted creation date
  String get formattedCreatedDate {
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }

  /// Get formatted creation time
  String get formattedCreatedTime {
    return '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
  }

  /// Get formatted updated date
  String get formattedUpdatedDate {
    return '${updatedAt.day}/${updatedAt.month}/${updatedAt.year}';
  }

  /// Get formatted updated time
  String get formattedUpdatedTime {
    return '${updatedAt.hour.toString().padLeft(2, '0')}:${updatedAt.minute.toString().padLeft(2, '0')}';
  }

  /// Get restaurant name from form data
  String get restaurantName {
    return formData['restaurantName']?.toString() ?? 'Untitled Restaurant';
  }

  /// Get sector from form data
  String get sector {
    return formData['sector']?.toString() ?? 'restaurant';
  }

  /// Get entity label based on sector
  String get entityLabel {
    switch (sector) {
      case 'grocery':
        return 'Grocery';
      case 'handyman':
        return 'Handyman';
      default:
        return 'Restaurant';
    }
  }

  /// Check if form is ready for submission
  bool get isReadyForSubmission {
    final requiredFields = [
      'restaurantName',
      'address',
      'phone',
      'wilaya',
      'workingHours',
      'latitude',
      'longitude',
    ];

    for (final field in requiredFields) {
      if (formData[field] == null || formData[field].toString().isEmpty) {
        return false;
      }
    }

    return true;
  }

  /// Get missing required fields
  List<String> get missingRequiredFields {
    final requiredFields = {
      'restaurantName': 'Restaurant Name',
      'address': 'Address',
      'phone': 'Phone Number',
      'wilaya': 'Wilaya',
      'workingHours': 'Working Hours',
      'latitude': 'Location',
      'longitude': 'Location',
    };

    final missing = <String>[];

    for (final entry in requiredFields.entries) {
      if (formData[entry.key] == null ||
          formData[entry.key].toString().isEmpty) {
        missing.add(entry.value);
      }
    }

    return missing;
  }

  /// Calculate completion percentage
  static double _calculateCompletionPercentage(Map<String, dynamic> formData) {
    int completedFields = 0;
    int totalFields = 0;

    // Required fields (weighted more heavily)
    final requiredFields = [
      'restaurantName',
      'address',
      'phone',
      'wilaya',
      'workingHours',
      'latitude',
      'longitude',
    ];

    totalFields +=
        requiredFields.length * 2; // Double weight for required fields

    for (final field in requiredFields) {
      if (formData[field] != null && formData[field].toString().isNotEmpty) {
        completedFields += 2; // Double points for required fields
      }
    }

    // Optional fields
    final optionalFields = [
      'description',
      'logoUrl',
      'facebook',
      'instagram',
      'tiktok',
    ];

    totalFields += optionalFields.length;

    for (final field in optionalFields) {
      if (formData[field] != null && formData[field].toString().isNotEmpty) {
        completedFields++;
      }
    }

    return totalFields > 0 ? (completedFields / totalFields) * 100 : 0;
  }

  @override
  String toString() {
    return 'RestaurantFormDraft(id: $id, restaurantName: $restaurantName, completion: ${completionPercentage.toStringAsFixed(1)}%, step: $currentStep)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is RestaurantFormDraft &&
        other.id == id &&
        other.currentStep == currentStep &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        currentStep.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode;
  }
}
