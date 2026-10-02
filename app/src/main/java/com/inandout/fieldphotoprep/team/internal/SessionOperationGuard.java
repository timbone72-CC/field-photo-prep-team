package com.inandout.fieldphotoprep.team.internal;

/** Prevents an old login/refresh from restoring access after sign-out. */
final class SessionOperationGuard {
    private long generation;

    synchronized long capture() {
        return generation;
    }

    synchronized boolean isCurrent(long operation) {
        return operation == generation;
    }

    // Credential writes and invalidation share the lock: a stale write can
    // never land after sign-out has cleared the reusable session.
    synchronized boolean runIfCurrent(long operation, Runnable action) {
        if (operation != generation) {
            return false;
        }
        action.run();
        return true;
    }

    synchronized long invalidate(Runnable action) {
        generation++;
        action.run();
        return generation;
    }
}
