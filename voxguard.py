"""Demo-domain logic for the QuickFix-Campus Streamlit application."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timedelta
from typing import Literal
from uuid import uuid4

Role = Literal["Student", "Maintenance", "Admin"]
Status = Literal["Submitted", "Verified", "Assigned", "In progress", "Resolved"]
Severity = Literal["Low", "Medium", "High", "Critical"]

CATEGORIES = (
    "Electrical",
    "Plumbing",
    "Cleanliness",
    "Infrastructure",
    "Furniture",
    "Network",
    "Water Supply",
    "Security",
    "Environment",
    "Other",
)

SEVERITY_POINTS: dict[str, int] = {"Low": 10, "Medium": 22, "High": 36, "Critical": 48}

LOCATIONS: dict[str, dict[str, object]] = {
    "Academic Block A · Room A101": {
        "code": "BLOCK-A-FLOOR-1-ROOM-A101",
        "building": "Academic Block A",
        "floor": "1st floor",
        "room": "A101",
        "latitude": 20.2972,
        "longitude": 85.8236,
    },
    "Academic Block B · Ground floor": {
        "code": "BLOCK-B-FLOOR-0-ROOM-GF",
        "building": "Academic Block B",
        "floor": "Ground floor",
        "room": "Ground floor",
        "latitude": 20.2968,
        "longitude": 85.8247,
    },
    "Academic Block B · Room B204": {
        "code": "BLOCK-B-FLOOR-2-ROOM-B204",
        "building": "Academic Block B",
        "floor": "2nd floor",
        "room": "B204",
        "latitude": 20.2968,
        "longitude": 85.8247,
    },
    "Library · 1st floor": {
        "code": "LIBRARY-FLOOR-1-ROOM-01",
        "building": "Library",
        "floor": "1st floor",
        "room": "01",
        "latitude": 20.2974,
        "longitude": 85.8242,
    },
    "Canteen · East entrance": {
        "code": "CANTEEN-GROUND-EAST",
        "building": "Canteen",
        "floor": "Ground floor",
        "room": "East entrance",
        "latitude": 20.2962,
        "longitude": 85.8238,
    },
    "Hostel A · Room 204": {
        "code": "HOSTEL-A-FLOOR-2-ROOM-204",
        "building": "Hostel A",
        "floor": "2nd floor",
        "room": "204",
        "latitude": 20.2958,
        "longitude": 85.8252,
    },
}


@dataclass
class IssueEvent:
    label: str
    at: datetime
    detail: str = ""


@dataclass
class CampusIssue:
    issue_id: str
    title: str
    description: str
    category: str
    severity: Severity
    status: Status
    building: str
    floor: str
    room: str
    reported_by: str
    reported_at: datetime
    report_count: int = 1
    assigned_staff: str = ""
    resolution_note: str = ""
    image_name: str = ""
    image_bytes: bytes = field(default=b"", repr=False)
    resolution_image_name: str = ""
    resolution_image_bytes: bytes = field(default=b"", repr=False)
    latitude: float | None = None
    longitude: float | None = None
    ai_confidence: float = 0.93
    duplicate_group_id: str = ""
    events: list[IssueEvent] = field(default_factory=list)

    @property
    def priority_score(self) -> int:
        severity_points = SEVERITY_POINTS[self.severity]
        duplicate_points = min(max((self.report_count - 1) * 5, 0), 25)
        location_points = 15 if self.building == "Library" else 10
        age_points = min(max(int((datetime.now() - self.reported_at).total_seconds() // 3600), 0), 12)
        return min(severity_points + duplicate_points + location_points + age_points, 100)


def classify_issue(description: str) -> tuple[str, Severity, float]:
    """Deterministic demo fallback; replace with a provider behind this function."""
    text = description.casefold()
    if any(word in text for word in ("leak", "water", "tap", "pipe", "drain")):
        category = "Plumbing"
    elif any(word in text for word in ("wifi", "wi-fi", "network", "internet", "signal")):
        category = "Network"
    elif any(word in text for word in ("light", "wire", "electric", "spark")):
        category = "Electrical"
    elif any(word in text for word in ("dirty", "waste", "garbage", "clean")):
        category = "Cleanliness"
    elif any(word in text for word in ("desk", "chair", "table", "furniture")):
        category = "Furniture"
    else:
        category = "Infrastructure"

    if any(word in text for word in ("sparking", "exposed wire", "danger", "unsafe")):
        severity: Severity = "Critical"
    elif any(word in text for word in ("flood", "leak", "leaking", "burst")):
        severity = "High"
    elif any(word in text for word in ("broken", "not working", "stopped", "loose")):
        severity = "Medium"
    else:
        severity = "Low"
    return category, severity, 0.93


def find_duplicate(issues: list[CampusIssue], category: str, building: str) -> CampusIssue | None:
    return next(
        (
            issue
            for issue in issues
            if issue.category == category
            and issue.building.casefold() == building.casefold()
            and issue.status != "Resolved"
        ),
        None,
    )


def staff_queue_issues(issues: list[CampusIssue], staff_name: str) -> list[CampusIssue]:
    """Include new unassigned reports plus open work assigned to this staff member."""
    return [
        issue
        for issue in issues
        if issue.status != "Resolved"
        and (not issue.assigned_staff or issue.assigned_staff == staff_name)
    ]


def create_issue(
    *,
    description: str,
    category: str,
    severity: Severity,
    building: str,
    floor: str,
    room: str,
    reported_by: str,
    image_name: str = "",
    image_bytes: bytes = b"",
    latitude: float | None = None,
    longitude: float | None = None,
) -> CampusIssue:
    title = description.strip().splitlines()[0].strip(" .!?\t") or "Campus issue"
    if len(title) > 46:
        title = f"{title[:43].rstrip()}..."
    now = datetime.now()
    return CampusIssue(
        issue_id=f"QF-{uuid4().hex[:5].upper()}",
        title=title,
        description=description.strip(),
        category=category,
        severity=severity,
        status="Submitted",
        building=building,
        floor=floor,
        room=room,
        reported_by=reported_by,
        reported_at=now,
        image_name=image_name,
        image_bytes=image_bytes,
        latitude=latitude,
        longitude=longitude,
        events=[
            IssueEvent("Issue submitted", now),
            IssueEvent("AI classification completed", now, "Demo analysis · user confirmed"),
        ],
    )


def join_report(issue: CampusIssue, reporter: str) -> None:
    issue.report_count += 1
    issue.duplicate_group_id = issue.issue_id
    issue.events.append(IssueEvent("Report joined", datetime.now(), f"{reporter} added a matching report"))


def advance_issue(
    issue: CampusIssue,
    role: Role,
    *,
    resolution_note: str = "",
    resolution_image_name: str = "",
    resolution_image_bytes: bytes = b"",
    staff_name: str = "Arun Das",
) -> bool:
    transitions: dict[tuple[str, str], Status] = {
        ("Admin", "Submitted"): "Verified",
        ("Admin", "Verified"): "Assigned",
        ("Maintenance", "Assigned"): "In progress",
        ("Student", "Resolved"): "Submitted",
    }
    if role == "Maintenance" and issue.status == "In progress":
        if not resolution_note.strip() and not resolution_image_name:
            return False
        next_status: Status = "Resolved"
    else:
        next_status = transitions.get((role, issue.status))  # type: ignore[assignment]
        if next_status is None:
            return False

    issue.status = next_status
    if next_status == "Assigned":
        issue.assigned_staff = staff_name
    if next_status == "Resolved":
        issue.resolution_note = resolution_note.strip()
        issue.resolution_image_name = resolution_image_name
        issue.resolution_image_bytes = resolution_image_bytes
    detail = issue.resolution_note if next_status == "Resolved" else issue.assigned_staff if next_status == "Assigned" else ""
    issue.events.append(IssueEvent(next_status, datetime.now(), detail))
    return True


def seed_issues() -> list[CampusIssue]:
    now = datetime.now()
    rows: list[tuple[str, str, str, Severity, Status, str, str, str, int]] = [
        ("Water Leakage", "Pipe leaking beside the washroom entrance", "Plumbing", "High", "In progress", "Academic Block B", "Ground floor", "Ground floor", 8),
        ("Broken Light", "Ceiling light is not turning on", "Electrical", "Medium", "Resolved", "Academic Block A", "1st floor", "A102", 2),
        ("Wi-Fi dead zone", "No network signal in the study area", "Network", "Low", "Submitted", "Library", "1st floor", "01", 3),
        ("Damaged desk", "Desk leg is loose in the back row", "Furniture", "Medium", "Assigned", "Academic Block A", "2nd floor", "A201", 2),
        ("Overflowing bin", "Waste bin is full near the east entrance", "Cleanliness", "Low", "Verified", "Canteen", "Ground floor", "East entrance", 1),
        ("Exposed wiring", "Loose wire near the lab door", "Electrical", "Critical", "In progress", "Academic Block B", "1st floor", "LAB-B", 4),
        ("Tap pressure low", "Water pressure is low in the north wing", "Water Supply", "Medium", "Submitted", "Hostel A", "2nd floor", "204", 1),
        ("Broken door closer", "Main door slams shut unexpectedly", "Infrastructure", "High", "Assigned", "Administrative Block", "Ground floor", "ADMIN-01", 2),
        ("Washroom cleaning", "Floor needs attention near the sinks", "Cleanliness", "Medium", "Resolved", "Hostel B", "Ground floor", "HB-WC", 5),
        ("Pathway light out", "Walkway is dark after sunset", "Electrical", "High", "Submitted", "Sports Complex", "Ground floor", "SPORTS-N", 3),
        ("Cracked window latch", "Window cannot be secured", "Infrastructure", "Medium", "Verified", "Academic Block A", "1st floor", "A101", 1),
        ("Water cooler offline", "Cooler has stopped dispensing water", "Water Supply", "Medium", "In progress", "Library", "Ground floor", "Water point", 4),
        ("Loose chair", "Chair back is unstable", "Furniture", "Low", "Resolved", "Canteen", "Ground floor", "CAN-04", 1),
        ("Drain smell", "Strong odor from the outdoor drain", "Plumbing", "High", "Submitted", "Hostel A", "Ground floor", "HA-DRAIN", 2),
        ("Projector offline", "Classroom projector will not connect", "Network", "Low", "Assigned", "Academic Block B", "2nd floor", "B204", 1),
        ("Broken handrail", "Handrail moves when used on the stairs", "Infrastructure", "Critical", "Verified", "Academic Block A", "1st floor", "A-STAIR", 3),
        ("Canteen spill", "Liquid spill by the serving counter", "Cleanliness", "High", "In progress", "Canteen", "Ground floor", "CAN-01", 3),
        ("Gate sensor issue", "Side gate sensor is not responding", "Security", "High", "Submitted", "Hostel B", "Ground floor", "HB-GATE", 1),
    ]
    issues: list[CampusIssue] = []
    building_coordinates = {
        "Academic Block A": (20.2972, 85.8236),
        "Academic Block B": (20.2968, 85.8247),
        "Library": (20.2974, 85.8242),
        "Canteen": (20.2962, 85.8238),
        "Hostel A": (20.2958, 85.8252),
        "Hostel B": (20.2955, 85.8243),
        "Administrative Block": (20.2970, 85.8229),
        "Sports Complex": (20.2949, 85.8234),
    }
    for index, row in enumerate(rows):
        title, description, category, severity, status, building, floor, room, report_count = row
        issue_time = now - timedelta(hours=2 + index)
        base_latitude, base_longitude = building_coordinates[building]
        marker_offset = (index % 3) * 0.00012
        issue = CampusIssue(
            issue_id=f"QF-{1024 + index}",
            title=title,
            description=description,
            category=category,
            severity=severity,
            status=status,
            building=building,
            floor=floor,
            room=room,
            reported_by="Maya Patel" if index == 0 else "Campus user",
            reported_at=issue_time,
            report_count=report_count,
            latitude=base_latitude + marker_offset,
            longitude=base_longitude - marker_offset,
            assigned_staff="Arun Das" if status in ("Assigned", "In progress") else "",
            resolution_note="Repair completed and checked by facilities." if status == "Resolved" else "",
            events=[IssueEvent("Issue submitted", issue_time, "Reported by a campus user")],
        )
        if status != "Submitted":
            issue.events.append(IssueEvent(status, now - timedelta(minutes=42 + index)))
        if status == "Resolved":
            issue.events.append(IssueEvent("Resolved", now - timedelta(minutes=10 + index)))
        issues.append(issue)
    return issues