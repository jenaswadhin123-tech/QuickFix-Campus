import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:speech_to_text/speech_to_text.dart' as speech;

import 'app_controller.dart';
import 'core/theme/app_theme.dart';
import 'models/issue.dart';

class QuickFixCampusApp extends StatelessWidget {
  const QuickFixCampusApp({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'QuickFix-Campus',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: AnimatedBuilder(
          animation: controller,
          builder: (context, _) => controller.role == null
              ? RoleGate(controller: controller)
              : AppShell(controller: controller),
        ),
      );
}

class RoleGate extends StatelessWidget {
  const RoleGate({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.all(26),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const BrandMark(),
                    const SizedBox(height: 54),
                    const Text('A better campus\nstarts with a signal.', style: TextStyle(fontSize: 34, height: 1.12, fontWeight: FontWeight.w700, letterSpacing: 0)),
                    const SizedBox(height: 14),
                    const Text('Report. Track. Resolve.', style: TextStyle(color: AppTheme.muted, fontSize: 16)),
                    const SizedBox(height: 38),
                    const Eyebrow('DEMO ACCESS'),
                    const SizedBox(height: 14),
                    RoleOption(role: UserRole.student, subtitle: 'Report issues and follow progress', onTap: () => controller.signInDemo(UserRole.student)),
                    const SizedBox(height: 10),
                    RoleOption(role: UserRole.staff, subtitle: 'Accept tasks and record repairs', onTap: () => controller.signInDemo(UserRole.staff)),
                    const SizedBox(height: 10),
                    RoleOption(role: UserRole.admin, subtitle: 'Prioritize, assign and analyze', onTap: () => controller.signInDemo(UserRole.admin)),
                    const SizedBox(height: 22),
                    const Text('Demo accounts are ready. No network setup required.', style: TextStyle(color: AppTheme.muted, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class RoleOption extends StatelessWidget {
  const RoleOption({super.key, required this.role, required this.subtitle, required this.onTap});
  final UserRole role;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (role) {
      UserRole.student => (Icons.school_rounded, 'Student'),
      UserRole.staff => (Icons.handyman_rounded, 'Maintenance staff'),
      UserRole.admin => (Icons.admin_panel_settings_rounded, 'Admin'),
    };
    return Material(
      color: AppTheme.panel,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Icon(icon, color: AppTheme.cyan),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontWeight: FontWeight.w600)), const SizedBox(height: 3), Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.muted))])),
            const Icon(Icons.arrow_forward_rounded, size: 18, color: AppTheme.muted),
          ]),
        ),
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.controller});
  final AppController controller;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int selected = 0;

  List<(String, IconData)> get destinations => switch (widget.controller.role!) {
        UserRole.student => [('Home', Icons.grid_view_rounded), ('Report', Icons.add_a_photo_rounded), ('My issues', Icons.receipt_long_rounded), ('Campus', Icons.map_rounded), ('Profile', Icons.person_rounded)],
        UserRole.staff => [('Tasks', Icons.task_alt_rounded), ('Campus', Icons.map_rounded), ('Alerts', Icons.notifications_rounded), ('Profile', Icons.person_rounded)],
        UserRole.admin => [('Dashboard', Icons.dashboard_rounded), ('Issues', Icons.list_alt_rounded), ('Campus', Icons.map_rounded), ('Analytics', Icons.query_stats_rounded), ('Settings', Icons.settings_rounded)],
      };

  @override
  Widget build(BuildContext context) {
    final role = widget.controller.role!;
    final pages = switch (role) {
      UserRole.student => <Widget>[
          HomePage(controller: widget.controller, onReport: () => setState(() => selected = 1), onIssues: () => setState(() => selected = 2)),
          ReportPage(controller: widget.controller),
          IssueListPage(controller: widget.controller, mineOnly: true),
          CampusPage(controller: widget.controller),
          ProfilePage(controller: widget.controller),
        ],
      UserRole.staff => <Widget>[
          IssueListPage(controller: widget.controller, staffOnly: true),
          CampusPage(controller: widget.controller),
          AlertPage(controller: widget.controller),
          ProfilePage(controller: widget.controller),
        ],
      UserRole.admin => <Widget>[
          AdminPage(controller: widget.controller),
          IssueListPage(controller: widget.controller),
          CampusPage(controller: widget.controller),
          AnalyticsPage(controller: widget.controller),
          ProfilePage(controller: widget.controller),
        ],
    };
    final safeIndex = selected.clamp(0, pages.length - 1);
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: safeIndex, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: (index) => setState(() => selected = index),
        destinations: destinations.map((item) => NavigationDestination(icon: Icon(item.$2), label: item.$1)).toList(),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.controller, required this.onReport, required this.onIssues});
  final AppController controller;
  final VoidCallback onReport;
  final VoidCallback onIssues;

  @override
  Widget build(BuildContext context) {
    final myIssues = controller.issues.where((issue) => issue.reportedBy == 'Maya Patel').toList();
    return PageScroll(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const BrandMark(compact: true),
      const SizedBox(height: 28),
      const Text('Good morning, Maya', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700)),
      const SizedBox(height: 5),
      const Text('Your campus, in better shape.', style: TextStyle(color: AppTheme.muted)),
      const SizedBox(height: 22),
      const HealthPanel(),
      const SizedBox(height: 18),
      FilledButton.icon(onPressed: onReport, icon: const Icon(Icons.add_rounded), label: const Text('REPORT AN ISSUE'), style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54), backgroundColor: AppTheme.cyan, foregroundColor: AppTheme.ink)),
      const SizedBox(height: 22),
      Row(children: [
        Expanded(child: StatTile(label: 'MY REPORTS', value: '${myIssues.length}', icon: Icons.outgoing_mail, color: AppTheme.cyan)),
        const SizedBox(width: 10), Expanded(child: StatTile(label: 'IN PROGRESS', value: '${myIssues.where((i) => i.status == IssueStatus.inProgress).length}', icon: Icons.sync_rounded, color: const Color(0xFFFFC45C))),
        const SizedBox(width: 10), Expanded(child: StatTile(label: 'RESOLVED', value: '${myIssues.where((i) => i.status == IssueStatus.resolved).length}', icon: Icons.check_circle_outline, color: AppTheme.mint)),
      ]),
      const SizedBox(height: 27),
      SectionHeading(title: 'Recent reports', action: 'View all', onTap: onIssues),
      const SizedBox(height: 10),
      ...myIssues.take(3).map((issue) => IssueTile(issue: issue, onTap: () => showIssueDetail(context, controller, issue))),
      const SizedBox(height: 15),
      const AlertStrip(),
    ]));
  }
}

class ReportPage extends StatefulWidget {
  const ReportPage({super.key, required this.controller});
  final AppController controller;

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final description = TextEditingController();
  final picker = ImagePicker();
  final recognizer = speech.SpeechToText();
  String building = 'Academic Block B';
  String room = 'Ground floor';
  String category = 'Plumbing';
  Severity severity = Severity.high;
  String? imagePath;
  String? locationHint;
  String? error;
  bool createSeparate = false;
  double? latitude;
  double? longitude;
  bool analyzing = false;
  bool listening = false;
  int step = 0;

  @override
  void dispose() {
    description.dispose();
    super.dispose();
  }

  Future<void> pickImage(ImageSource source) async {
    try {
      final image = await picker.pickImage(source: source, imageQuality: 78, maxWidth: 1440);
      if (image == null) return;
      setState(() { imagePath = image.path; analyzing = true; error = null; });
      final result = await widget.controller.aiService.classifyIssue(description.text, imagePath: image.path);
      if (!mounted) return;
      setState(() { category = result.category; severity = result.severity; analyzing = false; });
    } catch (_) {
      setState(() { error = 'Photo access unavailable. You can continue without a photo.'; analyzing = false; });
    }
  }

  Future<void> scanLocation() async {
    final code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.panel,
      builder: (context) => SizedBox(height: MediaQuery.sizeOf(context).height * .72, child: Column(children: [
        const SizedBox(height: 20), const Text('Scan campus location', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14), Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(18), child: MobileScanner(onDetect: (capture) {
          final value = capture.barcodes.firstOrNull?.rawValue;
          if (value != null && context.mounted) Navigator.pop(context, value);
        }))),
        const Padding(padding: EdgeInsets.all(14), child: Text('Point the camera at a campus QR marker', style: TextStyle(color: AppTheme.muted))),
      ])),
    );
    if (code == null) return;
    final decoded = _decodeLocation(code);
    setState(() {
      building = decoded.$1;
      room = decoded.$2;
      latitude = decoded.$3;
      longitude = decoded.$4;
      locationHint = 'Location QR verified · campus coordinates attached';
      error = null;
    });
  }

  Future<void> useCurrentLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) throw Exception('permission');
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        latitude = position.latitude;
        longitude = position.longitude;
        locationHint = 'GPS · ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      });
    } catch (_) {
      setState(() { error = 'Location unavailable. Scan a campus QR or select the suggested location.'; });
    }
  }

  Future<void> toggleVoice() async {
    if (listening) {
      await recognizer.stop();
      setState(() => listening = false);
      return;
    }
    final available = await recognizer.initialize(onStatus: (status) {
      if (status == 'done' && mounted) setState(() => listening = false);
    }, onError: (_) { if (mounted) setState(() { listening = false; error = 'Speech recognition unavailable. Type your description instead.'; }); });
    if (!available) {
      setState(() => error = 'Speech recognition unavailable. Type your description instead.');
      return;
    }
    setState(() => listening = true);
    await recognizer.listen(localeId: 'en_IN', onResult: (result) => setState(() => description.text = result.recognizedWords));
  }

  Future<void> analyzeDescription() async {
    if (description.text.trim().isEmpty) {
      setState(() => error = 'Describe the issue first, then run AI analysis.');
      return;
    }
    setState(() { analyzing = true; error = null; });
    final result = await widget.controller.aiService.classifyIssue(description.text, imagePath: imagePath);
    if (!mounted) return;
    setState(() { category = result.category; severity = result.severity; analyzing = false; });
  }

  Future<void> submit() async {
    if (description.text.trim().isEmpty) { setState(() => error = 'Add a short description before submitting.'); return; }
    final duplicate = widget.controller.findDuplicate(category, building);
    if (duplicate != null) {
      final join = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
        title: const Text('Similar issue found'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('#${duplicate.id} · ${duplicate.title}', style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8), Text('${duplicate.building} · ${duplicate.room}\n${duplicate.reportCount} campus users have reported this.', style: const TextStyle(color: AppTheme.muted)),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Create separate')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add my report'))],
      ));
      if (join == null) return;
      if (!join) createSeparate = true;
    }
    try {
      await widget.controller.submitIssue(description: description.text, category: category, severity: severity, building: building, room: room, imagePath: imagePath, latitude: latitude, longitude: longitude, createSeparate: createSeparate);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.controller.lastMessage ?? 'Issue submitted')));
      setState(() { description.clear(); imagePath = null; step = 0; locationHint = null; latitude = null; longitude = null; createSeparate = false; });
    } catch (_) {
      setState(() => error = 'Unable to submit right now. Your report is still available to retry.');
    }
  }

  @override
  Widget build(BuildContext context) => PageScroll(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Eyebrow('QUICKFIX · NEW REPORT'),
    const SizedBox(height: 7),
    const Text('What needs fixing?', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700)),
    const SizedBox(height: 6),
    const Text('A few details help the right team act faster.', style: TextStyle(color: AppTheme.muted)),
    const SizedBox(height: 21),
    StepRail(step: step, onTap: (next) => setState(() => step = next)),
    const SizedBox(height: 20),
    if (step == 0) _photoStep(),
    if (step == 1) _locationStep(),
    if (step == 2) _detailsStep(),
    if (step == 3) _reviewStep(),
    if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: Color(0xFFFF8894)))),
    const SizedBox(height: 20),
    Row(children: [
      if (step > 0) OutlinedButton(onPressed: () => setState(() => step--), child: const Text('Back')),
      if (step > 0) const SizedBox(width: 10),
      Expanded(child: FilledButton(onPressed: step == 3 ? submit : () => setState(() { error = null; step++; }), style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), backgroundColor: AppTheme.cyan, foregroundColor: AppTheme.ink), child: Text(step == 3 ? 'SUBMIT ISSUE' : 'CONTINUE'))),
    ]),
  ]));

  Widget _photoStep() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    if (imagePath != null) ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.file(File(imagePath!), height: 220, width: double.infinity, fit: BoxFit.cover))
    else Container(height: 185, width: double.infinity, decoration: BoxDecoration(color: AppTheme.panel, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.line)), child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo_outlined, size: 32, color: AppTheme.cyan), SizedBox(height: 10), Text('Add a photo of the issue', style: TextStyle(fontWeight: FontWeight.w600)), SizedBox(height: 4), Text('Clear photos help the team prepare', style: TextStyle(color: AppTheme.muted, fontSize: 12))])),
    const SizedBox(height: 12),
    Row(children: [Expanded(child: OutlinedButton.icon(onPressed: () => pickImage(ImageSource.camera), icon: const Icon(Icons.camera_alt_outlined), label: const Text('Camera'))), const SizedBox(width: 10), Expanded(child: OutlinedButton.icon(onPressed: () => pickImage(ImageSource.gallery), icon: const Icon(Icons.photo_library_outlined), label: const Text('Gallery')))]),
    const SizedBox(height: 17),
    Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: AppTheme.panel, borderRadius: BorderRadius.circular(14)), child: Row(children: [Icon(analyzing ? Icons.radar_rounded : Icons.auto_awesome_rounded, color: AppTheme.cyan), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(analyzing ? 'Analyzing issue...' : 'AI suggestion · confirm below', style: const TextStyle(fontWeight: FontWeight.w600)), const SizedBox(height: 4), Text(analyzing ? 'Checking image and description' : '$category  ·  ${severityLabel(severity)}  ·  93% confidence', style: const TextStyle(fontSize: 12, color: AppTheme.muted))])), if (analyzing) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))])),
    const SizedBox(height: 15),
    DropdownButtonFormField<String>(value: category, decoration: const InputDecoration(labelText: 'Confirm category'), items: IssueCategory.all.map((item) => DropdownMenuItem(value: item.name, child: Text(item.name))).toList(), onChanged: (value) => setState(() => category = value ?? category)),
    const SizedBox(height: 12),
    DropdownButtonFormField<Severity>(value: severity, decoration: const InputDecoration(labelText: 'Confirm severity'), items: Severity.values.map((item) => DropdownMenuItem(value: item, child: Text(severityLabel(item)))).toList(), onChanged: (value) => setState(() => severity = value ?? severity)),
  ]);

  Widget _locationStep() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _actionRow(Icons.qr_code_scanner_rounded, 'Scan location QR', 'Fastest · identifies the room', scanLocation),
    const SizedBox(height: 10), _actionRow(Icons.my_location_rounded, 'Use current location', 'Attach GPS coordinates', useCurrentLocation),
    const SizedBox(height: 18),
    const Eyebrow('SUGGESTED CAMPUS LOCATION'),
    const SizedBox(height: 9),
    DropdownButtonFormField<String>(value: building, decoration: const InputDecoration(labelText: 'Building'), items: const ['Academic Block A', 'Academic Block B', 'Library', 'Canteen', 'Hostel A', 'Hostel B', 'Administrative Block', 'Sports Complex'].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(), onChanged: (value) => setState(() => building = value ?? building)),
    const SizedBox(height: 10), TextFormField(initialValue: room, decoration: const InputDecoration(labelText: 'Room / floor'), onChanged: (value) => room = value),
    if (locationHint != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(locationHint!, style: const TextStyle(color: AppTheme.mint, fontSize: 12))),
  ]);

  Widget _detailsStep() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    TextField(controller: description, minLines: 5, maxLines: 8, decoration: const InputDecoration(hintText: 'Describe what happened and where...', alignLabelWithHint: true)),
    const SizedBox(height: 12),
    OutlinedButton.icon(onPressed: toggleVoice, icon: Icon(listening ? Icons.stop_circle_outlined : Icons.mic_none_rounded, color: listening ? const Color(0xFFFF6478) : AppTheme.cyan), label: Text(listening ? 'Listening · tap to stop' : 'Tap to describe it')),
    const SizedBox(height: 12),
    OutlinedButton.icon(onPressed: analyzing ? null : analyzeDescription, icon: const Icon(Icons.auto_awesome_rounded), label: Text(analyzing ? 'Analyzing...' : 'Analyze description')),
    const SizedBox(height: 12),
    ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.auto_awesome, color: AppTheme.cyan), title: const Text('AI classification is a suggestion'), subtitle: Text('$category · ${severityLabel(severity)}', style: const TextStyle(color: AppTheme.muted)), trailing: const Icon(Icons.edit_outlined, size: 18)),
  ]);

  Widget _reviewStep() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Review report', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
    const SizedBox(height: 14),
    if (imagePath != null) ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(File(imagePath!), width: double.infinity, height: 160, fit: BoxFit.cover)),
    const SizedBox(height: 12),
    ReviewRow(label: 'CATEGORY', value: category, color: IssueCategory.byName(category).color),
    ReviewRow(label: 'SEVERITY', value: severityLabel(severity), color: severityColor(severity)),
    ReviewRow(label: 'LOCATION', value: '$building · $room'),
    ReviewRow(label: 'DESCRIPTION', value: description.text.isEmpty ? 'Add a description in the previous step' : description.text),
    const SizedBox(height: 8),
    const Text('Submitting shares this issue with campus facilities.', style: TextStyle(color: AppTheme.muted, fontSize: 12)),
  ]);

  Widget _actionRow(IconData icon, String title, String subtitle, VoidCallback onTap) => Material(color: AppTheme.panel, borderRadius: BorderRadius.circular(14), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(14), child: Padding(padding: const EdgeInsets.all(15), child: Row(children: [Icon(icon, color: AppTheme.cyan), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w600)), Text(subtitle, style: const TextStyle(color: AppTheme.muted, fontSize: 12))])), const Icon(Icons.chevron_right_rounded, color: AppTheme.muted)]))));

  (String, String, double, double) _decodeLocation(String raw) {
    final value = raw.toUpperCase();
    final building = value.contains('BLOCK-B') || value.contains('BLOCK_B')
        ? 'Academic Block B'
        : value.contains('LIB')
            ? 'Library'
            : value.contains('CANTEEN')
                ? 'Canteen'
                : value.contains('HOSTEL-B')
                    ? 'Hostel B'
                    : value.contains('HOSTEL-A')
                        ? 'Hostel A'
                        : 'Academic Block A';
    final roomMatch = RegExp(r'ROOM[-_ ]?(\w+)|([AB]\d{3})').firstMatch(value);
    final room = roomMatch?.group(1) ?? roomMatch?.group(2) ?? (value.contains('204') ? '204' : 'Ground floor');
    final coordinates = switch (building) {
      'Academic Block B' => (20.2968, 85.8247),
      'Library' => (20.2974, 85.8242),
      'Canteen' => (20.2962, 85.8238),
      'Hostel A' => (20.2958, 85.8252),
      'Hostel B' => (20.2955, 85.8243),
      _ => (20.2972, 85.8236),
    };
    return (building, room, coordinates.$1, coordinates.$2);
  }
}

class IssueListPage extends StatefulWidget {
  const IssueListPage({super.key, required this.controller, this.mineOnly = false, this.staffOnly = false});
  final AppController controller;
  final bool mineOnly;
  final bool staffOnly;

  @override
  State<IssueListPage> createState() => _IssueListPageState();
}

class _IssueListPageState extends State<IssueListPage> {
  String query = '';
  String filter = 'All';

  @override
  Widget build(BuildContext context) {
    final issues = widget.controller.issues.where((issue) {
      if (widget.mineOnly && issue.reportedBy != 'Maya Patel') return false;
      if (widget.staffOnly && (issue.assignedStaffId != 'Arun Das' || issue.status == IssueStatus.resolved)) return false;
      final matchesQuery = '${issue.title} ${issue.building} ${issue.category} ${issue.id}'.toLowerCase().contains(query.toLowerCase());
      final matchesFilter = filter == 'All' || issue.category == filter || severityLabel(issue.severity) == filter.toUpperCase() || statusLabel(issue.status) == filter;
      return matchesQuery && matchesFilter;
    }).toList()..sort((a, b) => b.priorityScore.compareTo(a.priorityScore));
    final heading = widget.mineOnly ? 'My issues' : widget.staffOnly ? 'Assigned tasks' : 'Campus issues';
    return PageScroll(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Eyebrow(widget.staffOnly ? 'MAINTENANCE QUEUE' : 'ISSUE REGISTER'),
      const SizedBox(height: 6), Text(heading, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w700)),
      const SizedBox(height: 16), TextField(onChanged: (value) => setState(() => query = value), decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search title, category, location...')),
      const SizedBox(height: 11),
      SizedBox(height: 38, child: ListView(scrollDirection: Axis.horizontal, children: ['All', 'CRITICAL', 'HIGH', 'In progress', 'Plumbing', 'Electrical', 'Network'].map((value) => Padding(padding: const EdgeInsets.only(right: 7), child: ChoiceChip(label: Text(value), selected: filter == value, onSelected: (_) => setState(() => filter = value))).toList())),
      const SizedBox(height: 14),
      Text('${issues.length} ISSUES  ·  PRIORITY ORDER', style: const TextStyle(color: AppTheme.muted, fontSize: 11, letterSpacing: 1)),
      const SizedBox(height: 8),
      ...issues.map((issue) => IssueTile(issue: issue, onTap: () => showIssueDetail(context, widget.controller, issue), showPriority: true)),
      if (issues.isEmpty) const EmptyState(title: 'No matching issues', subtitle: 'Try another search or filter.'),
    ]));
  }
}

class AdminPage extends StatelessWidget {
  const AdminPage({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) => PageScroll(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Eyebrow('OPERATIONS · LIVE OVERVIEW'),
    const SizedBox(height: 6),
    const Text('Campus control', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700)),
    const SizedBox(height: 18),
    const HealthPanel(),
    const SizedBox(height: 14),
    GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, childAspectRatio: 1.8, crossAxisSpacing: 10, mainAxisSpacing: 10, children: [
      StatTile(label: 'TOTAL ISSUES', value: '${controller.issues.length}', icon: Icons.inbox_rounded, color: AppTheme.cyan),
      StatTile(label: 'OPEN', value: '${controller.openCount}', icon: Icons.pending_actions_rounded, color: const Color(0xFFFFC45C)),
      StatTile(label: 'RESOLVED', value: '${controller.resolvedCount}', icon: Icons.task_alt_rounded, color: AppTheme.mint),
      StatTile(label: 'CRITICAL', value: '${controller.criticalCount}', icon: Icons.warning_amber_rounded, color: const Color(0xFFFF6478)),
    ]),
    const SizedBox(height: 24),
    const SectionHeading(title: 'Needs attention'),
    const SizedBox(height: 8),
    ...controller.issues.where((issue) => issue.severity == Severity.critical || issue.status == IssueStatus.submitted).take(5).map((issue) => IssueTile(issue: issue, showPriority: true, onTap: () => showIssueDetail(context, controller, issue))),
    const SizedBox(height: 8), const AlertStrip(),
  ]));
}

class CampusPage extends StatelessWidget {
  const CampusPage({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) => PageScroll(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Eyebrow('CAMPUS PULSE'), const SizedBox(height: 6), const Text('Live campus map', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700)),
    const SizedBox(height: 6), const Text('Issue activity by campus zone', style: TextStyle(color: AppTheme.muted)), const SizedBox(height: 18),
    Container(height: 255, width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFF111C22), borderRadius: BorderRadius.circular(18), border: Border.all(color: AppTheme.line)), child: Stack(children: [
      Positioned.fill(child: CustomPaint(painter: CampusGridPainter())),
      const Positioned(left: 22, top: 25, child: MapPin(label: 'BLOCK A', color: Color(0xFFFFC45C), count: '4')),
      const Positioned(right: 32, top: 51, child: MapPin(label: 'BLOCK B', color: Color(0xFFFF6478), count: '7')),
      const Positioned(left: 94, bottom: 33, child: MapPin(label: 'LIBRARY', color: AppTheme.cyan, count: '3')),
      const Positioned(right: 25, bottom: 28, child: MapPin(label: 'CANTEEN', color: AppTheme.mint, count: '2')),
      const Positioned(left: 18, bottom: 12, child: Text('QUICKFIX-CAMPUS · ISSUE DENSITY', style: TextStyle(fontSize: 9, color: AppTheme.muted, letterSpacing: 0))),
    ])),
    if (controller.role == UserRole.admin) ...[
      const SizedBox(height: 14),
      OutlinedButton.icon(onPressed: () => showLocationQr(context), icon: const Icon(Icons.qr_code_2_rounded), label: const Text('Generate location QR')),
    ],
    const SizedBox(height: 20), const SectionHeading(title: 'Active locations'), const SizedBox(height: 8),
    ...controller.issues.where((issue) => issue.status != IssueStatus.resolved).take(8).map((issue) => IssueTile(issue: issue, onTap: () => showIssueDetail(context, controller, issue))),
  ]));
}

Future<void> showLocationQr(BuildContext context) => showDialog<void>(
      context: context,
      builder: (context) => const LocationQrDialog(),
    );

class LocationQrDialog extends StatefulWidget {
  const LocationQrDialog({super.key});
  @override
  State<LocationQrDialog> createState() => _LocationQrDialogState();
}

class _LocationQrDialogState extends State<LocationQrDialog> {
  static const locations = <String, String>{
    'Academic Block A · Room A101': 'BLOCK-A-FLOOR-1-ROOM-A101',
    'Academic Block B · Room B204': 'BLOCK-B-FLOOR-2-ROOM-B204',
    'Library · 1st floor': 'LIBRARY-FLOOR-1-ROOM-01',
    'Canteen · East entrance': 'CANTEEN-GROUND-EAST',
    'Hostel A · Room 204': 'HOSTEL-A-FLOOR-2-ROOM-204',
  };
  String selected = locations.values.first;

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Location QR code'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(value: selected, isExpanded: true, items: locations.entries.map((entry) => DropdownMenuItem(value: entry.value, child: Text(entry.key, overflow: TextOverflow.ellipsis))).toList(), onChanged: (value) { if (value != null) setState(() => selected = value); }),
          const SizedBox(height: 18),
          Container(color: Colors.white, padding: const EdgeInsets.all(12), child: QrImageView(data: selected, size: 190)),
          const SizedBox(height: 10), Text(selected, style: const TextStyle(color: AppTheme.muted, fontSize: 11), textAlign: TextAlign.center),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))],
      );
}

class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final issue in controller.issues) { counts[issue.category] = (counts[issue.category] ?? 0) + 1; }
    final entries = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return PageScroll(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Eyebrow('INSIGHTS · THIS TERM'), const SizedBox(height: 6), const Text('Campus analytics', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700)),
      const SizedBox(height: 20), const HealthPanel(), const SizedBox(height: 22),
      const Text('ISSUES BY CATEGORY', style: TextStyle(color: AppTheme.muted, fontSize: 11, letterSpacing: 1)), const SizedBox(height: 12),
      ...entries.map((entry) => Padding(padding: const EdgeInsets.only(bottom: 14), child: Column(children: [
        Row(children: [Icon(IssueCategory.byName(entry.key).icon, size: 17, color: IssueCategory.byName(entry.key).color), const SizedBox(width: 9), Expanded(child: Text(entry.key)), Text('${entry.value}', style: const TextStyle(color: AppTheme.muted))]),
        const SizedBox(height: 7), ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: entry.value / (entries.first.value == 0 ? 1 : entries.first.value), minHeight: 6, backgroundColor: AppTheme.panelRaised, color: IssueCategory.byName(entry.key).color)),
      ]))),
      const SizedBox(height: 8), const AlertStrip(),
    ]));
  }
}

class AlertPage extends StatelessWidget {
  const AlertPage({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) => PageScroll(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Eyebrow('CAMPUS NOTIFICATIONS'), const SizedBox(height: 6), const Text('Updates', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700)), const SizedBox(height: 18),
    const AlertStrip(), const SizedBox(height: 12),
    ...controller.issues.take(6).map((issue) => ListTile(contentPadding: EdgeInsets.zero, leading: CircleAvatar(backgroundColor: AppTheme.panelRaised, child: Icon(issue.status == IssueStatus.resolved ? Icons.check_rounded : Icons.build_rounded, color: AppTheme.cyan, size: 19)), title: Text('${issue.id} · ${statusLabel(issue.status)}', style: const TextStyle(fontSize: 14)), subtitle: Text(issue.title, style: const TextStyle(color: AppTheme.muted)), trailing: const Text('now', style: TextStyle(fontSize: 11, color: AppTheme.muted)))),
  ]));
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final role = controller.role!;
    final name = role == UserRole.student ? 'Maya Patel' : role == UserRole.staff ? 'Arun Das' : 'Campus Admin';
    return PageScroll(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Eyebrow('ACCOUNT'), const SizedBox(height: 6), const Text('Your profile', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700)), const SizedBox(height: 22),
      Container(width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AppTheme.panel, borderRadius: BorderRadius.circular(16)), child: Column(children: [const CircleAvatar(radius: 32, backgroundColor: AppTheme.panelRaised, child: Icon(Icons.person_rounded, color: AppTheme.cyan, size: 30)), const SizedBox(height: 12), Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)), Text('${role.name.toUpperCase()} · QuickFix-Campus', style: const TextStyle(color: AppTheme.muted, fontSize: 12)), const SizedBox(height: 14), const Text('maya.patel@campus.edu', style: TextStyle(color: AppTheme.muted))])),
      const SizedBox(height: 20),
      const Eyebrow('PREFERENCES'),
      const ListTile(leading: Icon(Icons.notifications_none_rounded, color: AppTheme.cyan), title: Text('Notifications'), trailing: Icon(Icons.toggle_on_rounded, color: AppTheme.mint, size: 34)),
      const ListTile(leading: Icon(Icons.translate_rounded, color: AppTheme.cyan), title: Text('Language'), trailing: Text('English', style: TextStyle(color: AppTheme.muted))),
      const ListTile(leading: Icon(Icons.privacy_tip_outlined, color: AppTheme.cyan), title: Text('Privacy and data'), trailing: Icon(Icons.chevron_right_rounded, color: AppTheme.muted)),
      const SizedBox(height: 12), OutlinedButton.icon(onPressed: controller.signOut, icon: const Icon(Icons.logout_rounded), label: const Text('Switch demo role')),
    ]));
  }
}

Future<void> showIssueDetail(BuildContext context, AppController controller, CampusIssue issue) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.panel,
      builder: (context) => IssueDetailSheet(controller: controller, issue: issue),
    );

class IssueDetailSheet extends StatelessWidget {
  const IssueDetailSheet({super.key, required this.controller, required this.issue});
  final AppController controller;
  final CampusIssue issue;

  @override
  Widget build(BuildContext context) => SafeArea(child: Padding(padding: EdgeInsets.fromLTRB(20, 18, 20, MediaQuery.viewInsetsOf(context).bottom + 20), child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: AppTheme.line, borderRadius: BorderRadius.circular(9)))),
    const SizedBox(height: 19), Row(children: [Text('#${issue.id}', style: const TextStyle(color: AppTheme.muted)), const Spacer(), StatusBadge(text: severityLabel(issue.severity), color: severityColor(issue.severity))]),
    const SizedBox(height: 8), Text(issue.title, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w700)),
    const SizedBox(height: 7), Text(issue.description, style: const TextStyle(color: AppTheme.muted)),
    const SizedBox(height: 16), Wrap(spacing: 8, runSpacing: 8, children: [StatusBadge(text: issue.category, color: IssueCategory.byName(issue.category).color), StatusBadge(text: statusLabel(issue.status), color: AppTheme.cyan), StatusBadge(text: 'Priority ${issue.priorityScore}', color: const Color(0xFFFFC45C))]),
    const SizedBox(height: 15), Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: AppTheme.panelRaised, borderRadius: BorderRadius.circular(12)), child: Row(children: [const Icon(Icons.place_outlined, color: AppTheme.cyan), const SizedBox(width: 10), Expanded(child: Text('${issue.building} · ${issue.floor} · ${issue.room}')), Text('${issue.reportCount} reports', style: const TextStyle(color: AppTheme.muted, fontSize: 12))])),
    const SizedBox(height: 20), const Eyebrow('ISSUE TIMELINE'), const SizedBox(height: 10),
    ...issue.events.reversed.map((event) => TimelineEntry(event: event)),
    if (issue.resolutionNote != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text('Resolution note: ${issue.resolutionNote}', style: const TextStyle(color: AppTheme.mint))),
    const SizedBox(height: 14),
    final canAdminAdvance = controller.role == UserRole.admin && (issue.status == IssueStatus.submitted || issue.status == IssueStatus.verified);
    final canStaffAdvance = controller.role == UserRole.staff && (issue.status == IssueStatus.assigned || issue.status == IssueStatus.inProgress);
    if (canAdminAdvance || canStaffAdvance)
      SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () async {
        String? note;
        if (controller.role == UserRole.staff && issue.status == IssueStatus.inProgress) {
          note = await showDialog<String>(context: context, builder: (context) => const ResolutionDialog());
          if (note == null || note.trim().isEmpty) return;
        }
        await controller.advanceIssue(issue, resolutionNote: note);
        if (context.mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(controller.lastMessage ?? 'Issue updated'))); }
      }, icon: Icon(issue.status == IssueStatus.inProgress ? Icons.check_circle_outline : Icons.play_arrow_rounded), label: Text(switch ((controller.role, issue.status)) {
        (UserRole.admin, IssueStatus.submitted) => 'VERIFY ISSUE',
        (UserRole.admin, IssueStatus.verified) => 'ASSIGN TO MAINTENANCE',
        (UserRole.staff, IssueStatus.assigned) => 'ACCEPT · START TASK',
        _ => 'MARK RESOLVED',
      }), style: FilledButton.styleFrom(backgroundColor: AppTheme.cyan, foregroundColor: AppTheme.ink, minimumSize: const Size.fromHeight(48)))),
    if (issue.status == IssueStatus.resolved && controller.role == UserRole.student) Row(children: [Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Issue fixed'))), const SizedBox(width: 9), Expanded(child: OutlinedButton(onPressed: () async { await controller.advanceIssue(issue); if (context.mounted) Navigator.pop(context); }, child: const Text('Still a problem')))]),
  ]))));
}

class ResolutionDialog extends StatefulWidget {
  const ResolutionDialog({super.key});
  @override
  State<ResolutionDialog> createState() => _ResolutionDialogState();
}

class _ResolutionDialogState extends State<ResolutionDialog> {
  final note = TextEditingController();
  @override
  void dispose() { note.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(title: const Text('Resolve issue'), content: TextField(controller: note, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Resolution note', hintText: 'What repair was completed?')), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, note.text.trim()), child: const Text('Confirm'))]);
}

class PageScroll extends StatelessWidget {
  const PageScroll({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) => SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 18, 20, 26), child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: child))));
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: compact ? 35 : 45, height: compact ? 35 : 45, decoration: BoxDecoration(color: AppTheme.cyan.withValues(alpha: .12), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.shield_rounded, color: AppTheme.cyan, size: compact ? 22 : 28)),
    const SizedBox(width: 10), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('QuickFix-Campus', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0)), Text(compact ? 'REPORT · TRACK · RESOLVE' : 'SMART CAMPUS', style: TextStyle(fontSize: compact ? 9 : 11, color: AppTheme.cyan, letterSpacing: 0, fontWeight: FontWeight.w600))]),
  ]);
}

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(fontSize: 10, color: AppTheme.cyan, fontWeight: FontWeight.w700, letterSpacing: 1.4));
}

class HealthPanel extends StatelessWidget {
  const HealthPanel({super.key});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(17), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF172A30), Color(0xFF142129)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF27434A))), child: Row(children: [
    Container(width: 48, height: 48, decoration: BoxDecoration(color: AppTheme.mint.withValues(alpha: .12), shape: BoxShape.circle), child: const Icon(Icons.health_and_safety_outlined, color: AppTheme.mint)),
    const SizedBox(width: 13), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('CAMPUS HEALTH', style: TextStyle(fontSize: 10, color: AppTheme.muted, letterSpacing: 1.2)), SizedBox(height: 4), Text('Looking good today', style: TextStyle(fontWeight: FontWeight.w600))])),
    const Text('92%', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w700, color: AppTheme.mint)),
  ]));
}

class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, required this.icon, required this.color});
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppTheme.panel, borderRadius: BorderRadius.circular(13), border: Border.all(color: AppTheme.line)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(children: [Icon(icon, color: color, size: 16), const Spacer(), Text(value, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700))]), FittedBox(alignment: Alignment.centerLeft, fit: BoxFit.scaleDown, child: Text(label, style: const TextStyle(fontSize: 9, color: AppTheme.muted, letterSpacing: .8)))]));
}

class SectionHeading extends StatelessWidget {
  const SectionHeading({super.key, required this.title, this.action, this.onTap});
  final String title;
  final String? action;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Row(children: [Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))), if (action != null) TextButton(onPressed: onTap, child: Text(action!))]);
}

class IssueTile extends StatelessWidget {
  const IssueTile({super.key, required this.issue, required this.onTap, this.showPriority = false});
  final CampusIssue issue;
  final VoidCallback onTap;
  final bool showPriority;
  @override
  Widget build(BuildContext context) {
    final category = IssueCategory.byName(issue.category);
    return Padding(padding: const EdgeInsets.only(bottom: 9), child: Material(color: AppTheme.panel, borderRadius: BorderRadius.circular(14), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(14), child: Padding(padding: const EdgeInsets.all(13), child: Row(children: [
      Container(width: 40, height: 40, decoration: BoxDecoration(color: category.color.withValues(alpha: .12), borderRadius: BorderRadius.circular(11)), child: Icon(category.icon, color: category.color, size: 20)),
      const SizedBox(width: 11), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Expanded(child: Text(issue.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))), const SizedBox(width: 5), StatusBadge(text: severityLabel(issue.severity), color: severityColor(issue.severity))]), const SizedBox(height: 5), Text('${issue.building} · ${issue.room}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.muted, fontSize: 11)), const SizedBox(height: 6), Row(children: [Text(statusLabel(issue.status), style: TextStyle(color: issue.status == IssueStatus.resolved ? AppTheme.mint : AppTheme.cyan, fontSize: 11)), const SizedBox(width: 9), Icon(Icons.people_outline_rounded, size: 13, color: AppTheme.muted), const SizedBox(width: 3), Text('${issue.reportCount}', style: const TextStyle(color: AppTheme.muted, fontSize: 11)), if (showPriority) ...[const Spacer(), Text('${issue.priorityScore} PTS', style: const TextStyle(color: AppTheme.muted, fontSize: 10))]])])),
    ])))));
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.text, required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4), decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(6)), child: Text(text, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: .2)));
}

class AlertStrip extends StatelessWidget {
  const AlertStrip({super.key});
  @override
  Widget build(BuildContext context) => Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFF28251D), borderRadius: BorderRadius.circular(13), border: Border.all(color: const Color(0xFF504332))), child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.campaign_outlined, size: 19, color: Color(0xFFFFC45C)), SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('CAMPUS ALERT', style: TextStyle(fontSize: 9, color: Color(0xFFFFC45C), letterSpacing: 1, fontWeight: FontWeight.w700)), SizedBox(height: 5), Text('Water supply maintenance at Block B, 10:00 AM–12:00 PM.', style: TextStyle(fontSize: 12, height: 1.35))]))]));
}

class StepRail extends StatelessWidget {
  const StepRail({super.key, required this.step, required this.onTap});
  final int step;
  final ValueChanged<int> onTap;
  @override
  Widget build(BuildContext context) {
    const labels = ['Photo & AI', 'Location', 'Details', 'Review'];
    return Row(children: List.generate(labels.length, (index) => Expanded(child: InkWell(onTap: () { if (index <= step) onTap(index); }, child: Padding(padding: const EdgeInsets.only(right: 6), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Expanded(child: Container(height: 3, decoration: BoxDecoration(color: index <= step ? AppTheme.cyan : AppTheme.line, borderRadius: BorderRadius.circular(5)))), if (index < labels.length - 1) const SizedBox(width: 5)]), const SizedBox(height: 6), Text(labels[index], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: index == step ? AppTheme.cyan : AppTheme.muted, fontSize: 9))])))));
  }
}

class ReviewRow extends StatelessWidget {
  const ReviewRow({super.key, required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 9), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 92, child: Text(label, style: const TextStyle(color: AppTheme.muted, fontSize: 10, letterSpacing: .8))), Expanded(child: Text(value, style: TextStyle(color: color ?? Colors.white, fontSize: 13, fontWeight: color == null ? FontWeight.w500 : FontWeight.w700)))]));
}

class TimelineEntry extends StatelessWidget {
  const TimelineEntry({super.key, required this.event});
  final IssueEvent event;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 13), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 9, height: 9, margin: const EdgeInsets.only(top: 4), decoration: const BoxDecoration(color: AppTheme.cyan, shape: BoxShape.circle)), const SizedBox(width: 11), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(event.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)), if (event.detail.isNotEmpty) Text(event.detail, style: const TextStyle(color: AppTheme.muted, fontSize: 11)), Text('${event.at.hour.toString().padLeft(2, '0')}:${event.at.minute.toString().padLeft(2, '0')}', style: const TextStyle(color: AppTheme.muted, fontSize: 10))]))]));
}

class MapPin extends StatelessWidget {
  const MapPin({super.key, required this.label, required this.color, required this.count});
  final String label;
  final Color color;
  final String count;
  @override
  Widget build(BuildContext context) => Column(children: [Container(width: 34, height: 34, decoration: BoxDecoration(color: color.withValues(alpha: .18), shape: BoxShape.circle, border: Border.all(color: color)), child: Center(child: Text(count, style: TextStyle(color: color, fontWeight: FontWeight.w700)))), const SizedBox(height: 4), Text(label, style: const TextStyle(fontSize: 8, color: Colors.white, letterSpacing: .7))]);
}

class CampusGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final pathPaint = Paint()..color = const Color(0xFF27383A)..strokeWidth = 13..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    final route = Path()..moveTo(size.width * .12, size.height * .55)..cubicTo(size.width * .3, size.height * .5, size.width * .28, size.height * .25, size.width * .51, size.height * .34)..cubicTo(size.width * .72, size.height * .43, size.width * .74, size.height * .68, size.width * .92, size.height * .55);
    canvas.drawPath(route, pathPaint);
    final plotPaint = Paint()..color = const Color(0xFF1C302B)..style = PaintingStyle.fill;
    for (final rect in [Rect.fromLTWH(size.width * .38, size.height * .62, 52, 34), Rect.fromLTWH(size.width * .69, size.height * .18, 42, 36), Rect.fromLTWH(size.width * .12, size.height * .18, 40, 30)]) {
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(7)), plotPaint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, required this.subtitle});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 50), child: Center(child: Column(children: [const Icon(Icons.search_off_rounded, color: AppTheme.muted), const SizedBox(height: 10), Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 4), Text(subtitle, style: const TextStyle(color: AppTheme.muted, fontSize: 12))])));
}