import unittest

from streamlit.testing.v1 import AppTest

from voxguard import (
    CampusIssue,
    advance_issue,
    classify_issue,
    create_issue,
    find_duplicate,
    join_report,
    seed_issues,
    staff_queue_issues,
)


class VoxguardCoreTests(unittest.TestCase):
    def setUp(self) -> None:
        self.issues = seed_issues()

    def test_seed_contains_eighteen_issues_and_bounded_scores(self) -> None:
        self.assertEqual(len(self.issues), 18)
        self.assertTrue(all(0 <= issue.priority_score <= 100 for issue in self.issues))

    def test_demo_classifier_detects_plumbing_and_high_severity(self) -> None:
        self.assertEqual(classify_issue("Water leak near the washroom"), ("Plumbing", "High", 0.93))

    def test_duplicate_join_increments_report_count_without_new_issue(self) -> None:
        issue = find_duplicate(self.issues, "Plumbing", "Academic Block B")
        self.assertIsNotNone(issue)
        assert issue is not None
        original_count = issue.report_count
        join_report(issue, "Maya Patel")
        self.assertEqual(issue.report_count, original_count + 1)
        self.assertEqual(len(self.issues), 18)

    def test_admin_and_staff_have_separate_transitions(self) -> None:
        issue = self.issues[2]
        self.assertTrue(advance_issue(issue, "Admin"))
        self.assertEqual(issue.status, "Verified")
        self.assertTrue(advance_issue(issue, "Admin"))
        self.assertEqual(issue.status, "Assigned")
        self.assertEqual(issue.assigned_staff, "Arun Das")
        self.assertTrue(advance_issue(issue, "Maintenance"))
        self.assertEqual(issue.status, "In progress")

    def test_resolution_requires_note_or_image(self) -> None:
        issue = self.issues[0]
        self.assertFalse(advance_issue(issue, "Maintenance"))
        self.assertEqual(issue.status, "In progress")
        self.assertTrue(advance_issue(issue, "Maintenance", resolution_image_name="repair.jpg", resolution_image_bytes=b"image-data"))
        self.assertEqual(issue.status, "Resolved")
        self.assertEqual(issue.resolution_image_bytes, b"image-data")

    def test_student_cannot_advance_unresolved_issue(self) -> None:
        issue = self.issues[2]
        self.assertFalse(advance_issue(issue, "Student"))
        self.assertEqual(issue.status, "Submitted")

    def test_staff_queue_includes_unassigned_reports_and_own_assignments(self) -> None:
        unassigned = next(issue for issue in self.issues if issue.issue_id == "QF-1026")
        other_staff = next(issue for issue in self.issues if issue.issue_id == "QF-1027")
        other_staff.assigned_staff = "Facilities Team B"

        queue = staff_queue_issues(self.issues, "Arun Das")

        self.assertIn(unassigned, queue)
        self.assertNotIn(other_staff, queue)
        self.assertIn(self.issues[0], queue)

    def test_admin_dashboard_shows_new_low_priority_reports(self) -> None:
        app = AppTest.from_file("streamlit_app.py").run(timeout=20)
        next(item for item in app.text_input if item.label == "Email").set_value("admin@campus.edu").run(timeout=20)
        next(item for item in app.text_input if item.label == "Password").set_value("quickfix123").run(timeout=20)
        next(button for button in app.button if button.label == "LOG IN").click().run(timeout=20)
        issue = create_issue(
            description="Fresh low priority report",
            category="Other",
            severity="Low",
            building="Hostel B",
            floor="Ground floor",
            room="HB-9",
            reported_by="Maya Patel",
        )
        app.session_state["issues"].insert(0, issue)
        app.run(timeout=20)

        self.assertFalse(app.exception)
        self.assertEqual(app.session_state["role"], "Admin")
        self.assertTrue(any(issue.title in item.value for item in app.markdown))

    def test_new_report_has_submission_and_ai_timeline(self) -> None:
        issue: CampusIssue = create_issue(
            description="Tap is leaking in Block B",
            category="Plumbing",
            severity="High",
            building="Academic Block B",
            floor="Ground floor",
            room="Ground floor",
            reported_by="Maya Patel",
        )
        self.assertEqual(issue.status, "Submitted")
        self.assertEqual(len(issue.events), 2)
        self.assertTrue(issue.issue_id.startswith("QF-"))

    def test_new_issue_keeps_live_coordinates(self) -> None:
        issue = create_issue(
            description="Door closer is broken",
            category="Infrastructure",
            severity="Medium",
            building="Academic Block B",
            floor="Ground floor",
            room="B101",
            reported_by="Maya Patel",
            latitude=20.12345,
            longitude=85.54321,
        )
        self.assertEqual(issue.latitude, 20.12345)
        self.assertEqual(issue.longitude, 85.54321)


if __name__ == "__main__":
    unittest.main()