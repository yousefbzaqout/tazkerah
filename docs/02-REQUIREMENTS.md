# Requirements

## 1. Functional Requirements

### FR-001: Dynamic TOTP QR Code Generation

* **Requirement ID:** FR-001
* **Name:** Dynamic TOTP QR Code Generation
* **Description:** The Attendee **Flutter Ticket Vault** must generate dynamic Time-based One-Time Password (TOTP) QR codes offline using a pre-shared cryptographic seed provisioned by the Ticket Issuance engine. The QR encodes an ECDSA P-256–signed ticket payload plus a rotating HMAC-SHA256 TOTP. The QR code must rotate every **20 seconds** (ADR-006).
* **Source:** `docs/00-INTAKE.md` Section 3 (Module 1); ADR-004
* **Preconditions:** User is logged in and an issued ticket payload (ECDSA P-256 signature + TOTP seed) is synced to Flutter secure storage / Isar (or SQLite).
* **Expected Behavior:** The Flutter Ticket Vault renders a QR code encoding the dynamic TOTP payload. Every **20 seconds**, the QR code updates automatically without requiring network connectivity.
* **Exceptions / Failure Behavior:** If seed storage is inaccessible, display an error message and prompt user re-authentication when online.
* **Dependencies:** Ticket Issuance & Cryptographic Signing Engine (T-000)
* **Acceptance Criteria:**
* **AC-001-01:** QR code content changes every 20 seconds based on HMAC-SHA256 TOTP calculation over an ECDSA P-256–signed ticket envelope.
* **AC-001-02:** QR code generation completes successfully when device is completely offline (Airplane mode).
* **AC-001-03:** Visual countdown indicator depicts time remaining in current 20-second cycle.


* **Status:** APPROVED

---

### FR-002: Screenshot Invalidation & User Warning

* **Requirement ID:** FR-002
* **Name:** Screenshot Invalidation & User Warning
* **Description:** The Attendee **Flutter Ticket Vault** must apply platform anti-capture controls on the ticket view. Detecting screenshot/screen-capture class events must immediately invalidate the active TOTP QR code, refresh in-memory TOTP state, and display a security warning toast.
* **Source:** `docs/00-INTAKE.md` Section 3 (Module 1); ADR-004; `docs/03-VALIDATION.md` Decision 1
* **Preconditions:** User navigates to active ticket QR display screen.
* **Expected Behavior:** Capture/screenshot-class events trigger immediate invalidation of the displayed QR and force a refresh so captured static screenshots are unusable. Screen-share / recording attempts obscure or blacken the QR container.
* **Exceptions / Failure Behavior:** If memory refresh fails, app immediately hides the QR view and prompts the user to re-open the ticket.
* **Dependencies:** FR-001
* **Acceptance Criteria:**
* **AC-002-01:** Ticket view applies platform protections that prevent usable capture of the QR surface (blackened/obscured presentation in capture/preview contexts).
* **AC-002-02:** Detected capture/screenshot-class events immediately invalidate the current QR code, render a new TOTP sequence, and show toast: "Screenshot detected: Code refreshed for security."
* **AC-002-03:** Video recording / screen-share attempts obscure or blacken the QR container view.


* **Status:** APPROVED

---

### FR-003: NTP Time Drift Detection & Fallback Mechanism

* **Requirement ID:** FR-003
* **Name:** NTP Time Drift Detection & Fallback Mechanism
* **Description:** The Attendee **Flutter Ticket Vault** must detect device system clock drift exceeding 3 minutes. When detected, the app must present an in-app 8-digit algorithmic offline backup code. Apple/Google Wallet PassKit / `.pkpass` export is out of scope (ADR-005).
* **Source:** `docs/00-INTAKE.md` Section 3 (Module 1); ADR-004; ADR-005
* **Preconditions:** App calculates offset between local RTC and last known NTP network timestamp.
* **Expected Behavior:** If clock drift > 180 seconds, hide the dynamic QR and display an offline fallback screen containing an 8-digit algorithmic fallback code.
* **Exceptions / Failure Behavior:** If fallback code generation fails, direct user to gate supervisor for manual lookup via identity verification.
* **Dependencies:** FR-001
* **Acceptance Criteria:**
* **AC-003-01:** System drift > 180 seconds automatically flags clock skew warning and hides standard dynamic QR code.
* **AC-003-02:** 8-digit algorithmic code is generated using user seed and static epoch anchor.


* **Status:** APPROVED

---

### FR-004: Automatic Screen Brightness Boost

* **Requirement ID:** FR-004
* **Name:** Automatic Screen Brightness Boost
* **Description:** The Attendee **Flutter Ticket Vault** must automatically maximize screen brightness and hold the screen awake when viewing active ticket QR codes to optimize optical scanner reading.
* **Source:** `docs/00-INTAKE.md` Section 3 (Module 1); ADR-004
* **Preconditions:** User opens active ticket view.
* **Expected Behavior:** Device screen brightness boosts to maximum (best-effort). Upon exiting or backgrounding the ticket view, brightness restores and wake lock is released.
* **Exceptions / Failure Behavior:** If platform APIs deny brightness control, display ticket without crashing, keep wake lock if available, and show a subtle prompt asking the user to increase brightness manually.
* **Dependencies:** FR-001
* **Acceptance Criteria:**
* **AC-004-01:** Display brightness increases to maximum (or best-effort Wake Lock + brightness boost) upon ticket view launch.
* **AC-004-02:** Display brightness reverts to initial level and wake lock is released upon navigating away from ticket screen.


* **Status:** APPROVED

---

### FR-005: Asymmetric Cryptographic Verification & Offline Manifest Provisioning

* **Requirement ID:** FR-005
* **Name:** Asymmetric Cryptographic Verification & Offline Manifest Provisioning
* **Description:** **Flutter Gate Scanner** must perform offline verification of dynamic TOTP QR payloads using **ECDSA P-256** public keys stored locally (PointyCastle/native). Devices sync an Event Manifest (Public Keys + Revocation List) online prior to event, or scan a Master Config QR for 100% offline provisioning (ADR-006).
* **Source:** `docs/00-INTAKE.md` Section 3 (Module 2); ADR-004; `docs/03-VALIDATION.md` Decision 3
* **Preconditions:** Tablet pre-synced via online 1-click manifest fetch or Master Config QR scan; tickets issued with ECDSA P-256 signatures (T-000).
* **Expected Behavior:** Dedicated Flutter isolate verifies ECDSA P-256 signature (PointyCastle/native), checks ticket against revoked blacklist, and validates TOTP window in < 50ms without network calls.
* **Exceptions / Failure Behavior:** Corrupted QR or signature matching revoked blacklist returns `INVALID` / `REVOKED` result immediately.
* **Dependencies:** FR-001; Ticket Issuance & Cryptographic Signing Engine (T-000)
* **Acceptance Criteria:**
* **AC-005-01:** 1-Click pre-sync downloads ECDSA P-256 public key and revoked ticket list into local Isar/SQLite.
* **AC-005-02:** Scanning a Master Config QR code provisions keys and blacklist without internet connectivity.
* **AC-005-03:** ECDSA P-256 cryptographic verification executes off UI isolate in < 50ms.


* **Status:** APPROVED

---

### FR-006: Local Anti-Passback Enforcement & Offline Scan Caching

* **Requirement ID:** FR-006
* **Name:** Local Anti-Passback Enforcement & Offline Scan Caching
* **Description:** Upon valid QR scan, Flutter Gate must update the local Isar/SQLite ticket record to `LOCAL_USED` immediately. Subsequent scans of the same ticket must be rejected as duplicate entries.
* **Source:** `docs/00-INTAKE.md` Section 3 (Module 2); ADR-006
* **Preconditions:** Ticket payload verified successfully by cryptographic verifier (FR-005).
* **Expected Behavior:** Local ledger record set to `LOCAL_USED` with scan timestamp and gate ID. Re-scanning same ticket ID triggers `ANTI_PASSBACK_DUPLICATE` error showing original entry time and gate.
* **Exceptions / Failure Behavior:** If local DB transaction fails, lock gate scanner interface (**G3-LOCK** full-bleed storage fault) and raise storage integrity alert; refuse further admits until storage recovers.
* **Dependencies:** FR-005
* **Acceptance Criteria:**
* **AC-006-01:** Ticket state transitions to `LOCAL_USED` in local DB within 20ms of scan.
* **AC-006-02:** Second scan of ticket ID produces `ANTI_PASSBACK_DUPLICATE` state output displaying prior gate and time.
* **AC-006-03:** Scanned records persist in local DB across app restarts.
* **AC-006-04:** If Isar/SQLite write/transaction fails during scan or mesh sync, Gate UI enters **G3-LOCK** hard lockout with storage-integrity alert and refuses further admits until storage recovers.


* **Status:** APPROVED

---

### FR-007: Primary-Secondary Local Mesh Gate Synchronization

* **Requirement ID:** FR-007
* **Name:** Primary-Secondary Local Mesh Gate Synchronization
* **Description:** Gate scanner tablets synchronize scan logs in real-time over a local Wi-Fi router network using WebSocket connections to a Primary Gate Master. Disconnected devices write to an Append-Only local DB log and push updates upon reconnection, resolving conflicts via Timestamp + Device ID.
* **Source:** `docs/00-INTAKE.md` Section 3 (Module 2) & `docs/03-VALIDATION.md` Decision 2
* **Preconditions:** Tablets connected to local gate Wi-Fi access point.
* **Expected Behavior:** Scan events stream to Primary Node and broadcast to Secondary tablets in < 200ms. Disconnections trigger local caching; reconnection flushes local Append-Only logs to Primary Node for deterministic timestamp-based ordering.
* **Exceptions / Failure Behavior:** If Primary Master node drops, operator can manually toggle any Secondary tablet to operate as Primary Master Node.
* **Dependencies:** FR-006
* **Acceptance Criteria:**
* **AC-007-01:** Scan log at Gate A propagates to Gate B in < 200ms over local Wi-Fi WebSocket.
* **AC-007-02:** Reconnecting tablet flushes Append-Only log to Primary Node without losing scan records.
* **AC-007-03:** Conflicting offline scans of same ticket are resolved deterministically by earliest timestamp + device ID.
* **AC-007-04:** Operator can toggle a Secondary tablet to Primary Master when the previous Primary is unavailable (manual Primary election).


* **Status:** APPROVED

---

### FR-008: Peripheral Visual, Audio, and Haptic Gate Feedback

* **Requirement ID:** FR-008
* **Name:** Peripheral Visual, Audio, and Haptic Gate Feedback
* **Description:** Gate scanner interface must provide unambiguous peripheral feedback using full-screen background color flashes, audio chimes, and haptic vibration patterns.
* **Source:** `docs/00-INTAKE.md` Section 3 (Module 2)
* **Preconditions:** Scan result evaluated (`VALID`, `ANTI_PASSBACK`, or `INVALID`).
* **Expected Behavior:**
* **VALID:** Full-screen green flash (`#10B981`) for 600ms, high-pitch beep, single haptic click. Screen auto-resets.
* **ANTI_PASSBACK:** Full-screen red flash (`#EF4444`), double low-tone chime, continuous haptic vibration. UI freezes 2 seconds showing entry gate/time.
* **INVALID:** Full-screen amber flash (`#F59E0B`), repeating error tone. Display "Wrong Event / Unregistered".


* **Exceptions / Failure Behavior:** If audio playback is blocked by OS/device policy on Flutter Gate, revert gracefully to visual flash and haptics without crashing.
* **Dependencies:** FR-005, FR-006
* **Acceptance Criteria:**
* **AC-008-01:** Valid scan turns full background `#10B981` for 600ms and triggers high-pitch audio.
* **AC-008-02:** Anti-passback scan turns background `#EF4444`, locks screen for 2s, and displays prior scan metadata.
* **AC-008-03:** Invalid scan turns background `#F59E0B` with repeating error tone.
* **AC-008-04:** When audio is blocked by device policy, visual + haptic feedback still complete without crash.


* **Status:** APPROVED

---

### FR-009: Built-in Camera Scan Path & Manual 8-Digit Backup Entry

* **Requirement ID:** FR-009
* **Name:** Built-in Camera Scan Path & Manual 8-Digit Backup Entry
* **Description:** Flutter Gate Scanner must accept QR input from the device **built-in camera** and provide an emergency manual modal for typing 8-digit algorithmic backup codes. External USB/Bluetooth HID barcode readers are out of scope (ADR-005).
* **Source:** `docs/00-INTAKE.md` Section 3 (Module 2); ADR-005; ADR-006
* **Preconditions:** Gate operator opens scanner view.
* **Expected Behavior:** Camera frames are decoded off UI isolate and fed into the ECDSA P-256 verification pipeline. "Manual Entry" opens numeric keypad for 8-digit backup into the same offline path.
* **Exceptions / Failure Behavior:** Invalid manual code format (<8 digits) displays validation error instantly.
* **Dependencies:** FR-005, FR-006
* **Acceptance Criteria:**
* **AC-009-01:** Built-in camera decode path triggers verification pipeline identical to manual entry confirmation.
* **AC-009-02:** Manual keypad modal accepts 8-digit code and validates against local offline backup algorithm.


* **Status:** APPROVED

---

### FR-010: Atomic Redis Seat Holding Engine

* **Requirement ID:** FR-010
* **Name:** Atomic Redis Seat Holding Engine
* **Description:** High-concurrency seat reservation engine must execute Redis Lua scripts (`SET NX PX 600000`) for atomic 10-minute seat holds during flash sales.
* **Source:** `docs/00-INTAKE.md` Section 3 (Module 3)
* **Preconditions:** Attendee initiates seat hold request.
* **Expected Behavior:** Redis Lua script atomically checks seat availability and sets lock key with 600,000 ms TTL. Success returns HTTP 200 with hold token; collision returns HTTP 409 Conflict in < 5ms without querying PostgreSQL.
* **Exceptions / Failure Behavior:** If Redis connection is lost, surface a degraded-mode error and rely on Standalone Redis AOF restart recovery (ADR-003); no Sentinel/cluster failover topology in MVP.
* **Dependencies:** None
* **Acceptance Criteria:**
* **AC-010-01:** Concurrent hold requests for same seat ID result in exactly 1 success and N-1 HTTP 409 Conflicts.
* **AC-010-02:** Successful lock sets Redis key with precisely 10-minute TTL.
* **AC-010-03:** Conflict response returns in < 5ms.


* **Status:** APPROVED

---

### FR-011: Checkout Payment TTL Extension & Keyspace Expiration

* **Requirement ID:** FR-011
* **Name:** Checkout Payment TTL Extension & Keyspace Expiration
* **Description:** Upon payment gateway dispatch, system extends Redis hold TTL by +3 minutes (180,000 ms). If payment fails or times out, Redis Keyspace Notifications release seat hold automatically.
* **Source:** `docs/00-INTAKE.md` Section 3 (Module 3)
* **Preconditions:** Seat hold active in Redis (`HELD` state).
* **Expected Behavior:** Initiating payment checkout extends TTL. Expired TTL triggers key expiration listener, clearing lock and broadcasting seat release event to subscribers.
* **Exceptions / Failure Behavior:** Payment gateway webhook failure triggers automated background reconciler job to verify payment status before releasing hold.
* **Dependencies:** FR-010
* **Acceptance Criteria:**
* **AC-011-01:** Payment dispatch call increases remaining Redis key TTL by 180,000 ms.
* **AC-011-02:** Redis key expiration triggers SSE event emitting seat state transition to `AVAILABLE`.
* **AC-011-03:** Completed payment converts seat state permanently to `SOLD` in PostgreSQL database.


* **Status:** APPROVED

---

### FR-012: Live 60/40 Split-View Telemetry Dashboard

* **Requirement ID:** FR-012
* **Name:** Live 60/40 Split-View Telemetry Dashboard
* **Description:** Organizer dashboard must present a 60% left panel featuring an interactive WebGL Canvas seat map (60 FPS) and a 40% right panel displaying real-time SSE telemetry (sales velocity, Redis latency, rate limiting metrics, audit stream).
* **Source:** `docs/00-INTAKE.md` Section 3 (Module 3)
* **Preconditions:** Organizer authenticated with event administrative permissions.
* **Expected Behavior:** WebGL canvas renders 5,000+ seat statuses in real-time driven by SSE events without DOM degradation. Right telemetry panel updates metrics (tix/sec, revenue, P95 latency) dynamically.
* **Exceptions / Failure Behavior:** If SSE connection drops, automatically attempt reconnection with exponential backoff while showing reconnection badge.
* **Dependencies:** FR-010, FR-011
* **Acceptance Criteria:**
* **AC-012-01:** Seat map canvas renders at stable 60 FPS during 1,000 req/s incoming event updates.
* **AC-012-02:** Left/Right screen proportion strictly maintains 60% Canvas / 40% Telemetry ratio.
* **AC-012-03:** SSE audit stream displays real-time key logs (`[TIMESTAMP] Seat X released via TTL`).


* **Status:** APPROVED

---

### FR-013: Emergency Sector Hold and Lock Control (Block New Holds Only)

* **Requirement ID:** FR-013
* **Name:** Emergency Sector Hold and Lock Control (Block New Holds Only)
* **Description:** Organizer dashboard must allow single-click sector-level locking (Emergency Sector Lock). Locking a sector blocks all new incoming seat hold attempts immediately while preserving active existing `HELD` and `CHECKOUT` sessions until their TTL expires or payment completes.
* **Source:** `docs/00-INTAKE.md` Section 3 (Module 3) & `docs/03-VALIDATION.md` Decision 4
* **Preconditions:** Organizer selects venue sector on WebGL canvas map.
* **Expected Behavior:** Clicking "Lock Sector" persists `sectors.is_locked = true` in PostgreSQL (**SoT**) then sets Redis cache `sector:{id}:locked`. New hold attempts return HTTP 423 Locked. Active checkouts proceed normally.
* **Exceptions / Failure Behavior:** If DB or Redis sync fails after a partial write, rollback/repair to keep DB and Redis consistent and notify operator.
* **Dependencies:** FR-010, FR-012
* **Acceptance Criteria:**
* **AC-013-01:** Emergency lock persists PostgreSQL `sectors.is_locked` and syncs Redis `sector:{id}:locked` within < 50ms end-to-end.
* **AC-013-02:** New hold requests within locked sector return HTTP 423 Locked immediately.
* **AC-013-03:** Active checkout sessions in locked sector complete payment successfully without cancellation.


* **Status:** APPROVED

---

### FR-014: RAG-Powered AI Concierge for Event Inquiries

* **Requirement ID:** FR-014
* **Name:** RAG-Powered AI Concierge for Event Inquiries
* **Description:** The system must provide an AI Concierge chat interface utilizing PostgreSQL `pgvector` with HNSW indexing to answer attendee event inquiries with zero hallucination.
* **Source:** `docs/00-INTAKE.md` Section 3 (Module 4)
* **Preconditions:** Event policy and FAQ knowledge base embedded and indexed in `pgvector`.
* **Expected Behavior:** User query undergoes vector search. Matching document chunks populate LLM prompt context. System returns factual response with ground truth verification score.
* **Exceptions / Failure Behavior:** If vector retrieval confidence < 0.85, prompt user to connect with human support desk.
* **Dependencies:** None
* **Acceptance Criteria:**
* **AC-014-01:** Inquiry retrieves relevant policy context from `pgvector` HNSW index.
* **AC-014-02:** Retrieval confidence < 0.85 renders "Talk to Human Support" button.
* **AC-014-03:** Response includes verified Grounding Confidence badge.


* **Status:** APPROVED

---

### FR-015: Real-Time Hybrid Tool Calling for AI State Queries

* **Requirement ID:** FR-015
* **Name:** Real-Time Hybrid Tool Calling for AI State Queries
* **Description:** AI Concierge must route queries regarding live data (seat availability, ticket prices, gate locations) to backend function calls (Redis/PostgreSQL) rather than generating text from static LLM weights.
* **Source:** `docs/00-INTAKE.md` Section 3 (Module 4)
* **Preconditions:** User asks a dynamic state question (e.g., "Are VIP seats available?").
* **Expected Behavior:** LLM emits structured tool call function execution. Engine queries Redis/PostgreSQL and returns formatted Rich Action Card (e.g., Mini Seat Map Widget).
* **Exceptions / Failure Behavior:** Tool execution timeout (>2s) causes AI to report temporary state check unavailability gracefully.
* **Dependencies:** FR-010, FR-014
* **Acceptance Criteria:**
* **AC-015-01:** Seat inquiry triggers function call executing SQL/Redis lookup.
* **AC-015-02:** Output renders interactive Rich Action Card with live price/seat data.


* **Status:** APPROVED

---

### FR-016: Multi-Tenant Isolation and PostgreSQL Row-Level Security

* **Requirement ID:** FR-016
* **Name:** Multi-Tenant Isolation and PostgreSQL Row-Level Security
* **Description:** Platform must enforce strict multi-tenant data isolation using Global Scopes and PostgreSQL Row-Level Security (RLS) based on tenant context.
* **Source:** `docs/00-INTAKE.md` Section 3 (Module 4)
* **Preconditions:** Request executed within authenticated tenant context (`tenant_id`).
* **Expected Behavior:** Database queries automatically restrict read/write access to records matching session `tenant_id` via PostgreSQL RLS policies, with Eloquent Global Scopes as application defense-in-depth.
* **Exceptions / Failure Behavior:** Cross-tenant or missing-tenant access **fails closed**: queries return an empty result set and writes affect **0 rows** (or are rejected by RLS `WITH CHECK`). Phase-1 does **not** require a separate security-exception throw or audit-violation log sink. Per-request `SET LOCAL app.current_tenant_id` is owned by **`F-004`**.
* **Dependencies:** None
* **Acceptance Criteria:**
* **AC-016-01:** Query execution without valid `tenant_id` session context returns empty result set or error.
* **AC-016-02:** Organizer A cannot view or manipulate Organizer B's events, seats, or scan logs.


* **Status:** APPROVED

---

## 2. Non-Functional Requirements

### NFR-001: Peak Flash Sale Concurrency & Throughput

* **Requirement ID:** NFR-001
* **Name:** Peak Flash Sale Concurrency & Throughput
* **Description:** Seat hold transaction engine must process 1,000+ incoming reservation requests per second during peak flash sales without database connection pool exhaustion.
* **Source:** `docs/00-INTAKE.md` Section 4
* **Preconditions:** Simulated load test generating 1,000 HTTP POST hold requests/sec.
* **Expected Behavior:** System handles 1,000 req/s maintaining HTTP 200/409 responses with zero unhandled HTTP 500 server errors.
* **Exceptions / Failure Behavior:** Excess traffic above threshold triggers rate limiting (HTTP 429) via NGINX / Redis rate limiter.
* **Dependencies:** FR-010
* **Acceptance Criteria / Verification:**
* **AC-NFR-001-01:** Load test sustains 1,000 req/s throughput for 15 consecutive minutes with zero database deadlock errors.
* **AC-NFR-001-02:** Active PostgreSQL database connection count remains bounded by Phase-1 `max_connections=100` (dev/staging) and PHP-FPM worker sizing. PgBouncer is deferred to Phase-2 Production Scaling / High-Concurrency Flash Sale Profile.


* **Status:** APPROVED

---

### NFR-002: Redis Seat Lock Execution Latency

* **Requirement ID:** NFR-002
* **Name:** Redis Seat Lock Execution Latency
* **Description:** Redis Lua script execution for seat hold check and conflict response must execute in < 5ms.
* **Source:** `docs/00-INTAKE.md` Section 4
* **Preconditions:** Standalone Redis operational with peak key load.
* **Expected Behavior:** Hold check returning success or HTTP 409 conflict resolves within 5ms.
* **Exceptions / Failure Behavior:** Script execution exceeding 10ms triggers slow log alert in Redis monitor.
* **Dependencies:** FR-010
* **Acceptance Criteria / Verification:**
* **AC-NFR-002-01:** P99 execution duration for Redis Lua seat hold script is < 5ms under 1,000 req/s load.


* **Status:** APPROVED

---

### NFR-003: API Checkout P95 Response Latency

* **Requirement ID:** NFR-003
* **Name:** API Checkout P95 Response Latency
* **Description:** End-to-end API response time for checkout initialization must maintain P95 latency < 180ms.
* **Source:** `docs/00-INTAKE.md` Section 4
* **Preconditions:** Client submits checkout payload for held seat.
* **Expected Behavior:** Checkout endpoint processes request, extends Redis TTL, and returns payment gateway checkout URL in < 180ms at P95.
* **Exceptions / Failure Behavior:** Requests taking > 500ms log APM trace for performance bottleneck inspection.
* **Dependencies:** FR-011
* **Acceptance Criteria / Verification:**
* **AC-NFR-003-01:** Benchmark test of 10,000 checkout requests yields P95 latency < 180ms.


* **Status:** APPROVED

---

### NFR-004: Gate Verification End-to-End Latency

* **Requirement ID:** NFR-004
* **Name:** Gate Verification End-to-End Latency
* **Description:** End-to-end gate scan process (camera frame capture → Flutter isolate ECDSA verification → local DB write → visual flash feedback) must complete in < 400ms.
* **Source:** `docs/00-INTAKE.md` Section 4
* **Preconditions:** Gate app running on target tablet hardware.
* **Expected Behavior:** Total time elapsed from QR detection to screen color flash is < 400ms. Isolate crypto execution strictly < 50ms.
* **Exceptions / Failure Behavior:** Frame processing delay > 400ms drops frame and retries next video frame automatically.
* **Dependencies:** FR-005, FR-006, FR-008
* **Acceptance Criteria / Verification:**
* **AC-NFR-004-01:** Measured scan-to-color-flash latency is < 400ms across 100 sample scans on standard tablet hardware.
* **AC-NFR-004-02:** Isolated ECDSA P-256 cryptographic verification time is < 50ms.


* **Status:** APPROVED

---

### NFR-005: High Availability & Database Connectivity

* **Requirement ID:** NFR-005
* **Name:** High Availability & Database Connectivity
* **Description:** Backend must connect **directly** to PostgreSQL in Phase-1 (Laravel PDO, native prepared statements) with `max_connections=100` on dev/staging profiles, and use a **Standalone Redis** instance with Append-Only File (AOF) persistence to prevent seat-hold data loss (ADR-003). Redis Sentinel/Cluster is out of MVP scope. **PgBouncer is deferred to Phase-2** Production Scaling / High-Concurrency Flash Sale Profile.
* **Source:** `docs/00-INTAKE.md` Section 4; ADR-003
* **Preconditions:** Full system deployment on Phase-1 infrastructure.
* **Expected Behavior:** Laravel PHP-FPM opens direct PostgreSQL sessions; connection count stays within Postgres `max_connections=100` under Phase-1 sizing. Redis AOF logs every write for durability. Process restart recovers hold state from AOF.
* **Exceptions / Failure Behavior:** Standalone Redis process crash/restart reloads AOF with interruption under 3 seconds.
* **Dependencies:** FR-010, FR-016
* **Acceptance Criteria / Verification:**
* **AC-NFR-005-01:** Simulated Standalone Redis process restart recovers via AOF reload with interruption under 3 seconds.
* **AC-NFR-005-02:** Under Phase-1 load, PostgreSQL active connections remain within `max_connections=100` despite concurrent client threads (bounded by PHP-FPM workers).


* **Status:** APPROVED

---

### NFR-006: Gate Tablet Local Storage Footprint & Schema Efficiency

* **Requirement ID:** NFR-006
* **Name:** Gate Tablet Local Storage Footprint & Schema Efficiency
* **Description:** Flutter Gate local DB schema (Isar/SQLite) must store ticket scan records at ~120 Bytes per record, ensuring 50,000 ticket records occupy < 6 MB storage space.
* **Source:** `docs/00-INTAKE.md` Section 4; ADR-006
* **Preconditions:** Gate tablet local storage initialized.
* **Expected Behavior:** 50,000 ticket pre-loads plus scan status records consume less than 6 MB of local storage.
* **Exceptions / Failure Behavior:** Storage utilization exceeding 80% of device quota triggers keymap compaction.
* **Dependencies:** FR-006
* **Acceptance Criteria / Verification:**
* **AC-NFR-006-01:** Local dataset containing 50,000 full ticket verification keys measures < 6.0 MB.


* **Status:** APPROVED

---

### NFR-007: OLED Dark Theme Design Token Compliance

* **Requirement ID:** NFR-007
* **Name:** OLED Dark Theme Design Token Compliance
* **Description:** Next.js web commerce, Flutter Ticket Vault, Flutter Gate Scanner, and Organizer Dashboard must strictly implement the "Neon Obsidian" dark theme color tokens (`#090A0F` base background, `#FFFFFF` QR plate, `#10B981` active accent, `#EF4444` anti-passback, `#F59E0B` warning) for OLED power saving and low-light venue visibility.
* **Source:** `docs/00-INTAKE.md` Section 5; ADR-006
* **Preconditions:** UI components rendered.
* **Expected Behavior:** Theme tokens enforced across all primary view screens (CSS on web; Flutter theme on mobile).
* **Exceptions / Failure Behavior:** Automated visual regression test flags non-conforming color values.
* **Dependencies:** FR-001, FR-008, FR-012
* **Acceptance Criteria / Verification:**
* **AC-NFR-007-01:** Primary background color evaluates to `#090A0F`.
* **AC-NFR-007-02:** Active status elements utilize accent `#10B981`.


* **Status:** APPROVED

---

## 3. Actors

| Actor ID | Actor Name | Role & Scope | Key Interactions |
| --- | --- | --- | --- |
| **ACT-01** | **Sami** | Event Attendee | Purchases on Next.js web (A1–A6); opens Flutter Ticket Vault via **VL** login; displays offline dynamic TOTP QR (A7–A8); uses 8-digit backup when clock drift exceeds threshold. |
| **ACT-02** | **Khalid** | Gate Operator | Scans QR codes offline via Flutter Gate Scanner (G1–G4, **G3-LOCK** on storage fault), monitors peripheral flashes, uses manual keypad. |
| **ACT-03** | **Sara** | Event Organizer | Signs in (**ORG-AUTH**), views **ORG-60/40** telemetry dashboard, triggers **ORG-LOCK** emergency sector locks. |
| **ACT-04** | **AI Concierge** | Virtual Assistant | Responds to attendee inquiries via RAG (`pgvector`) and function calls for live seat availability. |
| **ACT-05** | **Super Admin** | System Administrator | Phase-1 **Zero-UI**: provisions tenants and rotates master keys via **Artisan CLI** + authenticated **REST/OpenAPI** only — **no** Super Admin UI screens. |

---

## 4. Business Rules

* **BR-001 (TOTP Rotation Period):** Dynamic QR TOTP codes are valid for exactly 20 seconds. Past TOTP tokens within a ±1 window (20s grace) are accepted for gate scan tolerance.
* **BR-002 (Single Entry Anti-Passback):** A ticket ID marked `LOCAL_USED` or `SOLD_USED` cannot be used for entry again. Subsequent scan attempts must be blocked immediately.
* **BR-003 (Seat Lock Hold TTL):** Initial Redis seat holds expire after 600,000 ms (10 minutes). Transition to checkout extends TTL by 180,000 ms (3 minutes).
* **BR-004 (Clock Drift Threshold):** System clock skew > 180 seconds relative to NTP anchor disables TOTP QR display and forces offline 8-digit algorithmic code fallback.
* **BR-005 (P2P Primary-Secondary Mesh Sync):** Secondary gate scan logs must sync to Primary Gate Master over local Wi-Fi within 200 ms. Conflicting offline records resolve deterministically by Timestamp + Device ID.
* **BR-006 (AI Grounding Confidence Threshold):** If AI Concierge document retrieval confidence is < 0.85, the assistant must display a direct link to human customer support.
* **BR-007 (Ticket Issuance Timing):** The `tickets` database row and TOTP seed envelope are created **atomically only** upon successful payment confirmation when the seat transitions to `SOLD`. `HELD` / `CHECKOUT` manipulate seats and Redis holds only. Checkout session `PAID` is not a seat/ticket enum.
* **BR-008 (Sector Lock Dual-Layer):** PostgreSQL `sectors.is_locked` is persistent SoT; Redis `sector:{id}:locked` is the hold-path cache. Lock/unlock writes DB first, then syncs Redis.

---

## 5. Constraints

* **CST-001 (Tech Stack):**
* Backend: **Laravel 13** (PHP-FPM; **no Octane/Swoole**), **PHP 8.4+** (minimum PHP 8.3), PostgreSQL **18** (`pgvector`/HNSW; **direct** Phase-1 connectivity), **Standalone Redis 8.x** (Lua, Keyspace Notifications, AOF, Horizon). PgBouncer deferred to Phase-2.
* Frontend Web: **Next.js 16** (Attendee A1–A6 + Organizer **ORG-AUTH** / **ORG-60/40** / **ORG-LOCK**) on **Node.js 20.9+**; Web Crypto API (**ECDSA P-256**) where needed.
* Mobile Native: **Flutter** iOS/Android — Attendee Ticket Vault (**VL**, A7–A8) + Gate Scanner (G1–G4, **G3-LOCK**); PointyCastle/native ECDSA P-256 + HMAC-SHA256 TOTP; Isar/SQLite offline store (ADR-006).
* Super Admin Phase-1: **Zero-UI** — Artisan + OpenAPI only (`T-SA-01`).
* Browsers (Web): Chrome 111+ / Edge 111+ / Firefox 111+ / Safari 16.4+.


* **CST-002 (Offline Execution Environment):** Flutter gate scanning and ticket vault rendering must operate 100% without active internet (after sync).
* **CST-003 (Design Tokens):** Neon Obsidian (`#090A0F` base, `#FFFFFF` QR plate, `#10B981` accent, `#EF4444` alert, `#F59E0B` warning).
* **CST-004 (Cryptography):** Ticket payloads signed with **ECDSA P-256**. Dynamic codes use **HMAC-SHA256 TOTP** (**20s**). Ed25519 and RSA are prohibited.

---

## 6. External Contracts

* **EXT-001 (Payment Gateway API):** External payment gateway handling checkout session webhooks. System must extend Redis TTL by 3 minutes upon dispatching user to payment gateway.
* **EXT-002 (NTP Network Time Servers):** Periodic background time synchronization endpoint when network connectivity is available.

*Note:* Apple/Google Wallet / PassKit (`.pkpass`) is **out of scope** for MVP (ADR-005).

---

## 7. Requirement Dependencies

```text
Ticket Issuance / ECDSA P-256 Signing (T-000)
        │
        ▼
FR-001 (Dynamic TOTP) ◄─── FR-002 (Screenshot Invalidation)
                      ◄─── FR-003 (NTP Time Drift Fallback)
                      ◄─── FR-004 (Screen Brightness)
                      ◄─── FR-005 (ECDSA P-256 Gate Scan & Provisioning) ◄─── FR-006 (Local Anti-Passback) ◄─── FR-007 (Primary-Secondary Mesh Sync)
                                                                            ◄─── FR-008 (Peripheral Visual/Audio)
                                                                            ◄─── FR-009 (Camera / Manual Entry)

FR-010 (Redis Seat Engine) ◄─── FR-011 (Checkout TTL & Expiration)
                           ◄─── FR-012 (60/40 Split Dashboard)
                           ◄─── FR-013 (Emergency Sector Lock - Block New Holds)
                           ◄─── FR-015 (AI Hybrid Tool Calling) ◄─── FR-014 (RAG AI Concierge)

```

---

## 8. Requirement Conflicts

* *Resolved.* HID vs camera-only, PassKit exclusion, Redis Standalone, ECDSA P-256, and **Tri-Stack clients (Laravel + Next.js + Flutter)** are closed by ADRs 003–**006**.

---

## 9. Unresolved Requirements

* *Zero Unresolved Requirements.* All functional and non-functional requirements are fully resolved, classified, and approved against the ADR baseline.

---

## 10. Requirement Completion Assessment

* **Total Requirements Count:** 23 Requirements (16 Functional, 7 Non-Functional).
* **Acceptance Criteria Coverage:** 100% (Every FR and NFR has distinct, testable, numbered Acceptance Criteria aligned to ADR MVP).
* **Status Summary:** 23 APPROVED (100% Approval Rate).
* **Assessment Verdict:** Requirements are structured, atomic, testable, aligned with Architecture ADRs, and **APPROVED / Baseline-Ready**.
