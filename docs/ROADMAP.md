# Field Photo Prep Team — Master Implementation Roadmap

Planning status: **APPROVED / CURRENT — runtime work remains phase-gated**

Operator approval recorded: **2026-09-14**.

This is the authoritative product and implementation roadmap for Field Photo Prep Team. It defines the intended user workflow, authority boundaries, offline behavior, photo rules, work-order lifecycle, HNP delivery rules, phase boundaries, failure handling, verification, and real-device gates.

The existing single-user Field Photo Prep (`timbone72-CC/field-photo-prep`) remains separate, working, and read-only to Team development.

## First finish line

The first Team version succeeds when:

**Admin creates and assigns a work order on a PC/laptop → the contractor receives it on Android → the assignment remains usable without internet → the contractor starts/finishes field work and takes protected photos offline → work/photo state survives restart → after Finish Field Work the frozen evidence set synchronizes safely when connectivity permits → the office can distinguish field-complete work from delivery still pending/failed/uncertain → confirmed photos reach the exact company-controlled HNP destination without loss, wrong placement, or blind duplicates.**

## Governing build rule

Build the smallest architecture that safely performs the real workflow.

Do not add tools, screens, settings, roles, services, frameworks, abstractions, or “future hooks” merely because they may be useful someday. Complexity is justified only when it protects a demonstrated requirement such as identity, authorization, assignment ownership, offline work, photo evidence, restart safety, exact remote placement, duplicate prevention, or truthful status.

`AGENTS.md`, `CHANGE_CONTROL_CONTRACT.md`, `TESTING_CONTRACT.md`, `INTEGRATION_CONTRACT.md`, and `docs/PHASE_STAGING_DOCTRINE.md` govern implementation.

**Mandatory phase gate:** if a phase does not define behavior, failure handling, protected boundaries, verification, and its completion gate, implementation stops and planning is the work.

---

# Product scope and FPP transfer baseline

Field Photo Prep (FPP) is both the proven field-photo workflow reference and the proven development-process reference.

## Carry forward as protected behavior

Team carries forward:

- plan before coding;
- mandatory governing-source rereads at work-session and phase boundaries;
- isolated branches and proportional change classification;
- focused tests while building, then one complete automated suite on the final runtime head;
- build everything automated evidence can honestly prove, then stop once at the next genuine physical/provider boundary;
- disposable fixtures instead of live field data when a safe equivalent exists;
- permanent photo UUID before capture;
- app-private protected original before camera bytes are accepted;
- one shutter press = one independent protected-photo transaction;
- immutable work-order binding;
- CameraX multi-shot `Take → Take → Take → Done`;
- capture without internet;
- preservation of non-empty image bytes even after abnormal callback/lifecycle paths;
- separate protected original and prepared upload derivative;
- automatic preparation after durable capture;
- JPEG preparation baseline: max long edge 2048 px, quality 85, no upscale, usable orientation;
- serialized preparation and restart recovery;
- `WAITING`, `UPLOADING`, `FAILED`, `UNCERTAIN`, `UPLOADED`, plus local `CAPTURING`;
- deterministic remote photo name from photo UUID;
- exact destination/remote identity never inferred from visible name once stable identity exists;
- `UNCERTAIN` fails closed and reconciles before another create;
- one photo failure does not corrupt unrelated photos;
- remote confirmation must be durable before local image cleanup;
- confirmed-delivery metadata survives local image cleanup;
- the app is not a permanent local gallery;
- physical evidence is recorded once and reused rather than repeatedly retested for reassurance.

## Adapt for Team

FPP concepts change where Team has multiple users and server authority:

- FPP file-per-record persistence → Room structured local persistence;
- FPP operator-selected SAF Drive tree → server-mediated company HNP storage;
- FPP destination business identity → Team WO UUID + server-stored Drive IDs;
- FPP device-side Drive account selection → no reusable HNP credential on contractor phones;
- FPP manual/foreground upload → durable Team queue + WorkManager only once persistent network work is actually required;
- FPP local selected address/WO → authenticated server assignment cached by immutable Team identity;
- FPP name-based folder discovery → stored Drive ID and Team UUID metadata;
- direct provider reconciliation → trusted backend plus Drive API.

## Do not carry forward

Do not carry forward:

- Android SAF folder selection for HNP;
- contractor-side Google account/folder picker;
- persisted SAF tree grants;
- contractor-side Drive create/reuse/Clear & Reuse;
- names, emails, addresses, WO numbers, or timestamps as permanent identity;
- external-camera accept/select loops;
- permanent local gallery behavior;
- route optimization;
- payroll/payments;
- invoicing/accounting;
- OCR/AI photo classification or inspection judging;
- video;
- continuous location;
- employee time tracking;
- iOS in the first version;
- generalized event sourcing or framework-heavy architecture.

---

# Global identity and authority model

## Permanent identities

- Organization: UUID.
- Auth user/contractor: Supabase Auth UUID.
- Work order: Team WO UUID.
- Field run: Team run UUID.
- Assignment instance/history row: stable server ID/UUID where implemented.
- Photo: UUID generated on Android before capture.
- Remote Drive folder/file: Drive ID stored separately after creation/resolution.

Display fields such as contractor name, email, address, WO number, work type, due date, folder name, filename, status label, and run sequence are not permanent identity.

## Authority map

### Supabase is authoritative for

- authenticated identity;
- organization and role;
- contractor active/deactivated state;
- seat allowance and invitations;
- current work-order/run assignment;
- server-visible WO/run fields;
- assignment/reassignment/consent;
- accepted server field status/timestamps;
- requirement snapshots;
- server-visible photo metadata;
- confirmed remote delivery metadata;
- current conflict/problem state.

### Room/app-private storage is authoritative for

- whether previously downloaded work is available offline on that device;
- pending local actions not yet accepted by Supabase;
- locally captured photo bytes before confirmed delivery;
- local preparation state;
- local queue/session/reconciliation evidence;
- unresolved local conflict evidence that must not be silently erased.

Local pending state must never be presented as if the server already accepted it.

### Google Drive/HNP is authoritative for

- the exact remote object/folder that existed when Team confirmed delivery;
- the exact returned remote Drive folder/file identity at that time.

A local flag or successful HTTP request by itself cannot prove remote success.

---

# Organization, Admin, Contractor, seats, and devices

Initial roles remain only:

- `ADMIN`
- `CONTRACTOR`

Do not add an OWNER role merely for licensing.

## Contractor seats

Each organization has a server-controlled maximum number of active Contractor seats approved by the product owner/operator.

- Organization Admin may invite/add Contractors only while a seat is available.
- Admin cannot raise/bypass the seat limit.
- Pending invitations reserve a seat until accepted, cancelled, or expired.
- Dashboard shows simple usage such as `3 of 5 contractor seats in use`.
- Deactivation frees a seat only after server-side disable is durably recorded.
- Enforcement is server-side, not dashboard-only JavaScript.
- Creation of additional Admin accounts remains product-owner controlled until real need proves otherwise.

## Contractor invitation/account lifecycle

`Admin enters contractor name + email → Team reserves a seat → trusted backend sends invitation → contractor sets own password → account becomes active`

Rules:

- Admin never chooses or sees the contractor password.
- Admin may see name, email, invite/account status, seat usage, resend invite, cancel pending invite, deactivate/reactivate.
- Auth Admin/invite/reset operations stay in a trusted server environment.
- Service-role/secret credentials never ship to Android or the dashboard.
- Password reset uses the normal secure Auth recovery flow; Admin does not receive/reset the password in plain text.
- Exact invite-expiration duration is an implementation choice; expiration must release the reserved seat.

## Device support

A seat represents a Contractor account, not a phone.

First pilot:

- one active field device per contractor is the supported workflow;
- Team does not build device registration/locking merely to enforce that;
- contractor may replace/sign in on another supported Android phone;
- simultaneous field work from two devices under one Contractor account is unsupported;
- no special multi-device merge system is added unless real use proves it necessary.

## Deactivation

Used contractor identities are deactivated, not deleted.

Deactivation:

- removes contractor from future assignment choices;
- blocks new authenticated server work once the device reconnects/validates;
- does not auto-cancel/reassign existing WOs;
- does not delete Drive folders;
- does not rewrite historical attribution;
- does not destroy unresolved offline work/photos;
- leaves Admin responsible for explicit action on existing assignments;
- allows later reactivation of the same account/UUID if a seat is available.

If legitimate unsynchronized evidence exists on a deactivated contractor device, first-version recovery is to temporarily reactivate the same identity so valid evidence can synchronize. Do not invent an emergency bypass credential.

Principle: **deactivate access, never delete evidence; reassign business work explicitly; preserve historical identity.**

---

# Work types and photo requirement templates

## Work-type templates

Each organization has a small flat reusable list of work types, for example:

- Interior Inspection
- Yard Cut
- Trash Removal
- Lock Change
- Tree Work

Each reusable work type owns its default photo requirement template.

WO creation selects from this list so repeated work does not depend on free-text spelling.

A simple `Custom / Other` path remains available for one-off work without forcing creation of a permanent template.

Do not add categories, subcategories, codes, inheritance trees, or ADE-style rule hierarchies unless field evidence later proves they are necessary.

Renaming/editing a template changes future defaults only. Existing WOs/runs keep the label and requirement snapshot they were dispatched with.

If a reusable template has already been used, remove it from future selection by **archiving/deactivating** it rather than destructively rewriting history.

## Requirement shape

A run requirement snapshot may contain:

- minimum total photos;
- Before enabled + minimum;
- During enabled + minimum;
- After enabled + minimum;
- Wide Angle enabled + minimum.

Rules:

- all counts are nonnegative;
- disabled stage count is treated as zero;
- Before/During/After are mutually exclusive stage labels for a captured photo;
- therefore `minimum total` must be at least the sum of required Before + During + After minimums;
- Wide Angle is an overlapping designation, not another additive total;
- one photo may satisfy its stage requirement and Wide Angle requirement simultaneously;
- stage minimums are sub-requirements of total, not “total plus all stage counts.”

Examples:

- Interior Inspection may require at least 100 total and no B/D/A.
- Yard Cut normally uses Before/During/After and may also require Wide Angle.
- Trash removal, tree work, lock replacement, and similar preservation/repair work normally use Before/During/After.

## Default stage rule

Working product rule:

- preservation/repair templates normally enable `BEFORE → DURING → AFTER`;
- inspections are the expected exception and normally use total-photo + optional Wide Angle without B/D/A;
- this remains a configurable template default, not hard-coded law.

## Named-shot checklist is deliberately out of v1

Do **not** build a named-photo checklist system and do not pre-build dormant schema/UI hooks for it.

Most contractors are expected to know the specific shots required.

If repeated field evidence later shows missed specific shots are a real problem, design a named-shot feature deliberately then.

---

# Work-order and field-run lifecycle

## Why a run exists

A Team WO is the permanent business/archive identity. A **field run** represents one dispatched attempt/cycle of field work under that WO.

This narrow run model is required because reopened work must preserve earlier completion, assignment receipt, requirements, photo counts, and evidence instead of overwriting them.

It is **not** generalized event sourcing.

## Minimum server model

Before Phase 3 depends on it, introduce a narrow run identity model:

### `work_orders`

Retains permanent WO identity and business fields, including:

- WO UUID;
- organization;
- WO number;
- property address;
- current work-type display context;
- current run pointer;
- remote Drive WO folder identity when known;
- current operational projection used by existing APIs/dashboard during migration.

### `work_order_runs`

At minimum:

- run UUID;
- WO UUID;
- run sequence (`1`, `2`, ... for display only);
- reopen reason when applicable;
- current/current-final assignee;
- run field state;
- assignment-received timestamp for the current assignment instance/projection;
- started event time;
- field-completed event time;
- requirement snapshot;
- created/closed timestamps.

### Assignment history

Preserve a narrow assignment history for each run sufficient to answer:

- who the run was assigned to;
- when assignment began;
- whether/when that contractor received it;
- when assignment ended;
- whether it ended by reassignment, handoff, cancellation, completion, or deactivation-related Admin action.

This may be a small append-only assignment-history table. It is not a generalized audit/event architecture.

Existing Phase 2 current-assignment fields may remain as transactional projections while migrating, but history must not be silently overwritten.

### Photos and offline actions

Once run identity exists:

- every new photo binds to both WO UUID and run UUID;
- every offline START/COMPLETE action binds to the exact run UUID;
- run UUID is included in remote metadata/appProperties where practical;
- a photo never moves from one run/WO identity to another.

Existing disposable/legacy test rows are backfilled into Run 1 during the controlled migration.

## Run states

Keep durable field states small:

`ASSIGNED → IN_PROGRESS → FIELD_COMPLETE`

`CANCELLED` remains separate.

Photo delivery state is not a WO/run field state.

## Assignment and reassignment

- `ASSIGNED` work may be reassigned immediately by Admin.
- `IN_PROGRESS` reassignment requires the current contractor consent path.
- Once Phase 4 exists, the contractor app must not knowingly approve an in-progress handoff while that device still has unresolved field actions or unsynchronized photos for the run. It must sync first or surface a blocker.
- Server assignment remains authoritative.
- Local evidence from an offline stale assignment is preserved as conflict rather than forced through or deleted.

## Assignment receipt

Receipt means the assigned contractor app successfully and durably downloaded that assignment/run.

It does **not** mean the human read every instruction.

Receipt is acknowledged only after the assignment is durably committed locally.

Every new assignment instance requiring redispatch gets its own receipt truth. Do not reuse an old contractor receipt as proof of a later assignment.

## Post-start edit rule

Before `IN_PROGRESS`, Admin may edit normal dispatch fields under the assignment and requirement rules.

After Start Work:

- work type is frozen for that run;
- requirement snapshot is frozen for that run;
- address may be corrected only when it is still the same property (typo/format/canonicalization);
- changing to a different property requires cancelling that WO/run and creating a new WO;
- instructions become additive timestamped Admin updates/notes rather than silently replacing the instructions originally received;
- due date may be corrected but the change is auditable;
- reassignment follows the consent/handoff rules.

Principle: **after Start Work, corrections may clarify the job; they do not redefine the job.**

## Requirement bypass

V1 has no contractor self-bypass of required photo counts and no generic “ignore requirements” button.

A run cannot be field-completed while its active snapshot is unmet.

Do not build a broad Admin override merely in anticipation of rare exceptions. If real pilot evidence proves an exception path is required, add a narrow Admin-only, reasoned design deliberately.

## Cancellation versus deletion

Normal organization Admins may **Cancel Work Order** but may not hard-delete real dispatched work.

- untouched `ASSIGNED` work with no local/server activity/photos can cancel cleanly;
- if started work, pending offline actions, or photos exist, cancellation preserves them and becomes a protected cancellation/offline conflict until explicitly resolved;
- cancellation never erases assignment/status/photo evidence;
- completed work is not cancelled; later work uses Reopen;
- cancelled work is not generically “uncancelled” in v1; if the business reissues work, use a deliberate new dispatch/new WO unless pilot evidence proves same-WO restore is required;
- hard deletion is reserved for controlled test/development cleanup or another operator-only maintenance path.

Principle: **before completion, cancel; after completion, reopen; normal Admins do not hard-delete real work.**

## Reopen Work Order

A fully completed WO may be reopened only through explicit **Reopen Work Order**.

Required behavior:

- Admin must provide a reopen reason;
- same Team WO UUID remains;
- same Drive WO folder/archive identity remains;
- all prior runs, assignments, receipts, requirements, photos, and delivery evidence remain preserved;
- generic status editing cannot silently roll a completed WO backward;
- reopening creates a new run UUID/sequence.

### Reopened assignment

Reopening does not return control to the prior contractor.

Admin explicitly chooses an active contractor for the new run before redispatch.

Prior assignment creates no continuing ownership right.

If the previous contractor performed the work incorrectly or previously gave up/approved reassignment, Admin may choose someone else.

### Reopened receipt

Every reopened redispatch requires a fresh receipt even if Admin chooses the same contractor again.

Prior receipt stays with prior history.

### Reopened requirements and photo counts

Admin sets the reopened run's new requirement snapshot before redispatch.

The new run starts at **zero** for all of its own photo counters.

Old photos remain preserved/reference history but do not satisfy the new run's Total, Before, During, After, or Wide Angle requirements.

Example:

- prior run delivered 100 photos;
- HNP requests 12 replacement/additional photos;
- new run starts `0 / 12`.

## Field completion versus final Complete

Two truths remain separate:

**Field requirement satisfied / FIELD_COMPLETE**
- current run has enough valid protected captures to satisfy its frozen numeric requirement snapshot;
- contractor has performed Finish Field Work locally;
- server accepts completion once required metadata/authorization is synchronized.

**Fully Complete**
- current run is server field-complete;
- server-known current-run requirement counts are satisfied;
- every frozen current-run photo is resolved and confirmed delivered;
- no unresolved assignment, cancellation, delivery, or archive-placement problem remains.

Do not invent another durable field state merely for the human-facing Complete label.

---

# Authentication and offline access

First device use requires a successful online Supabase sign-in.

After a successful authenticated download:

- cache belongs to exact user UUID + organization UUID;
- previously downloaded work can reopen with zero signal after app/process/device restart;
- local offline access does not manufacture network authority;
- when connectivity exists, app refreshes/validates the server session before privileged network work;
- explicit Sign Out removes/invalidates reusable auth credentials and locks ordinary access to cached work;
- Sign Out does not delete unresolved actions/photos/evidence;
- another authenticated user on the phone never sees prior-user cache/evidence;
- prior-user unresolved evidence remains quarantined by user UUID;
- successful server revocation/deactivation stops future server work but does not destroy already-captured evidence.

Credential storage remains app-private and uses appropriate current Android secure storage; credentials are never logged or committed.

---

# HNP archive and delivery semantics

## Approved Drive hierarchy

Development root initially:

`Field Photo Prep Team - HNP / TEST / Work Orders`

Inside:

```text
Work Orders
└── Contractor
    └── Property Address
        └── Work Order
            ├── field-photo-<uuid>.jpg
            └── field-photo-<uuid>.jpg
```

There is no extra `Photos` child in v1.

## Contractor folder

- visible name uses current contractor display name;
- permanent identity is Auth user UUID;
- use contractor UUID `appProperties` where practical;
- rename must not create another identity;
- email is not permanent identity.

## Address folder

- organizational display context only;
- no permanent `properties` table merely for Drive layout;
- resolve/reuse only beneath the exact contractor parent;
- same visible address may exist under multiple contractors;
- do not auto-delete empty address folders.

## Work-order folder

Human-facing name:

`<WO number> - <work type>`

Identity:

- Team WO UUID in `appProperties` where practical;
- exact returned Drive folder ID stored server-side;
- once Drive ID exists, target it directly;
- display edits never replace WO identity.

## Reassignment/reopen folder movement

The Drive hierarchy follows the **current approved assignment**, but only the exact WO archive moves.

When current assignment changes and a remote WO folder already exists:

- move the same WO folder ID beneath the new contractor's matching address parent;
- preserve every existing historical/current photo inside;
- do not move sibling WOs;
- do not move the old contractor's entire address folder;
- do not copy photos into a replacement WO folder;
- do not auto-delete the old empty address folder;
- in-progress move occurs only after consent actually changes the server assignee;
- reopened redispatch to a different contractor may move the same completed WO folder after the new run assignment is committed;
- ambiguous move preserves the same known folder ID, surfaces placement problem, and reconciles before any retry/create.

If no remote WO folder exists yet, nothing is moved; first authorized delivery creates/resolves beneath the current assignment.

## Photo remote identity

Baseline filename:

`field-photo-<photo UUID>.jpg`

Remote metadata should include where practical:

- Team photo UUID;
- Team WO UUID;
- Team run UUID.

The confirmed Drive file ID becomes remote photo identity.

## Delivery confirmation, not permanent-presence policing

Team must prove each photo was successfully delivered to the exact authorized WO folder and retain lightweight evidence:

- photo UUID;
- WO UUID;
- run UUID;
- capturing/assigned contractor identity as required for history;
- upload-confirmed timestamp;
- Drive file ID that existed at confirmation.

HNP post-delivery retention behavior is currently **UNKNOWN**.

Therefore:

- do not assume HNP keeps forever, moves, or deletes;
- Team does not continuously police permanent Drive presence;
- later file absence alone never triggers automatic recreation/re-upload;
- `UNCERTAIN` reconciliation is for an ambiguous in-flight delivery, not perpetual retention auditing;
- if HNP later documents a retention/consumption policy, adapt deliberately.

Dashboard language says **delivery/upload confirmed**, not guaranteed permanent presence.

---

# Phase 0 — Separation and test foundation — COMPLETE

Completed and verified:

- separate Team repository;
- separate Android package/app identity and app data;
- dedicated HNP TEST storage root/account;
- separate Supabase project;
- credentials outside GitHub;
- Team and FPP install side-by-side;
- real phone opened both independently.

Gate: **SATISFIED.**

---

# Phase 1 — Identity, login, minimum server model — COMPLETE

Completed:

- Supabase Auth user identity;
- server-controlled org + role;
- only ADMIN/CONTRACTOR roles;
- base `organizations`, `work_orders`, `photos`;
- RLS/explicit grants;
- narrow contractor Start/Complete actions;
- real Admin/Contractor RLS boundaries;
- stable Team internal signer;
- migration history mirrored under `supabase/migrations/`.

Gate: **SATISFIED.**

---

# Phase 2 — Admin dashboard and dispatch — IMPLEMENTED; FINAL REAL-CLIENT CLOSURE SMOKE PENDING

## Existing implemented behavior

- create/edit WO;
- auto or custom WO number;
- address/work type/instructions/due date;
- assign contractor;
- immediate `ASSIGNED` reassignment;
- `IN_PROGRESS` consent handoff;
- contractor approve/decline;
- assignment receipt after authenticated download;
- receipt reset on assignee change;
- Admin receipt/handoff visibility;
- organization WO-number duplicate guard;
- tab-scoped dashboard session refresh behavior.

## Existing proof

- hosted Admin create/assign;
- Contractor receives under RLS;
- Admin-only controls stay hidden;
- real Android receipt auto-ack;
- dashboard refresh session works;
- backend/CI coverage for edit/reassign/consent/receipt/numbering/authorization/direct-table restrictions.

## Final closure smoke

With disposable data:

1. reassign an `ASSIGNED` WO away;
2. old contractor refresh no longer receives;
3. receipt resets;
4. reassign back;
5. contractor receives and receipt confirms;
6. if practical, perform one real `IN_PROGRESS` Approve/Decline handoff.

Gate: **PENDING ONLY THIS COMPACT REAL-CLIENT SMOKE.**

Future template/run/lifecycle additions do not retroactively make this existing dispatch baseline “unfinished”; they are implemented in their roadmap phases.

---

# Phase 3 — Run identity, Room work list, and offline field actions — PLANNED; NOT AUTHORIZED

## Goal

Make assigned work reliable with no internet, including restart, while introducing the minimum run identity needed so later reopen/photo behavior cannot overwrite history.

## 3A — Server run foundation + Room cache

Before the Android offline model depends on it:

- add narrow `work_order_runs`;
- backfill existing valid WOs into Run 1;
- add current run pointer/projection safely;
- preserve current Phase 2 behavior during migration;
- bind assignment receipt to the current assignment/run history;
- add Room schema for cached WOs/runs;
- cache by immutable WO UUID + run UUID + user/org ownership;
- UI reads normal work list/details from Room;
- online refresh transactionally updates Room;
- acknowledge receipt only after durable Room save;
- migration tests begin with Room v1.

Minimum cached data:

- WO UUID;
- run UUID/sequence;
- org UUID;
- assigned user UUID;
- WO number/address/work type;
- base instructions + synced Admin updates;
- due date;
- requirement snapshot when available;
- server run state/timestamps;
- receipt timestamp;
- server snapshot marker/updated_at;
- last successful sync;
- cache-owner user UUID.

## 3B — Offline Start/Finish queue

Each local field action has its own UUID and stores:

- action UUID;
- WO UUID;
- run UUID;
- user UUID;
- `START` or `COMPLETE`;
- truthful local event timestamp;
- deterministic ordering/creation time;
- pending/syncing/accepted/conflict state.

Rules:

- persist action before UI reports it queued;
- offline Start survives restart;
- offline Finish survives restart;
- Start → Finish ordering is deterministic;
- retries are idempotent;
- server validates current user/org/assignment/run/transition/timestamp sanity;
- server acceptance remains authoritative;
- WorkManager is not required merely to prove queue correctness if app-open sync proves it first.

Before Phase 4 exists, Finish validation is only field-state based. After Phase 4 requirement/photos exist, the extended rule below applies.

## 3C — Reconciliation + persistent action sync

Introduce WorkManager only after the queue is already correct.

Worker:

- re-reads Room before each action;
- creates no new authority;
- retries retry-safe transport failures with backoff;
- turns authorization/state rejection into visible conflict/terminal local result, not infinite retry.

## Cache reconciliation

### Still assigned

Update mutable server snapshot while preserving unresolved local overlays/evidence.

### No longer returned and untouched

If there is no local Start/pending/photo evidence, remove from active list after reconciliation without inventing a conflict.

### No longer assigned/cancelled but local evidence exists

- preserve local row/evidence;
- show conflict;
- do not force unauthorized actions;
- do not delete;
- do not claim server completion;
- require explicit Admin resolution.

Conservative v1 resolution:

- Admin may restore/reassign work back when the local evidence should be accepted;
- otherwise protected conflict remains until a later explicitly governed discard/recovery path exists.

## Session/restart

- first use online;
- downloaded work usable offline after restart;
- no-network token refresh failure does not erase previously authorized offline work;
- Sign Out locks but preserves evidence;
- revocation/deactivation stops future server work after validation but never deletes evidence.

## Automated proof

At minimum:

- multiple assignments survive reconstruction;
- user A cache invisible to user B;
- refresh does not erase pending overlay;
- receipt only after durable save;
- offline Start/Finish survive restart;
- ordered idempotent sync;
- truthful event times;
- transport retry safety;
- stale reassignment/cancel becomes conflict without deletion;
- untouched removed assignment safely evicts;
- Sign Out preserves unresolved evidence;
- every Room migration tested.

## Physical gate

1. sign in online;
2. download at least two disposable WOs;
3. verify receipt;
4. disable network;
5. kill/restart;
6. open cached work;
7. Start/Finish offline;
8. restore network;
9. prove exactly-once ordered server acceptance with truthful event times;
10. repeat one offline reassignment/cancel race and prove conflict preservation.

Completion gate: **multiple assignments, offline Start/Finish, restart, identity isolation, and one race are proven on real Android without manual DB repair.**

---

# Phase 4 — Photo requirements, CameraX capture, protection, and preparation — PLANNED

## Goal

Add the programmed photo rules and the proven FPP multi-shot field camera without weakening run identity or offline safety.

## 4A — Admin work-type templates + run requirement snapshots

Implement:

- organization-scoped reusable work-type templates;
- active/archive template behavior;
- flat dropdown + Custom/Other;
- numeric Total/B/D/A/Wide Angle requirements;
- validation rules from the global template section;
- copy template values into the run snapshot at WO/run creation;
- allow Admin edits before Start;
- freeze snapshot once run becomes `IN_PROGRESS`;
- no silent mid-job requirement mutation;
- contractor details show requirement summary before Start.

Do not add a named-shot checklist.

## Camera workflow

`Open assigned run → Camera → choose required stage when applicable → Take → Take → Take → Done`

Requirements:

- dominant CameraX preview;
- one large shutter;
- multi-shot same-run session;
- Done exits;
- controls respect system insets;
- Flash Auto/On/Off;
- Torch separate, default Off;
- pinch zoom + fine zoom;
- 1× normal rear framing;
- additional lens/zoom shortcuts only when device capability is proven;
- usable orientation;
- no network required.

## Stage and Wide Angle capture semantics

If B/D/A is enabled for the run:

- every captured photo must carry exactly one enabled stage label before shutter finalization;
- current stage remains selected until contractor changes it;
- contractor manually changes stage; Team does not guess/auto-advance business stage.

If no B/D/A is enabled:

- camera does not force a stage control.

Wide Angle:

- independent designation/mode;
- photo may count toward both one stage and Wide Angle;
- use the widest reliable supported rear-camera path where CameraX/device capability permits;
- if no dedicated ultra-wide lens is reliably exposed, Team may still use the widest supported normal rear framing for the designated Wide Angle workflow;
- Team enforces the designated capture/count workflow, not visual composition quality;
- no image-content judging in v1.

Live counters show current-run progress and remaining requirement.

## Capture transaction

Before each shutter write:

1. verify exact cached WO UUID + run UUID + local user;
2. generate permanent photo UUID;
3. reserve app-private protected-original path;
4. persist Room photo record as `CAPTURING` bound to WO/run/capturing user and chosen stage/Wide designation;
5. only then allow CameraX write.

After callback:

- non-empty successful image → durable `WAITING`;
- abnormal callback with non-empty bytes → preserve/reconcile, never discard evidence merely because callback was abnormal;
- empty unused reservation → safe cleanup;
- next shutter only after prior transaction is durably finalized.

## Photo identity

Permanent binding:

- photo UUID;
- WO UUID;
- run UUID;
- capturing user UUID;
- captured timestamp;
- stage designation where applicable;
- Wide Angle designation.

Later address/work type/reassignment/reopen never redirects the photo to another run or WO.

## Local files

- protected original: app-private and immutable until confirmed remote delivery + durable bookkeeping;
- prepared derivative: app-private, deterministic from photo UUID, recreatable while original exists;
- Room metadata is persistence authority.

## Automatic preparation

After durable `WAITING`:

- best-effort in-process serialized preparation;
- scheduling failure cannot invalidate capture;
- camera remains usable while preparation continues;
- deterministic prepared path;
- max 2048 px long edge;
- JPEG 85;
- no upscaling;
- usable orientation;
- preparation failure leaves original/WAITING recoverable;
- startup requeues eligible waiting photos missing derivative.

Preparation occurs **during field work**, incrementally. Do not wait until Finish to process a 100-photo job.

No WorkManager merely for preparation unless real Team evidence proves it necessary.

## Safe pre-Finish discard

Before Finish:

- explicit contractor action + confirmation;
- only eligible local photos may be discarded;
- discard updates current-run Total/stage/Wide counters;
- remote Drive content is never deleted by this action;
- `UPLOADING`, `UNCERTAIN`, `UPLOADED`, and frozen post-Finish photos are not ordinary-discard eligible;
- validate a batch fully before first deletion if batch discard is ever added.

## Restart recovery

- `CAPTURING` + non-empty original → preserve/reconcile to recoverable `WAITING`;
- `CAPTURING` + empty/missing reservation → remove empty reservation only;
- `WAITING` + valid original → retain;
- `WAITING` + missing/empty original → visible problem, never pretend safe;
- eligible missing derivative → prepare again.

## Low-storage safety

- never auto-delete unresolved/protected evidence to make space;
- a new capture that cannot reserve/write safe storage fails visibly before being counted;
- preparation failure from low storage leaves original safe;
- confirmed-delivery cleanup later frees local bytes.

## Finish Field Work with photos

Local Finish is allowed only when current-run protected valid captures satisfy the frozen requirement snapshot.

When contractor taps Finish:

1. persist local COMPLETE intent;
2. freeze the current run's eligible photo set and counts;
3. ordinary contractor delete/detach becomes blocked for that frozen set;
4. run becomes locally field-complete/pending server acceptance;
5. HNP delivery becomes **eligible**, but no privileged upload occurs until authenticated server synchronization confirms authorization.

When connectivity returns after Phase 5 exists, safe order is:

1. synchronize frozen photo metadata using existing phone UUIDs/run UUID;
2. synchronize/accept server Finish with requirement validation;
3. only after server authorization permits the completed run, start/resume HNP byte delivery.

This prevents a stale/reassigned/cancelled offline run from uploading before server ownership is resolved.

A `WAITING`, `FAILED`, or `UNCERTAIN` upload photo still counts as captured field evidence; it does not count as delivered.

## Server photo metadata timing

V1 does not require every in-progress photo to be mirrored to Supabase while the contractor is still shooting.

To keep pre-Finish discard simple:

- local Room owns in-progress capture metadata;
- on Finish/reconnect the frozen set is registered/upserted server-side with the same phone-generated UUIDs before/alongside completion acceptance;
- server never allocates a replacement photo ID.

## Automated proof

At minimum:

- template validation/snapshot/freeze;
- old runs unaffected by template edits/rename/archive;
- unique photo UUID/path per shutter;
- `CAPTURING` persisted before write;
- immutable WO/run/user binding;
- sequential shots cannot overwrite;
- abnormal non-empty callback preserved;
- stage/Wide counts correct;
- discard decrements eligible counters;
- Finish blocks unmet requirements;
- Finish freezes evidence;
- prep dimensions/quality/orientation;
- original unchanged by prep;
- serialized prep/recovery;
- network-independent capture;
- server metadata uses same UUID/run;
- conflict cannot delete/redirect photo.

## Physical gate

Fully offline:

1. open disposable cached run;
2. verify requirement summary/counters;
3. CameraX multi-shot;
4. exercise applicable stage/Wide/flash/torch/zoom/orientation;
5. discard one safe pre-Finish bad photo;
6. satisfy requirements;
7. Finish offline;
8. kill/restart;
9. verify frozen originals/prepared copies/counters/run binding survive;
10. verify no network was required.

Completion gate: **one disposable run can satisfy programmed photo rules, capture repeatedly offline, protect/prepare/freeze evidence, and survive restart on real Android.**

---

# Phase 5 — Safe server-mediated HNP delivery — PLANNED

## Goal

Deliver the frozen completed-run photo set to the exact company-controlled HNP folder without reusable HNP credentials on the contractor phone and without duplicate creates during weak/interrupted connectivity.

## Security boundary

Android calls authenticated Team backend with user JWT.

Backend:

- validates user/org/active account;
- validates exact WO/run/photo;
- validates current authorization/conflict state;
- owns HNP Drive secrets;
- never returns OAuth refresh/service secrets;
- issues only narrow per-photo upload/session capability required for the authorized operation.

## Drive hierarchy resolution

Resolve from stable identity outward.

### Contractor parent

- use stored contractor Drive folder ID if valid;
- otherwise search root by contractor UUID appProperties, not name alone;
- one match reuse;
- none create with current display name + UUID metadata;
- multiple/inconclusive fail closed.

### Address parent

- resolve only beneath exact contractor parent;
- exact suitable folder may be reused;
- otherwise create;
- never cross into same-named address under another contractor;
- ambiguity fails closed.

### WO folder

- stored `remote_folder_id` first;
- verify expected WO where practical;
- if absent search intended parent by Team WO UUID metadata;
- one reuse;
- none create `<WO number> - <work type>`;
- multiple/inconclusive fail closed;
- persist exact returned Drive ID.

Once known, Drive WO folder ID is authoritative remote destination.

## Folder move

On approved assignment change:

- move same WO folder ID only;
- keep all historical/current photos inside;
- preserve WO UUID;
- do not create replacement;
- do not move siblings/address folder;
- ambiguous outcome → archive-placement problem and reconciliation;
- no remote folder → no move yet.

## Upload baseline

Prefer Drive resumable upload.

Safe flow:

1. prepared copy exists and size/hash evidence known;
2. frozen photo metadata exists server-side and is authorized;
3. server run completion/current ownership is accepted;
4. backend starts resumable session for exact stored WO folder and deterministic filename;
5. Android persists session capability/URI **before bytes**;
6. transition/retain `UPLOADING`;
7. send/resume bytes;
8. final Drive result establishes exact file ID;
9. server + local bookkeeping durably record delivery confirmation;
10. only then local image cleanup becomes eligible.

Session capability is sensitive app-private state and is never logged/displayed/committed.

## Persistent background delivery

WorkManager is appropriate here.

Baseline:

- network constraint `CONNECTED`;
- cellular or Wi-Fi allowed in pilot;
- no Wi-Fi-only preference unless field evidence proves need;
- worker re-reads Room each attempt;
- process restart/reboot resumes eligible work;
- photos deliver sequentially by default;
- one known retry-safe failure need not corrupt/block unrelated safe photos;
- `UNCERTAIN` never authorizes blind duplicate create.

## States

Normal:

`WAITING → UPLOADING → UPLOADED`

Known retry-safe:

`WAITING/FAILED → UPLOADING → FAILED`

Ambiguous:

`UPLOADING → UNCERTAIN`

`UPLOADED` is terminal for automatic retry.

## Interrupted resumable upload

Preserve exact WO/run/photo, prepared bytes, session URI, attempt evidence.

Then:

- complete → confirm exact remote identity;
- incomplete → continue from server position;
- expired/missing session → reconcile exact stored WO folder using photo UUID/appProperties/deterministic name before replacement session;
- inconclusive → `UNCERTAIN`, no blind create.

## UNCERTAIN reconciliation

1. validate local photo/run/WO/prepared evidence;
2. use exact session/provisional evidence first;
3. inspect exact stored WO folder by photo UUID/app metadata/deterministic name;
4. exactly one strong candidate → verify metadata/size/checksum/hash as needed then confirm;
5. multiple candidates → remain uncertain;
6. authoritative absence + no unresolved provisional evidence → release to retry-safe `FAILED`;
7. inaccessible/mismatched/ambiguous → remain uncertain;
8. reconciliation never deletes/overwrites remote content merely to simplify state.

## Post-Finish phone experience

Finish means **field work is done**, not “wait on an upload screen.”

After Finish:

- contractor may leave WO screen;
- open another WO;
- lock phone;
- close app;
- restart device.

Durable queue survives.

Phone shows truthful states such as:

- Waiting for connection;
- Sending `18 of 42`;
- Delivery problem — retrying;
- Action needed.

`UNCERTAIN` remains visibly unresolved.

Sign Out stops authenticated network delivery but preserves frozen photos/queue; delivery resumes after the same contractor signs in and authorization validates.

## Persistent failure surfacing

V1 does not add a business push-notification subsystem merely for delivery failures.

Instead:

- unresolved delivery appears as persistent **Needs Attention / Delivery Problem** in contractor app whenever reopened;
- Admin dashboard shows the WO as Problem;
- job cannot disappear into Recently Completed while unresolved;
- Android OS notifications required by WorkManager/foreground execution are implementation mechanics, not a separate product messaging system.

## Cleanup

After durable local + server delivery confirmation with Drive file ID:

- protected original may be deleted safely;
- prepared derivative may be deleted safely;
- retain lightweight identity/delivery metadata;
- cleanup failure does not roll remote state backward;
- cleanup never triggers re-upload.

## Delivery-confirmation retention rule

Later Drive absence alone does not change `UPLOADED`/confirmed-delivery history and does not trigger re-upload.

## Automated proof

At minimum:

- authorization/org/assignment/run guard;
- no server/HNP secrets in clients;
- unique contractor/address/WO resolution;
- ambiguous hierarchy fails closed;
- exact WO folder move only;
- deterministic filename/metadata incl run;
- session persisted before bytes;
- restart/resume;
- server-reported position;
- retry-safe vs uncertain;
- no blind duplicate create;
- one remote candidate can reconcile;
- authoritative absence can safely release retry;
- multiple candidates remain uncertain;
- cleanup only after confirmation;
- WorkManager idempotency;
- Sign Out pauses without deleting queue;
- unresolved failures remain visible.

## Provider gate

Using disposable HNP TEST data:

1. resolve contractor/address/WO folder;
2. use Phase 4 frozen offline photos;
3. restore connectivity;
4. metadata + completion sync first;
5. deliver several photos sequentially;
6. kill/restart during queue;
7. interrupt one upload safely;
8. prove resume/reconcile without duplicate;
9. verify exact Drive IDs retained;
10. verify cleanup;
11. reassign one disposable WO and move only same folder;
12. verify unrelated TEST content untouched.

Do not manufacture a dangerous ambiguity solely to satisfy a test.

Completion gate: **frozen offline evidence survives interruption/restart and reaches the exact HNP TEST archive through server mediation without reusable contractor Drive credentials, wrong placement, or blind duplicates.**

---

# Phase 6 — Admin operational truth, completion history, reopen/cancel, and problem resolution — PLANNED

## Goal

Give the office a truthful operational view and the minimum lifecycle controls needed after the field/photo engine is proven.

## Dashboard facts

At minimum per current run:

- contractor;
- receipt;
- due date;
- server field state;
- start time;
- field-complete time;
- frozen requirement snapshot;
- server-known captured counts (Total/B/D/A/Wide where applicable);
- delivered count;
- waiting/uploading;
- failed;
- uncertain;
- assignment/offline/cancellation conflict;
- archive-placement problem;
- pending handoff;
- current run sequence/reopen reason when applicable.

Dashboard never claims knowledge of phone-only unsynchronized facts.

## Derived views

Use derived presentation, not extra field states:

- Due/upcoming;
- Overdue;
- In progress;
- Field complete — photos pending;
- Complete;
- Problem.

**Complete** requires current-run requirements satisfied server-side, current run field-complete, all frozen current-run photos confirmed delivered, and no unresolved problem.

A server that knows zero current-run photos cannot claim Complete if the run snapshot requires photos.

## Metadata-first reconnect truth

After offline Finish, synchronize small metadata/field facts before or alongside large photo bytes:

- frozen photo metadata first;
- field completion acceptance with requirement validation;
- dashboard becomes `Field complete — photos pending`;
- bytes continue;
- final delivery turns derived view to Complete.

## Completed visibility

Admin:

- fully Complete leaves normal Active queue automatically;
- stays searchable in Completed/history indefinitely unless explicit later retention policy changes that.

Contractor Android:

- fully Complete leaves active work;
- appears in lightweight Recently Completed for 7 days;
- then drops from normal phone UI;
- server metadata/history remains;
- local delivered image bytes need not remain for 7 days.

## Reopen UI/action

Admin `Reopen Work Order`:

- requires reason;
- shows prior runs/requirements for reference;
- creates new run;
- Admin chooses active contractor;
- Admin sets new requirement snapshot;
- fresh receipt required;
- photo counts start zero;
- same WO UUID/Drive folder identity.

If original contractor is inactive, that does not block reopen; Admin selects any eligible active contractor.

## Cancel action

Admin can cancel non-complete work under the global cancellation rules.

If protected local evidence later reports conflict, dashboard surfaces resolution need rather than pretending cancellation erased it.

## Conflict resolution

Keep lean.

Minimum actions may include:

- restore/reassign to contractor whose protected offline work should be accepted;
- reconcile exact existing Drive placement;
- clear a resolved problem only after server/local evidence proves protection is no longer needed.

Do not build generic case management.

## Automated proof

- derived counts/status from server facts;
- org/RLS isolation;
- no cross-contractor leakage;
- required counts prevent false Complete;
- field-complete does not imply delivered;
- failed/uncertain/conflict/archive issue cannot render Complete;
- Completed/Recent visibility rules;
- Reopen creates new run, fresh receipt, zero counters, same WO;
- old history remains unchanged;
- Cancel preserves evidence;
- repeated retries remain idempotent.

## End-to-end gate

1. contractor completes offline with required photos;
2. Admin initially sees old server facts only;
3. reconnect;
4. metadata + completion arrive;
5. Admin sees `Field complete — photos pending`;
6. photos deliver;
7. Admin sees Complete and contractor gets Recently Completed;
8. reopen same WO to a chosen contractor with a new requirement;
9. verify fresh receipt/zero counters/prior history;
10. repeat one safe failure/conflict and show Problem.

Completion gate: **office can accurately tell what is assigned, received, field-complete, delivering, fully complete, reopened, cancelled, or genuinely needs intervention without false certainty.**

---

# Phase 7 — Internal real-world Team pilot — PLANNED

## Goal

Use Team repeatedly under realistic field conditions before an outside HNP pilot.

## Rules

- FPP remains installed/untouched;
- Team remains test/disposable where possible;
- no live customer evidence when safe equivalent exists;
- fixes respond to observed failure/friction, not hypothetical features;
- manual DB/Drive repair is not accepted as normal operation.

## Required scenarios

Exercise repeatedly:

- same-address multiple WOs;
- different work types at same address;
- multiple WOs on one phone;
- work-type templates + Custom/Other;
- numeric photo requirements;
- B/D/A and inspection/no-stage jobs;
- Wide Angle workflow;
- due date/instruction updates;
- receipt;
- online Start/Finish;
- offline Start/Finish;
- app kill/phone restart;
- multiple offline CameraX sessions;
- realistic high photo counts;
- incremental preparation while still capturing;
- pre-Finish bad-photo discard;
- post-Finish frozen queue while contractor moves to another job;
- weak cellular;
- lost connectivity during delivery;
- later cellular/Wi-Fi recovery;
- one retry-safe failure;
- one safely observable uncertain/reconciliation case where feasible;
- reassignment while untouched;
- approved in-progress handoff;
- offline reassignment/cancel race;
- exact single-WO Drive move with siblings unchanged;
- completed → reopen to same contractor and different contractor;
- fresh reopened receipt + zero counts;
- signout/signin;
- deactivation/reactivation recovery with disposable evidence if safe;
- low-storage behavior where practical;
- app update over existing install without state loss;
- final archive placement;
- Admin Completed/Problem views.

## Failure bar

Not stable if routine use requires:

- SQL/manual row repair;
- app-data deletion;
- reinstall to clear queues;
- manual Drive photo/WO move;
- repeated blind retry until uncertain upload happens to work;
- FPP fallback for Team data.

## Lean architecture review

Before leaving Phase 7:

- inventory actual dependencies/components;
- identify complexity that protects demonstrated safety;
- remove obvious dead/duplicate architecture only when safe;
- do not refactor working code for cosmetic architecture;
- keep the smallest architecture that passed real use.

Completion gate: **repeated internal field sessions succeed without lost/misattributed work, duplicate remote files/WOs, manual repair, or unexplained intermittent failures.**

---

# Phase 8 — Production readiness and small HNP pilot — PLANNED

## Goal

Harden only what is required for a small outside pilot.

## 8A — Production identity/environment

- production package `com.inandout.fieldphotoprep.team`;
- production label `Field Photo Prep Team`;
- production signing key outside public repo;
- deliberate versionCode/versionName;
- production Supabase environment separated from disposable development data where practical;
- production HNP Drive root separated from TEST;
- approved Contractor → Address → WO hierarchy;
- server-only secrets;
- no test IDs/PII baked into clients;
- known rollback APK/build identity.

Internal package remains separate.

## 8B — User lifecycle and seats

Implement/prove:

- server-controlled contractor seat cap;
- Admin contractor invite flow;
- pending-seat reservation;
- resend/cancel invite;
- secure password setup/reset;
- activation/deactivation/reactivation;
- assignable list excludes inactive contractors;
- active-assignment warning before deactivation;
- seat released only after durable deactivation;
- historical identity remains;
- product-owner-controlled additional Admin creation;
- one-field-device support statement.

Example deactivation warning:

> This contractor has 4 assigned WOs and 2 in-progress WOs. Deactivation will stop new access but will not automatically move or cancel these work orders.

## 8C — Storage ownership, retention, recovery

Document before outside use:

- HNP owns/controls remote archive;
- contractor-folder rename responsibility;
- empty address folders remain unless manually cleaned;
- local confirmed image bytes normally cleaned after durable delivery evidence;
- server metadata retention;
- HNP post-delivery file retention remains unknown unless documented;
- what happens if HNP Google account loses access/quota;
- Supabase backup/export level for pilot;
- whether free storage remains adequate.

Do not buy/build more storage complexity until real use requires it.

## 8D — Controlled update path

- one documented production install/update method;
- update preserves Room DB, cached WOs/runs, actions, photos, queue state;
- migration tests for every production schema change;
- rollback does not delete unresolved evidence;
- Play Store publication only if distribution need proves it useful.

## 8E — Second-phone/outside-user gate

On another supported Android phone/account:

- install production candidate;
- sign in as pilot Contractor;
- receive disposable pilot WO;
- use offline;
- capture required photos;
- restart;
- finish;
- reconnect/deliver;
- verify Admin truth;
- verify exact HNP placement;
- prove nothing depends on developer phone local identity/session.

## Small HNP pilot

Start small: few users, low-risk/disposable pilot work where possible, close feedback.

Answer only:

- is dispatch clear;
- is offline behavior trustworthy;
- is camera workflow fast;
- are requirements understandable;
- are photos reliably delivered;
- is archive organization useful;
- can Admin see finished/pending/problem work;
- are account/update/storage operations manageable.

Only observed pilot needs authorize expansion.

Completion gate: **small HNP pilot operates with controlled identity, seats/user lifecycle, safe updates, known storage recovery, and repeated end-to-end work without exposed privileged credentials or developer-only repair.**

---

# Explicit first-version non-requirements / deferred features

Keep out unless real evidence changes the roadmap:

- route optimization;
- payroll/contractor payment;
- invoicing/accounting;
- customer billing tiers;
- OCR/AI photo classification/judging;
- named required-shot checklist;
- generic photo-requirement override/bypass;
- business push-notification subsystem;
- video;
- continuous/live location;
- employee time tracking;
- iOS;
- public marketplace;
- advanced analytics/report builder;
- permanent local photo gallery;
- multiple storage-provider abstraction;
- permanent Property entity solely for Drive organization;
- automatic deletion of empty contractor/address folders;
- property-preservation management beyond dispatch/photo workflow;
- extra roles without demonstrated need;
- generalized event sourcing;
- simultaneous multi-device field merge;
- generalized case-management system;
- dependency-injection/framework layers merely for architectural fashion.

---

# Implementation references to re-check at runtime

Re-read current official documentation when implementing; do not rely on roadmap memory of external APIs:

- Android Room;
- Android offline-first data guidance;
- Android WorkManager;
- Android CameraX;
- Google Drive API parent/move/appProperties/search/resumable upload behavior;
- Supabase Auth/RLS/JWT/Edge Functions/secrets/current API-key model.

---

# Roadmap approval and runtime gate

This roadmap was **approved by the operator on 2026-09-14** and is the current authoritative Team product/implementation plan.

Roadmap approval does **not** bypass runtime governance. Phase 3 runtime work, Room migration, Supabase run migration, WorkManager workers, CameraX Team work, template schema changes, Edge Functions, and Drive API integration remain subject to the governing change-control/Level-3 rules.

Before Phase 3 runtime begins:

1. finish the compact remaining Phase 2 real-client reassignment/consent smoke if still pending;
2. reread governance + this roadmap;
3. obtain the explicit Level-3 runtime authorization required by the governing contracts;
4. create a Level-3 impact/implementation record only where concrete schema/API details are not already sufficiently specified;
5. implement Phase 3 in the largest safe automated-testable slices;
6. stop once at the documented real-device boundary;
7. record physical evidence once;
8. continue only when evidence supports the next phase.

Principle:

**plan fully → build everything provable without the phone → stage at the genuine device/provider boundary → run the smallest reality gate → accept evidence → adjust only when reality contradicts the plan.**
