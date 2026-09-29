import os
import tempfile
import unittest
from pathlib import Path

from streamlit.testing.v1 import AppTest

from auth_store import authenticate_user, ensure_demo_accounts, list_accounts, register_account


class AuthStoreTests(unittest.TestCase):
    def setUp(self) -> None:
        self.previous_database = os.environ.get("QUICKFIX_USERS_DB")
        self.temporary_directory = tempfile.TemporaryDirectory()
        os.environ["QUICKFIX_USERS_DB"] = str(Path(self.temporary_directory.name) / "users.sqlite3")
        ensure_demo_accounts()

    def tearDown(self) -> None:
        if self.previous_database is None:
            os.environ.pop("QUICKFIX_USERS_DB", None)
        else:
            os.environ["QUICKFIX_USERS_DB"] = self.previous_database
        self.temporary_directory.cleanup()

    def test_demo_accounts_authenticate(self) -> None:
        account = authenticate_user("ADMIN@CAMPUS.EDU", "quickfix123")
        self.assertIsNotNone(account)
        assert account is not None
        self.assertEqual(account.name, "Campus Admin")
        self.assertEqual(account.role, "Admin")

    def test_role_prefixed_demo_email_text_is_accepted(self) -> None:
        account = authenticate_user("Student   maya@campus.edu", "quickfix123")
        self.assertIsNotNone(account)
        assert account is not None
        self.assertEqual(account.email, "maya@campus.edu")

    def test_registered_account_can_log_in_with_saved_profile(self) -> None:
        account, error = register_account(
            name="Jordan Lee",
            email="jordan.lee@campus.edu",
            password="campuspass88",
            role="Student",
            institution="Northstar College",
            student_id="STU-8801",
            phone="9876500880",
        )
        self.assertIsNone(error)
        self.assertIsNotNone(account)
        self.assertEqual(authenticate_user("jordan.lee@campus.edu", "campuspass88"), account)

    def test_invalid_password_and_duplicate_email_are_rejected(self) -> None:
        self.assertIsNone(authenticate_user("maya@campus.edu", "incorrect-password"))
        account, error = register_account(
            name="Maya Patel",
            email="maya@campus.edu",
            password="anotherpass1",
            role="Student",
            institution="Northstar College",
            student_id="STU-1",
            phone="9876500000",
        )
        self.assertIsNone(account)
        self.assertIsNotNone(error)
        self.assertIsNone(authenticate_user("maya@campus.edu", "anotherpass1"))

    def test_registration_cannot_grant_admin_role(self) -> None:
        account, error = register_account(
            name="Self Admin",
            email="self-admin@campus.edu",
            password="anotherpass1",
            role="Admin",
            institution="Northstar College",
            student_id="",
            phone="9876500000",
        )
        self.assertIsNone(account)
        self.assertIn("Admin access is reserved", error or "")

    def test_registered_maintenance_account_is_assignable(self) -> None:
        account, error = register_account(
            name="Sam Facilities",
            email="sam.facilities@campus.edu",
            password="maintenance88",
            role="Maintenance",
            institution="Northstar College",
            student_id="",
            phone="9876500099",
        )
        self.assertIsNone(error)
        self.assertIsNotNone(account)
        self.assertIn(account, list_accounts("Maintenance"))

    def test_streamlit_registration_logout_and_login(self) -> None:
        app = AppTest.from_file("streamlit_app.py").run(timeout=30)
        next(item for item in app.radio if item.label == "Account").set_value("Register").run(timeout=30)
        values = {
            "Full name": "Casey Example",
            "Email": "casey.example@campus.edu",
            "Password": "campuspass77",
            "College / institution": "Northstar College",
            "Student ID": "STU-7700",
            "Phone number": "9876500770",
        }
        for label, value in values.items():
            next(item for item in app.text_input if item.label == label).set_value(value).run(timeout=30)
        next(button for button in app.button if button.label == "CREATE ACCOUNT").click().run(timeout=30)
        self.assertFalse(app.exception)
        self.assertTrue(app.session_state["is_authenticated"])
        self.assertEqual(app.session_state["current_user"], "Casey Example")

        next(button for button in app.button if button.label == "Log out").click().run(timeout=30)
        next(item for item in app.text_input if item.label == "Email").set_value("casey.example@campus.edu").run(timeout=30)
        next(item for item in app.text_input if item.label == "Password").set_value("campuspass77").run(timeout=30)
        next(button for button in app.button if button.label == "LOG IN").click().run(timeout=30)

        self.assertFalse(app.exception)
        self.assertTrue(app.session_state["is_authenticated"])
        self.assertEqual(app.session_state["current_account"].student_id, "STU-7700")


if __name__ == "__main__":
    unittest.main()