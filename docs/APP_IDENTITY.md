# Field Photo Prep Team — Android App Identity

## Purpose

Keep Field Photo Prep Team completely separate from the existing Field Photo Prep V1 app on the same Android phone.

## Reserved identities

### Team internal / development build

- App label: `Field Photo Prep Team Internal`
- Application ID: `com.inandout.fieldphotoprep.team.internal`
- Purpose: development, disposable HNP test work orders, device testing, and internal pilot work.

### Team production build

- App label: `Field Photo Prep Team`
- Application ID: `com.inandout.fieldphotoprep.team`
- Purpose: future production/HNP pilot release only after production-readiness gates are satisfied.

## Separation rule

The Team application IDs must remain distinct from the existing Field Photo Prep V1 identities:

- V1 production: `com.inandout.fieldphotoprep`
- V1 internal: `com.inandout.fieldphotoprep.internal`

Android therefore treats V1 and Team as separate applications with separate app-private storage, settings, databases, queues, permissions, and lifecycle state.

Team code must not read, migrate, overwrite, or delete V1 app-private data.

## Current build target

Build only the Team internal identity first. The production identity is reserved now so it cannot be accidentally reused later, but no production Team APK is required yet.
