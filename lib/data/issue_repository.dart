import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/issue.dart';

abstract interface class IssueRepository {
  Future<List<CampusIssue>> loadIssues();
  Future<void> saveIssue(CampusIssue issue);
}

class DemoIssueRepository implements IssueRepository {
  DemoIssueRepository() : _issues = _seedIssues();
  final List<CampusIssue> _issues;

  @override
  Future<List<CampusIssue>> loadIssues() async => List.unmodifiable(_issues);

  @override
  Future<void> saveIssue(CampusIssue issue) async {
    final index = _issues.indexWhere((item) => item.id == issue.id);
    if (index == -1) {
      _issues.insert(0, issue);
    } else {
      _issues[index] = issue;
    }
  }
}

class FirebaseIssueRepository implements IssueRepository {
  FirebaseIssueRepository(this.firestore, this.storage);
  final FirebaseFirestore firestore;
  final FirebaseStorage storage;

  @override
  Future<List<CampusIssue>> loadIssues() async {
    final snapshot = await firestore.collection('issues').orderBy('reportedAt', descending: true).limit(50).get();
    return snapshot.docs.map((doc) => CampusIssue.fromMap(doc.data())).toList();
  }

  @override
  Future<void> saveIssue(CampusIssue issue) async {
    final issueRef = firestore.collection('issues').doc(issue.id);
    await issueRef.set(issue.toMap(), SetOptions(merge: true));
    if (issue.localImagePath != null && issue.imageUrl == null) {
      final ref = storage.ref('issues/${issue.id}/report.jpg');
      await ref.putFile(File(issue.localImagePath!));
      final saved = issue.copyWith(imageUrl: await ref.getDownloadURL());
      await issueRef.set(saved.toMap(), SetOptions(merge: true));
    }
  }
}

List<CampusIssue> _seedIssues() {
  final now = DateTime.now();
  const examples = [
    ('Water Leakage', 'Pipe leaking beside the washroom entrance', 'Plumbing', Severity.high, IssueStatus.inProgress, 'Academic Block B', 'Ground floor', 'B-WASH-01', 8),
    ('Broken Light', 'Ceiling light is not turning on', 'Electrical', Severity.medium, IssueStatus.resolved, 'Academic Block A', '1st floor', 'A102', 2),
    ('Wi-Fi dead zone', 'No network signal in the study area', 'Network', Severity.low, IssueStatus.submitted, 'Library', '1st floor', 'LIB-01', 3),
    ('Damaged desk', 'Desk leg is loose in the back row', 'Furniture', Severity.medium, IssueStatus.assigned, 'Academic Block A', '2nd floor', 'A201', 2),
    ('Overflowing bin', 'Waste bin is full near the east entrance', 'Cleanliness', Severity.low, IssueStatus.verified, 'Canteen', 'Ground floor', 'CAN-E', 1),
    ('Exposed wiring', 'Loose wire near the lab door', 'Electrical', Severity.critical, IssueStatus.inProgress, 'Academic Block B', '1st floor', 'LAB-B', 4),
    ('Tap pressure low', 'Water pressure is low in the north wing', 'Water Supply', Severity.medium, IssueStatus.submitted, 'Hostel A', '2nd floor', 'HA-204', 1),
    ('Broken door closer', 'Main door slams shut unexpectedly', 'Infrastructure', Severity.high, IssueStatus.assigned, 'Administrative Block', 'Ground floor', 'ADMIN-01', 2),
    ('Washroom cleaning', 'Floor needs attention near the sinks', 'Cleanliness', Severity.medium, IssueStatus.resolved, 'Hostel B', 'Ground floor', 'HB-WC', 5),
    ('Pathway light out', 'Walkway is dark after sunset', 'Electrical', Severity.high, IssueStatus.submitted, 'Sports Complex', 'Ground floor', 'SPORTS-N', 3),
    ('Cracked window latch', 'Window cannot be secured', 'Infrastructure', Severity.medium, IssueStatus.verified, 'Academic Block A', '1st floor', 'A101', 1),
    ('Water cooler offline', 'Cooler has stopped dispensing water', 'Water Supply', Severity.medium, IssueStatus.inProgress, 'Library', 'Ground floor', 'LIB-W', 4),
    ('Loose chair', 'Chair back is unstable', 'Furniture', Severity.low, IssueStatus.resolved, 'Canteen', 'Ground floor', 'CAN-04', 1),
    ('Drain smell', 'Strong odor from the outdoor drain', 'Plumbing', Severity.high, IssueStatus.submitted, 'Hostel A', 'Ground floor', 'HA-DRAIN', 2),
    ('Projector offline', 'Classroom projector will not connect', 'Network', Severity.low, IssueStatus.assigned, 'Academic Block B', '2nd floor', 'B204', 1),
    ('Broken handrail', 'Handrail moves when used on the stairs', 'Infrastructure', Severity.critical, IssueStatus.verified, 'Academic Block A', '1st floor', 'A-STAIR', 3),
    ('Canteen spill', 'Liquid spill by the serving counter', 'Cleanliness', Severity.high, IssueStatus.inProgress, 'Canteen', 'Ground floor', 'CAN-01', 3),
    ('Gate sensor issue', 'Side gate sensor is not responding', 'Security', Severity.high, IssueStatus.submitted, 'Hostel B', 'Ground floor', 'HB-GATE', 1),
  ];
  return List.generate(examples.length, (i) {
    final e = examples[i];
    final status = e.$5;
    final events = [IssueEvent('Issue submitted', now.subtract(Duration(hours: 2 + i)), detail: 'Reported by a campus user')];
    if (status != IssueStatus.submitted) events.add(IssueEvent(statusLabel(status), now.subtract(Duration(minutes: 42 + i))));
    if (status == IssueStatus.resolved) events.add(IssueEvent('Resolved', now.subtract(Duration(minutes: 10 + i))));
    return CampusIssue(
      id: 'QF-${1024 + i}', title: e.$1, description: e.$2, category: e.$3,
      severity: e.$4, status: status, building: e.$6, floor: e.$7, room: e.$8,
      reportedBy: i == 0 ? 'Maya Patel' : 'Campus user', reportedAt: now.subtract(Duration(hours: 2 + i)),
      reportCount: e.$9, assignedStaffId: status == IssueStatus.assigned || status == IssueStatus.inProgress ? 'Arun Das' : null,
      resolutionNote: status == IssueStatus.resolved ? 'Repair completed and checked by the facilities team.' : null,
      events: events,
    );
  });
}