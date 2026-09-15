package com.inandout.fieldphotoprep.team.internal;

import static org.junit.Assert.assertEquals;

import android.content.Context;

import androidx.room.Room;

import org.junit.After;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.RuntimeEnvironment;
import org.robolectric.annotation.Config;

import java.util.Arrays;
import java.util.Collections;
import java.util.List;
import java.util.UUID;

@RunWith(RobolectricTestRunner.class)
@Config(sdk = 34)
public final class RoomAssignmentStoreTest {
    private final Context context = RuntimeEnvironment.getApplication();
    private final String databaseName = "room-assignment-" + UUID.randomUUID() + ".db";
    private TeamDatabase database;

    @After
    public void tearDown() {
        if (database != null) {
            database.close();
        }
        context.deleteDatabase(databaseName);
    }

    @Test
    public void multipleAssignmentsSurviveDatabaseCloseAndReopen() {
        SupabaseApi.AuthSession session = session("user-a", "org-a");
        openDatabase();
        RoomAssignmentStore store = new RoomAssignmentStore(database.cachedWorkOrderDao());
        store.replace(
                session,
                Arrays.asList(
                        workOrder("wo-1", "run-1", "WO-1", "user-a", "org-a"),
                        workOrder("wo-2", "run-2", "WO-2", "user-a", "org-a")),
                1234L);
        database.close();
        database = null;

        openDatabase();
        RoomAssignmentStore reopened = new RoomAssignmentStore(database.cachedWorkOrderDao());
        List<SupabaseApi.WorkOrder> loaded = reopened.load(session);

        assertEquals(2, loaded.size());
        assertEquals("wo-1", loaded.get(0).id);
        assertEquals("wo-2", loaded.get(1).id);
    }

    @Test
    public void cacheIsIsolatedByAuthenticatedOwnerAndOrganization() {
        SupabaseApi.AuthSession userA = session("user-a", "org-a");
        SupabaseApi.AuthSession userB = session("user-b", "org-a");
        openDatabase();
        RoomAssignmentStore store = new RoomAssignmentStore(database.cachedWorkOrderDao());

        store.replace(
                userA,
                Collections.singletonList(workOrder("wo-a", "run-a", "WO-A", "user-a", "org-a")),
                1L);
        store.replace(
                userB,
                Collections.singletonList(workOrder("wo-b", "run-b", "WO-B", "user-b", "org-a")),
                2L);

        assertEquals(1, store.load(userA).size());
        assertEquals("wo-a", store.load(userA).get(0).id);
        assertEquals(1, store.load(userB).size());
        assertEquals("wo-b", store.load(userB).get(0).id);
    }

    @Test
    public void replacingOneUsersSnapshotDoesNotEraseAnotherUsersCache() {
        SupabaseApi.AuthSession userA = session("user-a", "org-a");
        SupabaseApi.AuthSession userB = session("user-b", "org-a");
        openDatabase();
        RoomAssignmentStore store = new RoomAssignmentStore(database.cachedWorkOrderDao());

        store.replace(
                userA,
                Collections.singletonList(workOrder("wo-a", "run-a", "WO-A", "user-a", "org-a")),
                1L);
        store.replace(
                userB,
                Collections.singletonList(workOrder("wo-b", "run-b", "WO-B", "user-b", "org-a")),
                2L);
        store.replace(userA, Collections.emptyList(), 3L);

        assertEquals(0, store.load(userA).size());
        assertEquals(1, store.load(userB).size());
        assertEquals("wo-b", store.load(userB).get(0).id);
    }

    private void openDatabase() {
        database = Room.databaseBuilder(context, TeamDatabase.class, databaseName)
                .allowMainThreadQueries()
                .build();
    }

    private static SupabaseApi.AuthSession session(String userId, String organizationId) {
        return new SupabaseApi.AuthSession(
                "access",
                "refresh",
                userId,
                userId + "@example.invalid",
                "CONTRACTOR",
                organizationId,
                0L);
    }

    private static SupabaseApi.WorkOrder workOrder(
            String workOrderId,
            String runId,
            String woNumber,
            String assignedUserId,
            String organizationId) {
        return new SupabaseApi.WorkOrder(
                workOrderId,
                organizationId,
                runId,
                1,
                woNumber,
                "100 Test Rd",
                "Inspection",
                "Test instructions",
                "2026-09-16",
                "ASSIGNED",
                assignedUserId,
                "",
                "",
                "2026-09-15T12:00:00Z",
                "",
                "",
                "2026-09-15T12:00:00Z");
    }
}
