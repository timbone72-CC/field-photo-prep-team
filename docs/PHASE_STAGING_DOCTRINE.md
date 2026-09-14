# Field Photo Prep Team Phase Staging Doctrine

Status: **GOVERNED PROJECT OPERATING RULE**

## Mandatory reread before using this doctrine

Before making a phase-transition decision, deciding how far to implement before the next phone test, staging a physical-device gate, or resuming work after device evidence:

1. read `AGENTS.md` completely;
2. read the relevant current and next phase in `docs/ROADMAP.md` completely;
3. read `CHANGE_CONTROL_CONTRACT.md`;
4. read `TESTING_CONTRACT.md`;
5. read `INTEGRATION_CONTRACT.md` when the phase touches Supabase/Auth/RLS, Room/offline state, reassignment, camera/photos, background sync, remote storage, upload, retry, or cleanup;
6. read the exact device-gate plan for that phase if one exists.

Do not replace these rereads with memory, a chat summary, previous-session notes, or an earlier read.

If the next phase is not fully planned in `docs/ROADMAP.md`, **STOP. Planning is the next task.**

## Purpose

Team is developed in large, evidence-based stages rather than alternating constantly between tiny code changes and repeated phone checks.

Default pattern:

`plan the phase fully → build everything that can be honestly proven without the phone → stage at the next genuine physical-device boundary → run the smallest required reality gate → accept the evidence → adjust only where reality requires it → continue`

A phone gate is an evidence checkpoint, not an automatic reason to stop development after every small slice.

## Straight-line development rule

Within an approved phase:

- settled product decisions stay settled unless evidence contradicts them;
- use the largest safe testable implementation chunk practical;
- use focused automated tests while developing;
- use one final complete automated suite on the final runtime head;
- do not repeatedly ask for authorization already granted by the approved scope;
- do not stop for a phone check when the next safe work does not depend on phone evidence;
- do not invent real-device, Android lifecycle, camera, network, background-work, Supabase, or remote-storage behavior that only a reality gate can prove;
- do not continue past a boundary where the next design decision materially depends on unverified reality.

## Phase-plan gate

Before runtime implementation begins for a phase, the roadmap must define:

- user-visible workflow;
- authority boundaries;
- offline/restart behavior where applicable;
- conflict/reassignment/cancellation behavior where applicable;
- protected identity/data rules;
- failure behavior;
- implementation boundaries;
- automated verification;
- physical-device/provider gate where needed;
- completion criteria.

If any material item is missing, implementation is blocked until planning is completed and approved.

## What may be decided inside an approved phase

Narrow implementation details may be decided without reopening product planning when they:

- stay inside documented behavior;
- do not expand scope;
- do not weaken authorization, offline preservation, photo protection, identity, duplicate prevention, or uncertainty handling;
- are covered by the planned test boundary;
- do not introduce a new unproven device/provider assumption.

Examples: helper shape, local naming, a narrow test seam, or harmless internal refactoring required by the approved implementation.

## What requires stopping/replanning

Stop the affected path when:

- a real device/provider/backend result contradicts a roadmap assumption;
- continuing requires guessing about Android, connectivity, CameraX, background execution, Supabase authorization, or remote storage;
- scope must expand;
- a new Level 3 behavior appears outside the approved plan;
- a required focused/final test fails;
- protected local work/photos could be lost, misattributed, or silently overwritten;
- an upload/result becomes ambiguous and the next action would be a blind retry.

The stop is targeted. Independent work may continue only when it does not depend on the failed assumption and cannot hide or worsen the problem.

## Staging standard at a genuine device boundary

Before a device gate, record:

1. exact branch and runtime SHA;
2. exact final automated-tested head;
3. final CI result and artifact identity where applicable;
4. current implementation/impact record;
5. roadmap status;
6. rollback point;
7. the smallest straight-line device test plan;
8. PASS/BLOCKED/FAIL criteria;
9. explicit stop conditions;
10. which observations will be accepted as durable evidence for the next phase.

Do not create a large audit ritual when the phase added little risk. Verification must remain proportional.

## After a device gate

- record the result once;
- do not rerun it merely for reassurance;
- if PASS, use the evidence to continue as far as safely possible;
- if BLOCKED, preserve the tested runtime and identify the missing external/device condition;
- if FAIL, fix the specific failed assumption/behavior before continuing the dependent path;
- update the roadmap if the evidence changes the planned behavior or next boundary.

## FPP inheritance

This doctrine intentionally carries forward the successful FPP development pattern: build to evidence, stop only where reality is required, and keep the repository instructions strong enough that future agents cannot silently skip the plan.

## Governing principle

**Plan before coding. Build to evidence, not fear. Stop where reality is required, not where another safety prompt could be invented.**
