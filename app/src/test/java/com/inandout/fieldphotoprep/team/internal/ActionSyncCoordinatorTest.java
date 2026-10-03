package com.inandout.fieldphotoprep.team.internal;

import static org.junit.Assert.*;

import android.content.Context;

import androidx.room.Room;

import org.junit.*;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.RuntimeEnvironment;
import org.robolectric.annotation.Config;

import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicInteger;

@RunWith(RobolectricTestRunner.class)
@Config(sdk = 34)
public class ActionSyncCoordinatorTest {
    TeamDatabase db;
    CachedWorkOrderDao dao;
    SessionCoordinator sessions;
    SupabaseApi.AuthSession owner = OfflineActionTest.session("a", "org");

    @Before
    public void setup() {
        Context c = RuntimeEnvironment.getApplication();
        db = Room.inMemoryDatabaseBuilder(c, TeamDatabase.class).allowMainThreadQueries().build();
        dao = db.cachedWorkOrderDao();
        new RoomAssignmentStore(dao)
                .replace(
                        owner,
                        List.of(OfflineActionTest.wo("1", "i-1"), OfflineActionTest.wo("2", "i-2")),
                        1);
        c.getSharedPreferences(SecureSessionStore.PREFERENCES_NAME, Context.MODE_PRIVATE)
                .edit()
                .clear()
                .commit();
        SecureSessionStore store =
                new SecureSessionStore(
                        c,
                        new SecureSessionStore.Crypto() {
                            public byte[] encrypt(byte[] b) {
                                return b;
                            }

                            public byte[] decrypt(byte[] b) {
                                return b;
                            }
                        });
        sessions = new SessionCoordinator(store, t -> owner);
        sessions.install(sessions.beginLogin(), owner);
    }

    @After
    public void close() {
        db.close();
    }

    FieldAction queue(String wo, String kind, String time) {
        return dao.createAction(owner, wo, "run-" + wo, kind, time);
    }

    @Test
    public void timeoutReplaysSameUuidAndDoesNotSendFinishAheadOfStart() {
        FieldAction start = queue("1", "START", "2026-10-03T12:00:00Z");
        queue("1", "COMPLETE", "2026-10-03T12:01:00Z");
        AtomicInteger attempts = new AtomicInteger();
        List<String> ids = new ArrayList<>();
        ActionSyncCoordinator sync =
                new ActionSyncCoordinator(
                        dao,
                        sessions,
                        (token, a) -> {
                            ids.add(a.actionId);
                            if (attempts.getAndIncrement() == 0)
                                throw new java.io.IOException("response lost");
                            return OfflineActionTest.result(
                                    a, "START".equals(a.kind) ? "IN_PROGRESS" : "FIELD_COMPLETE");
                        });
        assertEquals(ActionSyncCoordinator.Outcome.RETRY, sync.drain("a", "org", () -> false));
        assertEquals(List.of(start.actionId), ids);
        assertEquals(ActionSyncCoordinator.Outcome.DONE, sync.drain("a", "org", () -> false));
        assertEquals(start.actionId, ids.get(1));
        assertEquals(3, ids.size());
        assertEquals("ACCEPTED", dao.action(start.actionId).state);
    }

    @Test
    public void conflictBlocksItsDependentFinishAndAllowsUnrelatedWork() {
        FieldAction start = queue("1", "START", "2026-10-03T12:00:00Z");
        queue("1", "COMPLETE", "2026-10-03T12:01:00Z");
        FieldAction other = queue("2", "START", "2026-10-03T12:00:00Z");
        List<String> submitted = new ArrayList<>();
        ActionSyncCoordinator sync =
                new ActionSyncCoordinator(
                        dao,
                        sessions,
                        (t, a) -> {
                            submitted.add(a.actionId);
                            return a.workOrderId.equals("1")
                                    ? new FieldActionResult(
                                            a,
                                            "{\"action_id\":\""
                                                    + a.actionId
                                                    + "\",\"outcome\":\"CONFLICT\",\"reason\":\"CANCELLED\"}")
                                    : OfflineActionTest.result(a, "IN_PROGRESS");
                        });
        assertEquals(ActionSyncCoordinator.Outcome.DONE, sync.drain("a", "org", () -> false));
        assertEquals(List.of(start.actionId, other.actionId), submitted);
        assertEquals("CONFLICT", dao.action(start.actionId).state);
        assertEquals("ACCEPTED", dao.action(other.actionId).state);
        sync.drain("a", "org", () -> false);
        assertEquals(2, submitted.size());
    }

    @Test
    public void signOutDuringSubmissionPreservesOriginalResultAndStopsFurtherSends() {
        FieldAction start = queue("1", "START", "2026-10-03T12:00:00Z");
        FieldAction finish = queue("1", "COMPLETE", "2026-10-03T12:01:00Z");
        AtomicInteger submitted = new AtomicInteger();
        ActionSyncCoordinator sync =
                new ActionSyncCoordinator(
                        dao,
                        sessions,
                        (t, a) -> {
                            submitted.incrementAndGet();
                            sessions.signOut();
                            sessions.install(
                                    sessions.beginLogin(), OfflineActionTest.session("b", "org"));
                            return OfflineActionTest.result(a, "IN_PROGRESS");
                        });
        assertEquals(ActionSyncCoordinator.Outcome.PAUSED, sync.drain("a", "org", () -> false));
        assertEquals(1, submitted.get());
        assertEquals("ACCEPTED", dao.action(start.actionId).state);
        assertEquals("PENDING", dao.action(finish.actionId).state);
        assertEquals(ActionSyncCoordinator.Outcome.PAUSED, sync.drain("a", "org", () -> false));
        assertEquals("b", sessions.load().userId);
    }

    @Test
    public void workerStopBeforeSendLeavesQueueEligibleAndEmptyDrainDoesNotPurge() {
        FieldAction start = queue("1", "START", "2026-10-03T12:00:00Z");
        ActionSyncCoordinator sync =
                new ActionSyncCoordinator(
                        dao, sessions, (t, a) -> OfflineActionTest.result(a, "IN_PROGRESS"));
        assertEquals(ActionSyncCoordinator.Outcome.PAUSED, sync.drain("a", "org", () -> true));
        assertEquals("PENDING", dao.action(start.actionId).state);
        sync.drain("a", "org", () -> false);
        sync.drain("a", "org", () -> false);
        assertEquals(1, dao.actions("a", "org").size());
    }

    @Test
    public void protocolFailureStopsBlindRetries() {
        FieldAction start = queue("1", "START", "2026-10-03T12:00:00Z");
        AtomicInteger calls = new AtomicInteger();
        ActionSyncCoordinator sync =
                new ActionSyncCoordinator(
                        dao,
                        sessions,
                        (t, a) -> {
                            calls.incrementAndGet();
                            throw new SupabaseApi.ApiException(400, "malformed");
                        });
        assertEquals(ActionSyncCoordinator.Outcome.DEFECT, sync.drain("a", "org", () -> false));
        assertEquals(ActionSyncCoordinator.Outcome.DEFECT, sync.drain("a", "org", () -> false));
        assertEquals(1, calls.get());
        assertEquals("PROTOCOL_HTTP", dao.action(start.actionId).reason);
    }

    @Test
    public void serverRetryDelaySurvivesDrainAndPreventsEarlyResubmission() {
        FieldAction start = queue("1", "START", "2026-10-03T12:00:00Z");
        AtomicInteger calls = new AtomicInteger();
        ActionSyncCoordinator sync =
                new ActionSyncCoordinator(
                        dao,
                        sessions,
                        (t, a) -> {
                            calls.incrementAndGet();
                            throw new SupabaseApi.ApiException(429, "slow down", 60000);
                        });
        assertEquals(ActionSyncCoordinator.Outcome.RETRY, sync.drain("a", "org", () -> false));
        assertTrue(dao.action(start.actionId).retryNotBefore > System.currentTimeMillis());
        assertEquals(ActionSyncCoordinator.Outcome.RETRY, sync.drain("a", "org", () -> false));
        assertEquals(1, calls.get());
    }

    @Test
    public void handoffBlocksPendingAndConflictedActionsUntilConfirmed() throws Exception {
        FieldAction start = queue("1", "START", "2026-10-03T12:00:00Z");
        ActionSyncCoordinator sync =
                new ActionSyncCoordinator(
                        dao, sessions, (t, a) -> OfflineActionTest.result(a, "IN_PROGRESS"));
        assertThrows(IllegalStateException.class, () -> sync.requireHandoffReady("a", "org", "1"));
        sync.requireHandoffReady("b", "org", "1");
        sync.drain("a", "org", () -> false);
        sync.requireHandoffReady("a", "org", "1");
        FieldAction finish = queue("1", "COMPLETE", "2026-10-03T12:01:00Z");
        dao.markRunConflict("a", "org", "1", "run-1", "ASSIGNMENT_CHANGED");
        assertThrows(IllegalStateException.class, () -> sync.requireHandoffReady("a", "org", "1"));
        assertEquals("CONFLICT", dao.action(finish.actionId).state);
    }

    @Test
    public void recoveryDisablesSubmissionsWithoutChangingEvidence() {
        FieldAction start = queue("1", "START", "2026-10-03T12:00:00Z");
        ActionSyncCoordinator sync =
                new ActionSyncCoordinator(
                        dao,
                        sessions,
                        (t, a) -> {
                            throw new AssertionError("Recovery sent an action");
                        },
                        false);
        assertEquals(ActionSyncCoordinator.Outcome.PAUSED, sync.drain("a", "org", () -> false));
        assertEquals("PENDING", dao.action(start.actionId).state);
        assertEquals(0, dao.action(start.actionId).attempts);
    }

    @Test
    public void foregroundAndWorkerCannotClaimSameActionTogether() throws Exception {
        FieldAction start = queue("1", "START", "2026-10-03T12:00:00Z");
        AtomicInteger calls = new AtomicInteger();
        CountDownLatch entered = new CountDownLatch(1), done = new CountDownLatch(1);
        ActionSyncCoordinator sync =
                new ActionSyncCoordinator(
                        dao,
                        sessions,
                        (t, a) -> {
                            calls.incrementAndGet();
                            entered.countDown();
                            assertTrue(done.await(5, TimeUnit.SECONDS));
                            return OfflineActionTest.result(a, "IN_PROGRESS");
                        });
        ExecutorService e = Executors.newFixedThreadPool(2);
        Future<?> first = e.submit(() -> sync.drain("a", "org", () -> false));
        assertTrue(entered.await(5, TimeUnit.SECONDS));
        Future<?> second = e.submit(() -> sync.drain("a", "org", () -> false));
        done.countDown();
        first.get(5, TimeUnit.SECONDS);
        second.get(5, TimeUnit.SECONDS);
        e.shutdownNow();
        assertEquals(1, calls.get());
        assertEquals("ACCEPTED", dao.action(start.actionId).state);
    }
}
