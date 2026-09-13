# Field Photo Prep Team Roadmap

## Purpose

Field Photo Prep Team is the separate multi-user/commercial version of Field Photo Prep.

The first target is a small HNP pilot:

**Admin assigns work on a PC/laptop → contractor receives the work order on Android → contractor can work and take protected photos offline → photos upload safely when connectivity returns → admin can see field completion and photo-sync status.**

The existing Field Photo Prep app remains separate and is not a Team test environment.

## Build rule

Build only what the current workflow needs. Keep identities and boundaries clean enough to grow later without rebuilding the foundation.

Do not add tools, screens, settings, roles, services, or frameworks merely because they may be useful someday.

## Decisions already made

- Team is a separate repository and Android app from Field Photo Prep V1.
- Team will use permanent IDs for companies, users, work orders, and photos.
- Initial user roles are `ADMIN` and `CONTRACTOR` only.
- Supabase is the planned backend for authentication, work-order data, assignments, permissions, and status.
- Android will keep downloaded work orders locally so assigned work remains usable offline.
- Taking a photo and uploading a photo are separate operations.
- Proven V1 camera/photo-protection behavior will be ported where appropriate rather than redesigned without reason.
- Initial HNP photo storage is a dedicated Google account controlled for Team testing.
- Current test storage root is `Field Photo Prep Team - HNP / TEST / Work Orders`.
- Storage credentials are owner-managed and must never be committed to this repository.
- Contractors will not receive the HNP storage-account password.
- Team should not be permanently coupled to Google Drive even though Google Drive is the initial photo destination.

## Phase 0 — Separation and test foundation — IN PROGRESS

Goal: create a safe Team development area without risking the working V1 field app.

Required:
- separate Team repository;
- separate Android package/application identity;
- separate local app data and queue;
- dedicated HNP test-storage account;
- dedicated disposable test folder hierarchy;
- credentials kept outside GitHub;
- Team and V1 installable side-by-side.

Already complete:
- Team repository created;
- dedicated HNP test Google account created and secured by the owner;
- test storage root created at `Field Photo Prep Team - HNP / TEST / Work Orders`.

Gate: V1 and Team can coexist on the same phone without sharing or altering data.

## Phase 1 — Identity, login, and minimum data model

Goal: establish the smallest backend foundation needed by both the dashboard and contractor app.

Minimum records:

### Company
- ID
- name

### User
- ID
- company ID
- name
- login identity
- role: `ADMIN` or `CONTRACTOR`
- active/inactive

### Work Order
- permanent Team WO ID
- company ID
- address
- outside/customer WO number
- work type
- instructions
- due date
- assigned contractor ID
- field status

### Photo
- permanent photo ID
- Team WO ID
- contractor ID
- capture time
- sync state
- confirmed remote file identity when uploaded

Authorization is enforced by the backend, not by hidden Android buttons.

Gate: one admin and one contractor can sign in and see only what their role permits.

## Phase 2 — Admin dashboard and assignment

Goal: let an admin dispatch work from a PC/laptop.

Admin needs only:
- create/edit a WO;
- address;
- external WO number;
- work type;
- instructions;
- due date;
- assign/reassign contractor;
- basic status.

Initial useful views:
- due today/upcoming;
- overdue;
- in progress;
- field complete;
- waiting on photos;
- complete/problem.

Gate: admin creates and assigns a disposable WO entirely from the dashboard.

## Phase 3 — Contractor work list and offline assignments

Goal: make assigned work usable even when the contractor has no internet.

Required:
- download assigned WOs;
- keep assigned WO details locally;
- open those WOs after connectivity is removed or the app restarts;
- begin/finish field work offline;
- do not silently destroy started work if an assignment changes while the phone is offline.

Gate: download multiple disposable WOs, disable connectivity, restart the phone, and continue working from the local assignments.

## Phase 4 — Offline camera and protected photos

Goal: bring the proven V1 field-photo workflow into Team.

Required:
- in-app multi-shot camera;
- unique protected photo identity before capture;
- immutable binding to the exact Team WO ID;
- protected local original;
- prepared/compressed upload copy;
- restart recovery;
- safe local discard;
- no internet requirement for capture.

Gate: complete a disposable WO with multiple photos fully offline, restart the app, and recover every protected photo correctly.

## Phase 5 — Safe photo synchronization

Goal: upload prepared photos when usable connectivity exists without losing or duplicating field evidence.

Required:
- queued uploads survive restart;
- each photo keeps its original WO binding;
- safe retry after known failure;
- uncertain remote outcomes do not cause blind duplicate retry;
- local originals are retained until remote success is durably confirmed;
- upload preference can initially be kept simple: allowed network vs Wi-Fi only, if field testing proves the choice is needed.

Initial permanent destination: the dedicated HNP Team Google storage account.

Contractor devices do not need the HNP storage-account password.

Gate: capture offline, restore connectivity, interrupt upload, restart, and confirm safe completion without missing or duplicate photos.

## Phase 6 — Admin completion and sync visibility

Goal: let the office distinguish work that was performed from photos that have not yet finished uploading.

Admin should be able to see, for a WO:
- assigned contractor;
- field status;
- field completion time;
- photos captured;
- photos confirmed uploaded;
- photos still waiting on device;
- upload problem if one exists.

Field completion and photo synchronization remain separate facts.

Gate: an offline field test appears accurately on the dashboard before and after connectivity returns.

## Phase 7 — Internal real-world pilot

Goal: use Team repeatedly before showing it to HNP.

Use:
- real addresses when useful;
- disposable Team WOs only;
- PC/laptop admin;
- Android contractor phone(s);
- realistic photo counts and poor-connectivity conditions.

Test assignment, due dates, offline work, multiple properties, large photo batches, phone restart, lost connectivity, later Wi-Fi/cellular recovery, and final archive placement.

The working Field Photo Prep V1 app remains installed and untouched.

Gate: Team works repeatedly without manual database repair or using V1 as a fallback for Team data.

## Phase 8 — HNP pilot readiness and pilot

Goal: harden only what is necessary for a small HNP pilot.

Before outside use, verify:
- production authentication and app signing;
- test/production separation;
- user revocation;
- backup/recovery sufficient for the pilot;
- controlled app updates;
- clear ownership/retention of HNP photos;
- appropriate paid storage only if the pilot requires it.

Then run a small HNP pilot and use actual feedback to decide what comes next.

## Initial field-status model

Keep it small:

`ASSIGNED → IN_PROGRESS → FIELD_COMPLETE`

`CANCELLED` is separate.

Photo synchronization has its own state and must not be hidden inside WO field status.

A final `COMPLETE` presentation may be derived when field work is complete and required photos are confirmed synchronized; do not create extra durable WO states unless testing proves they are needed.

## Storage plan

Initial:

`Field Photo Prep Team - HNP / TEST / Work Orders`

During development, work orders and photos in this area are disposable.

If HNP accepts Team, decide then whether to:
- add paid Google storage;
- move to Google Workspace;
- use another managed storage backend;
- export/transfer into HNP-controlled storage;
- offer managed photo retention as a paid service.

Do not build those options before they are needed.

## Keep out of the initial Team build

- route optimization;
- payroll;
- invoicing;
- contractor payment calculation;
- accounting;
- OCR;
- AI photo classification;
- video;
- continuous location tracking;
- employee time tracking;
- iOS;
- public marketplace rollout;
- complex reporting;
- client billing tiers;
- permanent in-app photo library;
- extra user roles without a demonstrated need.

## Finish-line definition

The first Team version succeeds when:

**The office can assign the right WO to the right contractor, the contractor can safely complete photo work without internet, the photos synchronize later without loss or duplication, and the office can see exactly what is finished and what is still waiting.**
