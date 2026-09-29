from __future__ import annotations

import html
from collections import Counter
from datetime import datetime
from io import BytesIO

import pandas as pd
import folium
import plotly.graph_objects as go
import qrcode
import streamlit as st
from streamlit_folium import st_folium
from streamlit_geolocation import streamlit_geolocation
from auth_store import (
    DEMO_ACCOUNTS,
    DEMO_PASSWORD,
    UserAccount,
    authenticate_user,
    ensure_demo_accounts,
    list_accounts,
    register_account,
)

from voxguard import (
    CATEGORIES,
    LOCATIONS,
    CampusIssue,
    Role,
    Severity,
    advance_issue,
    classify_issue,
    create_issue,
    find_duplicate,
    join_report,
    seed_issues,
    staff_queue_issues,
)


st.set_page_config(
    page_title="QuickFix-Campus",
    page_icon="QF",
    layout="wide",
    initial_sidebar_state="expanded",
)

INK = "#0B1017"
PANEL = "#131B25"
MUTED = "#91A1B2"
CYAN = "#62D6E5"
MINT = "#9CE3BD"
SEVERITY_COLORS = {
    "Critical": "#FF6478",
    "High": "#FF965C",
    "Medium": "#FFC45C",
    "Low": "#6EC99A",
}
STATUS_COLORS = {
    "Submitted": CYAN,
    "Verified": "#9AA8FF",
    "Assigned": "#E6A5FF",
    "In progress": "#FFC45C",
    "Resolved": MINT,
}
ROLE_PAGES: dict[str, list[str]] = {
    "Student": ["Home", "Report an issue", "My issues", "Campus", "Profile"],
    "Maintenance": ["Tasks", "Campus", "Updates", "Profile"],
    "Admin": ["Dashboard", "Issues", "Campus", "Analytics", "Settings"],
}


def inject_theme() -> None:
    st.markdown(
        """
        <style>
        @import url('https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;600;700&family=Manrope:wght@500;600;700;800&display=swap');
        html, body, [class*="st-"], button, input, textarea { font-family: 'DM Sans', sans-serif; }
        h1, h2, h3 { font-family: 'Manrope', sans-serif !important; letter-spacing: 0 !important; }
        h1, h2, h3, [data-testid="stMarkdownContainer"] p, [data-testid="stCaptionContainer"] p,
        [data-testid="stMetricValue"], [data-testid="stWidgetLabel"] p { overflow-wrap: anywhere; word-break: normal; white-space: normal; }
        div.stButton > button, div.stFormSubmitButton > button { height: auto; min-height: 42px; white-space: normal; overflow-wrap: anywhere; line-height: 1.3; }
        [data-testid="stAppViewContainer"] { background: #0B1017; }
        [data-testid="stHeader"] { background: rgba(11,16,23,.92); }
        [data-testid="stSidebar"] { background: #101720; border-right: 1px solid #263543; }
        [data-testid="stSidebar"] [data-testid="stMarkdownContainer"] p { color: #91A1B2; }
        .block-container { max-width: 1440px; padding-top: 1.5rem; padding-bottom: 3rem; }
        [data-testid="stMetric"] { background: #131B25; border: 1px solid #263543; border-radius: 14px; padding: 14px 16px; }
        [data-testid="stMetricLabel"] { color: #91A1B2; }
        [data-testid="stMetricValue"] { font-family: 'Manrope', sans-serif; }
        div[data-testid="stVerticalBlockBorderWrapper"] { border-color: #263543; border-radius: 14px; }
        div.stButton > button, div.stFormSubmitButton > button { border-radius: 9px; border: 1px solid #35505B; min-height: 42px; }
        div.stButton > button[kind="primary"], div.stFormSubmitButton > button[kind="primary"] { background: #62D6E5; border-color: #62D6E5; color: #0B1017; font-weight: 700; }
        [data-testid="stProgressBar"] > div > div { background-color: #62D6E5; }
        .vg-brand { display:flex; align-items:center; gap:11px; margin: 3px 0 8px; }
        .vg-mark { width:40px; height:42px; display:flex; align-items:center; justify-content:center; background:#193139; color:#62D6E5; font-family:Manrope,sans-serif; font-weight:800; font-size:13px; border:1px solid #31545B; clip-path:polygon(50% 0, 94% 17%, 87% 68%, 50% 100%, 13% 68%, 6% 17%); flex:none; }
        .vg-word { color:#F5F8FA; font-family:Manrope,sans-serif; font-size:15px; font-weight:800; letter-spacing:0; line-height:1.1; overflow-wrap:anywhere; }
        .vg-product { color:#62D6E5; font-size:9px; font-weight:700; letter-spacing:0; margin-top:4px; overflow-wrap:anywhere; }
        .vg-eyebrow { color:#62D6E5; font-size:10px; font-weight:700; letter-spacing:0; margin-bottom:6px; overflow-wrap:anywhere; }
        .vg-muted { color:#91A1B2; font-size:13px; }
        .vg-chip { display:inline-block; max-width:100%; white-space:normal; overflow-wrap:anywhere; padding:4px 8px; border-radius:6px; font-size:10px; font-weight:700; margin-right:4px; }
        .vg-event { border-left:2px solid #35505B; margin-left:5px; padding:0 0 15px 16px; position:relative; }
        .vg-event:before { content:''; width:8px; height:8px; border-radius:50%; background:#62D6E5; position:absolute; left:-5px; top:4px; }
        .vg-alert { background:#28251D; border:1px solid #504332; border-radius:12px; padding:14px 16px; }
        .vg-health { background:linear-gradient(115deg,#172A30,#142129); border:1px solid #27434A; border-radius:15px; padding:18px; }
        @media (max-width: 700px) { .block-container { padding-left:1rem; padding-right:1rem; } }
        </style>
        """,
        unsafe_allow_html=True,
    )


def initialize_state() -> None:
    if "issues" not in st.session_state:
        st.session_state.issues = seed_issues()
    if "accounts_initialized" not in st.session_state:
        ensure_demo_accounts()
        st.session_state.accounts_initialized = True
    if "role" not in st.session_state:
        st.session_state.role = "Student"
    if "is_authenticated" not in st.session_state:
        st.session_state.is_authenticated = False
    if "report_step" not in st.session_state:
        st.session_state.report_step = 0
    if "current_user" not in st.session_state:
        st.session_state.current_user = None
    if "current_account" not in st.session_state:
        st.session_state.current_account = None
    if "nav" not in st.session_state:
        st.session_state.nav = ROLE_PAGES[st.session_state.role][0]
    if "pending_report" not in st.session_state:
        st.session_state.pending_report = None


def clear_report() -> None:
    st.session_state.report_step = 0
    st.session_state.pending_report = None
    for key in (
        "report_description_value",
        "report_description_widget",
        "report_category_value",
        "report_severity_value",
        "report_location_value",
        "report_category_widget",
        "report_severity_widget",
        "report_location_widget",
        "report_photo",
        "report_camera",
        "report_qr",
        "report_location_pending",
        "report_ai_category",
        "report_ai_severity",
        "report_photo_name",
        "report_photo_bytes",
        "report_use_live_location",
        "report_location_selected",
        "report_latitude_value",
        "report_longitude_value",
    ):
        st.session_state.pop(key, None)


def brand(compact: bool = False) -> None:
    st.markdown(
        f"""<div class="vg-brand"><div class="vg-mark">QF</div><div>
        <div class="vg-word">QuickFix-Campus</div><div class="vg-product">REPORT · TRACK · RESOLVE</div></div></div>""",
        unsafe_allow_html=True,
    )


def start_user_session(account: UserAccount) -> None:
    st.session_state.is_authenticated = True
    st.session_state.current_user = account.name
    st.session_state.current_account = account
    st.session_state.role = account.role
    st.session_state.nav = ROLE_PAGES[account.role][0]


def render_auth_page() -> None:
    left, right = st.columns([1.05, 1], gap="large")
    with left:
        brand()
        st.markdown("<div style='height:2rem'></div>", unsafe_allow_html=True)
        st.markdown('<div class="vg-eyebrow">SMART CAMPUS · QUICKFIX</div>', unsafe_allow_html=True)
        st.title("Welcome to QuickFix-Campus")
        st.caption("Sign in to report campus issues, coordinate repairs, and follow each resolution.")
        st.markdown("<div style='height:1rem'></div>", unsafe_allow_html=True)
        with st.container(border=True):
            st.subheader("Demo access")
            st.caption(f"Use a demo account · password: `{DEMO_PASSWORD}`")
            for name, email, role, _, _, _ in DEMO_ACCOUNTS:
                account_column, action_column = st.columns([1.3, 1])
                with account_column:
                    st.markdown(f"**{role}** · {name}")
                with action_column:
                    if st.button(f"Use {role}", key=f"demo-login-{role}", use_container_width=True):
                        st.session_state.auth_email = email
                        st.session_state.auth_password = DEMO_PASSWORD

    with right:
        mode = st.radio("Account", ["Log in", "Register"], horizontal=True, label_visibility="collapsed", key="auth_mode")
        if mode == "Log in":
            with st.form("login-form"):
                email = st.text_input("Email", placeholder="you@campus.edu", autocomplete="email", key="auth_email")
                password = st.text_input("Password", type="password", autocomplete="current-password", key="auth_password")
                submitted = st.form_submit_button("LOG IN", type="primary", use_container_width=True)
            if submitted:
                account = authenticate_user(email, password)
                if account is None:
                    st.error("Email or password is incorrect.")
                else:
                    start_user_session(account)
                    st.rerun()
        else:
            role = st.selectbox("Register as", ["Student", "Maintenance"], key="register_role")
            with st.form("register-form"):
                name = st.text_input("Full name", autocomplete="name")
                email = st.text_input("Email", placeholder="you@campus.edu", autocomplete="email")
                password = st.text_input("Password", type="password", help="Use at least 8 characters.", autocomplete="new-password")
                institution = st.text_input("College / institution")
                student_id = st.text_input("Student ID", disabled=role != "Student")
                phone = st.text_input("Phone number", autocomplete="tel")
                submitted = st.form_submit_button("CREATE ACCOUNT", type="primary", use_container_width=True)
            if submitted:
                account, error = register_account(
                    name=name,
                    email=email,
                    password=password,
                    role=role,
                    institution=institution,
                    student_id=student_id,
                    phone=phone,
                )
                if error:
                    st.error(error)
                elif account is not None:
                    start_user_session(account)
                    st.success("Account created. You are now signed in.")
                    st.rerun()


def page_heading(eyebrow: str, title: str, subtitle: str = "") -> None:
    st.markdown(f'<div class="vg-eyebrow">{html.escape(eyebrow.upper())}</div>', unsafe_allow_html=True)
    st.title(title)
    if subtitle:
        st.caption(subtitle)


def chip(text: str, color: str) -> str:
    safe_text = html.escape(text)
    return f'<span class="vg-chip" style="background:{color}20;color:{color}">{safe_text}</span>'


def ordered_issues(issues: list[CampusIssue]) -> list[CampusIssue]:
    return sorted(issues, key=lambda issue: (-issue.priority_score, -issue.reported_at.timestamp()))


def show_health() -> None:
    st.markdown(
        """<div class="vg-health"><div style="display:flex;align-items:center;gap:14px">
        <div style="font-size:27px;color:#9CE3BD">◉</div><div style="flex:1">
        <div style="font-size:10px;color:#91A1B2;letter-spacing:0">CAMPUS HEALTH</div>
        <div style="font-weight:600;margin-top:3px">Looking good today</div></div>
        <div style="font-family:Manrope,sans-serif;font-weight:800;font-size:28px;color:#9CE3BD">92%</div>
        </div></div>""",
        unsafe_allow_html=True,
    )


def alert_strip() -> None:
    st.markdown(
        '<div class="vg-alert"><span style="color:#FFC45C;font-size:10px;font-weight:700;letter-spacing:0">CAMPUS ALERT</span><br><span>Water supply maintenance at Block B, 10:00 AM–12:00 PM.</span></div>',
        unsafe_allow_html=True,
    )


def issue_summary(issue: CampusIssue, *, detail_button: bool = True) -> None:
    with st.container(border=True):
        first, second, third = st.columns([5, 1.2, 1.1])
        with first:
            st.markdown(f"**{issue.title}**  ·  `{issue.issue_id}`")
            st.caption(f"{issue.building} · {issue.room}  |  {issue.category}  |  {issue.report_count} reports")
            if st.session_state.role == "Maintenance" and not issue.assigned_staff:
                st.caption("New report · awaiting admin assignment")
            st.markdown(
                f"{chip(issue.severity.upper(), SEVERITY_COLORS[issue.severity])}"
                f"{chip(issue.status, STATUS_COLORS[issue.status])}",
                unsafe_allow_html=True,
            )
        with second:
            st.metric("Priority", issue.priority_score)
        with third:
            if detail_button and st.button("Open", key=f"open-{issue.issue_id}", use_container_width=True):
                st.session_state.selected_issue_id = issue.issue_id
                st.session_state._next_nav = "My issues" if st.session_state.role == "Student" else "Issues" if st.session_state.role == "Admin" else "Tasks"
                st.rerun()


def render_home() -> None:
    user = st.session_state.current_user
    page_heading("STUDENT · CAMPUS PULSE", f"Good morning, {user.split()[0]}.", "Your campus, in better shape.")
    show_health()
    st.write("")
    if st.button("＋  REPORT AN ISSUE", type="primary", use_container_width=True):
        st.session_state._next_nav = "Report an issue"
        st.session_state.report_step = 0
        st.rerun()

    mine = [issue for issue in st.session_state.issues if issue.reported_by == user]
    in_progress = sum(issue.status == "In progress" for issue in mine)
    resolved = sum(issue.status == "Resolved" for issue in mine)
    metrics = st.columns(3)
    metrics[0].metric("MY REPORTS", len(mine))
    metrics[1].metric("IN PROGRESS", in_progress)
    metrics[2].metric("RESOLVED", resolved)

    st.subheader("Recent reports")
    recent = sorted(mine, key=lambda issue: issue.reported_at, reverse=True)[:4]
    if recent:
        for issue in recent:
            issue_summary(issue)
    else:
        st.info("No reports yet. Start with the report button above.")
    alert_strip()


def current_browser_location() -> dict[str, float] | None:
    result = streamlit_geolocation()
    if isinstance(result, dict):
        try:
            latitude = float(result["latitude"])
            longitude = float(result["longitude"])
        except (KeyError, TypeError, ValueError):
            return st.session_state.get("live_location")
        if -90 <= latitude <= 90 and -180 <= longitude <= 180:
            location = {
                "latitude": latitude,
                "longitude": longitude,
                "accuracy": float(result.get("accuracy") or 0),
            }
            st.session_state.live_location = location
            return location
    return st.session_state.get("live_location")


def render_osm_map(
    center: tuple[float, float],
    *,
    issues: list[CampusIssue],
    live_location: dict[str, float] | None = None,
    height: int = 390,
    key: str,
) -> None:
    campus_map = folium.Map(
        location=center,
        zoom_start=16,
        tiles="OpenStreetMap",
        control_scale=True,
    )
    for issue in issues:
        if issue.latitude is None or issue.longitude is None:
            continue
        color = SEVERITY_COLORS[issue.severity]
        folium.CircleMarker(
            location=(issue.latitude, issue.longitude),
            radius=min(5 + issue.report_count, 14),
            color=color,
            weight=2,
            fill=True,
            fill_color=color,
            fill_opacity=0.78,
            tooltip=f"{issue.title} · {issue.severity}",
            popup=folium.Popup(
                f"<strong>{html.escape(issue.title)}</strong><br>"
                f"{html.escape(issue.building)} · {html.escape(issue.room)}<br>"
                f"{html.escape(issue.status)} · {issue.report_count} reports",
                max_width=260,
            ),
        ).add_to(campus_map)
    if live_location:
        user_point = (live_location["latitude"], live_location["longitude"])
        folium.Marker(
            location=user_point,
            tooltip="Your live location",
            popup="Current browser location",
            icon=folium.Icon(color="blue", icon="user", prefix="fa"),
        ).add_to(campus_map)
        accuracy = live_location.get("accuracy", 0)
        if accuracy > 0:
            folium.Circle(
                location=user_point,
                radius=min(accuracy, 1000),
                color="#62D6E5",
                fill=True,
                fill_opacity=0.08,
                weight=1,
            ).add_to(campus_map)
    st_folium(
        campus_map,
        key=key,
        width=None,
        height=height,
        returned_objects=[],
        use_container_width=True,
    )


def location_entry() -> dict[str, object]:
    names = list(LOCATIONS)
    default_location = "Academic Block B · Ground floor"
    pending_location = st.session_state.pop("report_location_pending", None)
    if pending_location in LOCATIONS:
        st.session_state.report_location_widget = pending_location
        st.session_state.report_location_value = pending_location
        st.session_state.report_use_live_location = False
        st.session_state.report_latitude_value = float(LOCATIONS[pending_location]["latitude"])
        st.session_state.report_longitude_value = float(LOCATIONS[pending_location]["longitude"])
    saved_location = st.session_state.get("report_location_value", default_location)
    if "report_location_widget" not in st.session_state:
        st.session_state.report_location_widget = saved_location
    selected = st.selectbox("Campus location", names, key="report_location_widget")
    previous_location = st.session_state.get("report_location_selected")
    if previous_location is not None and previous_location != selected:
        st.session_state.report_use_live_location = False
        st.session_state.report_latitude_value = float(LOCATIONS[selected]["latitude"])
        st.session_state.report_longitude_value = float(LOCATIONS[selected]["longitude"])
    st.session_state.report_location_selected = selected
    st.session_state.report_location_value = selected
    location = LOCATIONS[selected]
    if "report_latitude_value" not in st.session_state:
        st.session_state.report_latitude_value = float(location["latitude"])
        st.session_state.report_longitude_value = float(location["longitude"])
    left, right = st.columns([1.5, 1])
    with left:
        st.caption(f"Location marker · `{location['code']}`")
        st.caption(f"{location['building']} · {location['floor']} · {location['room']}")
    with right:
        st.caption(f"Campus pin · {location['latitude']:.5f}, {location['longitude']:.5f}")

    st.markdown("**Use your current device location**")
    browser_location = current_browser_location()
    if browser_location:
        st.caption(
            f"GPS fix · ±{browser_location['accuracy']:.0f} m · "
            f"{browser_location['latitude']:.5f}, {browser_location['longitude']:.5f}"
        )
        if st.button("Use live GPS for this report", key="use-live-gps"):
            st.session_state.report_use_live_location = True
            st.rerun()
    else:
        st.caption("Allow location access in your browser to request a live GPS fix.")

    use_live_location = st.session_state.get("report_use_live_location", False) and browser_location is not None
    selected_point = browser_location if use_live_location else {
        "latitude": float(location["latitude"]),
        "longitude": float(location["longitude"]),
    }
    location_with_point = {
        **location,
        "latitude": selected_point["latitude"],
        "longitude": selected_point["longitude"],
    }
    st.session_state.report_latitude_value = float(selected_point["latitude"])
    st.session_state.report_longitude_value = float(selected_point["longitude"])
    st.caption("Map data © OpenStreetMap contributors")
    render_osm_map(
        (float(selected_point["latitude"]), float(selected_point["longitude"])),
        issues=st.session_state.issues,
        live_location=browser_location,
        height=330,
        key="report-location-map",
    )

    with st.expander("Have a QR value to apply?"):
        code = st.text_input("Paste the location QR value", key="report_qr")
        if st.button("Apply QR location", key="apply-qr"):
            matching = next((name for name, item in LOCATIONS.items() if item["code"].casefold() == code.strip().casefold()), None)
            if matching:
                st.session_state.report_location_pending = matching
                st.success("Campus location attached.")
                st.rerun()
            else:
                st.error("QR value not recognized. Select a campus location instead.")
    return location_with_point


def report_location_data() -> dict[str, object]:
    selected = st.session_state.get("report_location_value", "Academic Block B · Ground floor")
    location = LOCATIONS[selected]
    return {
        **location,
        "latitude": float(st.session_state.get("report_latitude_value", location["latitude"])),
        "longitude": float(st.session_state.get("report_longitude_value", location["longitude"])),
    }


def render_report() -> None:
    page_heading("QUICKFIX · NEW REPORT", "What needs fixing?", "A few details help the right team act faster.")
    step = int(st.session_state.report_step)
    labels = ["Photo & AI", "Location", "Details", "Review"]
    st.progress((step + 1) / len(labels), text=f"Step {step + 1} of {len(labels)} · {labels[step]}")

    if step == 0:
        st.subheader("Add a photo and confirm the classification")
        camera_column, upload_column = st.columns(2)
        with camera_column:
            camera_photo = st.camera_input("Take a photo now", key="report_camera")
        with upload_column:
            uploaded_photo = st.file_uploader("Or choose a photo", type=["jpg", "jpeg", "png", "webp"], key="report_photo")
        photo = camera_photo if camera_photo is not None else uploaded_photo
        if photo is not None:
            st.session_state.report_photo_name = getattr(photo, "name", "camera-capture.jpg")
            st.session_state.report_photo_bytes = photo.getvalue()
            st.image(st.session_state.report_photo_bytes, caption="Issue photo", use_container_width=True)
        elif st.session_state.get("report_photo_bytes"):
            st.image(st.session_state.report_photo_bytes, caption=st.session_state.get("report_photo_name", "Issue photo"), use_container_width=True)

        suggestion_category = st.session_state.get("report_category_value", st.session_state.get("report_ai_category", "Plumbing"))
        suggestion_severity = st.session_state.get("report_severity_value", st.session_state.get("report_ai_severity", "High"))
        category_index = CATEGORIES.index(suggestion_category) if suggestion_category in CATEGORIES else 0
        severity_options = ["Low", "Medium", "High", "Critical"]
        severity_index = severity_options.index(suggestion_severity) if suggestion_severity in severity_options else 0
        left, right = st.columns(2)
        with left:
            category = st.selectbox("Confirm category", CATEGORIES, index=category_index, key="report_category_widget")
            st.session_state.report_category_value = category
        with right:
            severity = st.selectbox("Confirm severity", severity_options, index=severity_index, key="report_severity_widget")
            st.session_state.report_severity_value = severity
        st.caption("AI output is a suggestion. You can change either field before submitting.")

    elif step == 1:
        st.subheader("Pinpoint the campus location")
        location_entry()
        st.info("Browser hosting uses campus QR values or the location list. Device GPS scanning is not available in this web demo.")

    elif step == 2:
        st.subheader("Describe what happened")
        if st.button("Insert demo voice transcript", icon=":material/mic:"):
            transcript = "Water is leaking near the Block B ground floor washroom."
            st.session_state.report_description_value = transcript
            st.session_state.report_description_widget = transcript
            st.session_state.report_voice_demo = True
        description = st.text_area(
            "Description",
            placeholder="Describe the issue and what people should know...",
            height=150,
            max_chars=800,
            value=st.session_state.get("report_description_value", ""),
            key="report_description_widget",
            label_visibility="collapsed",
        )
        st.session_state.report_description_value = description
        if st.session_state.get("report_voice_demo"):
            st.caption("Demo transcript inserted. Review and edit it before continuing.")
        if st.button("Analyze description"):
            if not description.strip():
                st.error("Add a description before running the analysis.")
            else:
                category, severity, confidence = classify_issue(description)
                st.session_state.report_ai_category = category
                st.session_state.report_ai_severity = severity
                st.session_state.report_ai_confidence = confidence
                st.session_state.report_category_value = category
                st.session_state.report_severity_value = severity
                st.success(f"Suggestion: {category} · {severity} · {confidence:.0%} confidence. Confirm on Photo & AI.")
        location = report_location_data()
        st.caption(f"Selected location · {location['building']} · {location['room']}")

    else:
        st.subheader("Review before submitting")
        description = st.session_state.get("report_description_value", "").strip()
        location = report_location_data()
        category = st.session_state.get("report_category_value", "Plumbing")
        severity = st.session_state.get("report_severity_value", "High")
        if st.session_state.get("report_photo_bytes"):
            st.image(st.session_state.report_photo_bytes, width=360)
        st.markdown(f"**Category**  {category}  &nbsp;&nbsp; **Severity**  {severity}", unsafe_allow_html=True)
        st.markdown(f"**Location**  {location['building']} · {location['floor']} · {location['room']}")
        st.markdown(f"**Description**  {description or '_Add a description in the previous step._'}")
        st.caption("Submitting shares the report with campus facilities.")

        pending = st.session_state.pending_report
        if pending:
            duplicate = next((item for item in st.session_state.issues if item.issue_id == pending["duplicate_id"]), None)
            if duplicate:
                st.warning(f"Similar issue found · {duplicate.issue_id} · {duplicate.title} · {duplicate.report_count} people have reported this.")
                join_col, separate_col = st.columns(2)
                if join_col.button("Add my report", type="primary", use_container_width=True):
                    join_report(duplicate, st.session_state.current_user)
                    st.success(f"Your report joined {duplicate.issue_id}.")
                    clear_report()
                    st.session_state._next_nav = "My issues"
                    st.rerun()
                if separate_col.button("Create separate issue", use_container_width=True):
                    save_new_report(pending)
                    st.rerun()

        elif st.button("SUBMIT ISSUE", type="primary", use_container_width=True):
            if not description:
                st.error("Add a short description before submitting.")
                return
            duplicate = find_duplicate(st.session_state.issues, category, str(location["building"]))
            report_data = {
                "description": description,
                "category": category,
                "severity": severity,
                "location": location,
                "image_name": st.session_state.get("report_photo_name", ""),
                "image_bytes": st.session_state.get("report_photo_bytes", b""),
            }
            if duplicate:
                st.session_state.pending_report = {**report_data, "duplicate_id": duplicate.issue_id}
                st.rerun()
            else:
                save_new_report(report_data)
                st.rerun()

    back, spacer, next_column = st.columns([1, 3, 1])
    with back:
        if step > 0 and st.button("Back", use_container_width=True):
            st.session_state.report_step -= 1
            st.rerun()
    with next_column:
        if step < 3 and not st.session_state.pending_report and st.button("Continue", type="primary", use_container_width=True):
            if step == 2 and not st.session_state.get("report_description_value", "").strip():
                st.error("Add a short description to continue.")
            else:
                st.session_state.report_step += 1
                st.rerun()


def save_new_report(report: dict[str, object]) -> None:
    location = report["location"]
    assert isinstance(location, dict)
    issue = create_issue(
        description=str(report["description"]),
        category=str(report["category"]),
        severity=report["severity"],  # type: ignore[arg-type]
        building=str(location["building"]),
        floor=str(location["floor"]),
        room=str(location["room"]),
        reported_by=st.session_state.current_user,
        image_name=str(report["image_name"]),
        image_bytes=report["image_bytes"],  # type: ignore[arg-type]
        latitude=float(location["latitude"]),
        longitude=float(location["longitude"]),
    )
    st.session_state.issues.insert(0, issue)
    st.session_state.pending_report = None
    clear_report()
    st.session_state._next_nav = "My issues"
    st.toast(f"{issue.issue_id} submitted · facilities notified", icon=":material/check_circle:")


def render_issue_list(*, mine_only: bool = False, staff_only: bool = False) -> None:
    if mine_only:
        page_heading("STUDENT · TRACKING", "My issues", "Follow every report from submission through resolution.")
    elif staff_only:
        page_heading("MAINTENANCE · WORK QUEUE", "Assigned tasks", "Accept work, add repair evidence, and close the loop.")
    else:
        page_heading("OPERATIONS · ISSUE REGISTER", "Campus issues", "Search, filter, and prioritize the live queue.")

    issues = list(st.session_state.issues)
    if mine_only:
        issues = [issue for issue in issues if issue.reported_by == st.session_state.current_user]
    if staff_only:
        issues = staff_queue_issues(issues, st.session_state.current_user)

    search = st.text_input("Search issues", placeholder="Title, category, location, or ID", key=f"search-{mine_only}-{staff_only}")
    filter_cols = st.columns(3)
    with filter_cols[0]:
        category_filter = st.selectbox("Category", ["All categories", *CATEGORIES], key=f"cat-filter-{mine_only}-{staff_only}")
    with filter_cols[1]:
        severity_filter = st.selectbox("Severity", ["All severities", "Critical", "High", "Medium", "Low"], key=f"sev-filter-{mine_only}-{staff_only}")
    with filter_cols[2]:
        status_filter = st.selectbox("Status", ["All statuses", "Submitted", "Verified", "Assigned", "In progress", "Resolved"], key=f"status-filter-{mine_only}-{staff_only}")

    query = search.casefold().strip()
    filtered = [
        issue for issue in issues
        if (not query or query in f"{issue.title} {issue.category} {issue.building} {issue.issue_id}".casefold())
        and (category_filter == "All categories" or issue.category == category_filter)
        and (severity_filter == "All severities" or issue.severity == severity_filter)
        and (status_filter == "All statuses" or issue.status == status_filter)
    ]
    st.caption(f"{len(filtered)} issues · sorted by priority")
    for issue in ordered_issues(filtered):
        issue_summary(issue)
    if not filtered:
        st.info("No issues match the current filters.")

    if filtered:
        st.divider()
        issue_by_id = {issue.issue_id: issue for issue in filtered}
        selected_id = st.selectbox("Issue details", list(issue_by_id), key=f"detail-select-{mine_only}-{staff_only}")
        render_issue_detail(issue_by_id[selected_id])


def render_issue_detail(issue: CampusIssue) -> None:
    st.subheader(f"{issue.title} · {issue.issue_id}")
    st.markdown(
        f"{chip(issue.category, CYAN)}{chip(issue.severity.upper(), SEVERITY_COLORS[issue.severity])}{chip(issue.status, STATUS_COLORS[issue.status])}",
        unsafe_allow_html=True,
    )
    st.write(issue.description)
    facts = st.columns(4)
    facts[0].metric("Priority", issue.priority_score)
    facts[1].metric("Reports", issue.report_count)
    facts[2].metric("Building", issue.building)
    facts[3].metric("Room", issue.room)
    st.caption(f"Reported by {issue.reported_by} · {issue.reported_at.strftime('%b %d, %I:%M %p')}")
    if issue.image_bytes:
        st.image(issue.image_bytes, caption=issue.image_name, width=420)
    if issue.latitude is not None and issue.longitude is not None:
        st.caption(f"Coordinates · {issue.latitude:.5f}, {issue.longitude:.5f}")

    with st.expander("Issue timeline", expanded=True):
        for event in reversed(issue.events):
            time = event.at.strftime("%I:%M %p")
            detail = f"<div style='color:{MUTED};font-size:12px'>{html.escape(event.detail)}</div>" if event.detail else ""
            st.markdown(
                f"<div class='vg-event'><strong>{html.escape(event.label)}</strong> <span style='color:{MUTED};font-size:11px'>{time}</span>{detail}</div>",
                unsafe_allow_html=True,
            )
    if issue.resolution_note:
        st.success(f"Resolution note · {issue.resolution_note}")
    if issue.resolution_image_name:
        st.caption(f"Resolution evidence · {issue.resolution_image_name}")
    if issue.resolution_image_bytes:
        st.image(issue.resolution_image_bytes, caption="Maintenance repair evidence", width=420)
    role: Role = st.session_state.role
    if role == "Maintenance" and not issue.assigned_staff:
        st.info("New report · awaiting admin assignment. You can review it here; task actions appear after assignment.")
    if role == "Admin" and issue.status in ("Submitted", "Verified"):
        with st.expander("Admin controls"):
            with st.form(f"admin-controls-{issue.issue_id}"):
                selected_severity = st.selectbox("Confirmed severity", ["Low", "Medium", "High", "Critical"], index=["Low", "Medium", "High", "Critical"].index(issue.severity))
                registered_staff = [account.name for account in list_accounts("Maintenance")]
                staff_options = sorted(set(registered_staff + ["Facilities Team B", "Electrical Team"]), key=str.casefold)
                current_assignee = issue.assigned_staff if issue.assigned_staff in staff_options else staff_options[0]
                staff_name = st.selectbox("Assign to", staff_options, index=staff_options.index(current_assignee))
                save_controls = st.form_submit_button("Save issue controls", type="primary")
            if save_controls:
                issue.severity = selected_severity  # type: ignore[assignment]
                issue.assigned_staff = staff_name
                st.toast("Priority and assignment updated")
                st.rerun()

    can_admin = role == "Admin" and issue.status in ("Submitted", "Verified")
    can_staff = role == "Maintenance" and issue.assigned_staff == st.session_state.current_user and issue.status in ("Assigned", "In progress")
    if can_admin:
        label = "VERIFY ISSUE" if issue.status == "Submitted" else "ASSIGN TO MAINTENANCE"
        if st.button(label, type="primary", key=f"advance-{issue.issue_id}"):
            staff_name = issue.assigned_staff or "Arun Das"
            advance_issue(issue, role, staff_name=staff_name)
            st.toast(f"Issue is now {issue.status}")
            st.rerun()
    elif can_staff and issue.status == "Assigned":
        if st.button("ACCEPT · START TASK", type="primary", key=f"advance-{issue.issue_id}"):
            advance_issue(issue, role)
            st.toast("Task accepted · status is In progress")
            st.rerun()
    elif can_staff and issue.status == "In progress":
        with st.form(f"resolve-{issue.issue_id}"):
            resolution_note = st.text_area("Resolution note", placeholder="Describe the repair completed...")
            evidence = st.file_uploader("Repair photo · optional", type=["jpg", "jpeg", "png", "webp"], key=f"evidence-{issue.issue_id}")
            resolve = st.form_submit_button("MARK RESOLVED", type="primary")
        if resolve:
            if not resolution_note.strip() and evidence is None:
                st.error("Add a repair note or resolution photo before resolving.")
            elif advance_issue(
                issue,
                role,
                resolution_note=resolution_note,
                resolution_image_name=evidence.name if evidence else "",
                resolution_image_bytes=evidence.getvalue() if evidence else b"",
            ):
                st.toast("Resolved · the reporter can now confirm or reopen")
                st.rerun()
    elif role == "Student" and issue.reported_by == st.session_state.current_user and issue.status == "Resolved":
        fixed, reopen = st.columns(2)
        if fixed.button("Issue fixed", key=f"fixed-{issue.issue_id}"):
            from voxguard import IssueEvent
            issue.events.append(IssueEvent("Reporter confirmed fix", datetime.now()))
            st.toast("Thanks for confirming")
            st.rerun()
        if reopen.button("Still a problem", key=f"reopen-{issue.issue_id}"):
            advance_issue(issue, role)
            st.toast("Issue reopened and returned to Submitted")
            st.rerun()


def render_admin_dashboard() -> None:
    page_heading("OPERATIONS · LIVE OVERVIEW", "Campus control", "Prioritize work and keep campus service transparent.")
    show_health()
    issues: list[CampusIssue] = st.session_state.issues
    metrics = st.columns(5)
    metrics[0].metric("TOTAL ISSUES", len(issues))
    metrics[1].metric("OPEN", sum(issue.status != "Resolved" for issue in issues))
    metrics[2].metric("IN PROGRESS", sum(issue.status == "In progress" for issue in issues))
    metrics[3].metric("RESOLVED", sum(issue.status == "Resolved" for issue in issues))
    metrics[4].metric("CRITICAL", sum(issue.severity == "Critical" for issue in issues))

    new_reports = sorted(
        (issue for issue in issues if issue.status == "Submitted"),
        key=lambda issue: issue.reported_at,
        reverse=True,
    )
    st.subheader(f"New reports · {len(new_reports)}")
    if new_reports:
        for issue in new_reports:
            issue_summary(issue)
    else:
        st.caption("No new reports are waiting for review.")

    st.subheader("Needs attention")
    urgent = [issue for issue in ordered_issues(issues) if issue.severity == "Critical" and issue.status != "Submitted"][:6]
    for issue in urgent:
        issue_summary(issue)
    alert_strip()


def render_campus() -> None:
    page_heading("CAMPUS PULSE", "Live campus map", "OpenStreetMap · campus issues and your current position.")
    issues: list[CampusIssue] = st.session_state.issues
    st.markdown("**Find your current position**")
    live_location = current_browser_location()
    if live_location:
        st.success(
            f"Live GPS fix · ±{live_location['accuracy']:.0f} m · "
            f"{live_location['latitude']:.5f}, {live_location['longitude']:.5f}"
        )
        center = (live_location["latitude"], live_location["longitude"])
    else:
        st.info("Allow browser location access to place your current position on the map. The campus map is still available.")
        center = (20.2968, 85.8242)
    st.caption("Map data © OpenStreetMap contributors")
    render_osm_map(center, issues=issues, live_location=live_location, height=510, key="campus-osm-map")

    building_counts = Counter(issue.building for issue in issues if issue.status != "Resolved")
    zone_col = st.columns(4)
    buildings = (
        "Academic Block A",
        "Academic Block B",
        "Library",
        "Canteen",
        "Hostel A",
        "Hostel B",
        "Administrative Block",
        "Sports Complex",
    )
    for index, building in enumerate(buildings):
        with zone_col[index % 4]:
            st.metric(building, building_counts.get(building, 0), delta="open issues", delta_color="off")
    st.caption("Issue markers are sample campus coordinates. Live GPS is requested only when you grant browser permission.")
    st.subheader("Generate a location QR")
    selected = st.selectbox("Campus location marker", list(LOCATIONS), key="qr-generator-location")
    location = LOCATIONS[selected]
    qr = qrcode.QRCode(box_size=8, border=2)
    qr.add_data(location["code"])
    qr.make(fit=True)
    image = qr.make_image(fill_color="#0B1017", back_color="#FFFFFF")
    output = BytesIO()
    image.save(output, format="PNG")
    left, right = st.columns([1, 3])
    with left:
        st.image(output.getvalue(), width=190)
    with right:
        st.code(str(location["code"]))
        st.caption(f"{location['building']} · {location['floor']} · {location['room']}")
        st.download_button("Download QR image", output.getvalue(), file_name=f"{str(location['code']).lower()}.png", mime="image/png")


def render_analytics() -> None:
    page_heading("INSIGHTS · THIS TERM", "Campus analytics", "Issue trends and resolution health from the demo dataset.")
    issues: list[CampusIssue] = st.session_state.issues
    counts = Counter(issue.category for issue in issues)
    data = pd.DataFrame({"Category": list(counts), "Reports": list(counts.values())}).sort_values("Reports", ascending=True)
    left, right = st.columns([1.4, 1])
    with left:
        st.subheader("Issues by category")
        st.bar_chart(data.set_index("Category"), color=CYAN, horizontal=True)
    with right:
        st.subheader("Severity mix")
        severity_counts = Counter(issue.severity for issue in issues)
        pie = go.Figure(go.Pie(labels=list(severity_counts), values=list(severity_counts.values()), hole=0.68, marker={"colors": [SEVERITY_COLORS[key] for key in severity_counts]}))
        pie.update_layout(height=310, paper_bgcolor=INK, font_color="#F4F7FA", margin={"l": 6, "r": 6, "t": 12, "b": 12}, showlegend=True)
        st.plotly_chart(pie, width="stretch", config={"displayModeBar": False})

    avg_resolution_hours = 5.4
    resolved_count = sum(issue.status == "Resolved" for issue in issues)
    columns = st.columns(3)
    columns[0].metric("RESOLUTION RATE", f"{resolved_count / len(issues):.0%}" if issues else "0%")
    columns[1].metric("AVG. RESOLUTION", f"{avg_resolution_hours:.1f} hrs", help="Illustrative demo statistic")
    columns[2].metric("DUPLICATE REPORTS", sum(max(issue.report_count - 1, 0) for issue in issues))
    st.caption("Resolution-time average is illustrative demo data; it is not computed from a production event store.")


def render_profile() -> None:
    role = st.session_state.role
    account: UserAccount = st.session_state.current_account
    name = account.name
    page_heading("ACCOUNT", "Profile and preferences", "Competition demo access · changes stay in this browser session.")
    with st.container(border=True):
        st.subheader(name)
        st.caption(f"{role.upper()} · {account.email}")
        st.caption(f"{account.institution} · {account.student_id or 'Campus user'}")
        st.caption(f"Phone · {account.phone}")
        st.caption("QuickFix-Campus · Academic campus demo")
    st.toggle("Issue updates", value=True, key="notifications-enabled")
    st.selectbox("Language catalog", ["English", "Hindi", "Odia"], help="ARB catalogs are included; UI translation is not fully wired yet.")
    st.info("Switch roles from the sidebar. Each demo role shares this browser session's issue state.")


def render_updates() -> None:
    page_heading("CAMPUS NOTIFICATIONS", "Updates", "Simulated notification feed for the demo workflow.")
    alert_strip()
    st.write("")
    for issue in sorted(st.session_state.issues, key=lambda item: item.reported_at, reverse=True)[:10]:
        st.markdown(f"**{issue.issue_id} · {issue.status}**  ")
        st.caption(f"{issue.title} · {issue.building} · now")
        st.divider()


def main() -> None:
    initialize_state()
    inject_theme()

    if not st.session_state.is_authenticated:
        render_auth_page()
        return

    role: Role = st.session_state.role

    with st.sidebar:
        brand()
        st.caption(f"{st.session_state.current_user} · {role}")
        st.markdown("---")
        requested_page = st.session_state.pop("_next_nav", None)
        if requested_page in ROLE_PAGES[role]:
            st.session_state.nav = requested_page
        st.radio("WORKSPACE", ROLE_PAGES[role], key="nav", label_visibility="visible")
        st.markdown("---")
        st.markdown(f"<span style='color:{MINT};font-size:11px'>●  QUICKFIX-CAMPUS</span>", unsafe_allow_html=True)
        if role == "Admin" and st.button("Reset issue demo data", use_container_width=True):
            st.session_state.issues = seed_issues()
            st.session_state._next_nav = ROLE_PAGES[role][0]
            st.rerun()
        if st.button("Log out", use_container_width=True):
            st.session_state.is_authenticated = False
            st.session_state.current_user = None
            st.session_state.current_account = None
            st.rerun()

    page = st.session_state.nav
    if role == "Student":
        if page == "Home":
            render_home()
        elif page == "Report an issue":
            render_report()
        elif page == "My issues":
            render_issue_list(mine_only=True)
        elif page == "Campus":
            render_campus()
        else:
            render_profile()
    elif role == "Maintenance":
        if page == "Tasks":
            render_issue_list(staff_only=True)
        elif page == "Campus":
            render_campus()
        elif page == "Updates":
            render_updates()
        else:
            render_profile()
    else:
        if page == "Dashboard":
            render_admin_dashboard()
        elif page == "Issues":
            render_issue_list()
        elif page == "Campus":
            render_campus()
        elif page == "Analytics":
            render_analytics()
        else:
            render_profile()


if __name__ == "__main__":
    main()