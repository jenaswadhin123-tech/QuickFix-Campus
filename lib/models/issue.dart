import 'package:flutter/material.dart';

enum UserRole { student, staff, admin }

enum IssueStatus { submitted, verified, assigned, inProgress, resolved }

enum Severity { low, medium, high, critical }

class IssueCategory {
  const IssueCategory(this.name, this.icon, this.color, this.description);

  final String name;
  final IconData icon;
  final Color color;
  final String description;

  static const all = <IssueCategory>[
    IssueCategory('Electrical', Icons.bolt_rounded, Color(0xFFFFC45C), 'Lights, wiring and power'),
    IssueCategory('Plumbing', Icons.water_drop_rounded, Color(0xFF53C8E8), 'Pipes, taps and drainage'),
    IssueCategory('Cleanliness', Icons.cleaning_services_rounded, Color(0xFF8ED7A8), 'Waste and cleaning'),
    IssueCategory('Infrastructure', Icons.domain_rounded, Color(0xFF9AA8FF), 'Buildings and walkways'),
    IssueCategory('Furniture', Icons.chair_rounded, Color(0xFFE6A5FF), 'Desks, chairs and fixtures'),
    IssueCategory('Network', Icons.wifi_rounded, Color(0xFF70D9C5), 'Wi-Fi and connectivity'),
    IssueCategory('Water Supply', Icons.water_rounded, Color(0xFF64AFFF), 'Campus water supply'),
    IssueCategory('Security', Icons.shield_rounded, Color(0xFFFF8888), 'Safety and access'),
    IssueCategory('Environment', Icons.park_rounded, Color(0xFF99CF75), 'Outdoor and environmental'),
    IssueCategory('Other', Icons.more_horiz_rounded, Color(0xFFB0BACB), 'Other campus concerns'),
  ];

  static IssueCategory byName(String name) =>
      all.firstWhere((item) => item.name == name, orElse: () => all.last);
}

class IssueEvent {
  const IssueEvent(this.label, this.at, {this.detail = ''});
  final String label;
  final DateTime at;
  final String detail;
}

class CampusIssue {
  const CampusIssue({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.severity,
    required this.status,
    required this.building,
    required this.room,
    required this.reportedBy,
    required this.reportedAt,
    required this.reportCount,
    this.floor = 'Ground floor',
    this.assignedStaffId,
    this.imageUrl,
    this.localImagePath,
    this.latitude,
    this.longitude,
    this.resolutionNote,
    this.aiConfidence = .93,
    this.events = const [],
  });

  final String id;
  final String title;
  final String description;
  final String category;
  final Severity severity;
  final IssueStatus status;
  final String building;
  final String floor;
  final String room;
  final String reportedBy;
  final DateTime reportedAt;
  final int reportCount;
  final String? assignedStaffId;
  final String? imageUrl;
  final String? localImagePath;
  final double? latitude;
  final double? longitude;
  final String? resolutionNote;
  final double aiConfidence;
  final List<IssueEvent> events;

  int get priorityScore {
    final severityPoints = switch (severity) {
      Severity.critical => 48,
      Severity.high => 36,
      Severity.medium => 22,
      Severity.low => 10,
    };
    final duplicatePoints = ((reportCount - 1) * 5).clamp(0, 25).toInt();
    final locationPoints = building.toLowerCase().contains('library') ? 15 : 10;
    final agePoints = DateTime.now().difference(reportedAt).inHours.clamp(0, 12).toInt();
    return (severityPoints + duplicatePoints + locationPoints + agePoints).clamp(0, 100).toInt();
  }

  CampusIssue copyWith({
    IssueStatus? status,
    String? assignedStaffId,
    String? resolutionNote,
    int? reportCount,
    List<IssueEvent>? events,
    String? imageUrl,
    double? latitude,
    double? longitude,
  }) => CampusIssue(
        id: id,
        title: title,
        description: description,
        category: category,
        severity: severity,
        status: status ?? this.status,
        building: building,
        floor: floor,
        room: room,
        reportedBy: reportedBy,
        reportedAt: reportedAt,
        reportCount: reportCount ?? this.reportCount,
        assignedStaffId: assignedStaffId ?? this.assignedStaffId,
        imageUrl: imageUrl ?? this.imageUrl,
        localImagePath: localImagePath,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        resolutionNote: resolutionNote ?? this.resolutionNote,
        aiConfidence: aiConfidence,
        events: events ?? this.events,
      );

  Map<String, dynamic> toMap() => {
        'issueId': id,
        'title': title,
        'description': description,
        'category': category,
        'severity': severity.name,
        'priorityScore': priorityScore,
        'status': status.name,
        'reportedBy': reportedBy,
        'reportedAt': reportedAt,
        'updatedAt': DateTime.now(),
        'locationId': '${building.toUpperCase().replaceAll(' ', '-')}-${room.toUpperCase().replaceAll(' ', '-')}',
        'building': building,
        'floor': floor,
        'room': room,
        'latitude': latitude,
        'longitude': longitude,
        'imageUrls': imageUrl == null ? <String>[] : <String>[imageUrl!],
        'aiCategory': category,
        'aiConfidence': aiConfidence,
        'duplicateGroupId': reportCount > 1 ? id : null,
        'reportCount': reportCount,
        'assignedStaffId': assignedStaffId,
        'resolutionNote': resolutionNote,
        'resolvedAt': status == IssueStatus.resolved ? DateTime.now() : null,
        'timeline': events.map((event) => {
              'label': event.label,
              'at': event.at,
              'detail': event.detail,
            }).toList(),
      };

  static CampusIssue fromMap(Map<String, dynamic> map) {
    DateTime date(dynamic value) {
      if (value is DateTime) return value;
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      try {
        return (value as dynamic).toDate() as DateTime;
      } catch (_) {
        return DateTime.now();
      }
    }
    return CampusIssue(
      id: map['issueId'] as String? ?? '',
      title: map['title'] as String? ?? 'Campus issue',
      description: map['description'] as String? ?? '',
      category: map['category'] as String? ?? 'Other',
      severity: Severity.values.firstWhere((item) => item.name == map['severity'], orElse: () => Severity.medium),
      status: IssueStatus.values.firstWhere((item) => item.name == map['status'], orElse: () => IssueStatus.submitted),
      building: map['building'] as String? ?? 'Campus',
      floor: map['floor'] as String? ?? 'Ground floor',
      room: map['room'] as String? ?? 'Unspecified',
      reportedBy: map['reportedBy'] as String? ?? 'Campus user',
      reportedAt: date(map['reportedAt']),
      reportCount: map['reportCount'] as int? ?? 1,
      assignedStaffId: map['assignedStaffId'] as String?,
      imageUrl: (map['imageUrls'] as List<dynamic>?)?.firstOrNull as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      resolutionNote: map['resolutionNote'] as String?,
      aiConfidence: (map['aiConfidence'] as num?)?.toDouble() ?? .80,
    );
  }
}

String statusLabel(IssueStatus status) => switch (status) {
      IssueStatus.submitted => 'Submitted',
      IssueStatus.verified => 'Verified',
      IssueStatus.assigned => 'Assigned',
      IssueStatus.inProgress => 'In progress',
      IssueStatus.resolved => 'Resolved',
    };

String severityLabel(Severity severity) => severity.name.toUpperCase();

Color severityColor(Severity severity) => switch (severity) {
      Severity.low => const Color(0xFF6EC99A),
      Severity.medium => const Color(0xFFFFC45C),
      Severity.high => const Color(0xFFFF965C),
      Severity.critical => const Color(0xFFFF6478),
    };