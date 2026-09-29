import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'app_controller.dart';
import 'data/issue_repository.dart';
import 'services/ai_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const useFirebase = bool.fromEnvironment('VOXGUARD_FIREBASE');
  IssueRepository repository = DemoIssueRepository();
  if (useFirebase) {
    try {
      await Firebase.initializeApp();
      repository = FirebaseIssueRepository(FirebaseFirestore.instance, FirebaseStorage.instance);
    } catch (error) {
      debugPrint('Firebase unavailable; continuing in demo mode: $error');
    }
  }
  final controller = AppController(repository: repository, aiService: DemoAIService());
  await controller.initialize();
  runApp(QuickFixCampusApp(controller: controller));
}