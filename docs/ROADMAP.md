# Field Photo Prep Team — Master Implementation Roadmap

Planning status: **DRAFT FOR OPERATOR REVIEW — PHASE 3 RUNTIME WORK IS NOT YET AUTHORIZED**

This is the authoritative product/implementation roadmap for Field Photo Prep Team. It intentionally combines the product path, protected behavior, phase boundaries, failure rules, verification strategy, and physical-device gates in one place so a future work session cannot begin from an incomplete phase description.

The existing single-user Field Photo Prep (`timbone72-CC/field-photo-prep`) remains separate, working, and read-only to Team development.

## First finish line

The first Team version succeeds when:

**Admin creates and assigns a work order on a PC/laptop → the contractor receives it on Android → the assignment remains usable without internet → the contractor takes/protects photos offline → field completion and photo state survive restart → photo upload resumes safely when permitted connectivity returns → the office can distinguish field-complete work from photos still waiting/failed/uncertain → confirmed photos reach company-controlled HNP storage without loss, wrong destination, or blind duplicates.**

## Governing build rule

Build the smallest architecture that safely performs the real workflow.

Do not add tools, screens, settings, roles, services, frameworks, or abstractions merely because they may be useful someday. Safety-critical complexity is not bloat when it is required to protect assignment ownership, offline work, photo evidence, authorization, remote identity, or duplicate prevention.

`AGENTS.md`, `CHANGE_CONTROL_CONTRACT.md`, `TESTING_CONTRACT.md`, `INTEGRATION_CONTRACT.md`, and `docs/PHASE_STAGING_DOCTRINE.md` govern how this roadmap may be implemented.

**Mandatory phase gate:** if the phase does not define behavior, failure handling, protected boundaries, verification, and its completion gate, implementation stops and planning is the work.

---

# FPP → Team transfer baseline

Field Photo Prep is both a proven field-workflow template and the proven development-process template. Team carries forward the behavior that earned its keep, adapts the pieces that are genuinely different in a multi-user/server-authorized product, and deliberately leaves behind FPP mechanisms that do not belong in Team.

## Carry forward as protected behavior

The following FPP behavior is the default Team behavior unless a later approved roadmap change explicitly replaces it:

- plan before coding;
- mandatory contract/phase rereads at work-session and phase boundaries;
- isolated branch + proportional change classification;
- focused tests while developing, then one complete automated suite on the final runtime head;
- build as far as automated evidence can honestly prove, then stop once at the next genuine physical-device/provider boundary;
- safe disposable fixtures instead of live field data;
- permanent photo UUID before capture;
- app-private protected original before camera bytes are accepted;
- one shutter press = one independent protected-photo transaction;
- immutable work-order binding for every captured photo;
- multi-shot in-app CameraX session ending with **Done** rather than bouncing through an accept/select loop for every photo;
- capture works with no internet;
- non-empty capture data is preserved even when a callback/lifecycle path is abnormal;
- protected original and prepared upload copy are separate;
- automatic background preparation only after capture is durably safe;
- prepared copy policy initially remains the proven FPP baseline: JPEG, maximum long edge 2048 px, quality 85, no upscaling, corrected usable orientation;
- preparation is serialized and failure never invalidates a durable capture;
- restart recovery for interrupted capture/preparation/queue work;
- meaningful queue states: `WAITING`, `UPLOADING`, `FAILED`, `UNCERTAIN`, `UPLOADED`, with local `CAPTURING` while a shutter transaction is incomplete;
- exact remote destination and remote identity are never inferred from a visible name once stable identity exists;
- uncertain remote outcome fails closed and is reconciled before another create/retry;
- deterministic photo naming derived from the photo UUID;
- one photo's failure does not corrupt unrelated photos;
- remote success must be durable before local originals/derivatives are eligible for cleanup;
- confirmed remote evidence needed for duplicate prevention is retained even after local image cleanup;
- the app is not a permanent local photo gallery;
- physical-device observations are recorded once and reused rather than repeatedly retested for reassurance.

## Adapt for Team

These FPP ideas remain, but their implementation changes because Team has multiple users, server-side authorization, assignment changes, and centralized HNP storage:

- FPP lightweight `.properties` persistence → **Room structured local persistence** for cached work orders, offline actions, local photo records, and sync evidence;
- FPP operator-selected SAF Drive tree → **company-controlled server-mediated remote storage**;
- FPP provider document IDs as work-order business destination → **Team WO UUID is business identity; server-stored Drive folder/file IDs are remote archive identity**;
- FPP manual per-device Drive account/provider selection → contractor phone receives no HNP Drive password or reusable privileged storage credential;
- FPP foreground/manual upload flow → Team may use **WorkManager** for approved persistent network synchronization while preserving the same fail-closed queue rules;
- FPP current-address/current-work-order local selection → Team assignment comes from Supabase and the cached WO is keyed by immutable Team WO UUID;
- FPP remote folder discovery by visible name → Team remote objects should be tagged/searchable by Team UUID metadata where the storage API permits it;
- FPP direct remote provider reconciliation → Team can use a trusted backend/Edge Function plus the Drive API to reconcile remote identity without giving the contractor privileged credentials.

## Do not carry forward

The following FPP mechanisms are intentionally **not** Team requirements:

- contractor selecting the HNP Drive account/folder through Android's system folder picker;
- SAF persisted tree grants on contractor phones;
- contractor-side Drive folder discovery/create/reuse/Clear & Reuse;
- using address text, folder names, WO numbers, or timestamps as permanent Team identity;
- FPP's file-per-record persistence model when Team now has a demonstrated structured/offline database requirement;
- external-camera accept/retake workflow that FPP already replaced with its proven CameraX multi-shot workflow;
- a permanent in-app photo library;
- route optimization, payroll, invoicing, accounting, OCR/AI classification, continuous location tracking, time tracking, video, or unrelated property-preservation features.

---

# Global authority and identity model

## Permanent identities

- Organization: UUID.
- Auth user: Supabase Auth UUID.
- Work order: Team WO UUID.
- Photo: UUID generated on the phone before capture.
- Remote Drive folder/file: Drive ID stored separately after creation/resolution.

Display/business fields such as address, WO number, work type, due date, folder name, filename, contractor email, and visible status labels are not permanent identity.

## Authority map

### Supabase is authoritative for

- authenticated user identity;
- organization and role;
- current server assignment;
- server-visible WO fields;
- reassignment request/consent state;
- accepted server field status/timestamps;
- server-visible photo metadata and remote sync result once synchronized.

### Room/app-private storage is authoritative for

- whether a previously downloaded WO is available offline on that device;
- pending offline field actions not yet accepted by Supabase;
- locally captured original/prepared photo bytes before remote confirmation;
- local queue/retry/reconciliation evidence;
- local conflict evidence that must not be silently erased.

Local pending state must never be displayed as if Supabase already accepted it.

### Google Drive/HNP remote storage is authoritative for

- whether the final remote photo object actually exists after confirmation;
- exact confirmed remote folder/file identity.

A local state update or HTTP request by itself cannot prove remote success.

## Work-order server field states

Keep the durable server model small:

`ASSIGNED → IN_PROGRESS → FIELD_COMPLETE`

`CANCELLED` remains separate.

Do not turn photo upload state into extra WO field states.

## Local offline overlay

The phone may need local-only state in addition to the server snapshot, for example:

- no pending field action;
- start queued/offline-started;
- completion queued/offline-complete;
- conflict / server decision required.

These are synchronization facts, not replacements for the server field status.

## Photo states

Local capture may temporarily use `CAPTURING`.

Normal sync model:

`WAITING → UPLOADING → UPLOADED`

with:

- `FAILED` for a known retry-safe failure;
- `UNCERTAIN` for an ambiguous outcome that may have created remote state and therefore must not be blindly retried.

## Field completion vs photo completion

Field work and photo synchronization are deliberately separate facts.

A WO can be `FIELD_COMPLETE` while photos are still `WAITING`, `UPLOADING`, `FAILED`, or `UNCERTAIN`.

A dashboard may derive a final human-facing **Complete** presentation only when the underlying field/photo facts justify it; do not invent another durable server WO state merely for display.

---

# Authentication and offline access baseline

The first use on a device requires a successful online Supabase sign-in.

After a successful authenticated download:

- cached work is associated with the exact user UUID + organization UUID;
- the app may reopen that user's previously downloaded work while offline, including after app/process/device restart;
- offline access does not manufacture a valid network token or server acceptance;
- whenever connectivity is available, the app refreshes/validates the server session before privileged network actions;
- explicit **Sign Out** removes/invalidates reusable auth credentials and locks that account's cached work from ordinary viewing until that same user authenticates again;
- signing out must not destructively delete unresolved local field work or unconfirmed photos;
- a different authenticated user on the same phone must never see the prior user's cached assignments/photos;
- prior-user unresolved evidence may remain quarantined by user UUID until the correct user returns or a later approved recovery process handles it;
- successful server revocation/invalid-session evidence must stop new server work; it must not silently delete already captured local evidence.

Exact credential-storage implementation is chosen inside Phase 3, but credentials must remain app-private and must never be logged or committed.

---

# Remote HNP archive baseline

The initial storage root remains:

`Field Photo Prep Team - HNP / TEST / Work Orders`

For the first pilot, prefer the leanest stable hierarchy:

`Work Orders root → one folder per Team WO → photos`

Suggested human-facing WO folder name:

`<WO number> - <property address>`

The visible folder name is only organization/context. Exact Team WO UUID is stored in Drive app metadata where practical, and the returned Drive folder ID is stored server-side as the remote destination identity.

Why Team does **not** initially recreate FPP's address-folder layer: Team currently has a WO entity but no permanent Property entity. Inventing a property identity only to reproduce FPP's Drive hierarchy would add a new domain model before the workflow demonstrates a need. If the HNP pilot proves address grouping is operationally necessary, add it deliberately later rather than making address text into identity.

Photo filename baseline:

`field-photo-<photo UUID>.jpg`

Use Drive app metadata where practical to tag at least the Team photo UUID and Team WO UUID so remote reconciliation does not depend on visible names alone.

Contractor phones never receive the HNP account password, OAuth refresh token, Supabase secret/service credential, or another reusable privileged storage credential.

---

# Phase 0 — Separation and test foundation — COMPLETE

Goal: create a safe Team development area without risking the working FPP V1 field app.

Completed and verified:

- separate Team repository;
- separate Android package/app identity;
- separate app data;
- dedicated HNP test-storage account/root;
- separate Supabase project;
- credentials kept outside GitHub;
- Team and V1 install side-by-side;
- real phone confirmed both apps continue to open independently.

Gate: **SATISFIED.**

---

# Phase 1 — Identity, login, minimum server data model — COMPLETE

Goal: establish the smallest shared backend foundation.

Completed:

- Supabase Auth user UUID identity;
- server-controlled `organization_id` + `role` claims;
- `ADMIN` and `CONTRACTOR` roles only;
- `organizations`, `work_orders`, and `photos` base tables;
- RLS and explicit grants;
- narrow contractor `start_work` / `complete_field_work` actions;
- Admin/Contractor real-client RLS boundaries proven on browser + Android;
- Team-only stable internal APK signer;
- migration history mirrored under `supabase/migrations/`.

Gate: **SATISFIED.**

---

# Phase 2 — Admin dashboard and dispatch — IMPLEMENTED; FINAL REAL-WORLD CLOSURE SMOKE PENDING

## Goal

Let an Admin dispatch and correct work from a PC/laptop without broad client database privileges.

## Implemented behavior

- create WO;
- automatic `FPP-######` number or Admin-supplied WO number;
- optional browser-only remembered WO-number mode preference;
- address, work type, instructions, due date;
- assign contractor;
- edit dispatch fields;
- immediate reassignment while server status is `ASSIGNED`;
- consent-required handoff while server status is `IN_PROGRESS`;
- contractor Approve/Decline handoff path;
- contractor receipt acknowledgement after successful authenticated download;
- receipt reset when assignment changes;
- Admin sees receipt/pending handoff;
- organization-level WO-number duplicate guard;
- dashboard refresh keeps the Admin signed in for the current browser tab without permanent auth storage.

## Proven

- hosted Admin creates/assigns a disposable WO;
- Contractor RLS receives it and Admin-only control remains hidden;
- real Contractor phone successfully auto-acknowledged receipt;
- dashboard session survives normal refresh;
- automated backend/CI coverage passed for edit/reassign, consent, receipt idempotency/reset, numbering, authorization, and direct-table restrictions.

## Remaining closure smoke

Before Phase 2 is marked `COMPLETE`, perform one compact disposable real-client test:

1. while a test WO is still `ASSIGNED`, Admin reassigns it away from Contractor;
2. Contractor refresh no longer receives it;
3. receipt resets for the new assignee;
4. Admin reassigns it back;
5. Contractor receives it again and receipt confirms again;
6. if practical, run one disposable `IN_PROGRESS` handoff Approve or Decline path on the real Android client.

No Phase 3 runtime work depends on repeating already-proven create/assign behavior beyond this closure smoke.

Gate: **PENDING FINAL REASSIGNMENT/CONSENT REAL-CLIENT SMOKE.**

---

# Phase 3 — Contractor work list and offline assignments — PLANNED, NOT AUTHORIZED FOR RUNTIME YET

## Goal

Make assigned work reliably usable with no internet, including after app/process/device restart, without letting stale server changes silently destroy locally started work.

## User-visible workflow

Online first use:

`Sign in → assignments download → assignments are committed locally → contractor receipt is acknowledged → Work list reads from the local store`

Offline later:

`Open app with no signal → previously downloaded Work list opens → open WO details → Start Work → Finish Field Work → actions remain visibly pending until server accepts them`

Reconnect:

`network returns → pending actions synchronize in order → server accepts or rejects under current authorization/state → local UI becomes confirmed or explicitly conflicted`

## Local architecture

Use Room because Team now has a demonstrated need for structured offline data.

Initial local ownership should stay small:

### Cached work order

At minimum retain:

- Team WO UUID;
- organization UUID;
- assigned user UUID from the last accepted server snapshot;
- WO number;
- property address;
- work type;
- instructions;
- due date;
- last server field status/timestamps;
- assignment receipt timestamp where known;
- server `updated_at`/equivalent snapshot marker;
- last successful local sync time;
- local-user ownership of the cache row.

### Pending field action

Each offline action receives its own UUID and stores at minimum:

- action UUID;
- Team WO UUID;
- authenticated user UUID;
- action type `START` or `COMPLETE`;
- local event timestamp captured when the contractor acted;
- deterministic ordering/creation time;
- pending/syncing/accepted/conflict result.

No action is considered server-confirmed merely because it exists locally.

### Local account/session ownership

Persist only what is needed to reopen the correct user's cache and refresh the Supabase session when online. A different user must not see those rows.

## Single source for Android UI

After Phase 3, normal Work-list rendering reads from Room, not directly from a transient network response.

Online fetch updates Room transactionally. This prevents the list from disappearing merely because the app restarts or a fetch fails.

## Receipt semantics

Receipt means the assigned contractor app durably received the WO.

Improvement over the current prototype:

1. authenticated server row is fetched;
2. row is committed into Room;
3. only then is `acknowledge_assignment_received` attempted;
4. failed acknowledgement is retryable without losing the locally received assignment.

## Offline field-action semantics

- **Start Work** first persists a local `START` action before the UI reports it queued/offline-started.
- **Finish Field Work** first persists a local `COMPLETE` action before the UI reports it queued/offline-complete.
- if both are created offline for one WO, synchronization preserves `START → COMPLETE` ordering;
- repeated worker/app retry must be idempotent;
- field-event time should represent when the contractor performed the action, not merely when connectivity returned;
- the narrow server actions may be extended to accept a client event timestamp while still validating authenticated user, organization, current assignment, valid transition, and timestamp ordering/sanity;
- server acceptance remains authoritative.

## Server refresh / cache reconciliation

When online assignment refresh succeeds:

### Row still assigned to this user

- update mutable display/server-snapshot fields;
- preserve unresolved local pending actions;
- never overwrite local pending evidence merely because the server snapshot is older/different.

### Row is no longer returned and there is no local started/pending/photo evidence

- it may be removed from the active contractor list after reconciliation;
- no fake conflict is required for untouched work.

### Row is no longer assigned/cancelled but local started/pending evidence exists

- preserve the local row/evidence;
- mark it as a visible conflict/no-longer-assigned state;
- do not send repeated unauthorized actions;
- do not silently delete the contractor's local work;
- do not claim server completion;
- approved resolution is required before destructive cleanup.

For the first version, the safest resolution is intentionally conservative: Admin can restore/reassign the WO back when the local field work should be accepted; otherwise the local conflict remains protected until a later explicit discard/recovery rule applies. The phone must never guess which side should win.

## Cancellation race

- server cancellation received before any local work → remove/hide the assignment from active work after local reconciliation;
- server cancellation received after local Start/Complete intent exists → preserve local work and surface conflict;
- no automatic deletion of later Phase 4 photos is ever implied by cancellation.

## Reassignment race

A server `ASSIGNED` WO may be reassigned while the old contractor is offline and locally starts it before learning about the change.

On reconnect:

- server remains authoritative for current assignment;
- old contractor's queued Start is not forced through;
- local start evidence remains preserved and becomes conflict;
- photos, once Phase 4 exists, remain bound to the original Team WO and original capturing user; they are never silently transferred to the new assignee.

## Session/restart behavior

- first device use requires online sign-in;
- previously downloaded work for the last authenticated account remains viewable/actionable offline after restart;
- token refresh failure due simply to no network does not erase/lock the already-authorized offline work session;
- explicit Sign Out locks cached work and clears reusable credentials but preserves unresolved evidence;
- successful online auth revocation invalidates future server operations and ordinary access according to the approved account rule without deleting protected evidence.

## Phase 3 implementation slices

### 3A — Room + cached Work list

- add Room dependency/schema;
- cache assignments by immutable WO UUID + user/org ownership;
- UI reads Work list/details from Room;
- authenticated online refresh transactionally updates cache;
- receipt acknowledged only after durable local save;
- automated migration/schema tests from the first Room version onward.

### 3B — Offline Start/Complete queue

- durable pending-action entity;
- local Start/Complete UI/overlay;
- event timestamps;
- deterministic per-WO action ordering;
- extend narrow server actions only as required for truthful offline event acceptance;
- no WorkManager dependency is required merely to prove the queue if explicit app-open sync can prove behavior first.

### 3C — Reconciliation + persistent network sync

- introduce WorkManager only when the durable queue is already correct;
- network-constrained worker re-reads Room before each action;
- worker creates no new business authority;
- conflict handling for reassignment/cancellation;
- retry/backoff only for retry-safe transport failures;
- authorization/state rejection becomes visible conflict or terminal local result, not infinite retry.

## Automated verification

At minimum prove:

- multiple assignments survive repository/app reconstruction;
- user A cache is not visible to user B;
- successful server fetch updates Room without erasing pending local overlay;
- receipt occurs only after durable cache save and is retry-idempotent;
- offline Start survives restart;
- offline Complete survives restart;
- Start + Complete sync in deterministic order;
- repeated sync does not duplicate timestamps/transitions;
- transport failure remains retryable;
- reassignment/cancellation authorization rejection preserves local evidence and becomes conflict;
- untouched removed assignment is safe to evict from active list;
- signout does not delete unresolved evidence;
- Room migration tests exist for every schema change.

## Physical-device gate

One straight-line disposable gate after the final Phase 3 runtime is automated-tested:

1. sign in online;
2. download at least two disposable assigned WOs;
3. verify receipt;
4. disable connectivity;
5. kill/restart the app (and restart phone if practical);
6. open both cached WOs;
7. Start one and Finish one fully offline;
8. restore connectivity;
9. prove server accepts actions once, in correct order, with truthful field-event times;
10. repeat with one disposable reassignment/cancellation while the contractor is offline and prove locally started work is preserved as conflict rather than deleted.

## Completion gate

**Phase 3 is complete only when multiple assignments, offline Start/Complete, restart recovery, identity isolation, and one reassignment/cancellation race are proven on the real Android path without manual database repair.**

---

# Phase 4 — Offline CameraX capture, protected photos, and preparation — PLANNED

## Goal

Port the proven FPP field-photo experience into Team without weakening Team WO/user identity or offline safety.

## User-visible workflow

`Open assigned WO → Open Camera → Take → Take → Take → Done → photos are already protected locally → prepared upload copies appear automatically in the background`

The contractor must not accept a system-camera review and then manually select the photo again for every shot.

## Camera baseline

Use the proven FPP in-app CameraX pattern rather than the old external-camera intent path.

Carry forward where the device supports it:

- dominant live preview;
- one large shutter;
- multi-shot same-WO session;
- **Done** exits the session;
- camera controls respect system-bar insets;
- Flash `Auto / On / Off`;
- Torch separate and defaults Off;
- pinch zoom + fine zoom control;
- 1× means normal rear-camera framing;
- additional quick zoom/lens shortcuts only when CameraX/device capability proves they are real and safe;
- portrait/landscape target rotation and usable saved orientation;
- camera/lens/light controls must never mutate photo identity, WO identity, or queue state.

## Camera permission

Camera permission is requested through normal Android runtime permission flow.

Protected originals remain app-private, so the contractor should not need broad photo/media-library permission merely to use Team capture.

## Capture transaction

Before every shutter write:

1. verify an exact cached Team WO UUID and authenticated local user context;
2. generate permanent photo UUID;
3. create/reserve an app-private protected-original path;
4. persist a local Room photo record as `CAPTURING`, bound to exact WO UUID + capturing user UUID;
5. only then allow CameraX to write that shot.

After callback:

- non-empty successful image → durably transition that photo to `WAITING`;
- callback error/cancel with non-empty bytes → preserve and reconcile to recoverable waiting/inspection state rather than deleting evidence;
- empty unused reservation → remove safely;
- next shutter is allowed only after the prior photo's durable capture transaction is finalized.

## Photo binding

A photo remains permanently bound to:

- photo UUID;
- Team WO UUID;
- capturing user UUID;
- capture timestamp.

Address/WO-number edits and later reassignment never move the photo to another WO.

## Local file model

At minimum:

- protected original: app-private, immutable until confirmed remote success + durable bookkeeping;
- prepared derivative: app-private, deterministic path from photo UUID, replaceable/recreatable while original remains;
- Room metadata stores file identity/state; UI selection never becomes persistence authority.

## Automatic preparation

Carry forward the proven FPP policy:

- begin only after `WAITING` is durably stored;
- best-effort scheduling failure cannot turn a good capture into failure;
- serialize full-image preparation;
- camera remains usable while queued preparation runs;
- prepared filename/path derives from photo UUID;
- maximum 2048 px long edge;
- JPEG quality 85;
- no upscaling;
- correct usable orientation;
- preparation failure leaves original + `WAITING` record recoverable;
- startup scan requeues eligible waiting photos missing a prepared derivative.

WorkManager is not required for image preparation merely because it is background work; FPP's lean in-process serialized queue + startup recovery remains appropriate unless Team testing proves otherwise.

## Server photo record timing

Offline capture does not require Supabase.

When connectivity exists, synchronization attempts to create/upsert the server photo metadata using the **same phone-generated photo UUID**. The server must never allocate a replacement photo identity for an already captured photo.

If server authorization rejects the photo because assignment/cancellation changed while offline, the local photo is preserved and the WO becomes/remains conflicted. No upload is authorized until the conflict is resolved.

## Safe local discard

Initial Team discard carries forward FPP guards:

- explicit operator action + confirmation;
- only local app-private data is removed;
- never deletes the remote Drive copy;
- `UPLOADING`, `UNCERTAIN`, and `UPLOADED` are not discardable through ordinary local discard;
- if a batch discard is added, validate the entire selection before the first deletion and stop on the first unsafe/missing item;
- local discard can never change WO/photo identity or server assignment.

## Restart recovery

On startup:

- `CAPTURING` + non-empty original → preserve and reconcile to recoverable `WAITING`;
- `CAPTURING` + empty/missing reservation → remove only the abandoned empty reservation;
- `WAITING` + valid original → retain;
- `WAITING` + missing/empty original → surface a problem; never pretend the photo is safe;
- eligible waiting original with missing prepared derivative → queue preparation again.

## Automated verification

At minimum prove:

- unique UUID/path per shutter;
- persisted `CAPTURING` before CameraX write;
- same immutable Team WO/user binding across a multi-shot session;
- three sequential shots cannot overwrite each other;
- non-empty abnormal callback preserved;
- restart recovery rules;
- prepared policy dimensions/quality/orientation;
- original byte-for-byte unchanged by preparation;
- serialized preparation/deduplication;
- capture remains independent of network;
- photo metadata sync uses the preexisting phone UUID;
- reassignment/cancellation rejection cannot delete or redirect the local photo.

## Physical-device gate

With connectivity disabled:

1. open one disposable cached assigned WO;
2. open CameraX;
3. take multiple photos without leaving the camera between shots;
4. exercise basic flash/torch/zoom/orientation controls supported by the phone;
5. tap Done;
6. verify automatic preparation occurs without per-photo manual Prepare taps;
7. kill/restart the app;
8. confirm every protected original and eligible prepared copy remains bound to the same WO;
9. verify no internet was required;
10. explicitly discard one disposable safe photo and prove the others remain.

## Completion gate

**Phase 4 is complete when one disposable WO can be photographed fully offline with repeated in-app shots, protected originals, automatic preparation, restart recovery, and immutable Team WO binding proven on the real phone.**

---

# Phase 5 — Safe server-mediated photo synchronization to HNP Drive — PLANNED

## Goal

Move prepared photos from the contractor phone to company-controlled HNP Drive without placing reusable HNP credentials on the phone and without losing/duplicating photos during weak or interrupted connectivity.

## Security boundary

The contractor calls an authenticated backend using the contractor's Supabase user JWT.

The backend/Edge Function:

- validates authenticated user and current authorization;
- validates exact Team photo UUID + Team WO UUID;
- verifies the photo may be synchronized for that contractor/WO/conflict state;
- owns access to HNP Drive credentials/secrets;
- never returns HNP OAuth refresh tokens or reusable privileged credentials to Android;
- may issue only the narrow one-photo upload capability/session needed for the authorized operation.

Supabase service/secret credentials and Google OAuth refresh credentials remain server-side secrets only.

## Drive destination creation/resolution

Before first photo upload for a WO:

1. resolve server-stored `remote_folder_id` if already present;
2. verify it still represents the expected Team WO archive where practical;
3. if absent, search beneath the configured HNP Work Orders root by Team WO UUID app metadata, not just folder name;
4. exactly one match → reuse it and persist its Drive ID;
5. no match → create one folder with readable display name plus Team WO UUID app metadata, then persist returned Drive ID;
6. multiple/inconclusive matches → fail closed; do not guess or create another folder.

Folder creation retry therefore cannot knowingly create duplicate WO folders after a successful but locally unrecorded create.

## Photo remote identity

Remote photo filename:

`field-photo-<photo UUID>.jpg`

Remote metadata should include Team photo UUID + Team WO UUID where practical.

The confirmed Drive file ID becomes the photo's remote identity. Visible filename is not identity after confirmation.

## Upload transport baseline

Prefer Google Drive **resumable upload** because the target is a mobile workflow with expected network interruption.

Expected safe flow:

1. local prepared copy exists and hash/byte size are known;
2. server photo metadata using the phone-generated photo UUID is durably present/authorized;
3. backend initiates a Drive resumable upload session for the exact WO folder + deterministic filename;
4. Android persists the returned resumable-session capability/URI **before sending photo bytes**;
5. only then transition/retain `UPLOADING` and send bytes;
6. final Drive response returns/establishes exact remote file identity;
7. server + local bookkeeping persist confirmed remote identity/status;
8. only after that durable confirmation may local cleanup become eligible.

The resumable-session URI is sensitive app-private sync state and must not be logged, exposed in UI, or committed.

## Persistent background synchronization

WorkManager becomes appropriate here for persistent network work.

Baseline:

- network constraint `CONNECTED` initially;
- default pilot behavior allows usable cellular or Wi-Fi because the product exists to function in the field;
- add a Wi-Fi-only preference only if field testing demonstrates a real need;
- worker re-reads Room before every attempt;
- worker never treats stale in-memory selection as upload authority;
- process restart/reboot can resume eligible sync work;
- queue executes photos sequentially by default to keep remote-create/reconciliation behavior simple and avoid bandwidth spikes;
- a known retry-safe failure may allow later photos to proceed;
- `UNCERTAIN`/unverified remote outcome stops blind retry for that photo and must not be interpreted as permission for another create.

## State transitions

Normal:

`WAITING → UPLOADING → UPLOADED`

Known retry-safe transport/server failure:

`WAITING/FAILED → UPLOADING → FAILED`

Ambiguous remote outcome:

`UPLOADING → UNCERTAIN`

`UPLOADED` is terminal for automatic upload retry.

## Interrupted resumable upload

When the process/network dies after a resumable session exists:

- preserve exact WO/photo identity, prepared file, session URI/capability, attempt evidence;
- query/resume the existing resumable session when possible rather than starting another file create;
- Drive-complete result → confirm remote identity;
- resumable-incomplete result → continue from server-reported byte position;
- expired/missing session → reconcile by Team photo UUID/deterministic name/app metadata under the exact stored WO folder before a replacement session is authorized;
- inconclusive result → `UNCERTAIN`, no blind new create.

## UNCERTAIN reconciliation

Carry forward the FPP decision ladder concept, adapted to Drive API/server control:

1. validate exact local photo + WO + prepared bytes/hash evidence;
2. use any exact resumable/provisional remote evidence first;
3. search the exact stored WO folder by Team photo UUID/app metadata/deterministic filename;
4. exactly one candidate → prove it strongly enough (metadata/size/checksum or remote-byte hash when needed) before confirming;
5. more than one candidate → remain `UNCERTAIN`;
6. authoritative proof of absence with no unresolved provisional evidence → release to retry-safe `FAILED`;
7. loading/inaccessible/mismatched/ambiguous evidence → remain `UNCERTAIN`;
8. reconciliation never deletes or overwrites remote content merely to make state simpler.

## Cleanup after success

After durable local + server `UPLOADED` with confirmed remote Drive ID:

- delete protected original when safe;
- delete prepared derivative when safe;
- retain lightweight photo metadata/remote identity needed for duplicate protection and dashboard truth;
- cleanup failure does not roll remote status backward and does not trigger a re-upload;
- later cleanup may remove whichever local file remains.

## Offline assignment conflict guard

No backend upload session is authorized when the photo/WO is in an unresolved assignment/cancellation conflict.

The photo stays local. Resolving ownership comes before remote archival; remote sync must never silently choose the new assignee or redirect the original photo.

## Automated verification

At minimum prove:

- user/role/org/assignment authorization on the upload endpoint;
- no secret/service/Google refresh credential reaches Android/browser code;
- WO folder unique resolution/create by Team WO UUID metadata;
- ambiguous duplicate folder result fails closed;
- deterministic photo filename/app metadata;
- resumable session persisted before byte transfer;
- process restart retains session and exact destination;
- resume uses server-reported position;
- retry-safe vs uncertain classification;
- uncertainty never causes blind second create;
- exactly one remote candidate can reconcile to confirmed success;
- safe authoritative absence can release retry;
- multiple/mismatched candidates remain uncertain;
- one photo failure cannot corrupt unrelated photos;
- cleanup only after confirmed success;
- cleanup failure never changes confirmed remote state;
- WorkManager repeated execution is idempotent and re-reads durable state.

## Physical/provider gate

Use only disposable Team WO/photo data under the HNP TEST root.

Prove:

1. capture several photos offline from Phase 4;
2. restore weak/normal connectivity;
3. verify server creates/resolves one exact WO folder;
4. verify several photos reach that exact folder sequentially;
5. kill/restart app during queued work and prove queue resumes;
6. perform one safe controlled network interruption of an upload;
7. prove the app resumes/reconciles rather than blindly duplicating;
8. verify final Drive file IDs are retained and local state reaches `UPLOADED` only after confirmation;
9. verify local cleanup removes unneeded image bytes while Drive copies remain;
10. verify unrelated HNP TEST content is untouched.

Do not manufacture a dangerous ambiguous remote create merely to satisfy a test. If a true ambiguity cannot be induced safely, automated reconciliation tests plus the safest provider interruption evidence are accepted and the limitation is recorded.

## Completion gate

**Phase 5 is complete when offline-captured photos survive interruption/restart, synchronize through the server to the exact HNP TEST WO folder without reusable Drive credentials on the contractor phone, and no tested failure path loses evidence or knowingly creates duplicates.**

---

# Phase 6 — Admin field/sync visibility and problem surfacing — PLANNED

## Goal

Give the office a truthful operational view that separates work performed in the field from photo synchronization progress/problems.

## Dashboard facts per WO

At minimum show:

- assigned contractor;
- contractor receipt;
- due date;
- server field status;
- field started time;
- field completed time;
- captured photo count known to server;
- uploaded photo count;
- waiting/uploading count;
- failed count;
- uncertain/problem count;
- unresolved assignment/offline conflict when one has been reported;
- pending in-progress reassignment request where applicable.

## Truthfulness rule

The dashboard cannot know what a fully offline phone has never synchronized.

Therefore:

- no signal does not become fake server knowledge;
- after reconnect, field actions/photo metadata should synchronize before/alongside large image bytes so Admin can see field completion and pending-photo counts while uploads continue;
- show server-known facts and useful last-sync context, not guesses about current phone state.

## Derived human-facing views

Use derived filters/presentation rather than more durable WO statuses:

- Due today/upcoming;
- Overdue;
- In progress;
- Field complete — photos pending;
- Complete — field complete and all known required photos confirmed uploaded;
- Problem — failed/uncertain/conflict requiring attention.

## Conflict reporting

If Phase 3/4 encounters a protected offline assignment/cancellation conflict, Phase 6 must give Admin enough server-visible problem metadata to act once the device reconnects.

Keep this lean. A single current conflict/problem record per affected WO is sufficient for the pilot unless real use proves an event-history table is needed.

The exact schema may be a narrow WO conflict/status record rather than a general audit/event subsystem.

## Admin actions

Phase 6 may add only the minimum resolution actions demonstrated by the conflict model, for example:

- restore/reassign the WO to the contractor whose protected offline work should be accepted;
- clear a resolved conflict only after server/local sync proves it no longer protects unsynchronized evidence.

Do not build a generic case-management system.

## Automated verification

Prove derived counts/views from underlying server facts; organization/RLS isolation; no cross-contractor leakage; field-complete does not imply uploaded; uncertain/failed/conflict cannot render as complete; counts remain stable under retries/idempotent updates.

## End-to-end gate

1. contractor completes a disposable WO offline with several photos;
2. Admin initially sees only previously known server facts;
3. connectivity returns;
4. pending field completion/photo metadata reaches server;
5. dashboard changes to **Field complete — photos pending** while bytes are still synchronizing;
6. uploads finish;
7. dashboard derives **Complete**;
8. repeat with one safe failed/uncertain/conflict case and verify **Problem** rather than false Complete.

## Completion gate

**Phase 6 is complete when the office can accurately tell what field work is finished, what photos are still moving, and what needs intervention, without conflating those facts.**

---

# Phase 7 — Internal real-world Team pilot — PLANNED

## Goal

Use Team repeatedly in realistic conditions before HNP receives a production pilot.

## Pilot rules

- V1 remains installed and untouched;
- Team data remains disposable/test-designated even when using real-looking addresses;
- no live customer evidence is used when a safe equivalent can prove behavior;
- fixes respond to observed friction/failure, not hypothetical feature ideas;
- no manual database repair is accepted as normal operation.

## Required scenarios

Across repeated runs, exercise:

- multiple WOs on one contractor phone;
- due dates/instructions edits;
- receipt;
- normal online Start/Complete;
- fully offline Start/Complete;
- app kill + phone restart;
- multiple offline CameraX photo sessions;
- larger realistic photo counts;
- automatic preparation while continuing capture;
- weak cellular connectivity;
- lost connectivity during queued sync;
- later recovery on cellular/Wi-Fi;
- reassignment while untouched;
- reassignment/cancellation race with locally started work;
- auth/session refresh and one intentional signout/signin;
- low-storage behavior if it can be tested safely;
- app update over an existing Team install without losing protected local state;
- final Drive archive placement/identity;
- Admin filters/problem visibility.

## Failure bar

The pilot is not considered stable if routine use requires:

- SQL/manual row repairs;
- deleting app data to recover;
- reinstalling to clear queues;
- manually moving misfiled Drive photos;
- repeated retry until an uncertain upload happens to work;
- using FPP V1 as a fallback for Team data.

## Lean review

Before leaving Phase 7, run one proportional architecture review like FPP's lean baseline:

- identify actual dependencies/components added;
- identify complexity that protects real safety;
- identify obvious dead/duplicate architecture;
- do not refactor working code merely to make diagrams cleaner;
- preserve the smallest architecture that passed real field use.

## Completion gate

**Phase 7 is complete after repeated internal routes/field sessions succeed without lost/misattributed work, duplicate remote photos, manual database repair, or V1 fallback, and remaining issues are understood rather than intermittent mysteries.**

---

# Phase 8 — Production/HNP pilot readiness and small HNP pilot — PLANNED

## Goal

Harden only what is necessary to let a small outside HNP pilot use Team safely.

## 8A — Production identity/environment separation

Before HNP field use:

- production Android package/label distinct from internal test package;
- private production signing key stored outside the public repository;
- deliberate versionCode/versionName update policy;
- production Supabase environment/project separated from disposable development data if practical for the pilot;
- HNP production Drive root separated from `TEST`;
- production secrets configured server-side only;
- no test account IDs/PII baked into client source;
- known-good rollback APK/build identity documented.

## 8B — User lifecycle

Prove the minimum required account administration:

- create/invite Admin or Contractor under the correct organization through a controlled server-authorized path;
- role/org assignment remains server-controlled;
- revoke/disable a user;
- revoked user cannot obtain new server work after the device reconnects/validates;
- revocation does not destructively erase unsynchronized protected evidence already on the device;
- no hybrid/more-granular roles unless the pilot proves they are required.

A full self-service organization/user-management product is not required for the first pilot.

## 8C — Storage ownership, retention, recovery

Before outside use, write the operational answer for:

- who owns the HNP photo archive;
- how long confirmed local photos remain before cleanup (normally only until confirmed remote success/bookkeeping);
- how long server metadata is retained;
- what happens if the dedicated HNP Google account loses access/quota;
- what Supabase backup/export level is sufficient for pilot data;
- whether free storage limits are still adequate or paid storage is now justified.

Do not buy/build storage complexity before the actual pilot requires it.

## 8D — Controlled update path

- one documented production install/update method;
- update preserves Room schema, cached assignments, pending actions, protected photo files, and queue state;
- migration tests for every production Room/schema change;
- failed update/install has known rollback without deleting unresolved local evidence;
- no Play Store publication is required unless distribution needs prove it useful.

## 8E — Second-phone / outside-user reality gate

On a separate supported Android phone/account:

- install production candidate normally;
- sign in as a pilot Contractor;
- receive a disposable pilot WO;
- use it offline;
- capture multiple photos;
- restart;
- restore connectivity and synchronize;
- verify Admin dashboard truth;
- verify exact HNP archive placement;
- confirm nothing depends on the first developer phone's local IDs/session/storage.

## Small HNP pilot

Start deliberately small: few users, disposable/low-risk pilot work where possible, close feedback loop.

Collect only evidence that answers:

- is dispatch clear enough;
- is offline behavior trustworthy;
- is camera workflow fast enough;
- are photos reliably archived;
- can Admin tell what is finished/pending/problematic;
- are account/update/storage operations manageable.

Only observed pilot needs authorize post-pilot expansion.

## Completion gate

**Phase 8 succeeds when a small HNP pilot can be operated with controlled production identity, user revocation, safe updates, known storage ownership/recovery, and repeated end-to-end work without exposing privileged credentials or depending on developer-only repair.**

---

# Explicit non-requirements for the first Team version

Keep out unless real pilot evidence changes the roadmap:

- route optimization;
- payroll/contractor payment calculation;
- invoicing/accounting;
- customer billing tiers;
- OCR/AI photo classification or inspection judging;
- video;
- continuous/live location;
- employee time tracking;
- iOS;
- public marketplace;
- advanced analytics/report builder;
- permanent local photo gallery;
- multiple storage-provider abstraction before a second provider is actually needed;
- property-preservation job management beyond the dispatch/photo workflow;
- extra roles without demonstrated need;
- a generalized event-sourcing architecture;
- dependency-injection/framework layers merely for architectural fashion.

---

# Research/implementation references to re-check before relevant runtime work

Do not rely on this roadmap's memory of external APIs; re-read current official documentation when implementation begins.

- Android Room: structured local persistence/offline cache and migration support.
- Android offline-first data layer guidance: local writes, queues, conflict resolution, network source of truth.
- Android WorkManager: persistent constrained/retryable work.
- Android CameraX: lifecycle-aware preview/image capture and device-specific capability handling.
- Google Drive API: folders/parents, custom `appProperties`, search, resumable uploads, interrupted-upload status/resume.
- Supabase: current RLS/Auth/JWT behavior, Edge Function authenticated-user patterns, Edge Function secrets, current API-key model.

---

# Roadmap approval gate

This expanded roadmap is intentionally a **draft** until the operator reviews it.

No Phase 3 runtime, Room schema, WorkManager worker, new Supabase migration, CameraX Team port, Edge Function, or Drive API integration is authorized merely because it appears in this draft.

After operator approval:

1. mark this roadmap approved/current;
2. close the remaining Phase 2 real-client reassignment/consent smoke if still pending;
3. create the exact Phase 3 Level 3 impact/implementation record only where this roadmap is not sufficiently specific for the concrete schema/API changes;
4. implement Phase 3 in the largest safe automated-testable slices;
5. stop once at the documented Phase 3 physical-device boundary;
6. use that evidence to adjust later phases only if reality contradicts this plan.
