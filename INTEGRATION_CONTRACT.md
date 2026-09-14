# Field Photo Prep Team Integration Contract

## Purpose

Protect the boundaries between the Admin dashboard, Android contractor app, Supabase, local offline state, camera/photo storage, background sync, and company-controlled remote photo storage.

This contract does not authorize unfinished roadmap phases. It defines safety rules those phases must preserve once implemented.

## Mandatory reread before integration work

Before changing Supabase/Auth/RLS, local persistence, offline synchronization, reassignment, camera/photo state, background work, remote storage, upload, retry, reconciliation, or cleanup:

1. read `AGENTS.md` completely;
2. read the relevant phase in `docs/ROADMAP.md` completely;
3. read `CHANGE_CONTROL_CONTRACT.md`;
4. read `TESTING_CONTRACT.md`;
5. read `docs/PHASE_STAGING_DOCTRINE.md` when the change depends on real-device/provider evidence or crosses a phase boundary.

Do not substitute memory, a chat summary, earlier-session notes, or assumptions from FPP for these rereads.

If the roadmap does not define the intended cross-system behavior, **STOP. Integration code may not invent it.**

## Authority map

### Supabase is authoritative for

- authenticated user identity;
- organization membership and role;
- server-visible work-order identity/details;
- current server assignment;
- server-approved reassignment request/consent state;
- server field-status state after successful synchronization;
- server-visible photo metadata/sync state once reported.

### Android local persistence is authoritative for

- whether a downloaded WO is available offline on that device;
- locally captured photo files/metadata before server/remote confirmation;
- pending offline field actions not yet accepted by the server;
- pending local photo sync attempts/recovery evidence.

Local pending state must never be falsely presented as already confirmed by Supabase.

### Remote photo storage is authoritative for

- whether a specific remote photo object/file actually exists after confirmed upload;
- its stable remote identity once created/confirmed.

A local queue update alone cannot prove remote success.

## Authentication and authorization

- Supabase Auth owns login identity.
- `organization_id` and application `role` are server-controlled authorization facts.
- Do not authorize from user-editable metadata.
- Android/browser clients use only publishable/public client credentials appropriate for untrusted clients.
- Service-role/secret credentials never ship in Android/browser code.
- RLS/narrow RPCs enforce authorization even if a client UI is modified or bypassed.
- JWT claims can become stale; workflows that depend on changed role/org/revocation must account for token refresh/reauthentication.
- Contractor devices never receive the company Google Drive account password or long-lived company storage credentials.

## Work-order identity

- Team WO UUID is permanent identity.
- WO number/address/work type/instructions/due date are mutable business/display fields, not identity.
- A server-generated WO number and an Admin-provided external number must not replace the permanent UUID.
- Local cached WOs are keyed by Team WO UUID.
- Photo binding uses Team WO UUID, not address text or visible WO number.

## Assignment and receipt

- Assignment is server-authoritative.
- Contractor receipt means the assigned authenticated contractor successfully received/downloaded that assignment and acknowledged it to the server.
- Receipt is tied to the current assignee; reassignment clears/invalidates prior-assignee receipt.
- Repeated receipt acknowledgement must be idempotent.
- `ASSIGNED` work may be reassigned by Admin under the approved server action.
- `IN_PROGRESS` reassignment requires current-contractor consent under the approved flow.
- approval transfers the WO while preserving truthful started-work state;
- decline leaves current assignment unchanged;
- field-complete/cancelled reassignment behavior must follow the roadmap and may not be improvised client-side.

## Offline work-order integration

Phase 3 must define the exact implementation before code is added. Once implemented:

- downloaded assigned WOs persist locally without contractor configuration;
- previously downloaded work remains readable without network after app/process restart;
- offline Start/Complete actions are persisted locally before the UI claims they are queued;
- local pending actions synchronize through narrow server-authorized operations;
- retries are idempotent;
- reconnect must not silently overwrite or erase locally started work;
- remote reassignment/cancellation racing local offline work must surface an approved reconciliation state;
- client-side cache eviction must not remove unresolved started work or unconfirmed photos.

Room is the planned structured local store because Team has multi-WO/offline-state requirements; contractors do not manually configure Room.

## Background-work integration

When background sync is introduced:

- use persistent work only for approved retry/sync tasks;
- background scheduling does not create new business authority;
- a worker must re-read durable state before acting;
- process death/restart must not turn stale in-memory selection into retry authority;
- connectivity returning may trigger eligible work, but must not bypass conflict/uncertainty guards;
- repeated worker execution must be safe/idempotent.

WorkManager is the planned Android mechanism for persistent deferred work where roadmap behavior requires it.

## Camera and local photo integration

Carry forward FPP-proven behavior unless the Team roadmap explicitly changes it:

- reserve permanent photo UUID before capture;
- reserve protected app-private original destination before bytes are accepted;
- one shutter press = one immutable photo identity;
- multi-shot session photos remain bound to the same selected Team WO unless a new session is deliberately started;
- protected original is never overwritten by preparation;
- preparation/network/provider/upload failure cannot destroy an unconfirmed original;
- process restart recovers durable captured photos;
- camera controls do not mutate WO/photo identity or sync state.

## Prepared-copy integration

- prepared/compressed copy is separate from protected original;
- preparation starts only after capture is durably recorded;
- preparation failure leaves the protected original recoverable;
- restart may recreate missing eligible prepared derivatives;
- prepared-copy generation must preserve usable orientation;
- preparation concurrency must not corrupt or redirect photo identity.

## Photo sync/upload integration

The Team upload implementation may differ from FPP's SAF path, but it must preserve the proven safety boundaries:

- every photo retains immutable Team WO identity;
- remote destination is explicit and server/company authorized;
- contractor device does not infer a destination from visible address/folder names;
- remote identity is retained once created/confirmed;
- success is recorded only after remote success is confirmed;
- known-safe failure may retry;
- ambiguous/uncertain remote outcome must not trigger blind duplicate create;
- retry/reconciliation must preserve original photo and destination identity;
- one photo's failure must not corrupt unrelated queue items;
- local original/derivative cleanup occurs only after confirmed remote success and durable local bookkeeping.

## Google Drive/storage boundary

Initial permanent destination is company-controlled HNP Google storage, but Team business data remains Supabase-authoritative.

- Team must not become architecturally inseparable from Google Drive.
- contractors never receive the HNP password or reusable privileged Google credentials;
- upload authorization must be mediated by approved backend/server logic;
- no client may broaden Drive sharing/permissions unless explicitly planned;
- visible folder names are organizational context, not permanent business identity;
- uncertain Drive/API outcomes fail closed until reconciled.

## Cross-system conflict rules

When local and server state disagree:

- do not silently discard locally started work;
- do not silently move photos to a new assignee/WO;
- do not let stale server data erase unconfirmed local evidence;
- do not claim server acceptance before the server accepted it;
- do not invent conflict resolution in UI code;
- surface an approved pending/conflict state until the roadmap-defined rule resolves it.

## Restart/recovery rules

Any integration that can leave work in flight must define restart behavior before implementation:

- what durable record exists before the risky action;
- how an interrupted action is recognized;
- whether retry is safe, unsafe, or requires reconciliation;
- what evidence is retained to avoid duplicates/misattribution;
- when local cleanup becomes safe.

## Reality gates

Mocks/fakes/emulators may prove deterministic logic, but cannot alone prove:

- actual Android offline/restart behavior;
- CameraX/device behavior;
- Android background execution under real lifecycle constraints;
- real remote upload/resume/reconciliation behavior;
- real device storage/provider behavior.

Use `docs/PHASE_STAGING_DOCTRINE.md` to stage only the smallest necessary real-device gate after all provider-independent work is complete.

## Relationship to the governance set

- `AGENTS.md` owns mandatory entry/reread rules.
- `docs/ROADMAP.md` owns approved product behavior and phase gates.
- `CHANGE_CONTROL_CONTRACT.md` owns risk classification, approval, and rollback.
- `TESTING_CONTRACT.md` owns test selection/timing/failure-stop behavior.
- `docs/PHASE_STAGING_DOCTRINE.md` owns evidence-based phase/device staging.

## Governing principle

**No integration boundary may silently change identity, authority, ownership, or the truthfulness of field/photo state.**
