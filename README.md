# VOXGUARD CAMPUS

**Smart Campus QuickFix · Report. Track. Resolve.**

The primary hostable app is a Streamlit browser application. It ships with session-local demo data so a competition walkthrough works without Firebase credentials or a campus network. The earlier Flutter prototype remains under `lib/` but is not used by the Streamlit entry point.

## Run Locally

Requires Python 3.12 or newer.

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
python -m streamlit run streamlit_app.py
```

Open the local URL printed by Streamlit, usually `http://localhost:8501`.

Run the domain tests with:

```powershell
python -m unittest -v test_streamlit_core
```

## Deploy to Streamlit Community Cloud

1. Push this project to a GitHub repository.
2. In Streamlit Community Cloud, create an app from that repository.
3. Set the main file path to `streamlit_app.py`.
4. Deploy. `requirements.txt` and `.streamlit/config.toml` are read automatically.

No secrets are needed for the demo. Keep any future Firebase credentials in Streamlit secrets, never in source control.

## Demo Roles

Choose a role in the sidebar; no login is required:

- **Student:** Maya Patel
- **Maintenance:** Arun Das, Facilities Team B, or Electrical Team
- **Admin:** Campus Admin

All roles in a browser session share the same in-memory demo issues, so the lifecycle can be shown by switching roles. “Reset demo data” restores the seeded state.

## Competition Walkthrough

1. As Student, open **Report an issue**. A Block B ground-floor location is preselected.
2. Add a water-leak description (or insert the demo voice transcript), run AI analysis, and confirm Plumbing / High.
3. Continue to Review and submit. The duplicate prompt finds the seeded Block B leak; choose **Add my report**.
4. Switch to Admin. Verify the submitted issue, set its assignee and confirmed severity, then assign it.
5. Switch to the selected Maintenance identity. Accept the task, add a repair note or image, and mark it resolved.
6. Switch to Student to inspect the status timeline and confirm or reopen the resolution.

The app includes 18 sample reports across eight campus zones, category/severity filters, priority scoring, an OpenStreetMap issue map with a browser GPS marker, category analytics, location QR generation/download, QR-value entry, direct camera capture or photo upload, and deterministic AI fallback suggestions.

## Project Structure

```text
streamlit_app.py          Streamlit UI, browser interactions, and role workspaces
voxguard.py               Typed demo issue model, seed data, AI fallback, priority, transitions
test_streamlit_core.py    Unit tests for issue lifecycle and duplicate behavior
requirements.txt          Streamlit and chart/QR dependencies
.streamlit/config.toml    Hosted app theme and headless server setting
lib/                      Earlier Flutter prototype; not required to run Streamlit
firestore.rules           Firebase rules reference for a future authenticated backend
storage.rules             Firebase rules reference
```

## Data and Integration Boundaries

The Streamlit version stores issue state in `st.session_state`. Changes survive reruns and role switches in the same browser session, but they are not persistent across sessions or shared between different visitors. For multi-user persistence, connect Firestore or another database and use authenticated user identities before deploying beyond a demo.

AI classification is deterministic keyword-based demo logic in `voxguard.py`; replace `classify_issue` with a provider adapter for real image/text analysis. The voice button inserts an editable sample transcript; browser microphone transcription is not connected. Location QR codes can be generated and downloaded, and QR payloads can be pasted into the location workflow; camera-based QR scanning is not available in the Streamlit build. The report workflow and Campus page can request the viewer's current browser GPS position and display it on an OpenStreetMap basemap. The live position is opt-in, stored only in the current Streamlit session, and requires browser permission. Location defaults to the selected sample campus pin if access is denied. Camera capture and geolocation require HTTPS on hosted deployments; localhost is allowed by modern browsers.

OpenStreetMap tiles include attribution in the map. The public tile service is suitable for a competition demo, not high-volume production traffic; production hosting should select a tile provider or service that meets its usage policy.

Firebase Authentication, Firestore/Storage adapters, FCM delivery, multilingual UI wiring, offline synchronization, and production analytics are not active in this Streamlit version. The included Firebase rules are reference configuration only; the Streamlit demo does not call Firebase. Responsive text wrapping is applied to headings, captions, labels, metrics, and buttons to reduce clipping on narrow screens.

## Firebase Reference Schema

An authenticated production backend can use:

- `users/{userId}`
- `issues/{issueId}` with `issueId`, `title`, `description`, `category`, `severity`, `priorityScore`, `status`, `reportedBy`, `reportedAt`, `updatedAt`, `locationId`, `building`, `floor`, `room`, `latitude`, `longitude`, `imageUrls`, `aiCategory`, `aiConfidence`, `duplicateGroupId`, `reportCount`, `assignedStaffId`, `resolutionNote`, `resolvedAt`, and `timeline`
- `locations/{locationId}`, `notifications/{notificationId}`, `campus_alerts/{alertId}`, `duplicate_groups/{groupId}`, `assignments/{assignmentId}`, and `analytics/{documentId}`

Deploy the reference rules only after adding Firebase Authentication and server-side role management. Never let a browser client grant itself the admin role.
