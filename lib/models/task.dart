import 'package:equatable/equatable.dart';

enum TaskStatus {
  pending,
  costReview,
  costProposed,
  costAccepted,
  userCounterProposed,
  deliveryCounterProposed,
  negotiationFinalized,
  assigned,
  completed,
  scheduled,
  expired
}

TaskStatus taskStatusFromString(String value) {
  switch (value) {
    case 'pending':
      return TaskStatus.pending;
    case 'cost_review':
      return TaskStatus.costReview;
    case 'cost_proposed':
      return TaskStatus.costProposed;
    case 'cost_accepted':
      return TaskStatus.costAccepted;
    case 'user_counter_proposed':
      return TaskStatus.userCounterProposed;
    case 'delivery_counter_proposed':
      return TaskStatus.deliveryCounterProposed;
    case 'negotiation_finalized':
      return TaskStatus.negotiationFinalized;
    case 'assigned':
      return TaskStatus.assigned;
    case 'completed':
      return TaskStatus.completed;
    case 'scheduled':
      return TaskStatus.scheduled;
    case 'expired':
      return TaskStatus.expired;
    default:
      return TaskStatus.pending;
  }
}

String taskStatusToString(TaskStatus status) {
  switch (status) {
    case TaskStatus.pending:
      return 'pending';
    case TaskStatus.costReview:
      return 'cost_review';
    case TaskStatus.costProposed:
      return 'cost_proposed';
    case TaskStatus.costAccepted:
      return 'cost_accepted';
    case TaskStatus.userCounterProposed:
      return 'user_counter_proposed';
    case TaskStatus.deliveryCounterProposed:
      return 'delivery_counter_proposed';
    case TaskStatus.negotiationFinalized:
      return 'negotiation_finalized';
    case TaskStatus.assigned:
      return 'assigned';
    case TaskStatus.completed:
      return 'completed';
    case TaskStatus.scheduled:
      return 'scheduled';
    case TaskStatus.expired:
      return 'expired';
  }
}

class Task extends Equatable {
  final String id;
  final String description;
  final String locationName;
  final String? locationPurpose;
  final double latitude;
  final double longitude;
  final TaskStatus status;
  final DateTime? scheduledAt;
  final String userId;
  final String? deliveryManId;
  final String? deliveryManName;
  final String? deliveryManPhone;
  final String? vehicleBrand;
  final String? vehicleModel;
  final String? vehicleColor;
  final int? vehicleYear;
  final String? contactPhone;
  final String? contactPhone2;
  final String? userName;
  final List<Map<String, dynamic>>? additionalLocations;
  final String? imageUrl;
  final String? imagePath;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? assignedAt;
  final DateTime? completedAt;
  final String? assignmentType;
  final String? assignedBy;
  final String? assignmentNotes;
  final double? proposedCost;
  final double? acceptedCost;
  final String? costNotes;
  final DateTime? costProposedAt;
  final DateTime? costAcceptedAt;
  final String? costProposedBy;
  final double? userCounterCost;
  final String? userCounterNotes;
  final DateTime? userCounterAt;
  final List<int>? locationCompletions;
  final Map<String, dynamic>? locationNotes;

  const Task({
    required this.id,
    required this.description,
    required this.locationName,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.scheduledAt,
    required this.userId,
    required this.deliveryManId,
    required this.createdAt,
    required this.updatedAt,
    this.locationPurpose,
    this.deliveryManName,
    this.deliveryManPhone,
    this.vehicleBrand,
    this.vehicleModel,
    this.vehicleColor,
    this.vehicleYear,
    this.contactPhone,
    this.contactPhone2,
    this.userName,
    this.additionalLocations,
    this.imageUrl,
    this.imagePath,
    this.assignedAt,
    this.completedAt,
    this.assignmentType,
    this.assignedBy,
    this.assignmentNotes,
    this.proposedCost,
    this.acceptedCost,
    this.costNotes,
    this.costProposedAt,
    this.costAcceptedAt,
    this.costProposedBy,
    this.userCounterCost,
    this.userCounterNotes,
    this.userCounterAt,
    this.locationCompletions,
    this.locationNotes,
  });

  Task copyWith({
    String? id,
    String? description,
    String? locationName,
    String? locationPurpose,
    double? latitude,
    double? longitude,
    TaskStatus? status,
    DateTime? scheduledAt,
    String? userId,
    String? deliveryManId,
    String? deliveryManName,
    String? deliveryManPhone,
    String? vehicleBrand,
    String? vehicleModel,
    String? vehicleColor,
    int? vehicleYear,
    String? contactPhone,
    String? contactPhone2,
    String? userName,
    List<Map<String, dynamic>>? additionalLocations,
    String? imageUrl,
    String? imagePath,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? assignedAt,
    DateTime? completedAt,
    String? assignmentType,
    String? assignedBy,
    String? assignmentNotes,
    double? proposedCost,
    double? acceptedCost,
    String? costNotes,
    DateTime? costProposedAt,
    DateTime? costAcceptedAt,
    String? costProposedBy,
    double? userCounterCost,
    String? userCounterNotes,
    DateTime? userCounterAt,
    List<int>? locationCompletions,
    Map<String, dynamic>? locationNotes,
  }) {
    return Task(
      id: id ?? this.id,
      description: description ?? this.description,
      locationName: locationName ?? this.locationName,
      locationPurpose: locationPurpose ?? this.locationPurpose,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      status: status ?? this.status,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      userId: userId ?? this.userId,
      deliveryManId: deliveryManId ?? this.deliveryManId,
      deliveryManName: deliveryManName ?? this.deliveryManName,
      deliveryManPhone: deliveryManPhone ?? this.deliveryManPhone,
      vehicleBrand: vehicleBrand ?? this.vehicleBrand,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      vehicleColor: vehicleColor ?? this.vehicleColor,
      vehicleYear: vehicleYear ?? this.vehicleYear,
      contactPhone: contactPhone ?? this.contactPhone,
      contactPhone2: contactPhone2 ?? this.contactPhone2,
      userName: userName ?? this.userName,
      additionalLocations: additionalLocations ?? this.additionalLocations,
      imageUrl: imageUrl ?? this.imageUrl,
      imagePath: imagePath ?? this.imagePath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      assignedAt: assignedAt ?? this.assignedAt,
      completedAt: completedAt ?? this.completedAt,
      assignmentType: assignmentType ?? this.assignmentType,
      assignedBy: assignedBy ?? this.assignedBy,
      assignmentNotes: assignmentNotes ?? this.assignmentNotes,
      proposedCost: proposedCost ?? this.proposedCost,
      acceptedCost: acceptedCost ?? this.acceptedCost,
      costNotes: costNotes ?? this.costNotes,
      costProposedAt: costProposedAt ?? this.costProposedAt,
      costAcceptedAt: costAcceptedAt ?? this.costAcceptedAt,
      costProposedBy: costProposedBy ?? this.costProposedBy,
      userCounterCost: userCounterCost ?? this.userCounterCost,
      userCounterNotes: userCounterNotes ?? this.userCounterNotes,
      userCounterAt: userCounterAt ?? this.userCounterAt,
      locationCompletions: locationCompletions ?? this.locationCompletions,
      locationNotes: locationNotes ?? this.locationNotes,
    );
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] as String,
      description: map['description'] as String? ?? '',
      locationName: map['location_name'] as String? ?? '',
      locationPurpose: map['location_purpose'] as String?,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      status: taskStatusFromString(map['status'] as String),
      scheduledAt: map['scheduled_at'] != null
          ? DateTime.parse(map['scheduled_at'] as String).toLocal()
          : null,
      userId: map['user_id'] as String,
      deliveryManId: map['delivery_man_id'] as String?,
      deliveryManName: map['delivery_man_name'] as String? ??
          map['delivery_man_email']
              as String?, // Use name if available, fallback to email
      deliveryManPhone: map['delivery_man_phone'] as String?,
      vehicleBrand: map['vehicle_brand'] as String?,
      vehicleModel: map['vehicle_model'] as String?,
      vehicleColor: map['vehicle_color'] as String?,
      vehicleYear: map['vehicle_year'] as int?,
      contactPhone: map['contact_phone'] as String?,
      contactPhone2: map['contact_phone_2'] as String?,
      userName: map['user_name'] as String?,
      additionalLocations: map['additional_locations'] != null
          ? List<Map<String, dynamic>>.from(map['additional_locations'] as List)
          : null,
      imageUrl: map['image_url'] as String?,
      imagePath: map['image_path'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(map['updated_at'] as String).toLocal(),
      assignedAt: map['assigned_at'] != null
          ? DateTime.parse(map['assigned_at'] as String).toLocal()
          : null,
      completedAt: map['completed_at'] != null
          ? DateTime.parse(map['completed_at'] as String).toLocal()
          : null,
      assignmentType: map['assignment_type'] as String?,
      assignedBy: map['assigned_by'] as String?,
      assignmentNotes: map['assignment_notes'] as String?,
      proposedCost: map['proposed_cost'] != null
          ? (map['proposed_cost'] as num).toDouble()
          : null,
      acceptedCost: map['accepted_cost'] != null
          ? (map['accepted_cost'] as num).toDouble()
          : null,
      costNotes: map['cost_notes'] as String?,
      costProposedAt: map['cost_proposed_at'] != null
          ? DateTime.parse(map['cost_proposed_at'] as String).toLocal()
          : null,
      costAcceptedAt: map['cost_accepted_at'] != null
          ? DateTime.parse(map['cost_accepted_at'] as String).toLocal()
          : null,
      costProposedBy: map['cost_proposed_by'] as String?,
      userCounterCost: map['user_counter_cost'] != null
          ? (map['user_counter_cost'] as num).toDouble()
          : null,
      userCounterNotes: map['user_counter_notes'] as String?,
      userCounterAt: map['user_counter_at'] != null
          ? DateTime.parse(map['user_counter_at'] as String).toLocal()
          : null,
      locationCompletions: map['location_completions'] != null
          ? List<int>.from(map['location_completions'])
          : null,
      locationNotes: map['location_notes'] != null
          ? Map<String, dynamic>.from(map['location_notes'])
          : null,
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'description': description,
      'location_name': locationName,
      'location_purpose': locationPurpose,
      'latitude': latitude,
      'longitude': longitude,
      'status': taskStatusToString(status),
      'scheduled_at': scheduledAt?.toUtc().toIso8601String(),
      'user_id': userId,
      'delivery_man_id': deliveryManId,
      'contact_phone': contactPhone,
      'contact_phone_2': contactPhone2,
      'additional_locations': additionalLocations,
      'image_url': imageUrl,
      'image_path': imagePath,
      'assignment_type': assignmentType,
      'assigned_by': assignedBy,
      'assignment_notes': assignmentNotes,
      'proposed_cost': proposedCost,
      'accepted_cost': acceptedCost,
      'cost_notes': costNotes,
      'cost_proposed_at': costProposedAt?.toUtc().toIso8601String(),
      'cost_accepted_at': costAcceptedAt?.toUtc().toIso8601String(),
      'cost_proposed_by': costProposedBy,
    };
  }

  /// Get location as a Map for compatibility with existing code
  Map<String, dynamic>? get location => {
        'latitude': latitude,
        'longitude': longitude,
        'address': locationName,
      };

  @override
  List<Object?> get props => [
        id,
        description,
        locationName,
        locationPurpose,
        latitude,
        longitude,
        status,
        scheduledAt,
        userId,
        deliveryManId,
        deliveryManName,
        deliveryManPhone,
        vehicleBrand,
        vehicleModel,
        vehicleColor,
        vehicleYear,
        contactPhone,
        contactPhone2,
        userName,
        additionalLocations,
        imageUrl,
        imagePath,
        createdAt,
        updatedAt,
        assignedAt,
        completedAt,
        assignmentType,
        assignedBy,
        assignmentNotes,
        proposedCost,
        acceptedCost,
        costNotes,
        costProposedAt,
        costAcceptedAt,
        costProposedBy,
        userCounterCost,
        userCounterNotes,
        userCounterAt,
        locationCompletions,
        locationNotes
      ];
}
