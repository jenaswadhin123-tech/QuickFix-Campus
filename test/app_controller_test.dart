import 'package:flutter_test/flutter_test.dart';
import 'package:quickfix_campus/app_controller.dart';
import 'package:quickfix_campus/data/issue_repository.dart';
import 'package:quickfix_campus/models/issue.dart';
import 'package:quickfix_campus/services/ai_service.dart';

void main() {
  late AppController controller;

  setUp(() async {
    controller = AppController(repository: DemoIssueRepository(), aiService: DemoAIService());
    await controller.initialize();
  });

  test('demo seed provides a campus-wide issue set', () {
    expect(controller.issues.length, 18);
    expect(controller.issues.any((issue) => issue.severity == Severity.critical), isTrue);
    expect(controller.issues.every((issue) => issue.priorityScore >= 0 && issue.priorityScore <= 100), isTrue);
  });

  test('demo AI suggests plumbing and high severity for a water leak', () async {
    final result = await controller.aiService.classifyIssue('Water leak near the washroom');
    expect(result.category, 'Plumbing');
    expect(result.severity, Severity.high);
    expect(result.confidence, greaterThan(0));
  });

  test('matching reports join the existing issue without creating another', () async {
    final initialCount = controller.issues.length;
    final original = controller.findDuplicate('Plumbing', 'Academic Block B')!;

    await controller.submitIssue(
      description: 'Water is leaking in Block B',
      category: 'Plumbing',
      severity: Severity.high,
      building: 'Academic Block B',
      room: 'Ground floor',
    );

    expect(controller.issues, hasLength(initialCount));
    expect(controller.issues.firstWhere((issue) => issue.id == original.id).reportCount, original.reportCount + 1);
  });

  test('user can deliberately create a separate report', () async {
    final initialCount = controller.issues.length;

    await controller.submitIssue(
      description: 'A separate leak in the same block',
      category: 'Plumbing',
      severity: Severity.medium,
      building: 'Academic Block B',
      room: 'Room B101',
      createSeparate: true,
    );

    expect(controller.issues, hasLength(initialCount + 1));
    expect(controller.issues.first.room, 'Room B101');
  });

  test('issue can move through assignment and resolution', () async {
    controller.signInDemo(UserRole.staff);
    final issue = controller.issues.firstWhere((item) => item.id == 'QF-1027');
    expect(issue.status, IssueStatus.assigned);

    await controller.advanceIssue(issue);
    final inProgress = controller.issues.firstWhere((item) => item.id == issue.id);
    expect(inProgress.status, IssueStatus.inProgress);

    await controller.advanceIssue(inProgress, resolutionNote: 'Repaired and checked.');
    final resolved = controller.issues.firstWhere((item) => item.id == issue.id);
    expect(resolved.status, IssueStatus.resolved);
    expect(resolved.resolutionNote, 'Repaired and checked.');
  });

  test('students cannot advance an issue before it is resolved', () async {
    controller.signInDemo(UserRole.student);
    final issue = controller.issues.firstWhere((item) => item.id == 'QF-1026');

    await controller.advanceIssue(issue);

    expect(controller.issues.firstWhere((item) => item.id == issue.id).status, IssueStatus.submitted);
  });

  test('admins verify and assign in separate lifecycle steps', () async {
    controller.signInDemo(UserRole.admin);
    final issue = controller.issues.firstWhere((item) => item.id == 'QF-1026');

    await controller.advanceIssue(issue);
    final verified = controller.issues.firstWhere((item) => item.id == issue.id);
    expect(verified.status, IssueStatus.verified);

    await controller.advanceIssue(verified);
    final assigned = controller.issues.firstWhere((item) => item.id == issue.id);
    expect(assigned.status, IssueStatus.assigned);
    expect(assigned.assignedStaffId, 'Arun Das');
  });
}