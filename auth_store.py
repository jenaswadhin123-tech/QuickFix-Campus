"""Local account storage for the QuickFix-Campus demo host."""

from __future__ import annotations

import hashlib
import hmac
import os
import re
import secrets
import sqlite3
from contextlib import contextmanager
from dataclasses import dataclass
from pathlib import Path
from collections.abc import Iterator

PASSWORD_ROUNDS = 240_000
DEMO_PASSWORD = "quickfix123"
DEMO_ACCOUNTS = (
    ("Maya Patel", "maya@campus.edu", "Student", "Northstar College", "STU-2048", "9876500001"),
    ("Arun Das", "arun@campus.edu", "Maintenance", "Northstar College", "STAFF-1001", "9876500002"),
    ("Campus Admin", "admin@campus.edu", "Admin", "Northstar College", "ADMIN-01", "9876500003"),
)
EMAIL_PATTERN = re.compile(r"[^\s@]+@[^\s@]+\.[^\s@]+")


@dataclass(frozen=True)
class UserAccount:
    name: str
    email: str
    role: str
    institution: str
    student_id: str
    phone: str


def _database_path() -> Path:
    configured_path = os.environ.get("QUICKFIX_USERS_DB")
    return Path(configured_path) if configured_path else Path(__file__).with_name(".quickfix-users.sqlite3")


@contextmanager
def _connect() -> Iterator[sqlite3.Connection]:
    database_path = _database_path()
    database_path.parent.mkdir(parents=True, exist_ok=True)
    connection = sqlite3.connect(database_path, timeout=10)
    connection.row_factory = sqlite3.Row
    try:
        with connection:
            yield connection
    finally:
        connection.close()


def _password_digest(password: str, salt: bytes) -> bytes:
    return hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, PASSWORD_ROUNDS)


def _normalize_email(value: str) -> str:
    matches = EMAIL_PATTERN.findall(value)
    return matches[0].casefold() if matches else value.strip().casefold()


def _insert_account(
    connection: sqlite3.Connection,
    *,
    name: str,
    email: str,
    password: str,
    role: str,
    institution: str,
    student_id: str,
    phone: str,
) -> bool:
    salt = secrets.token_bytes(16)
    result = connection.execute(
        """INSERT OR IGNORE INTO users
        (name, email, role, institution, student_id, phone, password_salt, password_hash)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
        (
            name.strip(),
            _normalize_email(email),
            role,
            institution.strip(),
            student_id.strip(),
            phone.strip(),
            salt,
            _password_digest(password, salt),
        ),
    )
    return result.rowcount == 1


def ensure_demo_accounts() -> None:
    with _connect() as connection:
        connection.execute(
            """CREATE TABLE IF NOT EXISTS users (
                email TEXT PRIMARY KEY COLLATE NOCASE,
                name TEXT NOT NULL,
                role TEXT NOT NULL CHECK(role IN ('Student', 'Maintenance', 'Admin')),
                institution TEXT NOT NULL,
                student_id TEXT NOT NULL,
                phone TEXT NOT NULL,
                password_salt BLOB NOT NULL,
                password_hash BLOB NOT NULL,
                created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
            )"""
        )
        for name, email, role, institution, student_id, phone in DEMO_ACCOUNTS:
            exists = connection.execute("SELECT 1 FROM users WHERE email = ?", (email,)).fetchone()
            if exists is None:
                _insert_account(
                    connection,
                    name=name,
                    email=email,
                    password=DEMO_PASSWORD,
                    role=role,
                    institution=institution,
                    student_id=student_id,
                    phone=phone,
                )


def register_account(
    *,
    name: str,
    email: str,
    password: str,
    role: str,
    institution: str,
    student_id: str,
    phone: str,
) -> tuple[UserAccount | None, str | None]:
    normalized_email = _normalize_email(email)
    if not name.strip() or not institution.strip() or not phone.strip():
        return None, "Complete your name, institution, and phone number."
    if not EMAIL_PATTERN.fullmatch(normalized_email):
        return None, "Enter a valid email address."
    if role not in ("Student", "Maintenance"):
        return None, "Choose Student or Maintenance. Admin access is reserved for the demo administrator."
    if role == "Student" and not student_id.strip():
        return None, "Student ID is required for student accounts."
    if len(password) < 8:
        return None, "Password must be at least 8 characters."

    ensure_demo_accounts()
    with _connect() as connection:
        try:
            inserted = _insert_account(
                connection,
                name=name,
                email=normalized_email,
                password=password,
                role=role,
                institution=institution,
                student_id=student_id,
                phone=phone,
            )
        except sqlite3.IntegrityError:
            return None, "An account with this email already exists."
        if not inserted:
            return None, "An account with this email already exists."
        row = connection.execute("SELECT * FROM users WHERE email = ?", (normalized_email,)).fetchone()
        if row is None:
            return None, "An account with this email already exists."
        return _account_from_row(row), None


def authenticate_user(email: str, password: str) -> UserAccount | None:
    ensure_demo_accounts()
    with _connect() as connection:
        row = connection.execute("SELECT * FROM users WHERE email = ?", (_normalize_email(email),)).fetchone()
    if row is None:
        return None
    submitted_digest = _password_digest(password, row["password_salt"])
    if not hmac.compare_digest(submitted_digest, row["password_hash"]):
        return None
    return _account_from_row(row)


def list_accounts(role: str) -> list[UserAccount]:
    ensure_demo_accounts()
    with _connect() as connection:
        rows = connection.execute(
            "SELECT * FROM users WHERE role = ? ORDER BY name COLLATE NOCASE",
            (role,),
        ).fetchall()
    return [_account_from_row(row) for row in rows]


def _account_from_row(row: sqlite3.Row) -> UserAccount:
    return UserAccount(
        name=row["name"],
        email=row["email"],
        role=row["role"],
        institution=row["institution"],
        student_id=row["student_id"],
        phone=row["phone"],
    )