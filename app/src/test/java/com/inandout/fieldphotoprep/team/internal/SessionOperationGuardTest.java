package com.inandout.fieldphotoprep.team.internal;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicReference;

public final class SessionOperationGuardTest {
    @Test
    public void refreshReturningAfterSignOutCannotSaveOrReopenWork() throws Exception {
        SessionOperationGuard guard = new SessionOperationGuard();
        AtomicReference<String> credential = new AtomicReference<>("old-session");
        CountDownLatch requestStarted = new CountDownLatch(1);
        CountDownLatch responseReady = new CountDownLatch(1);
        ExecutorService worker = Executors.newSingleThreadExecutor();
        long refresh = guard.capture();
        try {
            Future<Boolean> saved = worker.submit(() -> {
                requestStarted.countDown();
                if (!responseReady.await(5, TimeUnit.SECONDS)) {
                    throw new AssertionError("Refresh response was not released.");
                }
                return guard.runIfCurrent(refresh, () -> credential.set("rotated-session"));
            });
            assertTrue(requestStarted.await(5, TimeUnit.SECONDS));
            guard.invalidate(() -> credential.set(null));
            responseReady.countDown();

            assertFalse(saved.get(5, TimeUnit.SECONDS));
            assertEquals(null, credential.get());
            assertFalse(guard.isCurrent(refresh));
        } finally {
            responseReady.countDown();
            worker.shutdownNow();
        }
    }

    @Test
    public void oldAccountFailureCannotClearNewAccountsCredentials() {
        SessionOperationGuard guard = new SessionOperationGuard();
        AtomicReference<String> credential = new AtomicReference<>("account-a");
        long oldLogin = guard.capture();
        long newLogin = guard.invalidate(() -> credential.set("account-b"));

        assertFalse(guard.runIfCurrent(oldLogin, () -> credential.set(null)));
        assertEquals("account-b", credential.get());
        assertTrue(guard.isCurrent(newLogin));
    }

    @Test
    public void activityDestructionDiscardsCallbacksButPreservesRestartSession() {
        SessionOperationGuard guard = new SessionOperationGuard();
        AtomicReference<String> credential = new AtomicReference<>("saved-session");
        long operation = guard.capture();

        guard.invalidate(() -> { });

        assertFalse(guard.runIfCurrent(operation, () -> credential.set("stale-session")));
        assertEquals("saved-session", credential.get());
    }
}
