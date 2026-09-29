import 'package:flutter/foundation.dart';

import 'data/issue_repository.dart';
import 'models/issue.dart';
import 'services/ai_service.dart';

class AppController extends ChangeNotifier {
  AppController({required this.repository, required this.aiService});
  final IssueRepository repository;
  final AIService aiService;
  List<CampusIssue> issues = [];
  UserRole? role;
  bool loading = true;
  String? lastMessage;

  Future<void> initialize() async {
    try {
      issues = await repository.loadIssues();
    } catch (_) {
      lastMessage = 'Could not connect. Showing demo campus data.';
      issues = await DemoIssueRepository().loadIssues();
    }
    loading = false;
    notifyListeners();
  }

  void signInDemo(UserRole selectedRole) {
    role = selectedRole;
    notifyListeners();
  }

  void signOut() {
    role = null;
    notifyListeners();
  }

  int get myReports => issues.where((item) => item.reportedBy == 'Maya Patel').length;
  int get resolvedCount => issues.where((item) => item.status == IssueStatus.resolved).length;
  int get openCount => issues.where((item) => item.status != IssueStatus.resolved).length;
  int get criticalCount => issues.where((item) => item.severity == Severity.critical).length;

  CampusIssue? findDuplicate(String category, String building) {
    for (final issue in issues) {
      if (issue.category == category && issue.building.toLowerCase() == building.toLowerCase() && issue.status != IssueStatus.resolved) {
        return issue;
      }
    }
    return null;
  }

  Future<void> submitIssue({required String description, required String category, required Severity severity, required String building, required String room, String? imagePath, double? latitude, double? longitude, bool createSeparate = false}) async {
    final duplicate = createSeparate ? null : findDuplicate(category, building);
    final now = DateTime.now();
    if (duplicate != null) {
      final joined = duplicate.copyWith(
        reportCount: duplicate.reportCount + 1,
        events: [...duplicate.events, IssueEvent('Report joined', now, detail: 'Maya Patel added a matching report')],
      );
      await repository.saveIssue(joined);
      issues = [joined, ...issues.where((item) => item.id != joined.id)];
      lastMessage = 'Your report was added to ${joined.id}. ${joined.reportCount} people have reported this issue.';
    } else {
      final id = 'QF-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      final issue = CampusIssue(
        id: id, title: _titleFrom(description), description: description, category: category,
        severity: severity, status: IssueStatus.submitted, building: building, room: room,
        reportedBy: 'Maya Patel', reportedAt: now, reportCount: 1, localImagePath: imagePath, latitude: latitude, longitude: longitude,
        events: [IssueEvent('Issue submitted', now), IssueEvent('AI classification completed', now, detail: 'Demo AI · review before dispatch')],
      );
      await repository.saveIssue(issue);
      issues = [issue, ...issues];
      lastMessage = 'Issue submitted. The facilities team has been notified.';
    }
    notifyListeners();
  }

  Future<void> advanceIssue(CampusIssue issue, {String? resolutionNote}) async {
    final next = switch ((role, issue.status)) {
      (UserRole.admin, IssueStatus.submitted) => IssueStatus.verified,
      (UserRole.admin, IssueStatus.verified) => IssueStatus.assigned,
      (UserRole.staff, IssueStatus.assigned) => IssueStatus.inProgress,
      (UserRole.staff, IssueStatus.inProgress) when (resolutionNote?.trim().isNotEmpty ?? false) => IssueStatus.resolved,
      (UserRole.student, IssueStatus.resolved) => IssueStatus.submitted,
      _ => null,
    };
    if (next == null) return;
    final now = DateTime.now();
    final updated = issue.copyWith(
      status: next,
      assignedStaffId: next == IssueStatus.assigned ? 'Arun Das' : issue.assignedStaffId,
      resolutionNote: next == IssueStatus.resolved ? resolutionNote : issue.resolutionNote,
      events: [...issue.events, IssueEvent(statusLabel(next), now, detail: next == IssueStatus.resolved ? resolutionNote ?? '' : '')],
    );
    await repository.saveIssue(updated);
    issues = issues.map((item) => item.id == issue.id ? updated : item).toList();
    lastMessage = '${issue.id} moved to ${statusLabel(next)}.';
    notifyListeners();
  }

  String _titleFrom(String description) {
    final clean = description.trim();
    if (clean.isEmpty) return 'Campus issue';
    final firstLine = clean.split(RegExp(r'[.!?\n]')).first.trim();
    return firstLine.length > 36 ? '${firstLine.substring(0, 33)}...' : firstLine;
  }
}