import '../models/issue.dart';

class IssueAnalysis {
  const IssueAnalysis(this.category, this.severity, this.confidence);
  final String category;
  final Severity severity;
  final double confidence;
}

abstract interface class AIService {
  Future<IssueAnalysis> classifyIssue(String description, {String? imagePath});
  Future<String?> transcribeVoice();
}

class DemoAIService implements AIService {
  @override
  Future<IssueAnalysis> classifyIssue(String description, {String? imagePath}) async {
    await Future<void>.delayed(const Duration(milliseconds: 650));
    final text = description.toLowerCase();
    final category = text.contains('leak') || text.contains('water')
        ? 'Plumbing'
        : text.contains('wifi') || text.contains('network')
            ? 'Network'
            : text.contains('light') || text.contains('wire')
                ? 'Electrical'
                : text.contains('dirty') || text.contains('waste')
                    ? 'Cleanliness'
                    : 'Infrastructure';
    final severity = text.contains('sparking') || text.contains('danger')
        ? Severity.critical
        : text.contains('flood') || text.contains('leak')
            ? Severity.high
            : text.contains('broken') || text.contains('not working')
                ? Severity.medium
                : Severity.low;
    return IssueAnalysis(category, severity, imagePath == null ? .91 : .96);
  }

  @override
  Future<String?> transcribeVoice() async =>
      'Water is leaking near the Block B ground floor washroom.';
}